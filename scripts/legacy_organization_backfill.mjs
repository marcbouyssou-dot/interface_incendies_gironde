import {parseResponsibleAccess} from '../functions/src/responsible_access.js';

export const legacyOrganizationBackfillProjectId = 'mobilisation-sante';
export const legacyOrganizationId = 'legacy-gironde';
export const legacyOrganizationPath = `organizations/${legacyOrganizationId}`;
export const legacyOrganizationBackfillBatchSize = 200;

export const legacyOrganizationValues = Object.freeze({
  name: 'Périmètre legacy Gironde',
  category: 'other',
  defaultVisibility: 'platform',
  active: true,
  schemaVersion: 1,
});

const membershipRoles = new Set([
  'organization_admin',
  'coordinator',
  'site_manager',
  'professional',
]);

export function resolveLegacyOrganizationBackfillExecution(
  commandArguments,
) {
  let projectId = null;
  let mode = null;
  for (let index = 0; index < commandArguments.length; index++) {
    const argument = commandArguments[index];
    if (argument === '--dry-run' || argument === '--apply-confirmed') {
      if (mode !== null) {
        throw new Error(
          'Utiliser --dry-run ou --apply-confirmed, jamais les deux.',
        );
      }
      mode = argument === '--dry-run' ? 'dry-run' : 'apply';
      continue;
    }
    if (argument === '--project') {
      if (projectId !== null || index + 1 >= commandArguments.length) {
        throw new Error('Le projet Firebase doit être fourni une seule fois.');
      }
      projectId = commandArguments[++index];
      continue;
    }
    if (argument.startsWith('--project=')) {
      if (projectId !== null) {
        throw new Error('Le projet Firebase doit être fourni une seule fois.');
      }
      projectId = argument.slice('--project='.length);
      continue;
    }
    throw new Error(`Argument refusé: ${argument}.`);
  }
  if (projectId !== legacyOrganizationBackfillProjectId) {
    throw new Error(
      `Projet Firebase refusé: ${projectId || '<absent>'}. `
      + `Projet attendu: ${legacyOrganizationBackfillProjectId}.`,
    );
  }
  if (mode === null) {
    throw new Error(
      'Un mode explicite est obligatoire: --dry-run ou --apply-confirmed.',
    );
  }
  return {mode, projectId};
}

export function buildLegacyOrganizationBackfillPlan({
  organizations = [],
  organizationMemberships = [],
  roles = [],
  platformAdministrators = [],
  volunteers = [],
  operations = [],
  mobilizations = [],
  missions = [],
  engagements = [],
  mobilizationAssignments = [],
  locations = [],
  isTimestamp = isFirestoreTimestamp,
}) {
  const organization = classifyLegacyOrganization({
    organizations,
    isTimestamp,
  });
  const memberships = classifyLegacyMemberships({
    organizationMemberships,
    roles,
    platformAdministrators,
    volunteers,
    isTimestamp,
  });
  const operationEntries = operations.map(classifyOperation);
  const operationSummary = summarizeOperations(operationEntries);
  const children = auditChildren({
    operations,
    mobilizations,
    missions,
    engagements,
    mobilizationAssignments,
    locations,
  });
  const blockers = {
    organization: organization.action === 'conflict' ? 1 : 0,
    malformedRoles: memberships.summary.malformedRoles,
    membershipConflicts: memberships.summary.conflicts,
    operationConflicts:
      operationSummary.conflicts + operationSummary.malformed,
  };
  const global = Object.values(blockers).some((count) => count > 0)
    ? 'NO-GO'
    : 'GO';
  return {
    organization,
    memberships,
    operations: operationEntries,
    children,
    summary: {
      global,
      blockers,
      organization: {
        create: organization.action === 'create' ? 1 : 0,
        unchanged: organization.action === 'unchanged' ? 1 : 0,
        conflict: organization.action === 'conflict' ? 1 : 0,
      },
      memberships: memberships.summary,
      operations: operationSummary,
      children: Object.fromEntries(
        Object.entries(children).map(([name, value]) => [name, value.summary]),
      ),
    },
  };
}

