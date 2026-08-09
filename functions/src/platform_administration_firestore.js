import {
  isPlatformAdministrator,
  PlatformAdministrationError,
} from './platform_administration.js';
import {hasActiveCoordinatorRole} from './responsible_access.js';

const MOBILIZATION_STATUSES = new Set([
  'draft',
  'active',
  'inactive',
  'archived',
]);

export function platformAdministrationServices({
  firestore,
  serverTimestamp,
}) {
  return {
    createMobilization: (request) => runCreateMobilization({
      firestore,
      serverTimestamp,
      request,
    }),
    updateMobilization: (request) => runUpdateMobilization({
      firestore,
      serverTimestamp,
      request,
    }),
    activateMobilization: (request) => runActivateMobilization({
      firestore,
      serverTimestamp,
      request,
    }),
    deactivateMobilization: (request) => runDeactivateMobilization({
      firestore,
      serverTimestamp,
      request,
    }),
    archiveMobilization: (request) => runArchiveMobilization({
      firestore,
      serverTimestamp,
      request,
    }),
    assignMobilizationCoordinator: (request) =>
      runAssignMobilizationCoordinator({
        firestore,
        serverTimestamp,
        request,
      }),
    removeMobilizationCoordinator: (request) =>
      runRemoveMobilizationCoordinator({
        firestore,
        serverTimestamp,
        request,
      }),
  };
}

async function runCreateMobilization({firestore, serverTimestamp, request}) {
  return firestore.runTransaction(async (transaction) => {
    await requirePlatformAdministrator({firestore, transaction, request});
    const mobilizationRef = mobilizationReference(
      firestore,
      request.mobilizationId,
    );
    const territoryRef = firestore
      .collection('territories')
      .doc(request.territoryId);
    const [mobilization, territory] = await Promise.all([
      transaction.get(mobilizationRef),
      transaction.get(territoryRef),
    ]);
    if (mobilization.exists) {
      throw new PlatformAdministrationError(
        'already-exists',
        'Cette mobilisation existe déjà.',
      );
    }
    requireActiveTerritory(territory);
    const timestamp = serverTimestamp();
    transaction.create(mobilizationRef, {
      id: request.mobilizationId,
      territoryId: request.territoryId,
      name: request.name,
      subtitle: request.subtitle,
      contextType: request.contextType,
      status: 'draft',
      createdBy: request.callerUid,
      createdAt: timestamp,
      updatedBy: request.callerUid,
      updatedAt: timestamp,
      schemaVersion: 1,
    });
    return {mobilizationId: request.mobilizationId, status: 'draft'};
  });
}

async function runUpdateMobilization({firestore, serverTimestamp, request}) {
  return firestore.runTransaction(async (transaction) => {
    await requirePlatformAdministrator({firestore, transaction, request});
    const mobilizationRef = mobilizationReference(
      firestore,
      request.mobilizationId,
    );
    const territoryRef = firestore
      .collection('territories')
      .doc(request.territoryId);
    const [mobilization, territory] = await Promise.all([
      transaction.get(mobilizationRef),
      transaction.get(territoryRef),
    ]);
    const current = requireMobilization(mobilization);
    requireActiveTerritory(territory);
    if (current.status === 'archived') {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Une mobilisation archivée ne peut plus être modifiée.',
      );
    }
    if (
      current.status === 'active'
      && current.territoryId !== request.territoryId
    ) {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Le territoire d’une mobilisation active ne peut pas changer.',
      );
    }
    transaction.update(mobilizationRef, {
      territoryId: request.territoryId,
      name: request.name,
      subtitle: request.subtitle,
      contextType: request.contextType,
      updatedBy: request.callerUid,
      updatedAt: serverTimestamp(),
    });
    return {
      mobilizationId: request.mobilizationId,
      status: current.status,
    };
  });
}

