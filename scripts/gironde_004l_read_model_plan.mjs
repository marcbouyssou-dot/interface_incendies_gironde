#!/usr/bin/env node

// Offline-only derivation of the synthetic-history read model from 004J.
// Never connects to Firebase and never replaces the 004J archive.
import {createCipheriv, createDecipheriv, createHash, randomBytes} from 'node:crypto';
import {readFile, stat, writeFile} from 'node:fs/promises';

const directory = '/private/tmp/mobsante-004j-private';
const keyPath = '/private/tmp/mobsante-004j-key/backup-v2.key';
const sourcePath = `${directory}/cutover-plan-v3.aes256gcm.json`;
const backupPath = `${directory}/backup-v2.aes256gcm.json`;
const targetPath = `${directory}/cutover-plan-v4.aes256gcm.json`;
const operationId = 'incendies-gironde-2026';
const hash = (value) => createHash('sha256')
  .update(JSON.stringify(value)).digest('hex');
const check = (condition, message) => {
  if (!condition) throw Error(message);
};

async function privateFile(path) {
  const info = await stat(path);
  check(info.isFile() && (info.mode & 0o077) === 0,
    'Private file permissions invalid.');
  return readFile(path);
}

async function decrypt(path, key) {
  const envelope = JSON.parse((await privateFile(path)).toString('utf8'));
  check(envelope.algorithm === 'aes-256-gcm', 'Encryption format changed.');
  const decipher = createDecipheriv('aes-256-gcm', key,
    Buffer.from(envelope.iv, 'base64'));
  decipher.setAuthTag(Buffer.from(envelope.tag, 'base64'));
  return JSON.parse(Buffer.concat([
    decipher.update(Buffer.from(envelope.ciphertext, 'base64')),
    decipher.final(),
  ]).toString('utf8'));
}

function derive(plan, backup) {
  check(plan.projectId === 'mobilisation-sante'
    && plan.mutations.length === 67
    && plan.sourceBackupHash === hash(backup)
    && backup.siteHashes.length === 65
    && hash(backup.siteHashes) === backup.siteAggregateHash
    && plan.siteAggregateHash === backup.siteAggregateHash,
  '004J backup or plan drift.');
  const missionSites = new Map(backup.docs
    .filter((doc) => doc.path.startsWith('missions/'))
    .map((doc) => [doc.path.slice('missions/'.length),
      doc.data.locationId]));
  check(missionSites.size === 15, 'Historical mission count drift.');
  const actors = plan.mutations.filter((item) =>
    item.kind === 'create' && item.path.startsWith('demoActors/'));
  const engagements = plan.mutations.filter((item) =>
    item.kind === 'create' && item.path.startsWith('demoEngagements/'));
  check(actors.length === 12 && engagements.length === 9,
    'Synthetic object count drift.');
  const historicalSites = new Map(actors.map((item) =>
    [item.data.id, new Set(item.data.siteScopeIds)]));
  for (const engagement of engagements) {
    const siteId = missionSites.get(engagement.data.missionId);
    check(typeof siteId === 'string' && siteId.length > 0
      && historicalSites.has(engagement.data.actorId),
    'Synthetic engagement source mismatch.');
    historicalSites.get(engagement.data.actorId).add(siteId);
  }
  const mutations = plan.mutations.map((item) => {
    if (item.kind !== 'create') return item;
    if (item.path.startsWith('demoActors/')) {
      return {...item, data: {...item.data, operationId,
        historicalSiteIds: [...historicalSites.get(item.data.id)].sort()}};
    }
    if (item.path.startsWith('demoEngagements/')) {
      return {...item, data: {...item.data, operationId,
        locationId: missionSites.get(item.data.missionId)}};
    }
    return item;
  });
  check(mutations.every((item) => !item.path.startsWith('locations/')),
    'A site would be modified.');
  const friendUids = plan.privateActorMapping.filter((entry) =>
    entry.accountDisposition === 'FRIEND_TEST_ACCOUNT_REMOVE')
    .map((entry) => entry.sourceUid);
  check(friendUids.length === 9, 'Friend removal count drift.');
  check(mutations.filter((item) => item.kind !== 'delete')
    .every((item) => !friendUids.some((uid) =>
      JSON.stringify(item.data).includes(uid))),
  'Friend identity would remain in demonstration data.');
  const targetOperation = mutations.find((item) =>
    item.path === `operations/${operationId}`);
  check(targetOperation?.kind === 'create'
    && targetOperation.data.purpose === 'demonstration'
    && targetOperation.data.status === 'completed'
    && targetOperation.data.themeKey === 'fire',
  'Demonstration Action contract drift.');
  check(mutations.filter((item) => item.kind === 'create').length === 22
    && mutations.filter((item) => item.kind === 'update').length === 17
    && mutations.filter((item) => item.kind === 'delete').length === 28,
  'Mutation budget drift.');
  check(engagements.filter((item) => item.data.statusKnown).length === 8
    && engagements.filter((item) => !item.data.statusKnown).length === 1,
  'Historical status distribution drift.');
  return {...plan, schemaVersion: 2, sourcePlanHash: hash(plan),
    readModelLot: 'BETA-READY-004L', mutations,
    counts: {...plan.counts, historicalAccessGrants: 0,
      historicalAccessAudits: 0, untouchedSites: 65}};
}

async function main() {
  check(process.argv.length === 2
    || (process.argv.length === 3 && process.argv[2] === '--verify'),
  'Unsupported offline command.');
  check(!process.env.FIRESTORE_EMULATOR_HOST,
    'This offline plan must not depend on a Firestore instance.');
  const key = await privateFile(keyPath);
  check(key.length === 32, 'Invalid private key.');
  const [source, backup] = await Promise.all([
    decrypt(sourcePath, key), decrypt(backupPath, key),
  ]);
  const plan = derive(source, backup);
  if (process.argv[2] === '--verify') {
    const saved = await decrypt(targetPath, key);
    check(saved.sourcePlanHash === plan.sourcePlanHash
      && saved.siteAggregateHash === plan.siteAggregateHash
      && hash(saved.mutations) === hash(plan.mutations),
    'Saved offline plan differs from qualified source.');
    process.stdout.write(JSON.stringify({result: 'OFFLINE_CANDIDATE_VERIFIED',
      creates: 22, updates: 17, deletes: 28, total: 67,
      historicalAccessGrants: 0, untouchedSites: 65,
      siteAggregateHash: plan.siteAggregateHash}) + '\n');
    return;
  }
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([
    cipher.update(JSON.stringify(plan)), cipher.final(),
  ]);
  const envelope = {schemaVersion: 1, algorithm: 'aes-256-gcm',
    iv: iv.toString('base64'), tag: cipher.getAuthTag().toString('base64'),
    ciphertext: encrypted.toString('base64')};
  await writeFile(targetPath, `${JSON.stringify(envelope)}\n`,
    {flag: 'wx', mode: 0o600});
  process.stdout.write(JSON.stringify({result: 'OFFLINE_CANDIDATE_READY',
    planPath: targetPath, creates: 22, updates: 17, deletes: 28,
    total: 67, historicalAccessGrants: 0, untouchedSites: 65,
    siteAggregateHash: plan.siteAggregateHash,
    sourcePlanHash: plan.sourcePlanHash}) + '\n');
}

main().catch(() => {
  process.stderr.write('BLOCKED: Offline plan validation failed; no private detail logged.\n');
  process.exitCode = 1;
});
