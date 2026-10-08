// Admin-assisted, local-only rights review. This module has no Firebase client.
// Callers must supply a separately authorized snapshot and verify the requester.
export const DRY_RUN_REQUIRED = true;

const profileFields = new Set([
  'firstName', 'lastName', 'email', 'phone', 'profession', 'rpps',
  'professionalIdType', 'professionalIdValue', 'cptsId', 'cptsLabel',
  'professionalAddressLine1', 'professionalAddressLine2',
  'professionalPostalCode', 'professionalCity', 'professionalCountryCode',
  'equipment', 'otherEquipmentDetails', 'verificationStatus',
  'verificationSource', 'verifiedFirstName', 'verifiedLastName',
  'verifiedProfessionCode', 'verifiedProfessionLabel', 'verifiedAt',
  'competencies', 'mobilizationPreferences', 'communicationPreferences',
  'consentRecords', 'admissionScopes', 'createdAt', 'updatedAt',
]);
const relationshipFields = new Set([
  'uid', 'volunteerId', 'professionalUid', 'organizationId', 'operationId',
  'mobilizationId', 'locationId', 'missionId', 'role', 'status', 'profession',
  'recipientUid', 'sourceInvitationId', 'createdAt', 'updatedAt',
  'acceptedAt', 'admittedAt', 'revokedAt', 'expiresAt', 'active',
]);
const targetingFields = new Set([
  'uid', 'enabled', 'radiusKm', 'latitude', 'longitude', 'source',
  'geocodingProvider', 'geocodingPrecision', 'confirmedAt',
  'createdAt', 'updatedAt',
]);
const preferenceFields = new Set([
  'uid', 'compatibleMissions', 'engagementUpdates', 'operationalAlerts',
  'quietHoursStart', 'quietHoursEnd', 'updatedAt',
]);
const pushSubscriptionFields = new Set([
  'uid', 'installationId', 'platform', 'active', 'disabledReason',
  'createdAt', 'updatedAt', 'lastUsedAt',
]);
const notificationFields = new Set([
  'uid', 'recipientUid', 'status', 'channel', 'createdAt', 'updatedAt',
  'sentAt', 'deliveredAt', 'readAt', 'eventId', 'enabled',
]);
const secretKey = /password|secret|token|credential|authorization|privatekey|apikey|endpoint/i;
const ownDocumentRoots = new Set([
  'volunteers', 'roles', 'organizationMemberships',
  'mobilizationAssignments', 'operationAccess', 'historicalActionAccess',
  'engagements', 'professionalAdmissions', 'professionalTargeting',
  'notificationPreferences', 'notificationDeliveries',
  'professionalSolicitationJournal', 'pushSubscriptions',
]);
const uidFields = new Set([
  'uid', 'volunteerId', 'professionalUid', 'recipientUid', 'acceptedUid',
  'targetUid', 'coordinatorUid', 'consumedBy', 'createdBy', 'updatedBy',
  'cancelledBy',
]);

function checkInput({uid, documents, authRecord}) {
  if (typeof uid !== 'string' || !uid.trim() || !Array.isArray(documents)) {
    throw Error('INVALID_SUBJECT_REVIEW_INPUT');
  }
  if (authRecord && authRecord.uid !== uid) throw Error('AUTH_SUBJECT_MISMATCH');
  const paths = new Set();
  for (const doc of documents) {
    if (typeof doc.path !== 'string' || !doc.path.includes('/') ||
        !doc.data || typeof doc.data !== 'object' || paths.has(doc.path)) {
      throw Error('INVALID_SUBJECT_REVIEW_SNAPSHOT');
    }
    paths.add(doc.path);
  }
}

function matchedFields(value, uid, prefix = '') {
  if (typeof value === 'string') return value.includes(uid) ? [prefix] : [];
  if (!value || typeof value !== 'object') return [];
  if (Array.isArray(value)) {
    return value.flatMap((item, index) => matchedFields(item, uid, `${prefix}[${index}]`));
  }
  return Object.entries(value).flatMap(([key, item]) => {
    const field = prefix ? `${prefix}.${key}` : key;
    if (uidFields.has(key) && item === uid) return [field];
    return matchedFields(item, uid, field);
  });
}

function redactNested(value) {
  if (Array.isArray(value)) return value.map(redactNested);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value)
      .filter(([key]) => !secretKey.test(key))
      .map(([key, item]) => [key, redactNested(item)]));
  }
  return value;
}

