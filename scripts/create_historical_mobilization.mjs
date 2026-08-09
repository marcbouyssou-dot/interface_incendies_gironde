#!/usr/bin/env node

import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {applicationDefault, initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';

import {
  resolveHistoricalBootstrapExecution,
  runHistoricalMobilizationBootstrap,
} from './historical_mobilization_bootstrap.mjs';

export async function main({
  environment = process.env,
  commandArguments = process.argv.slice(2),
  log = console.log,
} = {}) {
  const execution = resolveHistoricalBootstrapExecution({
    environment,
    arguments: commandArguments,
  });
  log(`Projet Firebase ciblé: ${execution.projectId}`);
  log(`Mode: ${execution.mode === 'apply' ? 'APPLY' : 'DRY RUN'}`);

  initializeApp({
    credential: applicationDefault(),
    projectId: execution.projectId,
  });
  const firestore = getFirestore();
  const result = execution.mode === 'dry-run'
    ? await runDryRun(firestore)
    : await runApply(firestore);

  for (const entry of result.entries) {
    log(`${entry.action.toUpperCase()}: ${entry.path}`);
  }
  log(
    `Résumé: ${result.summary.create} création(s), `
    + `${result.summary.unchanged} document(s) inchangé(s).`,
  );
  if (execution.mode === 'dry-run') {
    log('DRY RUN terminé: aucune écriture Firestore.');
  } else {
    log(`APPLY terminé: ${result.writes} document(s) créé(s).`);
  }
  return result;
}

async function runDryRun(firestore) {
  return runHistoricalMobilizationBootstrap({
    mode: 'dry-run',
    readDocuments: (paths) => readWithGetAll(firestore, paths),
  });
}

async function runApply(firestore) {
  return firestore.runTransaction((transaction) =>
    runHistoricalMobilizationBootstrap({
      mode: 'apply',
      readDocuments: (paths) => readWithTransaction(
        firestore,
        transaction,
        paths,
      ),
      createDocuments: async (creations) => {
        for (const creation of creations) {
          transaction.create(firestore.doc(creation.path), creation.data);
        }
      },
      serverTimestamp: () => FieldValue.serverTimestamp(),
    }),
  );
}

async function readWithGetAll(firestore, paths) {
  const snapshots = await firestore.getAll(
    ...paths.map((path) => firestore.doc(path)),
  );
  return snapshotsByPath(paths, snapshots);
}

async function readWithTransaction(firestore, transaction, paths) {
  const snapshots = await Promise.all(
    paths.map((path) => transaction.get(firestore.doc(path))),
  );
  return snapshotsByPath(paths, snapshots);
}

function snapshotsByPath(paths, snapshots) {
  return new Map(
    snapshots.map((snapshot, index) => [
      paths[index],
      snapshot.exists ? snapshot.data() : null,
    ]),
  );
}

const invokedUrl = process.argv[1]
  ? pathToFileURL(resolve(process.argv[1])).href
  : null;
if (invokedUrl === import.meta.url) {
  await main();
}
