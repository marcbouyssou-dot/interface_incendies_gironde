#!/usr/bin/env node

import {createHash} from 'node:crypto';
import {readFile, writeFile} from 'node:fs/promises';
import {applicationDefault, initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {
  buildMigrationPlan,
  parseCsv,
  resolveExecution,
  sanitizePlan,
  writableChanges,
} from './location_address_migration.mjs';

const csvPath = new URL('../data/locations_verified.csv', import.meta.url);
const reportPath = new URL('../data/location_address_dry_run.json', import.meta.url);
const backupPath = new URL('../data/location_address_backup.json', import.meta.url);
const {apply, projectId} = resolveExecution({
  environment: process.env,
  arguments: process.argv.slice(2),
});
console.log(`Projet Firebase ciblé: ${projectId}`);
console.log(apply ? 'Mode: APPLY CONFIRMÉ' : 'Mode: DRY RUN (aucune écriture)');

const csvText = await readFile(csvPath, 'utf8');
const checksum = createHash('sha256').update(csvText).digest('hex');
const rows = parseCsv(csvText);

initializeApp({credential: applicationDefault(), projectId});
const firestore = getFirestore();
const snapshot = await firestore.collection('locations').get();
const documents = snapshot.docs.map((document) => ({
  id: document.id,
  data: document.data(),
}));
const plan = buildMigrationPlan({projectId, rows, documents});
const sanitized = {
  generatedAt: new Date().toISOString(),
  csvChecksum: checksum,
  ...sanitizePlan(plan),
};
console.log(JSON.stringify(sanitized.summary, null, 2));

if (!apply) {
  await writeFile(reportPath, JSON.stringify(sanitized, null, 2));
  console.log('DRY RUN terminé: aucune écriture Firestore.');
  console.log(`Rapport: ${reportPath.pathname}`);
  process.exit(0);
}

const previousReport = JSON.parse(await readFile(reportPath, 'utf8'));
if (
  previousReport.projectId !== projectId
  || previousReport.csvChecksum !== checksum
) {
  throw new Error(
    'Le dry-run ne correspond pas au projet ou au CSV actuel. '
    + 'Relancer le dry-run.',
  );
}
if ((plan.summary.categories.complet_mais_different ?? 0) > 0) {
  throw new Error('Des conflits nécessitent une validation humaine.');
}

const changes = writableChanges(plan);
if (changes.length === 0) {
  console.log('APPLY CONFIRMÉ: 0 document modifié, aucun batch créé.');
  process.exit(0);
}

await writeFile(
  backupPath,
  JSON.stringify(
    {
      exportedAt: new Date().toISOString(),
      projectId,
      documents,
    },
    timestampReplacer,
    2,
  ),
);
console.log(`Sauvegarde créée: ${backupPath.pathname}`);
const batch = firestore.batch();
for (const change of changes) {
  batch.update(
    firestore.collection('locations').doc(change.id),
    change.fields,
  );
}
await batch.commit();
console.log(`APPLY CONFIRMÉ: ${changes.length} lieu(x) complété(s).`);
console.log(`Sauvegarde: ${backupPath.pathname}`);

function timestampReplacer(_key, value) {
  return value?.toDate instanceof Function
    ? value.toDate().toISOString()
    : value;
}
