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
const OPERATION_STATUSES = new Set([
  'draft', 'planned', 'active', 'suspended', 'completed', 'archived',
]);
const OPERATION_TRANSITIONS = new Set([
  'draft:planned',
  'draft:archived',
  'planned:active',
  'planned:archived',
  'active:suspended',
  'active:completed',
  'suspended:active',
  'suspended:completed',
  'completed:archived',
]);

export function platformAdministrationServices({
  firestore,
  serverTimestamp,
}) {
  return {
    createOperation: (request) => runCreateOperation({
      firestore,
      serverTimestamp,
      request,
    }),
    updateOperation: (request) => runUpdateOperation({
      firestore,
      serverTimestamp,
      request,
    }),
    transitionOperation: (request) => runTransitionOperation({
      firestore,
      serverTimestamp,
      request,
    }),
    setOperationCoordinator: (request) => runSetOperationCoordinator({
      firestore,
      serverTimestamp,
      request,
    }),
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

async function runCreateOperation({firestore, serverTimestamp, request}) {
  return firestore.runTransaction(async (transaction) => {
    await requirePlatformAdministrator({firestore, transaction, request});
    const operationRef = operationReference(firestore, request.operationId);
    const [operation, scopeSnapshots] = await Promise.all([
      transaction.get(operationRef),
      readScopeReferences({firestore, transaction, refs: request.scopeRefs}),
    ]);
    if (operation.exists) {
      throw new PlatformAdministrationError(
        'already-exists',
        'Cette opération existe déjà.',
      );
    }
    requireValidScopes(request.scopeRefs, scopeSnapshots);
    const timestamp = serverTimestamp();
    transaction.create(operationRef, {
      id: request.operationId,
      name: request.name,
      type: request.type,
      status: 'draft',
      context: request.context,
      startAt: new Date(request.startAtMillis),
      endAt: request.endAtMillis === null
        ? null
        : new Date(request.endAtMillis),
      coordinatorUid: null,
      scopeRefs: [...request.scopeRefs],
      createdBy: request.callerUid,
      createdAt: timestamp,
      updatedBy: request.callerUid,
      updatedAt: timestamp,
      schemaVersion: 2,
    });
    return {operationId: request.operationId, status: 'draft'};
  });
}

async function runUpdateOperation({firestore, serverTimestamp, request}) {
  return firestore.runTransaction(async (transaction) => {
    await requirePlatformAdministrator({firestore, transaction, request});
    const operationRef = operationReference(firestore, request.operationId);
    const [operation, scopeSnapshots] = await Promise.all([
      transaction.get(operationRef),
      readScopeReferences({firestore, transaction, refs: request.scopeRefs}),
    ]);
    const current = requireOperation(operation);
    if (current.status === 'completed' || current.status === 'archived') {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Une opération terminée ou archivée ne peut plus être modifiée.',
      );
    }
    requireValidScopes(request.scopeRefs, scopeSnapshots);
    transaction.update(operationRef, {
      name: request.name,
      type: request.type,
      context: request.context,
      startAt: new Date(request.startAtMillis),
      endAt: request.endAtMillis === null
        ? null
        : new Date(request.endAtMillis),
      scopeRefs: [...request.scopeRefs],
      updatedBy: request.callerUid,
      updatedAt: serverTimestamp(),
    });
    return {operationId: request.operationId, status: current.status};
  });
}

async function runTransitionOperation({firestore, serverTimestamp, request}) {
  return firestore.runTransaction(async (transaction) => {
    await requirePlatformAdministrator({firestore, transaction, request});
    const operationRef = operationReference(firestore, request.operationId);
    const operation = await transaction.get(operationRef);
    const current = requireOperation(operation);
    if (!OPERATION_TRANSITIONS.has(`${current.status}:${request.targetStatus}`)) {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Cette transition d’opération n’est pas autorisée.',
      );
    }
    transaction.update(operationRef, {
      status: request.targetStatus,
      updatedBy: request.callerUid,
      updatedAt: serverTimestamp(),
    });
    return {operationId: request.operationId, status: request.targetStatus};
  });
}