export function changesForLegacyOrganizationBackfill(plan) {
  if (plan.summary.global !== 'GO') {
    throw new Error('Backfill refusé: le diagnostic contient des conflits.');
  }
  return [
    ...(plan.organization.action === 'create'
      ? [{
          kind: 'organization',
          action: 'create',
          path: legacyOrganizationPath,
          values: legacyOrganizationValues,
        }]
      : []),
    ...plan.memberships.entries
      .filter((entry) => entry.action === 'create')
      .map((entry) => ({
        kind: 'membership',
        action: 'create',
        path: entry.path,
        values: entry.values,
      })),
    ...plan.operations
      .filter((entry) => entry.action === 'update')
      .map((entry) => ({
        kind: 'operation',
        action: 'update',
        path: `operations/${entry.id}`,
        values: {ownerOrganizationId: legacyOrganizationId},
      })),
  ];
}

export function materializeLegacyOrganizationChange({
  change,
  serverTimestamp,
}) {
  if (typeof serverTimestamp !== 'function') {
    throw new TypeError('Un timestamp serveur est requis.');
  }
  if (change.kind === 'operation') return change;
  const timestamp = serverTimestamp();
  return {
    ...change,
    values: {
      ...change.values,
      createdAt: timestamp,
      updatedAt: timestamp,
    },
  };
}

export async function runLegacyOrganizationBackfill({
  mode,
  readCollections,
  writeChanges,
  batchSize = legacyOrganizationBackfillBatchSize,
}) {
  if (!['dry-run', 'apply'].includes(mode)) {
    throw new Error('Mode de backfill invalide.');
  }
  if (typeof readCollections !== 'function') {
    throw new TypeError('Le reader Admin est requis.');
  }
  if (!Number.isInteger(batchSize) || batchSize < 1 || batchSize > 400) {
    throw new Error('Taille de batch invalide.');
  }
  const before = buildLegacyOrganizationBackfillPlan(
    await readCollections(),
  );
  if (mode === 'dry-run' || before.summary.global === 'NO-GO') {
    return {mode, before, after: null, writes: 0};
  }
  if (typeof writeChanges !== 'function') {
    throw new TypeError('Le writer Admin est requis en mode apply.');
  }
  const changes = changesForLegacyOrganizationBackfill(before);
  let writes = 0;
  for (let offset = 0; offset < changes.length; offset += batchSize) {
    const batch = changes.slice(offset, offset + batchSize);
    const written = await writeChanges(batch);
    writes += Number.isInteger(written) ? written : batch.length;
  }
  const after = buildLegacyOrganizationBackfillPlan(await readCollections());
  if (
    after.summary.global !== 'GO'
    || after.summary.organization.create !== 0
    || after.summary.memberships.create !== 0
    || after.summary.operations.toBackfill !== 0
  ) {
    throw new Error('La vérification post-backfill a échoué.');
  }
  return {mode, before, after, writes};
}

function classifyLegacyOrganization({organizations, isTimestamp}) {
  const matches = organizations.filter(
    (document) => document?.id === legacyOrganizationId,
  );
  if (matches.length === 0) {
    return {path: legacyOrganizationPath, action: 'create'};
  }
  if (matches.length !== 1) {
    return {
      path: legacyOrganizationPath,
      action: 'conflict',
      reason: 'duplicate_document',
    };
  }
  const data = matches[0]?.data;
  if (!isPlainObject(data)) {
    return conflictOrganization('invalid_structure');
  }
  for (const [field, expected] of Object.entries(legacyOrganizationValues)) {
    if (field === 'schemaVersion') {
      if (!Number.isInteger(data[field]) || data[field] < expected) {
        return conflictOrganization(`invalid_${field}`);
      }
    } else if (data[field] !== expected) {
      return conflictOrganization(`different_${field}`);
    }
  }
  if (
    (Object.hasOwn(data, 'id') && data.id !== legacyOrganizationId)
    || !isTimestamp(data.createdAt)
    || !isTimestamp(data.updatedAt)
  ) {
    return conflictOrganization('invalid_identity_or_timestamps');
  }
  return {path: legacyOrganizationPath, action: 'unchanged'};
}

function conflictOrganization(reason) {
  return {path: legacyOrganizationPath, action: 'conflict', reason};
}

