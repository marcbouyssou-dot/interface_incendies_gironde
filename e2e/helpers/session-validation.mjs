export const AUTH_ROLES = ['coordinator', 'site_manager', 'standard'];

export function validateObservedRole(role, observed) {
  const valid =
    role === 'coordinator'
      ? observed.coordinator && observed.globalResponsibleManagement
      : role === 'site_manager'
        ? observed.siteManager &&
          !observed.coordinator &&
          !observed.globalResponsibleManagement
        : !observed.coordinator &&
          !observed.siteManager &&
          !observed.globalResponsibleManagement;

  if (!valid) {
    throw new Error(
      `Le rôle observé ne correspond pas à ${role}. ` +
        'Reconnectez-vous avec le bon compte.',
    );
  }
}

export function extractResponsibleUid(storageState) {
  for (const origin of storageState.origins ?? []) {
    for (const database of origin.indexedDB ?? []) {
      if (database.name !== 'firebaseLocalStorageDb') continue;
      for (const store of database.stores ?? []) {
        for (const record of store.records ?? []) {
          const pairs = collectEncodedPairs(record.valueEncoded);
          const key = pairs.find(
            (pair) =>
              pair.key === 'fbase_key' &&
              typeof pair.value === 'string' &&
              pair.value.endsWith(':responsible'),
          );
          if (!key) continue;
          const uid = pairs.find(
            (pair) => pair.key === 'uid' && typeof pair.value === 'string',
          )?.value;
          if (uid) return uid;
        }
      }
    }
  }
  throw new Error(
    'Aucun compte responsable authentifié détecté. ' +
      'Reconnectez-vous avec le bon compte.',
  );
}

export function registerUniqueSession(seenSessions, role, uid) {
  for (const [existingRole, existingUid] of seenSessions) {
    if (existingUid !== uid || existingRole === role) continue;
    throw new Error(
      `La session ${role} utilise déjà le même compte que ${existingRole}. ` +
        'Reconnectez-vous avec un autre compte.',
    );
  }
  seenSessions.set(role, uid);
}

function collectEncodedPairs(value, result = []) {
  if (Array.isArray(value)) {
    for (const item of value) collectEncodedPairs(item, result);
    return result;
  }
  if (!value || typeof value !== 'object') return result;
  if (typeof value.k === 'string' && Object.hasOwn(value, 'v')) {
    result.push({key: value.k, value: value.v});
  }
  for (const nested of Object.values(value)) {
    collectEncodedPairs(nested, result);
  }
  return result;
}
