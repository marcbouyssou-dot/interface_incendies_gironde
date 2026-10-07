import {isDeepStrictEqual} from 'node:util';

import {
  PUBLIC_MISSION_COLLECTION, projectPublicMission, publicMissionId,
} from './projector.js';

// Always read the current source in a transaction. Retried/out-of-order events
// cannot restore a stale projection. No notification collections are touched.
export async function reconcilePublicMission(firestore, missionId, now = new Date()) {
  const missionRef = firestore.collection('missions').doc(missionId);
  const projectionRef = firestore.collection(PUBLIC_MISSION_COLLECTION)
    .doc(publicMissionId(missionId));
  return firestore.runTransaction(async (transaction) => {
    const [missionSnapshot, projectionSnapshot] = await Promise.all([
      transaction.get(missionRef), transaction.get(projectionRef),
    ]);
    const mission = missionSnapshot.exists ? missionSnapshot.data() : null;
    let mobilization = null;
    let operation = null;
    let activeMobilizationId = null;
    if (typeof mission?.mobilizationId === 'string' &&
        mission.mobilizationId.length > 0 &&
        !mission.mobilizationId.includes('/')) {
      const mobilizationSnapshot = await transaction.get(
        firestore.collection('mobilizations').doc(mission.mobilizationId),
      );
      if (mobilizationSnapshot.exists) {
        mobilization = {...mobilizationSnapshot.data(), id: mobilizationSnapshot.id};
        if (typeof mobilization.operationId === 'string' &&
            mobilization.operationId.length > 0 &&
            !mobilization.operationId.includes('/')) {
          const operationSnapshot = await transaction.get(
            firestore.collection('operations').doc(mobilization.operationId),
          );
          if (operationSnapshot.exists) operation = operationSnapshot.data();
        } else if (!Object.hasOwn(mobilization, 'operationId')) {
          const configSnapshot = await transaction.get(firestore.doc('platform/config'));
          activeMobilizationId = configSnapshot.data()?.activeMobilizationId;
        }
      }
    }
    const expected = projectPublicMission({
      missionId, mission, mobilization, operation, activeMobilizationId, now,
    });
    if (expected === null) {
      if (projectionSnapshot.exists) transaction.delete(projectionRef);
      return projectionSnapshot.exists ? 'DELETE' : 'UNCHANGED';
    }
    if (projectionSnapshot.exists &&
        isDeepStrictEqual(projectionSnapshot.data(), expected)) return 'UNCHANGED';
    transaction.set(projectionRef, expected);
    return projectionSnapshot.exists ? 'UPDATE' : 'CREATE';
  });
}

export async function reconcileMobilizationMissions(firestore, mobilizationId) {
  const snapshot = await firestore.collection('missions')
    .where('mobilizationId', '==', mobilizationId).get();
  for (const mission of snapshot.docs) {
    await reconcilePublicMission(firestore, mission.id);
  }
}

export async function reconcileOperationMissions(firestore, operationId) {
  const snapshot = await firestore.collection('mobilizations')
    .where('operationId', '==', operationId).get();
  for (const mobilization of snapshot.docs) {
    await reconcileMobilizationMissions(firestore, mobilization.id);
  }
}

export async function reconcileAllPublicMissions(firestore) {
  const [missions, projections] = await Promise.all([
    firestore.collection('missions').get(),
    firestore.collection(PUBLIC_MISSION_COLLECTION).get(),
  ]);
  const missionIds = missions.docs.map((document) => document.id).sort();
  const expectedPublicIds = new Set(missionIds.map(publicMissionId));
  for (const id of missionIds) await reconcilePublicMission(firestore, id);
  for (const projection of projections.docs) {
    if (!expectedPublicIds.has(projection.id)) await projection.ref.delete();
  }
}