function classifyLegacyMemberships({
  organizationMemberships,
  roles,
  platformAdministrators,
  volunteers,
  isTimestamp,
}) {
  const existingByUid = new Map();
  let conflicts = 0;
  for (const document of organizationMemberships) {
    const isLegacyCandidate = document?.id?.startsWith(
      `${legacyOrganizationId}_`,
    ) || document?.data?.organizationId === legacyOrganizationId;
    if (!isLegacyCandidate) continue;
    const validation = validateExistingMembership(document, isTimestamp);
    if (!validation.valid) {
      conflicts++;
      continue;
    }
    const existing = existingByUid.get(validation.uid);
    if (existing !== undefined) {
      conflicts++;
      existingByUid.set(validation.uid, null);
      continue;
    }
    existingByUid.set(validation.uid, document);
  }

  const roleEntries = [];
  let malformedRoles = 0;
  for (const document of roles) {
    try {
      assertDocument(document, 'role');
      const access = parseResponsibleAccess(document.data);
      const rolesForMembership = access.roles.map((role) => role);
      const path = membershipPath(document.id);
      const existing = existingByUid.get(document.id);
      if (existing === null) {
        roleEntries.push({uid: document.id, path, action: 'conflict'});
        continue;
      }
      roleEntries.push({
        uid: document.id,
        path,
        action: existing === undefined ? 'create' : 'unchanged',
        values: {
          organizationId: legacyOrganizationId,
          uid: document.id,
          roles: rolesForMembership,
          locationIds: access.locationIds,
          active: access.active,
          schemaVersion: 1,
        },
      });
    } catch {
      malformedRoles++;
    }
  }
  conflicts += roleEntries.filter((entry) => entry.action === 'conflict').length;
  const roleUids = new Set(roleEntries.map((entry) => entry.uid));
  const platformAdminUids = new Set(
    platformAdministrators
      .filter((document) => document?.data?.active === true)
      .map((document) => document.id),
  );
  const volunteerUids = new Set(volunteers.map((document) => document?.id));
  const explicitWithoutRole = [...existingByUid.entries()].filter(
    ([uid, document]) => document !== null && !roleUids.has(uid),
  ).length;
  return {
    entries: roleEntries,
    summary: {
      roleDocuments: roles.length,
      usersConcerned: roleEntries.length,
      create: roleEntries.filter((entry) => entry.action === 'create').length,
      unchanged:
        roleEntries.filter((entry) => entry.action === 'unchanged').length,
      inactive: roleEntries.filter((entry) => entry.values?.active === false)
        .length,
      explicitWithoutRole,
      malformedRoles,
      conflicts,
      activePlatformAdministrators: platformAdminUids.size,
      platformAdministratorMembershipsProposed: 0,
      professionalProfiles: volunteerUids.size,
      professionalMembershipsProposed: 0,
    },
  };
}

function validateExistingMembership(document, isTimestamp) {
  if (!document || !isStrictText(document.id) || !isPlainObject(document.data)) {
    return {valid: false};
  }
  const data = document.data;
  const organizationId = data.organizationId;
  const uid = data.uid;
  if (
    organizationId !== legacyOrganizationId
    || !isStrictText(uid)
    || document.id !== `${organizationId}_${uid}`
    || !Array.isArray(data.roles)
    || data.roles.length === 0
    || data.roles.some((role) => !membershipRoles.has(role))
    || new Set(data.roles).size !== data.roles.length
    || !Array.isArray(data.locationIds)
    || data.locationIds.some((id) => !isStrictIdentifier(id))
    || new Set(data.locationIds).size !== data.locationIds.length
    || typeof data.active !== 'boolean'
    || !Number.isInteger(data.schemaVersion)
    || data.schemaVersion < 1
    || !isTimestamp(data.createdAt)
    || !isTimestamp(data.updatedAt)
  ) {
    return {valid: false};
  }
  return {valid: true, uid};
}

function classifyOperation(document) {
  try {
    assertDocument(document, 'operation');
  } catch {
    return {id: safeDocumentId(document, 'operation'), action: 'malformed'};
  }
  const value = document.data.ownerOrganizationId;
  if (value === undefined || value === null) {
    return {id: document.id, action: 'update'};
  }
  if (!isStrictIdentifier(value)) {
    return {id: document.id, action: 'conflict'};
  }
  return {
    id: document.id,
    action: value === legacyOrganizationId ? 'legacy' : 'explicit',
  };
}