async function runActivateMobilization({firestore, serverTimestamp, request}) {
  return firestore.runTransaction(async (transaction) => {
    await requirePlatformAdministrator({firestore, transaction, request});
    const mobilizationRef = mobilizationReference(
      firestore,
      request.mobilizationId,
    );
    const configRef = firestore.collection('platform').doc('config');
    const assignmentsQuery = firestore
      .collection('mobilizationAssignments')
      .where('mobilizationId', '==', request.mobilizationId)
      .where('role', '==', 'coordinator')
      .where('active', '==', true);
    const activeMobilizationsQuery = firestore
      .collection('mobilizations')
      .where('status', '==', 'active');
    const [mobilization, config, assignments, activeMobilizations] =
      await Promise.all([
        transaction.get(mobilizationRef),
        transaction.get(configRef),
        transaction.get(assignmentsQuery),
        transaction.get(activeMobilizationsQuery),
      ]);
    const current = requireMobilization(mobilization);
    if (current.status !== 'draft' && current.status !== 'inactive') {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Cette mobilisation ne peut pas être activée.',
      );
    }
    const territory = await transaction.get(
      firestore.collection('territories').doc(current.territoryId),
    );
    requireActiveTerritory(territory);
    if (!await hasEligibleCoordinator({
      firestore,
      transaction,
      assignments,
    })) {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Un Coordinateur actif doit être affecté à la mobilisation.',
      );
    }

    if (activeMobilizations.docs.length > 1) throw inconsistentActiveState();
    const previousActive = activeMobilizations.docs[0] ?? null;
    const configuredActiveId = config.exists
      ? config.data().activeMobilizationId
      : null;
    if (
      configuredActiveId !== null
      && typeof configuredActiveId !== 'string'
    ) {
      throw inconsistentActiveState();
    }
    if (
      (previousActive === null && configuredActiveId !== null)
      || (previousActive !== null && configuredActiveId !== previousActive.id)
    ) {
      throw inconsistentActiveState();
    }
    if (configuredActiveId === request.mobilizationId) {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Cette mobilisation est déjà déclarée active.',
      );
    }

    const timestamp = serverTimestamp();
    if (previousActive !== null) {
      transaction.update(
        mobilizationReference(firestore, previousActive.id),
        {
          status: 'inactive',
          deactivatedBy: request.callerUid,
          deactivatedAt: timestamp,
          updatedBy: request.callerUid,
          updatedAt: timestamp,
        },
      );
    }
    transaction.update(mobilizationRef, {
      status: 'active',
      activatedBy: request.callerUid,
      activatedAt: timestamp,
      updatedBy: request.callerUid,
      updatedAt: timestamp,
    });
    transaction.set(configRef, {
      activeMobilizationId: request.mobilizationId,
      updatedBy: request.callerUid,
      updatedAt: timestamp,
    }, {merge: true});
    return {mobilizationId: request.mobilizationId, status: 'active'};
  });
}

async function runDeactivateMobilization({
  firestore,
  serverTimestamp,
  request,
}) {
  return firestore.runTransaction(async (transaction) => {
    await requirePlatformAdministrator({firestore, transaction, request});
    const mobilizationRef = mobilizationReference(
      firestore,
      request.mobilizationId,
    );
    const configRef = firestore.collection('platform').doc('config');
    const [mobilization, config] = await Promise.all([
      transaction.get(mobilizationRef),
      transaction.get(configRef),
    ]);
    const current = requireMobilization(mobilization);
    if (
      current.status !== 'active'
      || !config.exists
      || config.data().activeMobilizationId !== request.mobilizationId
    ) {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Cette mobilisation n’est pas la mobilisation active.',
      );
    }
    const timestamp = serverTimestamp();
    transaction.update(mobilizationRef, {
      status: 'inactive',
      deactivatedBy: request.callerUid,
      deactivatedAt: timestamp,
      updatedBy: request.callerUid,
      updatedAt: timestamp,
    });
    transaction.set(configRef, {
      activeMobilizationId: null,
      updatedBy: request.callerUid,
      updatedAt: timestamp,
    }, {merge: true});
    return {mobilizationId: request.mobilizationId, status: 'inactive'};
  });
}

async function runArchiveMobilization({firestore, serverTimestamp, request}) {
  return firestore.runTransaction(async (transaction) => {
    await requirePlatformAdministrator({firestore, transaction, request});
    const mobilizationRef = mobilizationReference(
      firestore,
      request.mobilizationId,
    );
    const mobilization = await transaction.get(mobilizationRef);
    const current = requireMobilization(mobilization);
    if (current.status !== 'draft' && current.status !== 'inactive') {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Une mobilisation active ou archivée ne peut pas être archivée.',
      );
    }
    const timestamp = serverTimestamp();
    transaction.update(mobilizationRef, {
      status: 'archived',
      archivedBy: request.callerUid,
      archivedAt: timestamp,
      updatedBy: request.callerUid,
      updatedAt: timestamp,
    });
    return {mobilizationId: request.mobilizationId, status: 'archived'};
  });
}

