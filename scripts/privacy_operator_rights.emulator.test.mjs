import assert from 'node:assert/strict';
import {test} from 'node:test';
import {mkdtemp, readFile, readdir, rm} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {createDecipheriv} from 'node:crypto';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {decodeFirestoreValue} from './privacy_operator_rights.mjs';

test('operator rights dry-run backs up, then erases bounded fixture with Auth last', async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
  const projectId = 'demo-mobsante-rights';
  const uid = `rights-${process.pid}`;
  const app = initializeApp({projectId}, `rights-${process.pid}`);
  const auth = getAuth(app);
  const db = getFirestore(app);
  const out = await mkdtemp(join(tmpdir(), 'mobsante-rights-test-'));
  await auth.createUser({uid, email: `${uid}@example.test`});
  await db.collection('volunteers').doc(uid).set({uid, phone: 'private-phone'});
  await db.collection('professionalTargeting').doc(uid).set({uid, latitude: 44.8});
  await db.collection('termsAcceptances').doc(uid).set({
    uid, acceptedVersion: 'beta-v1', acceptedAt: new Date(),
  });
  const command = (confirm = null) => spawnSync(process.execPath, [
    resolve('privacy_operator_rights.mjs'),
    '--action', 'erase', '--project', projectId, '--uid', uid,
    '--case', 'CASE_FIXTURE', '--out', out, '--identity-verified', 'yes',
    ...(confirm ? ['--confirm', confirm] : []),
  ], {encoding: 'utf8', env: {...process.env,
    MOBSANTE_RIGHTS_BACKUP_KEY_HEX: 'a'.repeat(64),
    MOBSANTE_RIGHTS_APPLY_AUTHORIZED: 'yes'}});
  const dryRun = command();
  assert.equal(dryRun.status, 0, dryRun.stderr);
  const plan = JSON.parse(dryRun.stdout);
  assert.equal(plan.applied, false);
  assert.equal((await db.collection('volunteers').doc(uid).get()).exists, true);
  const applied = command(plan.fingerprint);
  assert.equal(applied.status, 0, applied.stderr);
  assert.equal(JSON.parse(applied.stdout).authLast, true);
  assert.equal((await db.collection('volunteers').doc(uid).get()).exists, false);
  assert.equal((await db.collection('professionalTargeting').doc(uid).get()).exists, false);
  assert.equal((await db.collection('termsAcceptances').doc(uid).get()).exists, false);
  await assert.rejects(() => auth.getUser(uid), (error) => error.code === 'auth/user-not-found');
  const files = await readdir(out);
  assert.ok(files.some((file) => file.endsWith('-preimage.enc.json')));
  for (const file of files) {
    const body = await readFile(join(out, file), 'utf8');
    if (file.endsWith('.enc.json')) assert.equal(body.includes('private-phone'), false);
  }
  const encrypted = JSON.parse(await readFile(join(out,
    files.find((file) => file.endsWith('-preimage.enc.json'))), 'utf8'));
  const decipher = createDecipheriv('aes-256-gcm', Buffer.from('a'.repeat(64), 'hex'),
    Buffer.from(encrypted.iv, 'base64'));
  decipher.setAuthTag(Buffer.from(encrypted.tag, 'base64'));
  const backup = JSON.parse(Buffer.concat([
    decipher.update(Buffer.from(encrypted.ciphertext, 'base64')),
    decipher.final(),
  ]).toString('utf8'));
  const restoreApp = initializeApp({projectId: `${projectId}-restore`}, `restore-${process.pid}`);
  const restoreDb = getFirestore(restoreApp);
  for (const item of backup.documents) {
    await restoreDb.doc(item.path).set(decodeFirestoreValue(item.data));
    assert.equal((await restoreDb.doc(item.path).get()).exists, true);
  }
  assert.equal((await restoreDb.collection('volunteers').doc(uid).get()).data().phone,
    'private-phone');
  await deleteApp(restoreApp);
  await deleteApp(app);
  await rm(out, {recursive: true, force: true});
});