function summarizeOperations(entries) {
  return {
    total: entries.length,
    toBackfill: count(entries, 'update'),
    alreadyLegacy: count(entries, 'legacy'),
    explicitRc4: count(entries, 'explicit'),
    conflicts: count(entries, 'conflict'),
    malformed: count(entries, 'malformed'),
  };
}

function auditChildren({
  operations,
  mobilizations,
  missions,
  engagements,
  mobilizationAssignments,
  locations,
}) {
  const operationIds = new Set(
    operations.filter(validDocument).map((document) => document.id),
  );
  const mobilizationEntries = mobilizations.map((document) => {
    if (!validDocument(document)) return unresolvedChild(document);
    const operationId = document.data.operationId;
    if (operationId === undefined || operationId === null) {
      return {id: document.id, action: 'legacy_fallback'};
    }
    return isStrictIdentifier(operationId) && operationIds.has(operationId)
      ? {id: document.id, action: 'derive'}
      : {id: document.id, action: 'unresolved'};
  });
  const mobilizationById = new Map(
    mobilizationEntries.map((entry) => [entry.id, entry]),
  );
  const missionEntries = missions.map((document) =>
    classifyLinkedChild(document, 'mobilizationId', mobilizationById));
  const missionById = new Map(missionEntries.map((entry) => [entry.id, entry]));
  const engagementEntries = engagements.map((document) =>
    classifyLinkedChild(document, 'missionId', missionById));
  const assignmentEntries = mobilizationAssignments.map((document) =>
    classifyLinkedChild(document, 'mobilizationId', mobilizationById));
  const locationEntries = locations.map((document) => {
    if (!validDocument(document)) return unresolvedChild(document);
    const manager = document.data.managingOrganizationId;
    if (manager === undefined || manager === null) {
      return {id: document.id, action: 'defer'};
    }
    return isStrictIdentifier(manager)
      ? {id: document.id, action: 'explicit'}
      : {id: document.id, action: 'unresolved'};
  });
  return {
    mobilizations: childAudit(mobilizationEntries),
    missions: childAudit(missionEntries),
    engagements: childAudit(engagementEntries),
    mobilizationAssignments: childAudit(assignmentEntries),
    locations: childAudit(locationEntries),
  };
}

function classifyLinkedChild(document, field, parents) {
  if (!validDocument(document)) return unresolvedChild(document);
  const parentId = document.data[field];
  if (!isStrictIdentifier(parentId)) {
    return {id: document.id, action: 'unresolved'};
  }
  const parent = parents.get(parentId);
  if (!parent || parent.action === 'unresolved') {
    return {id: document.id, action: 'unresolved'};
  }
  return {
    id: document.id,
    action: parent.action === 'legacy_fallback' ? 'legacy_fallback' : 'derive',
  };
}

function childAudit(entries) {
  return {
    entries,
    summary: {
      total: entries.length,
      derive: count(entries, 'derive'),
      legacyFallback: count(entries, 'legacy_fallback'),
      explicit: count(entries, 'explicit'),
      defer: count(entries, 'defer'),
      unresolved: count(entries, 'unresolved'),
      backfillNow: 0,
    },
  };
}

function membershipPath(uid) {
  if (!isStrictIdentifier(uid)) throw new Error('UID de rôle invalide.');
  return `organizationMemberships/${legacyOrganizationId}_${uid}`;
}

function assertDocument(document, kind) {
  if (!validDocument(document)) {
    throw new Error(`Document ${kind} invalide.`);
  }
}

function validDocument(document) {
  return document !== null
    && typeof document === 'object'
    && isStrictIdentifier(document.id)
    && isPlainObject(document.data);
}

function unresolvedChild(document) {
  return {id: safeDocumentId(document, 'document'), action: 'unresolved'};
}

function safeDocumentId(document, fallback) {
  return isStrictText(document?.id) ? document.id : `<${fallback}-invalide>`;
}

function count(entries, action) {
  return entries.filter((entry) => entry.action === action).length;
}

function isStrictIdentifier(value) {
  return isStrictText(value) && value.length <= 160 && !value.includes('/');
}

function isStrictText(value) {
  return typeof value === 'string'
    && value.length > 0
    && value.trim() === value;
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isFirestoreTimestamp(value) {
  return value !== null
    && typeof value === 'object'
    && typeof value.toDate === 'function';
}
