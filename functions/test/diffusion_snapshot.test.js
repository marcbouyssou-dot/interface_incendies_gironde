import assert from 'node:assert/strict';
import test from 'node:test';

import {diffusionIdForNeed} from '../src/diffusions/diffusion.js';
import {
  captureDiffusionSnapshot,
  currentCriteriaSnapshot,
  deserializeDiffusionSnapshot,
  diffusionSnapshot,
  ensureDiffusionSnapshot,
  serializeDiffusionSnapshot,
} from '../src/diffusions/diffusion_snapshot.js';

const createdAt = Object.freeze({toMillis: () => 1_776_067_200_000});
const needId = 'need-bassens';
const diffusionId = diffusionIdForNeed(needId);
const event = Object.freeze({
  eventType: 'mission.published',
  missionId: needId,
});

const snapshot = (populationCount = 2) => diffusionSnapshot({
  diffusionId,
  needId,
  createdAt,
  populationCount,
});

test('creates the minimal Diffusion Snapshot', () => {
  const value = snapshot();

  assert.deepEqual(Object.keys(value), [
    'diffusionId',
    'needId',
    'createdAt',
    'populationCount',
    'criteriaSnapshot',
  ]);
  assert.equal(value.diffusionId, diffusionId);
  assert.equal(value.needId, needId);
  assert.equal(value.populationCount, 2);
  assert.equal(Object.isFrozen(value), true);
});

test('criteriaSnapshot contains only the four criteria currently applied', () => {
  const criteria = currentCriteriaSnapshot();

  assert.deepEqual(criteria, {
    profession: 'needed_professions',
    consent: 'compatibleMissions',
    alreadyEngaged: 'excluded',
    antiRepetition: {
      category: 'compatible',
      maximum: 3,
      windowHours: 24,
    },
  });
  assert.equal('territory' in criteria, false);
  assert.equal('organization' in criteria, false);
  assert.equal('interests' in criteria, false);
});

test('serialization and deserialization preserve the exact Snapshot', () => {
  const serialized = serializeDiffusionSnapshot(snapshot());
  const restored = deserializeDiffusionSnapshot({
    id: diffusionId,
    data: serialized,
  });

  assert.deepEqual(restored, snapshot());
  assert.deepEqual(Object.keys(serialized), [
    'diffusionId',
    'needId',
    'createdAt',
    'populationCount',
    'criteriaSnapshot',
  ]);
});

test('capture uses recipientsForEvent result length without persisting UIDs', async () => {
  const firestore = new MemoryFirestore();
  const recipients = Object.freeze([{}, {}, {}]);

  const result = await captureDiffusionSnapshot({
    firestore,
    event,
    recipients,
    createdAt,
  });
  const persisted = firestore.read(`diffusionSnapshots/${diffusionId}`);

  assert.equal(result.created, true);
  assert.equal(result.snapshot.populationCount, recipients.length);
  assert.equal(persisted.populationCount, recipients.length);
  assert.equal(JSON.stringify(persisted).includes('uid'), false);
  assert.equal('recipients' in persisted, false);
});

test('the first Snapshot is idempotent and never duplicates recipients', async () => {
  const firestore = new MemoryFirestore();
  const first = await ensureDiffusionSnapshot({
    firestore,
    snapshot: snapshot(2),
  });
  const retry = await ensureDiffusionSnapshot({
    firestore,
    snapshot: snapshot(1),
  });

  assert.equal(first.created, true);
  assert.equal(retry.created, false);
  assert.equal(retry.snapshot.populationCount, 2);
  assert.equal(firestore.values.size, 1);
});

test('non-publication events create no Snapshot and remain untouched', async () => {
  const firestore = new MemoryFirestore();
  const result = await captureDiffusionSnapshot({
    firestore,
    event: {...event, eventType: 'mission.updated'},
    recipients: [{uid: 'professional-a'}],
    createdAt,
  });

  assert.equal(result, null);
  assert.equal(firestore.values.size, 0);
});

class MemoryFirestore {
  constructor() {
    this.values = new Map();
  }

  read(path) {
    return this.values.get(path);
  }

  collection(name) {
    return {
      doc: (id) => ({id, path: `${name}/${id}`}),
    };
  }

  async runTransaction(handler) {
    const transaction = {
      get: async (reference) => ({
        exists: this.values.has(reference.path),
        data: () => this.values.get(reference.path),
      }),
      create: (reference, data) => {
        if (this.values.has(reference.path)) {
          throw new Error('already-exists');
        }
        this.values.set(reference.path, data);
      },
    };
    return handler(transaction);
  }
}
