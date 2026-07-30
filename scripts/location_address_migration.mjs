export const targetProjectId = 'mobilisation-sante';

export const migratableStatuses = new Set([
  'verified_official',
  'verified_cross_source',
]);

export const knownStatuses = new Set([
  ...migratableStatuses,
  'needs_confirmation',
  'not_found',
]);

const addressKeys = [
  'addressLine1',
  'addressLine2',
  'postalCode',
  'city',
  'country',
  'fullAddress',
  'latitude',
  'longitude',
  'addressStatus',
  'addressSourceLabel',
  'addressSourceUrl',
  'addressSecondSourceLabel',
  'addressSecondSourceUrl',
  'addressVerifiedAt',
  'addressNotes',
];

export function assertTargetProject(projectId) {
  if (projectId !== targetProjectId) {
    throw new Error(
      `Projet Firebase refusé: ${projectId || '<absent>'}. `
      + `Projet attendu: ${targetProjectId}.`,
    );
  }
}

export function buildMigrationPlan({projectId, rows, documents}) {
  assertTargetProject(projectId);
  const remoteById = new Map(
    documents.map((document) => [document.id, document.data]),
  );
  const rowIds = new Set(rows.map((row) => row.location_id));
  const entries = [];

  for (const row of rows) {
    if (!knownStatuses.has(row.address_status)) {
      throw new Error(
        `Statut inconnu pour ${row.location_id}: ${row.address_status}`,
      );
    }
    const remote = remoteById.get(row.location_id);
    if (!remote) {
      entries.push(baseEntry(row, 'absent_firestore'));
      continue;
    }
    const metadataMatches = metadataIsCompatible(remote, row);
    if (!metadataMatches) {
      entries.push(baseEntry(row, 'correspondance_ambigue', remote));
      continue;
    }
    if (row.address_status === 'needs_confirmation') {
      entries.push(baseEntry(row, 'needs_confirmation', remote));
      continue;
    }
    if (row.address_status === 'not_found') {
      entries.push(baseEntry(row, 'not_found', remote));
      continue;
    }

    const desired = addressFieldsFromRow(row);
    const additions = {};
    const preservedFields = [];
    const conflicts = [];
    for (const [key, value] of Object.entries(desired)) {
      if (!hasValue(value)) continue;
      const current = remote[key];
      if (!hasValue(current)) {
        additions[key] = value;
      } else if (sameValue(current, value)) {
        preservedFields.push(key);
      } else {
        conflicts.push(key);
      }
    }
    const category = conflicts.length > 0
      ? 'complet_mais_different'
      : Object.keys(additions).length > 0
      ? 'incomplet_migrable'
      : 'complet_identique';
    entries.push({
      ...baseEntry(row, category, remote),
      additions,
      proposedFields: Object.keys(additions),
      preservedFields,
      conflicts,
    });
  }

  for (const document of documents) {
    if (!rowIds.has(document.id)) {
      entries.push({
        id: document.id,
        name: stringOrNull(document.data.name),
        category: 'absent_registre',
        ...presence(document.data),
        proposedFields: [],
        preservedFields: [],
        conflicts: [],
        additions: {},
      });
    }
  }

  return {
    projectId,
    entries,
    summary: summarize(entries),
  };
}

export function writableChanges(plan) {
  return plan.entries
    .filter((entry) => entry.category === 'incomplet_migrable')
    .map((entry) => ({id: entry.id, fields: entry.additions}));
}

export function sanitizePlan(plan) {
  return {
    projectId: plan.projectId,
    summary: plan.summary,
    entries: plan.entries.map(({additions: _, ...entry}) => entry),
  };
}

function baseEntry(row, category, remote = {}) {
  return {
    id: row.location_id,
    name: row.display_name || row.name,
    category,
    verificationStatus: row.address_status,
    ...presence(remote),
    proposedFields: [],
    preservedFields: [],
    conflicts: [],
    additions: {},
  };
}

function presence(data) {
  return {
    legacyAddressPresent: hasValue(data.address),
    structuredAddressPresent: hasValue(data.addressLine1),
    postalCodePresent: hasValue(data.postalCode),
    cityPresent: hasValue(data.city),
    coordinatesPresent: hasValue(data.latitude) && hasValue(data.longitude),
    contactNamePresent: hasValue(data.contactName),
    contactPhonePresent: hasValue(data.contactPhone),
  };
}

function metadataIsCompatible(remote, row) {
  const nameMatches = remote.name === row.name
    || remote.name === row.display_name;
  const typeMatches = remote.type === row.previous_location_type
    || remote.type === row.location_type;
  const group = remote.group ?? remote.territorialGroup;
  return nameMatches && typeMatches && group === row.territorial_group;
}

function addressFieldsFromRow(row) {
  return {
    addressLine1: row.address_line_1 || null,
    addressLine2: row.address_line_2 || null,
    postalCode: row.postal_code || null,
    city: row.city || null,
    country: row.country || 'France',
    fullAddress: row.full_address || null,
    latitude: numberOrNull(row.latitude),
    longitude: numberOrNull(row.longitude),
    addressStatus: row.address_status,
    addressSourceLabel: row.source_label || null,
    addressSourceUrl: row.source_url || null,
    addressSecondSourceLabel: row.second_source_label || null,
    addressSecondSourceUrl: row.second_source_url || null,
    addressVerifiedAt: row.verified_at
      ? new Date(`${row.verified_at}T00:00:00Z`)
      : null,
    addressNotes: row.notes || null,
  };
}

function summarize(entries) {
  const categories = {};
  let structuredComplete = 0;
  let registryMatches = 0;
  for (const entry of entries) {
    categories[entry.category] = (categories[entry.category] ?? 0) + 1;
    if (entry.category !== 'absent_registre') registryMatches++;
    if (
      entry.structuredAddressPresent
      && entry.postalCodePresent
      && entry.cityPresent
      && entry.coordinatesPresent
    ) {
      structuredComplete++;
    }
  }
  return {
    firestoreDocuments: entries.filter(
      (entry) => entry.category !== 'absent_firestore',
    ).length,
    registryMatches,
    structuredComplete,
    categories,
  };
}

function hasValue(value) {
  return value !== null
    && value !== undefined
    && (!(typeof value === 'string') || value.trim().length > 0);
}

function sameValue(left, right) {
  if (left instanceof Date && right instanceof Date) {
    return left.getTime() === right.getTime();
  }
  if (left?.toDate instanceof Function && right instanceof Date) {
    return left.toDate().getTime() === right.getTime();
  }
  return left === right;
}

function numberOrNull(value) {
  if (!hasValue(value)) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function stringOrNull(value) {
  return typeof value === 'string' && value.trim() ? value : null;
}

export function parseCsv(input) {
  const result = [];
  let row = [];
  let field = '';
  let quoted = false;
  for (let index = 0; index < input.length; index++) {
    const char = input[index];
    if (quoted && char === '"' && input[index + 1] === '"') {
      field += '"';
      index++;
    } else if (char === '"') {
      quoted = !quoted;
    } else if (!quoted && char === ',') {
      row.push(field);
      field = '';
    } else if (!quoted && (char === '\n' || char === '\r')) {
      if (char === '\r' && input[index + 1] === '\n') index++;
      row.push(field);
      if (row.some((value) => value.length > 0)) result.push(row);
      row = [];
      field = '';
    } else {
      field += char;
    }
  }
  if (field || row.length) {
    row.push(field);
    result.push(row);
  }
  const [header, ...lines] = result;
  return lines.map((values) =>
    Object.fromEntries(header.map((key, index) => [key, values[index] ?? ''])),
  );
}