function projection(data, allowed) {
  return Object.fromEntries(Object.entries(data)
    .filter(([key]) => allowed.has(key) && !secretKey.test(key))
    .map(([key, value]) => [key, redactNested(value)]));
}

function isOwnDocument(doc, uid, root, fields) {
  if (!ownDocumentRoots.has(root)) return false;
  if (['volunteers', 'roles', 'notificationPreferences',
    'professionalTargeting'].includes(root)) {
    return doc.path === `${root}/${uid}`;
  }
  return fields.some((field) => {
    if (field.includes('.') || field.includes('[')) return false;
    const key = field.split('.').at(-1);
    return ['uid', 'volunteerId', 'professionalUid', 'recipientUid'].includes(key);
  });
}

export function buildSubjectReview({uid, documents, authRecord = null}) {
  checkInput({uid, documents, authRecord});
  const exported = [];
  const omittedFieldNames = [];
  const sharedReferences = [];
  const erasure = {deleteCandidates: [], anonymizeCandidates: [],
    detachCandidates: [], pushTokensToRevoke: [], retainedForReview: [],
    quotaRecalculationMissions: [], authLast: Boolean(authRecord),
    executable: false, dryRunRequired: DRY_RUN_REQUIRED};
  for (const doc of documents) {
    const root = doc.path.split('/')[0];
    const fields = matchedFields(doc.data, uid);
    const directPath = doc.path === `${root}/${uid}`;
    if (directPath && ownDocumentRoots.has(root)
      && typeof doc.data.uid === 'string' && doc.data.uid !== uid) {
      throw Error('SUBJECT_DOCUMENT_UID_MISMATCH');
    }
    if (fields.length === 0 && !directPath && !doc.path.includes(uid)) continue;
    if (!isOwnDocument(doc, uid, root, fields)) {
      const references = doc.path.includes(uid) && !directPath
        ? [...fields, '$documentId'] : fields;
      sharedReferences.push({path: doc.path, fields: references});
      erasure.detachCandidates.push({path: doc.path, fields: references,
        requiresReview: true});
      continue;
    }
    const allowed = root === 'volunteers' ? profileFields
      : root === 'professionalTargeting' ? targetingFields
        : root === 'notificationPreferences' ? preferenceFields
          : root === 'pushSubscriptions' ? pushSubscriptionFields
            : root === 'notificationDeliveries' ? notificationFields
              : relationshipFields;
    const safe = projection(doc.data, allowed);
    for (const key of ['uid', 'volunteerId', 'professionalUid', 'recipientUid']) {
      if (typeof safe[key] === 'string' && safe[key] !== uid) delete safe[key];
    }
    const omitted = Object.keys(doc.data).filter((key) => !allowed.has(key));
    if (omitted.length) omittedFieldNames.push({path: doc.path, fields: omitted});
    exported.push({path: doc.path, data: safe});
    if (root === 'pushSubscriptions') {
      erasure.pushTokensToRevoke.push({path: doc.path, tokenExcluded: true});
    } else if (root === 'engagements') {
      erasure.anonymizeCandidates.push({path: doc.path,
        reason: 'historical_participation_requires_retention_review'});
      if (typeof doc.data.missionId === 'string') {
        erasure.quotaRecalculationMissions.push(doc.data.missionId);
      }
    } else if (root === 'historicalActionAccess') {
      erasure.retainedForReview.push({path: doc.path,
        reason: 'historical_access_audit_requires_review'});
    } else {
      erasure.deleteCandidates.push({path: doc.path,
        reason: 'subject_owned_document_requires_review'});
    }
  }
  erasure.quotaRecalculationMissions = [...new Set(erasure.quotaRecalculationMissions)].sort();
  return {
    format: 'mobsante-subject-review-v1',
    subjectUid: uid,
    partial: true,
    authenticatedIdentityVerified: false,
    auth: authRecord ? {
      uid, email: authRecord.email ?? null,
      createdAt: authRecord.createdAt ?? null,
      lastSignInAt: authRecord.lastSignInAt ?? null,
      disabled: authRecord.disabled ?? false,
    } : null,
    exported,
    omittedFieldNames,
    sharedReferences,
    erasure,
    limitations: [
      'An administrator must verify requester identity and authority.',
      'This is a scoped technical extract, not a complete legal response.',
      'Unknown fields and shared references require human review.',
      'No deletion is implemented. Auth must be deleted last in a separately authorized lot.',
    ],
  };
}
