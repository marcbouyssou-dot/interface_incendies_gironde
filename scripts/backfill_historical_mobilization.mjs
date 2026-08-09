#!/usr/bin/env node

import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {applicationDefault, initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';

import {
  historicalMobilizationId,
  resolveBackfillExecution,
  runHistoricalMobilizationBackfill,
} from './historical_mobilization_backfill.mjs';

export async function main({
  commandArguments = process.argv.slice(2),
  log = console.log,
} = {}) {
  const execution = resolveBackfillExecution(commandArguments);
  log(`Projet Firebase ciblé: ${execution.projectId}`);
  log(`Mode: ${execution.mode === 'apply' ? 'APPLY' : 'DRY RUN'}`);

  initializeApp({
    credential: applicationDefault(),
    projectId: execution.projectId,
  });
  const firestore = getFirestore();
  const result = await runHistoricalMobilizationBackfill({
    mode: execution.mode,
    readCollections: () => readCollections(firestore),
    writePatches: (patches) => writeBatch(firestore, patches),
  });

  printReport('AVANT', result.before.summary, log);
  printReport('APRÈS PRÉVU', result.expectedAfter, log);
  if (result.before.summary.global === 'NO-GO') {
    logBlockers(result.before, log);
    throw new Error('NO-GO: incohérences détectées, aucune écriture.');
  }
  if (result.after !== null) {
    printReport('APRÈS VÉRIFIÉ', result.after.summary, log);
  }
  log(`${execution.mode.toUpperCase()} terminé: ${result.writes} écriture(s).`);
  return result;
}

async function readCollections(firestore) {
  const [missions, engagements] = await Promise.all([
    firestore.collection('missions').get(),
    firestore.collection('engagements').get(),
  ]);
  return {
    missions: missions.docs.map(snapshotDocument),
    engagements: engagements.docs.map(snapshotDocument),
  };
}

async function writeBatch(firestore, patches) {
  return firestore.runTransaction(async (transaction) => {
    const snapshots = await Promise.all(
      patches.map((patch) => transaction.get(firestore.doc(patch.path))),
    );
    const missionIds = [...new Set(
      patches
        .filter((patch) => patch.kind === 'engagement')
        .map((patch) => patch.missionId),
    )];
    const missionSnapshots = await Promise.all(
      missionIds.map((id) =>
        transaction.get(firestore.collection('missions').doc(id)),
      ),
    );
    const missionsById = new Map(
      missionSnapshots.map((snapshot, index) => [
        missionIds[index],
        snapshot.exists ? snapshot.data() : null,
      ]),
    );
    const updates = [];
    for (const [index, patch] of patches.entries()) {
      const snapshot = snapshots[index];
      if (!snapshot.exists) {
        throw new Error(`Document disparu avant écriture: ${patch.path}.`);
      }
      const data = snapshot.data();
      const current = data.mobilizationId;
      if (
        Object.hasOwn(data, 'mobilizationId')
        && current !== historicalMobilizationId
      ) {
        throw new Error(
          `Conflit concurrent avant écriture: ${patch.path}.`,
        );
      }
      if (patch.kind === 'engagement') {
        if (data.missionId !== patch.missionId) {
          throw new Error(
            `Mission modifiée avant écriture: ${patch.path}.`,
          );
        }
        const mission = missionsById.get(patch.missionId);
        if (mission?.mobilizationId !== historicalMobilizationId) {
          throw new Error(
            `Mission incohérente avant écriture: ${patch.path}.`,
          );
        }
      }
      if (current !== historicalMobilizationId) {
        updates.push({reference: snapshot.ref, fields: patch.fields});
      }
    }
    for (const update of updates) {
      transaction.update(update.reference, update.fields);
    }
    return updates.length;
  });
}

function snapshotDocument(snapshot) {
  return {id: snapshot.id, data: snapshot.data()};
}

function printReport(label, summary, log) {
  log(label);
  printCollection('MISSIONS', summary.missions, log);
  printCollection('ENGAGEMENTS', summary.engagements, log);
  log(`GLOBAL: ${summary.global}`);
}

function printCollection(label, summary, log) {
  log(label);
  log(`- total: ${summary.total}`);
  log(`- à modifier: ${summary.toModify}`);
  log(`- déjà conformes: ${summary.compliant}`);
  log(`- conflits: ${summary.conflicts}`);
  if (label === 'ENGAGEMENTS') log(`- orphelins: ${summary.orphans}`);
  log(`- malformés: ${summary.malformed}`);
}

function logBlockers(plan, log) {
  for (const [collection, entries] of [
    ['missions', plan.missions],
    ['engagements', plan.engagements],
  ]) {
    for (const entry of entries) {
      if (['conflict', 'orphan', 'malformed'].includes(entry.action)) {
        log(
          `STOP ${collection}/${entry.id}: `
          + `${entry.reason ?? entry.action}`,
        );
      }
    }
  }
}

const invokedUrl = process.argv[1]
  ? pathToFileURL(resolve(process.argv[1])).href
  : null;
if (invokedUrl === import.meta.url) {
  await main();
}
