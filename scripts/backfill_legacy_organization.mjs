#!/usr/bin/env node

import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {applicationDefault, initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';

import {
  legacyOrganizationId,
  materializeLegacyOrganizationChange,
  resolveLegacyOrganizationBackfillExecution,
  runLegacyOrganizationBackfill,
} from './legacy_organization_backfill.mjs';

const collectionFields = Object.freeze({
  organizations: null,
  organizationMemberships: null,
  roles: ['role', 'roles', 'locationIds', 'active', 'schemaVersion'],
  platformAdministrators: ['active'],
  volunteers: ['uid'],
  operations: ['ownerOrganizationId'],
  mobilizations: ['operationId'],
  missions: ['mobilizationId'],
  engagements: ['missionId', 'mobilizationId'],
  mobilizationAssignments: ['mobilizationId'],
  locations: ['managingOrganizationId'],
});

export async function main({
  commandArguments = process.argv.slice(2),
  log = console.log,
} = {}) {
  const execution = resolveLegacyOrganizationBackfillExecution(
    commandArguments,
  );
  log(`Projet Firebase ciblé: ${execution.projectId}`);
  log(`Mode: ${execution.mode === 'apply' ? 'APPLY CONFIRMÉ' : 'DRY RUN'}`);

  const app = initializeApp({
    credential: applicationDefault(),
    projectId: execution.projectId,
  });
  const firestore = getFirestore(app);
  const result = await runLegacyOrganizationBackfill({
    mode: execution.mode,
    readCollections: () => readCollections(firestore),
    writeChanges: (changes) => writeChanges(firestore, changes),
  });
  printReport(result.before.summary, log);
  if (result.before.summary.global === 'NO-GO') {
    throw new Error('NO-GO: conflits détectés, aucune écriture effectuée.');
  }
  if (result.after !== null) {
    log('Vérification post-backfill: GO.');
  }
  log(
    `${execution.mode === 'apply' ? 'APPLY' : 'DRY RUN'} terminé: `
    + `${result.writes} écriture(s).`,
  );
  if (execution.mode === 'dry-run') {
    log('Aucune donnée Firestore réelle modifiée.');
  }
  return result;
}

async function readCollections(firestore) {
  const entries = await Promise.all(
    Object.entries(collectionFields).map(async ([name, fields]) => {
      let query = firestore.collection(name);
      if (fields !== null) query = query.select(...fields);
      const snapshot = await query.get();
      return [name, snapshot.docs.map(snapshotDocument)];
    }),
  );
  return Object.fromEntries(entries);
}

async function writeChanges(firestore, changes) {
  return firestore.runTransaction(async (transaction) => {
    const references = changes.map((change) => firestore.doc(change.path));
    const snapshots = await Promise.all(
      references.map((reference) => transaction.get(reference)),
    );
    let writes = 0;
    for (const [index, change] of changes.entries()) {
      const snapshot = snapshots[index];
      if (change.kind === 'operation') {
        if (!snapshot.exists) {
          throw new Error('Une opération a disparu avant le backfill.');
        }
        const owner = snapshot.data().ownerOrganizationId;
        if (owner === legacyOrganizationId) continue;
        if (owner !== undefined && owner !== null) {
          throw new Error(
            'Une opération a reçu un propriétaire concurrent explicite.',
          );
        }
        transaction.update(snapshot.ref, change.values);
        writes++;
        continue;
      }
      if (snapshot.exists) {
        throw new Error(
          'Un document Organisation a été créé concurremment. Relancer le dry-run.',
        );
      }
      const materialized = materializeLegacyOrganizationChange({
        change,
        serverTimestamp: () => FieldValue.serverTimestamp(),
      });
      transaction.create(snapshot.ref, materialized.values);
      writes++;
    }
    return writes;
  });
}

function snapshotDocument(snapshot) {
  return {id: snapshot.id, data: snapshot.data()};
}

function printReport(summary, log) {
  log('ORGANISATION LEGACY');
  log(`- à créer: ${summary.organization.create}`);
  log(`- déjà conforme: ${summary.organization.unchanged}`);
  log(`- conflit: ${summary.organization.conflict}`);
  log('MEMBERSHIPS LEGACY');
  log(`- utilisateurs concernés: ${summary.memberships.usersConcerned}`);
  log(`- à créer: ${summary.memberships.create}`);
  log(`- déjà conformes/explicites: ${summary.memberships.unchanged}`);
  log(`- inactives: ${summary.memberships.inactive}`);
  log(`- rôles malformés: ${summary.memberships.malformedRoles}`);
  log(`- conflits: ${summary.memberships.conflicts}`);
  log(
    `- platform_admin sans membership implicite: `
    + `${summary.memberships.activePlatformAdministrators}`,
  );
  log(
    `- profils Professionnels sans membership implicite: `
    + `${summary.memberships.professionalProfiles}`,
  );
  log('OPÉRATIONS');
  log(`- total: ${summary.operations.total}`);
  log(`- à backfiller: ${summary.operations.toBackfill}`);
  log(`- déjà legacy: ${summary.operations.alreadyLegacy}`);
  log(`- propriétaires RC4 explicites: ${summary.operations.explicitRc4}`);
  log(`- conflits/malformées: ${
    summary.operations.conflicts + summary.operations.malformed
  }`);
  log('COLLECTIONS ENFANTS (audit uniquement)');
  for (const [name, child] of Object.entries(summary.children)) {
    log(
      `- ${name}: total=${child.total}, dérivables=${child.derive}, `
      + `fallback legacy=${child.legacyFallback}, explicites=${child.explicit}, `
      + `reportés=${child.defer}, non résolus=${child.unresolved}`,
    );
  }
  log(`GLOBAL: ${summary.global}`);
}

const invokedUrl = process.argv[1]
  ? pathToFileURL(resolve(process.argv[1])).href
  : null;
if (invokedUrl === import.meta.url) {
  await main();
}
