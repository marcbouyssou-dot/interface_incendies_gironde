#!/usr/bin/env node

import {createHash} from 'node:crypto';
import {readFile, writeFile} from 'node:fs/promises';
import {applicationDefault, initializeApp} from 'firebase-admin/app';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';

const csvPath = new URL('../data/locations_verified.csv', import.meta.url);
const reportPath = new URL('../data/location_address_dry_run.json', import.meta.url);
const backupPath = new URL('../data/location_address_backup.json', import.meta.url);
const apply = process.argv.includes('--apply');
const dryRun = process.argv.includes('--dry-run');

if (apply === dryRun) {
  throw new Error('Choisir exactement --dry-run ou --apply.');
}

const projectId = process.env.FIREBASE_PROJECT_ID;
if (!projectId) throw new Error('FIREBASE_PROJECT_ID est obligatoire.');

const csvText = await readFile(csvPath, 'utf8');
const checksum = createHash('sha256').update(csvText).digest('hex');
const [header, ...lines] = parseCsv(csvText);
const rows = lines.map((values) =>
  Object.fromEntries(header.map((key, index) => [key, values[index] ?? ''])),
);

initializeApp({credential: applicationDefault(), projectId});
const firestore = getFirestore();
const snapshot = await firestore.collection('locations').get();
const remote = new Map(snapshot.docs.map((document) => [document.id, document]));
const unknown = rows.filter((row) => !remote.has(row.location_id));
if (unknown.length > 0) {
  throw new Error(
    `Identifiants inconnus: ${unknown.map((row) => row.location_id).join(', ')}`,
  );
}
const divergent = rows.filter((row) => {
  const data = remote.get(row.location_id).data();
  return data.name !== row.name
    || (data.group ?? data.territorialGroup) !== row.territorial_group
    || data.type !== row.location_type;
});
if (divergent.length > 0) {
  throw new Error(
    `Métadonnées divergentes: ${divergent.map((row) => row.location_id).join(', ')}`,
  );
}

const validated = rows.filter((row) =>
  ['verified_official', 'verified_cross_source'].includes(row.address_status),
);
const changes = validated.map((row) => ({
  id: row.location_id,
  before: addressFields(remote.get(row.location_id).data()),
  after: addressFieldsFromRow(row),
}));

if (dryRun) {
  await writeFile(
    reportPath,
    JSON.stringify(
      {
        generatedAt: new Date().toISOString(),
        projectId,
        csvChecksum: checksum,
        totalRows: rows.length,
        validatedRows: validated.length,
        ignoredRows: rows.length - validated.length,
        changes,
      },
      null,
      2,
    ),
  );
  console.log(`DRY RUN: ${changes.length} mise(s) à jour, aucune écriture.`);
  console.log(`Rapport: ${reportPath.pathname}`);
  process.exit(0);
}

const report = JSON.parse(await readFile(reportPath, 'utf8'));
if (report.projectId !== projectId || report.csvChecksum !== checksum) {
  throw new Error(
    'Le dry-run ne correspond pas au projet ou au CSV actuel. Relancer --dry-run.',
  );
}
await writeFile(
  backupPath,
  JSON.stringify(
    {
      exportedAt: new Date().toISOString(),
      projectId,
      documents: snapshot.docs.map((document) => ({
        id: document.id,
        data: document.data(),
      })),
    },
    null,
    replacer,
  ),
);

const batch = firestore.batch();
for (const change of changes) {
  batch.update(remote.get(change.id).ref, change.after);
}
await batch.commit();
console.log(`APPLY: ${changes.length} lieu(x) mis à jour.`);
console.log(`Sauvegarde: ${backupPath.pathname}`);

function addressFieldsFromRow(row) {
  return {
    addressLine1: row.address_line_1,
    addressLine2: row.address_line_2 || null,
    postalCode: row.postal_code,
    city: row.city,
    country: row.country || 'France',
    fullAddress: row.full_address,
    latitude: row.latitude ? Number(row.latitude) : null,
    longitude: row.longitude ? Number(row.longitude) : null,
    addressStatus: row.address_status,
    addressSourceLabel: row.source_label,
    addressSourceUrl: row.source_url,
    addressSecondSourceUrl: row.second_source_url || null,
    addressVerifiedAt: row.verified_at
      ? Timestamp.fromDate(new Date(`${row.verified_at}T00:00:00Z`))
      : null,
    addressNotes: row.notes || null,
  };
}

function addressFields(data) {
  return Object.fromEntries(
    Object.entries(data).filter(([key]) =>
      [
        'addressLine1', 'addressLine2', 'postalCode', 'city', 'country',
        'fullAddress', 'latitude', 'longitude', 'addressStatus',
        'addressSourceLabel', 'addressSourceUrl', 'addressSecondSourceUrl',
        'addressVerifiedAt', 'addressNotes',
      ].includes(key),
    ),
  );
}

function replacer(_key, value) {
  return value instanceof Timestamp ? value.toDate().toISOString() : value;
}

function parseCsv(input) {
  const result = [];
  let row = [];
  let field = '';
  let quoted = false;
  for (let index = 0; index < input.length; index++) {
    const char = input[index];
    if (quoted && char === '"' && input[index + 1] === '"') {
      field += '"';
      index++;
    } else if (char === '"') {
      quoted = !quoted;
    } else if (!quoted && char === ',') {
      row.push(field);
      field = '';
    } else if (!quoted && (char === '\n' || char === '\r')) {
      if (char === '\r' && input[index + 1] === '\n') index++;
      row.push(field);
      if (row.some((value) => value.length > 0)) result.push(row);
      row = [];
      field = '';
    } else {
      field += char;
    }
  }
  if (field || row.length) {
    row.push(field);
    result.push(row);
  }
  return result;
}
