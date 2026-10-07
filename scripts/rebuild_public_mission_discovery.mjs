#!/usr/bin/env node

import {pathToFileURL} from 'node:url';
import {applicationDefault, getApps, initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';

import {
  PUBLIC_MISSION_COLLECTION,
  planPublicMissionDiscovery,
} from '../functions/src/public_discovery/projector.js';
import {reconcilePublicMission} from '../functions/src/public_discovery/firestore_projector.js';

export function resolveExecution(arguments_ = process.argv.slice(2)) {
  let projectId = null;
  let apply = false;
  let productionWriteAuthorized = false;
  for (const argument of arguments_) {
    if (argument.startsWith('--project=')) {
      projectId = argument.slice('--project='.length);
    } else if (argument === '--apply') {
      apply = true;
    } else if (argument === '--production-write-authorized') {
      productionWriteAuthorized = true;
    } else {
      throw new Error('Argument inconnu.');
    }
  }
  if (!projectId || !/^[a-z][a-z0-9-]{4,40}$/.test(projectId)) {
    throw new Error('Un --project explicite est requis.');
  }
  if (productionWriteAuthorized && !apply) {
    throw new Error('Autorisation de production sans --apply.');
  }
  const emulator = /^(127\.0\.0\.1|localhost|\[::1\]):[0-9]+$/
    .test(process.env.FIRESTORE_EMULATOR_HOST ?? '');
  if (apply && !emulator && !productionWriteAuthorized) {
    throw new Error('Écriture distante interdite sans autorisation future explicite.');
  }
  return {projectId, apply, productionWriteAuthorized};
}

function safeId(value) {
  return /^[A-Za-z0-9_-]{1,128}$/.test(value) ? value : '[identifiant masqué]';
}

export async function runRebuild({firestore, apply = false, log = console.log,
  now = new Date()}) {
  const [missions, locations, mobilizations, operations, projections, config] =
    await Promise.all([
      firestore.collection('missions').get(),
      firestore.collection('locations').get(),
      firestore.collection('mobilizations').get(),
      firestore.collection('operations').get(),
      firestore.collection(PUBLIC_MISSION_COLLECTION).get(),
      firestore.doc('platform/config').get(),
    ]);
  const entries = (snapshot, includeId = false) => new Map(
    snapshot.docs.map((document) => [
      document.id,
      includeId ? {...document.data(), id: document.id} : document.data(),
    ]),
  );
  const plan = planPublicMissionDiscovery({
    missions: entries(missions),
    mobilizations: entries(mobilizations, true),
    operations: entries(operations),
    currentProjections: entries(projections),
    activeMobilizationId: config.data()?.activeMobilizationId,
    now,
  });
  const counts = {CREATE: 0, UPDATE: 0, DELETE: 0, UNCHANGED: 0};
  for (const item of plan) {
    counts[item.action]++;
    log(`${item.action} ${safeId(item.publicId)}`);
  }
  log(`SOURCE_COUNTS missions=${missions.size} locations=${locations.size} ` +
    `mobilizations=${mobilizations.size} operations=${operations.size}`);
  log(`PLAN CREATE=${counts.CREATE} UPDATE=${counts.UPDATE} ` +
    `DELETE=${counts.DELETE} UNCHANGED=${counts.UNCHANGED}`);
  if (apply) {
    for (const item of plan) {
      if (item.action !== 'UNCHANGED') {
        if (item.missionId === null) {
          await firestore.collection(PUBLIC_MISSION_COLLECTION)
            .doc(item.publicId).delete();
        } else {
          await reconcilePublicMission(firestore, item.missionId);
        }
      }
    }
    log('APPLY terminé ; sources opérationnelles inchangées.');
  } else {
    log('DRY RUN ; aucune écriture.');
  }
  return {counts, sourceCounts: {missions: missions.size, locations: locations.size}};
}

async function main() {
  const options = resolveExecution();
  if (getApps().length === 0) {
    initializeApp({credential: applicationDefault(), projectId: options.projectId});
  }
  await runRebuild({firestore: getFirestore(), apply: options.apply});
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