async function runAssignMobilizationCoordinator({
  firestore,
  serverTimestamp,
  request,
}) {
  return firestore.runTransaction(async (transaction) => {
    await requirePlatformAdministrator({firestore, transaction, request});
    const mobilizationRef = mobilizationReference(
      firestore,
      request.mobilizationId,
    );
    const assignmentId = `${request.mobilizationId}_${request.uid}`;
    const assignmentRef = firestore
      .collection('mobilizationAssignments')
      .doc(assignmentId);
    const roleRef = firestore.collection('roles').doc(request.uid);
    const [mobilization, assignment, role] = await Promise.all([
      transaction.get(mobilizationRef),
      transaction.get(assignmentRef),
      transaction.get(roleRef),
    ]);
    const current = requireMobilization(mobilization);
    if (current.status === 'archived') {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Une mobilisation archivée ne peut plus recevoir d’affectation.',
      );
    }
    if (!role.exists || !hasActiveCoordinatorRole(role.data())) {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Le compte cible doit être un Coordinateur V5 actif.',
      );
    }
    if (assignment.exists && assignment.data().active === true) {
      throw new PlatformAdministrationError(
        'already-exists',
        'Ce Coordinateur est déjà affecté à la mobilisation.',
      );
    }
    const timestamp = serverTimestamp();
    const existing = assignment.exists ? assignment.data() : null;
    transaction.set(assignmentRef, {
      uid: request.uid,
      mobilizationId: request.mobilizationId,
      role: 'coordinator',
      active: true,
      assignedBy: request.callerUid,
      createdAt: existing?.createdAt ?? timestamp,
      updatedBy: request.callerUid,
      updatedAt: timestamp,
    }, {merge: false});
    return {assignmentId, active: true};
  });
}

async function runRemoveMobilizationCoordinator({
  firestore,
  serverTimestamp,
  request,
}) {
  return firestore.runTransaction(async (transaction) => {
    await requirePlatformAdministrator({firestore, transaction, request});
    const mobilizationRef = mobilizationReference(
      firestore,
      request.mobilizationId,
    );
    const assignmentId = `${request.mobilizationId}_${request.uid}`;
    const assignmentRef = firestore
      .collection('mobilizationAssignments')
      .doc(assignmentId);
    const [mobilization, assignment] = await Promise.all([
      transaction.get(mobilizationRef),
      transaction.get(assignmentRef),
    ]);
    const current = requireMobilization(mobilization);
    if (current.status === 'active') {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Désactivez la mobilisation avant de retirer son Coordinateur.',
      );
    }
    if (!assignment.exists || assignment.data().active !== true) {
      throw new PlatformAdministrationError(
        'not-found',
        'Affectation Coordinateur active introuvable.',
      );
    }
    transaction.update(assignmentRef, {
      active: false,
      updatedBy: request.callerUid,
      updatedAt: serverTimestamp(),
    });
    return {assignmentId, active: false};
  });
}

async function requirePlatformAdministrator({
  firestore,
  transaction,
  request,
}) {
  const authorized = await isPlatformAdministrator(request.callerUid, {
    getAdministrator: async (uid) => {
      const snapshot = await transaction.get(
        firestore.collection('platformAdministrators').doc(uid),
      );
      return snapshot.exists ? snapshot.data() : null;
    },
  });
  if (!authorized) {
    throw new PlatformAdministrationError(
      'permission-denied',
      'Accès Administrateur plateforme requis.',
    );
  }
}

async function hasEligibleCoordinator({firestore, transaction, assignments}) {
  if (assignments.empty) return false;
  const coordinatorUids = assignments.docs.flatMap((assignment) => {
    const uid = assignment.data().uid;
    return typeof uid === 'string' && uid !== '' && !uid.includes('/')
      ? [uid]
      : [];
  });
  if (coordinatorUids.length === 0) return false;
  const roleSnapshots = await Promise.all(coordinatorUids.map((uid) =>
    transaction.get(firestore.collection('roles').doc(uid))));
  return roleSnapshots.some(
    (role) => role.exists && hasActiveCoordinatorRole(role.data()),
  );
}

function requireMobilization(snapshot) {
  if (!snapshot.exists) {
    throw new PlatformAdministrationError(
      'not-found',
      'Mobilisation introuvable.',
    );
  }
  const current = snapshot.data();
  if (
    current === null
    || typeof current !== 'object'
    || Array.isArray(current)
    || current.id !== snapshot.id
    || typeof current.territoryId !== 'string'
    || !MOBILIZATION_STATUSES.has(current.status)
  ) {
    throw new PlatformAdministrationError(
      'failed-precondition',
      'Le document de mobilisation existant est invalide.',
    );
  }
  return current;
}

function requireActiveTerritory(snapshot) {
  if (!snapshot.exists || snapshot.data().active !== true) {
    throw new PlatformAdministrationError(
      'failed-precondition',
      'Le territoire sélectionné est introuvable ou inactif.',
    );
  }
}

function mobilizationReference(firestore, mobilizationId) {
  return firestore.collection('mobilizations').doc(mobilizationId);
}

function inconsistentActiveState() {
  return new PlatformAdministrationError(
    'failed-precondition',
    'La configuration de la mobilisation active est incohérente.',
  );
}
