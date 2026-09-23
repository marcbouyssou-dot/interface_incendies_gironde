import assert from 'node:assert/strict';
import test from 'node:test';

import {
  deserializeDiffusion,
  diffusionIdForNeed,
  ensureDiffusion,
  readyDiffusion,
  serializeDiffusion,
} from '../src/diffusions/diffusion.js';
import {
  createDiffusionForPublishedNeed,
} from '../src/diffusions/create_published_need_diffusion.js';

const createdAt = Object.freeze({toMillis: () => 1_776_067_200_000});
const ready = () => readyDiffusion({
  needId: 'need-bassens',
  organizationId: 'legacy-gironde',
  mobilizationId: 'mobilization-gironde',
  createdBy: 'manager-bassens',
  createdAt,
});

test('a published Need creates the minimal READY Diffusion', () => {
  const diffusion = ready();

  assert.deepEqual(Object.keys(diffusion), [
    'id',
    'needId',
    'organizationId',
    'mobilizationId',
    'createdBy',
    'createdAt',
    'status',
  ]);
  assert.equal(diffusion.id, diffusionIdForNeed('need-bassens'));
  assert.equal(diffusion.status, 'READY');
  assert.equal(Object.isFrozen(diffusion), true);
});

test('Need to Diffusion uniqueness is deterministic and idempotent', async () => {
  const firestore = new MemoryFirestore();
  const first = await ensureDiffusion({firestore, diffusion: ready()});
  const second = await ensureDiffusion({firestore, diffusion: ready()});

  assert.equal(first.created, true);
  assert.equal(second.created, false);
  assert.equal(first.diffusion.id, second.diffusion.id);
  assert.equal(firestore.documents.size, 1);
  assert.equal(
    diffusionIdForNeed('need-bassens'),
    diffusionIdForNeed('need-bassens'),
  );
  assert.notEqual(
    diffusionIdForNeed('need-bassens'),
    diffusionIdForNeed('need-other'),
  );
});

test('Diffusion serialization contains only the seven domain fields', () => {
  const serialized = serializeDiffusion(ready());

  assert.deepEqual(serialized, {
    id: diffusionIdForNeed('need-bassens'),
    needId: 'need-bassens',
    organizationId: 'legacy-gironde',
    mobilizationId: 'mobilization-gironde',
    createdBy: 'manager-bassens',
    createdAt,
    status: 'READY',
  });
});

test('Diffusion deserialization accepts READY and CANCELLED only', () => {
  const serialized = serializeDiffusion(ready());
  const restored = deserializeDiffusion({id: serialized.id, data: serialized});
  const cancelled = deserializeDiffusion({
    id: serialized.id,
    data: {...serialized, status: 'CANCELLED'},
  });

  assert.deepEqual(restored, ready());
  assert.equal(cancelled.status, 'CANCELLED');
  assert.throws(
    () => deserializeDiffusion({
      id: serialized.id,
      data: {...serialized, status: 'SENT'},
    }),
    {code: 'invalid-diffusion-status'},
  );
});

test('the integration reuses publication eligibility without dispatching', async () => {
  const firestore = new MemoryFirestore();
  let contextReads = 0;
  const mission = {
    id: 'need-bassens',
    mobilizationId: 'mobilization-gironde',
    createdBy: 'manager-bassens',
    createdAt,
    isActive: true,
    status: 'critical',
  };
  const organizationContextResolver = async () => {
    contextReads += 1;
    return {organizationId: 'legacy-gironde'};
  };

  const result = await createDiffusionForPublishedNeed({
    firestore,
    mission,
    sourceEventId: 'mission-created',
    occurredAt: createdAt,
    organizationContextResolver,
  });
  const ignored = await createDiffusionForPublishedNeed({
    firestore,
    mission: {...mission, id: 'inactive-need', isActive: false},
    sourceEventId: 'inactive-created',
    occurredAt: createdAt,
    organizationContextResolver,
  });

  assert.equal(result.created, true);
  assert.equal(result.diffusion.needId, 'need-bassens');
  assert.equal(ignored, null);
  assert.equal(contextReads, 1);
  assert.equal(firestore.documents.size, 1);
});

class MemoryFirestore {
  constructor() {
    this.documents = new Map();
  }

  collection(name) {
    return {
      doc: (id) => ({id, path: `${name}/${id}`}),
    };
  }

  async runTransaction(handler) {
    const transaction = {
      get: async (reference) => ({
        exists: this.documents.has(reference.path),
        data: () => this.documents.get(reference.path),
      }),
      create: (reference, data) => {
        if (this.documents.has(reference.path)) {
          throw new Error('already-exists');
        }
        this.documents.set(reference.path, data);
      },
    };
    return handler(transaction);
  }
}
