const DEFAULT_BASE_URL = 'https://gateway.api.esante.gouv.fr/fhir/v2';
const DEFAULT_TIMEOUT_MS = 8_000;
const RPPS_PATTERN = /^\d{11}$/;

const IDENTIFIER_TYPE_SYSTEM =
  'https://hl7.fr/ig/fhir/core/CodeSystem/fr-core-cs-v2-0203';
const RPPS_IDENTIFIER_SYSTEM = 'https://rpps.esante.gouv.fr';
const PROFESSION_SYSTEM =
  'https://mos.esante.gouv.fr/NOS/TRE_G15-ProfessionSante/FHIR/'
  + 'TRE-G15-ProfessionSante';

export const ANS_RPPS_FHIR_ENDPOINT = `${DEFAULT_BASE_URL}/Practitioner`;

function normalizedResult(status, rpps, details = {}) {
  return Object.freeze({
    status,
    rpps,
    firstName: details.firstName ?? '',
    lastName: details.lastName ?? '',
    professionCode: details.professionCode ?? '',
    professionLabel: details.professionLabel ?? '',
    source: 'ans_rpps',
  });
}

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function hasRppsType(identifier) {
  const codings = identifier?.type?.coding;
  return Array.isArray(codings) && codings.some(
    (coding) => coding?.system === IDENTIFIER_TYPE_SYSTEM
      && coding?.code === 'RPPS',
  );
}

function findRppsIdentifier(practitioner, requestedRpps) {
  if (!Array.isArray(practitioner.identifier)) return null;
  return practitioner.identifier.find(
    (identifier) => isRecord(identifier)
      && identifier.value === requestedRpps
      && (
        hasRppsType(identifier)
        || identifier.system === RPPS_IDENTIFIER_SYSTEM
      ),
  ) ?? null;
}

function findExerciseName(practitioner) {
  if (!Array.isArray(practitioner.name)) return null;
  const usableNames = practitioner.name.filter(
    (name) => isRecord(name)
      && typeof name.family === 'string'
      && name.family.trim() !== ''
      && Array.isArray(name.given)
      && name.given.some(
        (given) => typeof given === 'string' && given.trim() !== '',
      ),
  );
  const name = usableNames.find((candidate) => candidate.use === 'official')
    ?? usableNames.find((candidate) => candidate.use === 'usual')
    ?? usableNames[0];
  if (!name) return null;

  return {
    firstName: name.given
      .filter((given) => typeof given === 'string' && given.trim() !== '')
      .map((given) => given.trim())
      .join(' '),
    lastName: name.family.trim(),
  };
}

function findProfession(practitioner) {
  if (!Array.isArray(practitioner.qualification)) return null;
  for (const qualification of practitioner.qualification) {
    const codings = qualification?.code?.coding;
    if (!Array.isArray(codings)) continue;
    const profession = codings.find(
      (coding) => coding?.system === PROFESSION_SYSTEM
        && typeof coding.code === 'string'
        && coding.code.trim() !== '',
    );
    if (!profession) continue;

    const label = typeof profession.display === 'string'
      && profession.display.trim() !== ''
      ? profession.display.trim()
      : typeof qualification.code.text === 'string'
        ? qualification.code.text.trim()
        : '';
    if (label === '') return null;
    return {
      professionCode: profession.code.trim(),
      professionLabel: label,
    };
  }
  return null;
}

function parseBundle(bundle, requestedRpps) {
  if (
    !isRecord(bundle)
    || bundle.resourceType !== 'Bundle'
    || bundle.type !== 'searchset'
  ) {
    return normalizedResult('unavailable', requestedRpps);
  }
  if (bundle.total !== undefined && !Number.isInteger(bundle.total)) {
    return normalizedResult('unavailable', requestedRpps);
  }
  if (bundle.entry !== undefined && !Array.isArray(bundle.entry)) {
    return normalizedResult('unavailable', requestedRpps);
  }

  const entries = bundle.entry ?? [];
  if (bundle.total === 0 && entries.length === 0) {
    return normalizedResult('not_found', requestedRpps);
  }
  if (entries.length === 0) {
    return bundle.total === undefined
      ? normalizedResult('not_found', requestedRpps)
      : normalizedResult('unavailable', requestedRpps);
  }
  if (bundle.total > 1 || entries.length > 1) {
    return normalizedResult('unavailable', requestedRpps);
  }

  const practitioner = entries[0]?.resource;
  if (!isRecord(practitioner) || practitioner.resourceType !== 'Practitioner') {
    return normalizedResult('unavailable', requestedRpps);
  }

  const identifier = findRppsIdentifier(practitioner, requestedRpps);
  const name = findExerciseName(practitioner);
  const profession = findProfession(practitioner);
  if (!identifier || !name || !profession) {
    return normalizedResult('unavailable', requestedRpps);
  }

  return normalizedResult('verified', identifier.value, {
    ...name,
    ...profession,
  });
}

/**
 * Vérifie un RPPS dans les données publiques de l'Annuaire Santé FHIR V2.
 * Le client HTTP est injectable afin que les tests n'effectuent aucun appel réseau.
 */
export async function verifyRpps(rawRpps, {
  apiKey = process.env.ESANTE_API_KEY,
  baseUrl = DEFAULT_BASE_URL,
  fetchImpl = globalThis.fetch,
  timeoutMs = DEFAULT_TIMEOUT_MS,
} = {}) {
  const rpps = typeof rawRpps === 'string' ? rawRpps.trim() : '';
  if (!RPPS_PATTERN.test(rpps)) {
    return normalizedResult('invalid', rpps);
  }
  if (
    typeof apiKey !== 'string'
    || apiKey.trim() === ''
    || typeof fetchImpl !== 'function'
    || !Number.isFinite(timeoutMs)
    || timeoutMs <= 0
  ) {
    return normalizedResult('unavailable', rpps);
  }

  let endpoint;
  try {
    endpoint = new URL('Practitioner', `${baseUrl.replace(/\/$/, '')}/`);
    endpoint.searchParams.set('identifier', rpps);
    endpoint.searchParams.set('_count', '2');
  } catch {
    return normalizedResult('unavailable', rpps);
  }

  const abortController = new AbortController();
  const timeout = setTimeout(() => abortController.abort(), timeoutMs);
  try {
    const response = await fetchImpl(endpoint, {
      method: 'GET',
      headers: {
        Accept: 'application/fhir+json',
        'ESANTE-API-KEY': apiKey.trim(),
      },
      signal: abortController.signal,
    });
    if (!response?.ok) {
      return normalizedResult('unavailable', rpps);
    }

    let bundle;
    try {
      bundle = await response.json();
    } catch {
      return normalizedResult('unavailable', rpps);
    }
    return parseBundle(bundle, rpps);
  } catch {
    return normalizedResult('unavailable', rpps);
  } finally {
    clearTimeout(timeout);
  }
}
