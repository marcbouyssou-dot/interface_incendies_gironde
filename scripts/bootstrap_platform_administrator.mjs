#!/usr/bin/env node

import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {applicationDefault, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';

import {
  resolvePlatformAdministratorExecution,
  resolvePlatformAdministratorUid,
  runPlatformAdministratorBootstrap,
} from './platform_administrator_bootstrap.mjs';

export async function main({
  environment = process.env,
  commandArguments = process.argv.slice(2),
  log = console.log,
} = {}) {
  const execution = resolvePlatformAdministratorExecution({
    environment,
    arguments: commandArguments,
  });
  log(`Projet Firebase ciblé: ${execution.projectId}`);
  log(`Mode: ${execution.mode === 'apply' ? 'APPLY' : 'DRY RUN'}`);

  const app = initializeApp({
    credential: applicationDefault(),
    projectId: execution.projectId,
  });
  const auth = getAuth(app);
  const firestore = getFirestore(app);
  const uid = await resolvePlatformAdministratorUid({
    auth,
    email: execution.targetEmail,
    uid: execution.targetUid,
  });
  log(`UID Firebase cible détecté: ${uid}`);

  const result = execution.mode === 'dry-run'
    ? await runDryRun({firestore, uid})
    : await runApply({firestore, uid});
  log(`${result.action.toUpperCase()}: ${result.path}`);
  if (execution.mode === 'dry-run') {
    log('DRY RUN terminé: aucune écriture Firestore.');
  } else {
    log(`APPLY terminé: ${result.writes} document créé.`);
  }
  return {...result, uid};
}

async function runDryRun({firestore, uid}) {
  return runPlatformAdministratorBootstrap({
    mode: 'dry-run',
    uid,
    readDocument: async (path) => {
      const snapshot = await firestore.doc(path).get();
      return snapshot.exists ? snapshot.data() : null;
    },
  });
}

async function runApply({firestore, uid}) {
  return firestore.runTransaction((transaction) =>
    runPlatformAdministratorBootstrap({
      mode: 'apply',
      uid,
      readDocument: async (path) => {
        const snapshot = await transaction.get(firestore.doc(path));
        return snapshot.exists ? snapshot.data() : null;
      },
      createDocument: async ({path, data}) => {
        transaction.create(firestore.doc(path), data);
      },
      serverTimestamp: () => FieldValue.serverTimestamp(),
    }),
  );
}

const invokedUrl = process.argv[1]
  ? pathToFileURL(resolve(process.argv[1])).href
  : null;
if (invokedUrl === import.meta.url) {
  await main();
}