async function runSetOperationCoordinator({
  firestore,
  serverTimestamp,
  request,
}) {
  return firestore.runTransaction(async (transaction) => {
    await requirePlatformAdministrator({firestore, transaction, request});
    const operationRef = operationReference(firestore, request.operationId);
    const targetRoleRef = firestore.collection('roles').doc(request.uid);
    const mobilizationsQuery = firestore
      .collection('mobilizations')
      .where('operationId', '==', request.operationId);
    const [operation, targetRole, mobilizations] =
      await Promise.all([
        transaction.get(operationRef),
        transaction.get(targetRoleRef),
        transaction.get(mobilizationsQuery),
      ]);
    const currentOperation = requireOperation(operation);
    const previousCoordinatorUid = operationCoordinatorUid(currentOperation);
    if (
      currentOperation.status === 'completed'
      || currentOperation.status === 'archived'
    ) {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Une opération terminée ou archivée ne peut plus changer de Coordinateur.',
      );
    }
    if (!targetRole.exists || !hasActiveCoordinatorRole(targetRole.data())) {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Le compte cible doit être un Coordinateur V5 actif.',
      );
    }

    const scopedMobilizations = mobilizations.docs.map((snapshot) => ({
      snapshot,
      data: requireMobilization(snapshot),
    }));
    const mobilizationIds = new Set(
      scopedMobilizations.map(({snapshot}) => snapshot.id),
    );
    const activeAssignmentSnapshots = await Promise.all(
      scopedMobilizations.map(({snapshot}) => transaction.get(firestore
        .collection('mobilizationAssignments')
        .where('mobilizationId', '==', snapshot.id))),
    );
    const scopedActiveAssignments = activeAssignmentSnapshots
      .flatMap((snapshot) => snapshot.docs)
      .filter((snapshot) =>
        snapshot.data().role === 'coordinator'
          && snapshot.data().active === true);
    const replacedUids = [...new Set([
      ...scopedActiveAssignments
        .map((snapshot) => snapshot.data().uid)
        .filter((uid) => typeof uid === 'string' && uid !== request.uid),
      ...(previousCoordinatorUid !== null
          && previousCoordinatorUid !== request.uid
        ? [previousCoordinatorUid]
        : []),
    ])];
    const estimatedWriteCount = 2
      + scopedMobilizations.length
      + scopedActiveAssignments.filter((snapshot) =>
        snapshot.id !== `${snapshot.data().mobilizationId}_${request.uid}`
          || snapshot.data().uid !== request.uid).length
      + replacedUids.length;
    if (estimatedWriteCount > 450) {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Cette opération contient trop de mobilisations pour cette action atomique.',
      );
    }

    const targetAssignmentRefs = scopedMobilizations.map(({snapshot}) =>
      firestore
        .collection('mobilizationAssignments')
        .doc(`${snapshot.id}_${request.uid}`));
    const targetAssignments = await Promise.all(
      targetAssignmentRefs.map((reference) => transaction.get(reference)),
    );
    const replacedRoleRefs = replacedUids.map((uid) =>
      firestore.collection('roles').doc(uid));
    const targetAssignmentsQuery = firestore
      .collection('mobilizationAssignments')
      .where('uid', '==', request.uid)
      .where('role', '==', 'coordinator')
      .where('active', '==', true);
    const replacedAssignmentsQueries = replacedUids.map((uid) => firestore
      .collection('mobilizationAssignments')
      .where('uid', '==', uid)
      .where('role', '==', 'coordinator')
      .where('active', '==', true));
    const [replacedRoles, targetActiveAssignments, replacedAssignments] =
      await Promise.all([
        Promise.all(
          replacedRoleRefs.map((reference) => transaction.get(reference)),
        ),
        transaction.get(targetAssignmentsQuery),
        Promise.all(
          replacedAssignmentsQueries.map((query) => transaction.get(query)),
        ),
      ]);

    const timestamp = serverTimestamp();
    transaction.update(operationRef, {
      coordinatorUid: request.uid,
      coordinatorUpdatedBy: request.callerUid,
      coordinatorUpdatedAt: timestamp,
      updatedBy: request.callerUid,
      updatedAt: timestamp,
    });
    for (const assignment of scopedActiveAssignments) {
      if (
        assignment.data().uid === request.uid
        && assignment.id === `${assignment.data().mobilizationId}_${request.uid}`
      ) continue;
      transaction.update(assignment.ref ?? firestore
        .collection('mobilizationAssignments')
        .doc(assignment.id), {
        active: false,
        updatedBy: request.callerUid,
        updatedAt: timestamp,
      });
    }
    for (let index = 0; index < scopedMobilizations.length; index += 1) {
      const mobilizationId = scopedMobilizations[index].snapshot.id;
      const existing = targetAssignments[index];
      transaction.set(targetAssignmentRefs[index], {
        uid: request.uid,
        mobilizationId,
        role: 'coordinator',
        active: true,
        assignedBy: request.callerUid,
        createdAt: existing.exists
          ? existing.data().createdAt ?? timestamp
          : timestamp,
        updatedBy: request.callerUid,
        updatedAt: timestamp,
      }, {merge: false});
    }

    const hasTargetAssignmentsOutsideOperation =
      targetActiveAssignments.docs.some(
        (snapshot) => !mobilizationIds.has(snapshot.data().mobilizationId),
      );
    transaction.update(targetRoleRef, {
      hasActiveMobilizationAssignments:
        scopedMobilizations.length > 0 || hasTargetAssignmentsOutsideOperation,
    });
    for (let index = 0; index < replacedRoles.length; index += 1) {
      if (!replacedRoles[index].exists) continue;
      const remainsAssigned = replacedAssignments[index].docs.some(
        (snapshot) => !mobilizationIds.has(snapshot.data().mobilizationId),
      );
      transaction.update(replacedRoleRefs[index], {
        hasActiveMobilizationAssignments: remainsAssigned,
      });
    }
    return {
      operationId: request.operationId,
      coordinatorUid: request.uid,
      previousCoordinatorUid,
      mobilizationCount: scopedMobilizations.length,
      activeMobilizationCount: scopedMobilizations.filter(
        ({data}) => data.status === 'active',
      ).length,
    };
  });
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
    const scopeRefs = request.scopeRefs
      ?? [`territories/${request.territoryId}`];
    const [mobilization, territory, operation, scopeSnapshots] = await Promise.all([
      transaction.get(mobilizationRef),
      transaction.get(territoryRef),
      request.operationId === undefined
        ? Promise.resolve(null)
        : transaction.get(operationReference(firestore, request.operationId)),
      readScopeReferences({firestore, transaction, refs: scopeRefs}),
    ]);
    if (mobilization.exists) {
      throw new PlatformAdministrationError(
        'already-exists',
        'Cette mobilisation existe déjà.',
      );
    }
    requireActiveTerritory(territory);
    const attachedOperation = operation === null
      ? null
      : requireAttachableOperation(operation);
    requireValidScopes(scopeRefs, scopeSnapshots);
    const coordinatorUid = operationCoordinatorUid(attachedOperation);
    const coordinatorRoleRef = coordinatorUid === null
      ? null
      : firestore.collection('roles').doc(coordinatorUid);
    const assignmentRef = coordinatorUid === null
      ? null
      : firestore
        .collection('mobilizationAssignments')
        .doc(`${request.mobilizationId}_${coordinatorUid}`);
    const [coordinatorRole, assignment] = coordinatorUid === null
      ? [null, null]
      : await Promise.all([
        transaction.get(coordinatorRoleRef),
        transaction.get(assignmentRef),
      ]);
    if (
      coordinatorRole !== null
      && (!coordinatorRole.exists
        || !hasActiveCoordinatorRole(coordinatorRole.data()))
    ) {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Le Coordinateur principal de l’opération n’est plus actif.',
      );
    }
    const timestamp = serverTimestamp();
    const fields = {
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
      scopeRefs,
      schemaVersion: 2,
    };
    if (request.operationId !== undefined) {
      fields.operationId = request.operationId;
    }
    transaction.create(mobilizationRef, fields);
    if (coordinatorUid !== null) {
      transaction.set(assignmentRef, {
        uid: coordinatorUid,
        mobilizationId: request.mobilizationId,
        role: 'coordinator',
        active: true,
        assignedBy: request.callerUid,
        createdAt: assignment.exists
          ? assignment.data().createdAt ?? timestamp
          : timestamp,
        updatedBy: request.callerUid,
        updatedAt: timestamp,
      }, {merge: false});
      transaction.update(coordinatorRoleRef, {
        hasActiveMobilizationAssignments: true,
      });
    }
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
    const [mobilization, territory, operation, scopeSnapshots] = await Promise.all([
      transaction.get(mobilizationRef),
      transaction.get(territoryRef),
      request.operationId === undefined
        ? Promise.resolve(null)
        : transaction.get(operationReference(firestore, request.operationId)),
      request.scopeRefs === undefined
        ? Promise.resolve([])
        : readScopeReferences({
          firestore,
          transaction,
          refs: request.scopeRefs,
        }),
    ]);
    const current = requireMobilization(mobilization);
    requireActiveTerritory(territory);
    const attachedOperation = operation === null
      ? null
      : requireAttachableOperation(operation);
    if (request.scopeRefs !== undefined) {
      requireValidScopes(request.scopeRefs, scopeSnapshots);
    }
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
    if (
      current.status === 'active'
      && request.operationId !== undefined
      && current.operationId !== request.operationId
    ) {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'L’opération d’une mobilisation active ne peut pas changer.',
      );
    }
    const coordinatorUid = operationCoordinatorUid(attachedOperation);
    let coordinatorSync = null;
    if (coordinatorUid !== null) {
      const roleRef = firestore.collection('roles').doc(coordinatorUid);
      const assignmentRef = firestore
        .collection('mobilizationAssignments')
        .doc(`${request.mobilizationId}_${coordinatorUid}`);
      const activeAssignmentsQuery = firestore
        .collection('mobilizationAssignments')
        .where('mobilizationId', '==', request.mobilizationId);
      const [role, assignment, activeAssignments] = await Promise.all([
        transaction.get(roleRef),
        transaction.get(assignmentRef),
        transaction.get(activeAssignmentsQuery),
      ]);
      if (!role.exists || !hasActiveCoordinatorRole(role.data())) {
        throw new PlatformAdministrationError(
          'failed-precondition',
          'Le Coordinateur principal de l’opération n’est plus actif.',
        );
      }
      const activeCoordinatorAssignments = activeAssignments.docs.filter(
        (snapshot) => snapshot.data().role === 'coordinator'
          && snapshot.data().active === true,
      );
      const oldUids = [...new Set(
        activeCoordinatorAssignments
          .map((snapshot) => snapshot.data().uid)
          .filter((uid) => typeof uid === 'string' && uid !== coordinatorUid),
      )];
      const oldRoleRefs = oldUids.map((uid) =>
        firestore.collection('roles').doc(uid));
      const oldAssignmentQueries = oldUids.map((uid) => firestore
        .collection('mobilizationAssignments')
        .where('uid', '==', uid)
        .where('role', '==', 'coordinator')
        .where('active', '==', true));
      const [oldRoles, oldAssignments] = await Promise.all([
        Promise.all(oldRoleRefs.map((reference) => transaction.get(reference))),
        Promise.all(oldAssignmentQueries.map((query) => transaction.get(query))),
      ]);
      coordinatorSync = {
        coordinatorUid,
        roleRef,
        assignmentRef,
        assignment,
        activeAssignments: activeCoordinatorAssignments,
        oldUids,
        oldRoleRefs,
        oldRoles,
        oldAssignments,
      };
    }
    const timestamp = serverTimestamp();
    const fields = {
      territoryId: request.territoryId,
      name: request.name,
      subtitle: request.subtitle,
      contextType: request.contextType,
      updatedBy: request.callerUid,
      updatedAt: timestamp,
    };
    if (request.operationId !== undefined) fields.operationId = request.operationId;
    if (request.scopeRefs !== undefined) fields.scopeRefs = request.scopeRefs;
    transaction.update(mobilizationRef, fields);
    if (coordinatorSync !== null) {
      for (const existing of coordinatorSync.activeAssignments) {
        if (
          existing.data().uid === coordinatorSync.coordinatorUid
          && existing.id ===
            `${request.mobilizationId}_${coordinatorSync.coordinatorUid}`
        ) continue;
        transaction.update(existing.ref ?? firestore
          .collection('mobilizationAssignments')
          .doc(existing.id), {
          active: false,
          updatedBy: request.callerUid,
          updatedAt: timestamp,
        });
      }
      transaction.set(coordinatorSync.assignmentRef, {
        uid: coordinatorSync.coordinatorUid,
        mobilizationId: request.mobilizationId,
        role: 'coordinator',
        active: true,
        assignedBy: request.callerUid,
        createdAt: coordinatorSync.assignment.exists
          ? coordinatorSync.assignment.data().createdAt ?? timestamp
          : timestamp,
        updatedBy: request.callerUid,
        updatedAt: timestamp,
      }, {merge: false});
      transaction.update(coordinatorSync.roleRef, {
        hasActiveMobilizationAssignments: true,
      });
      for (let index = 0; index < coordinatorSync.oldUids.length; index += 1) {
        if (!coordinatorSync.oldRoles[index].exists) continue;
        const remainsAssigned = coordinatorSync.oldAssignments[index].docs.some(
          (snapshot) =>
            snapshot.data().mobilizationId !== request.mobilizationId,
        );
        transaction.update(coordinatorSync.oldRoleRefs[index], {
          hasActiveMobilizationAssignments: remainsAssigned,
        });
      }
    }
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
    const [mobilization, config, assignments] =
      await Promise.all([
        transaction.get(mobilizationRef),
        transaction.get(configRef),
        transaction.get(assignmentsQuery),
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

    const configuredActiveId = config.exists
      ? config.data().activeMobilizationId
      : null;
    const timestamp = serverTimestamp();
    transaction.update(mobilizationRef, {
      status: 'active',
      activatedBy: request.callerUid,
      activatedAt: timestamp,
      updatedBy: request.callerUid,
      updatedAt: timestamp,
    });
    // Fallback RC3.5A : le premier pointeur reste disponible pour les écrans
    // legacy, sans devenir une autorité pour les nouveaux flux.
    if (configuredActiveId === null || configuredActiveId === undefined) {
      transaction.set(configRef, {
        activeMobilizationId: request.mobilizationId,
        updatedBy: request.callerUid,
        updatedAt: timestamp,
      }, {merge: true});
    }
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
    if (current.status !== 'active') {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Cette mobilisation n’est pas active.',
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
    if (config.exists
      && config.data().activeMobilizationId === request.mobilizationId) {
      transaction.set(configRef, {
        activeMobilizationId: null,
        updatedBy: request.callerUid,
        updatedAt: timestamp,
      }, {merge: true});
    }
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
    const operation = current.operationId === undefined
      ? null
      : await transaction.get(
        operationReference(firestore, current.operationId),
      );
    if (operation !== null && operationCoordinatorUid(requireOperation(operation)) !== null) {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Gérez le Coordinateur depuis l’opération.',
      );
    }
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
    transaction.update(roleRef, {
      hasActiveMobilizationAssignments: true,
    });
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
    const roleRef = firestore.collection('roles').doc(request.uid);
    const activeAssignmentsQuery = firestore
      .collection('mobilizationAssignments')
      .where('uid', '==', request.uid)
      .where('role', '==', 'coordinator')
      .where('active', '==', true);
    const [mobilization, assignment, role, activeAssignments] =
      await Promise.all([
        transaction.get(mobilizationRef),
        transaction.get(assignmentRef),
        transaction.get(roleRef),
        transaction.get(activeAssignmentsQuery),
      ]);
    const current = requireMobilization(mobilization);
    const operation = current.operationId === undefined
      ? null
      : await transaction.get(
        operationReference(firestore, current.operationId),
      );
    if (operation !== null && operationCoordinatorUid(requireOperation(operation)) !== null) {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Gérez le Coordinateur depuis l’opération.',
      );
    }
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
    if (role.exists) {
      transaction.update(roleRef, {
        hasActiveMobilizationAssignments: activeAssignments.docs.some(
          (candidate) => candidate.id !== assignmentId,
        ),
      });
    }
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

function requireOperation(snapshot) {
  if (!snapshot.exists) {
    throw new PlatformAdministrationError(
      'not-found',
      'Opération introuvable.',
    );
  }
  const current = snapshot.data();
  if (
    current === null
    || typeof current !== 'object'
    || Array.isArray(current)
    || current.id !== snapshot.id
    || !OPERATION_STATUSES.has(current.status)
  ) {
    throw new PlatformAdministrationError(
      'failed-precondition',
      'Le document d’opération existant est invalide.',
    );
  }
  return current;
}

function requireAttachableOperation(snapshot) {
  const operation = requireOperation(snapshot);
  if (operation.status === 'completed' || operation.status === 'archived') {
    throw new PlatformAdministrationError(
      'failed-precondition',
      'Cette opération ne peut plus recevoir de mobilisation.',
    );
  }
  return operation;
}

function operationCoordinatorUid(operation) {
  if (
    operation === null
    || operation === undefined
    || operation.coordinatorUid === null
    || operation.coordinatorUid === undefined
  ) {
    return null;
  }
  const uid = operation.coordinatorUid;
  if (
    typeof uid !== 'string'
    || uid.length === 0
    || uid.length > 128
    || uid.trim() !== uid
    || uid.includes('/')
  ) {
    throw new PlatformAdministrationError(
      'failed-precondition',
      'Le Coordinateur principal de l’opération est invalide.',
    );
  }
  return uid;
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

function operationReference(firestore, operationId) {
  return firestore.collection('operations').doc(operationId);
}

async function readScopeReferences({firestore, transaction, refs}) {
  return Promise.all(refs.map((ref) => {
    const [collection, id] = ref.split('/');
    return transaction.get(firestore.collection(collection).doc(id));
  }));
}

function requireValidScopes(refs, snapshots) {
  if (refs.length !== snapshots.length) {
    throw new PlatformAdministrationError(
      'failed-precondition',
      'Le périmètre opérationnel est invalide.',
    );
  }
  for (let index = 0; index < refs.length; index += 1) {
    const snapshot = snapshots[index];
    const collection = refs[index].split('/')[0];
    const data = snapshot.exists ? snapshot.data() : null;
    const valid = data !== null
      && (collection === 'territories'
        ? data.active === true
        : (data.isActive === true && data.isOperational !== false));
    if (!valid) {
      throw new PlatformAdministrationError(
        'failed-precondition',
        'Un élément du périmètre est introuvable ou inactif.',
      );
    }
  }
}
