const RPPS_PATTERN = /^\d{11}$/;
const STATUSES = new Set([
  'verified',
  'not_found',
  'invalid',
  'unavailable',
]);

export class ProfessionalRppsVerificationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ProfessionalRppsVerificationError';
    this.code = code;
  }
}

export async function verifyProfessionalRpps({callerUid, data, services}) {
  requireCaller(callerUid);
  if (!services || typeof services.verifyRpps !== 'function') {
    throw new ProfessionalRppsVerificationError(
      'internal',
      'Service de vérification RPPS indisponible.',
    );
  }

  const rawRpps = data?.rpps;
  let serviceResult;
  try {
    serviceResult = await services.verifyRpps(rawRpps);
  } catch {
    return unavailableResult(rawRpps);
  }
  return safeResult(serviceResult, rawRpps);
}

function requireCaller(callerUid) {
  if (typeof callerUid !== 'string' || callerUid.trim() === '') {
    throw new ProfessionalRppsVerificationError(
      'unauthenticated',
      'Authentification requise.',
    );
  }
}

function safeResult(result, rawRpps) {
  if (
    !isPlainObject(result)
    || !STATUSES.has(result.status)
    || result.source !== 'ans_rpps'
    || typeof result.rpps !== 'string'
  ) {
    return unavailableResult(rawRpps);
  }

  if (result.status === 'verified') {
    if (
      !RPPS_PATTERN.test(result.rpps)
      || !hasText(result.firstName)
      || !hasText(result.lastName)
      || !hasText(result.professionCode)
      || !hasText(result.professionLabel)
    ) {
      return unavailableResult(rawRpps);
    }
    return normalizedResult('verified', result.rpps, {
      firstName: result.firstName.trim(),
      lastName: result.lastName.trim(),
      professionCode: result.professionCode.trim(),
      professionLabel: result.professionLabel.trim(),
    });
  }

  const hasValidRpps = RPPS_PATTERN.test(result.rpps);
  if (
    (result.status === 'invalid' && hasValidRpps)
    || (result.status !== 'invalid' && !hasValidRpps)
  ) {
    return unavailableResult(rawRpps);
  }
  return normalizedResult(result.status, result.rpps);
}

function unavailableResult(rawRpps) {
  const rpps = typeof rawRpps === 'string' ? rawRpps.trim() : '';
  return normalizedResult('unavailable', RPPS_PATTERN.test(rpps) ? rpps : '');
}

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

function hasText(value) {
  return typeof value === 'string' && value.trim() !== '';
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
