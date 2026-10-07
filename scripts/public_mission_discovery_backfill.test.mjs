import assert from 'node:assert/strict';
import {test} from 'node:test';

import {resolveExecution} from './rebuild_public_mission_discovery.mjs';

test('backfill defaults to read-only and needs an explicit project', () => {
  assert.throws(() => resolveExecution([]), /project/);
  assert.deepEqual(resolveExecution(['--project=demo-mobsante']), {
    projectId: 'demo-mobsante', apply: false, productionWriteAuthorized: false,
  });
});

test('remote apply needs a separate future write-authorization flag', () => {
  const previous = process.env.FIRESTORE_EMULATOR_HOST;
  delete process.env.FIRESTORE_EMULATOR_HOST;
  try {
    assert.throws(() => resolveExecution([
      '--project=mobilisation-sante', '--apply',
    ]), /interdite/);
    assert.deepEqual(resolveExecution([
      '--project=mobilisation-sante', '--apply',
      '--production-write-authorized',
    ]), {
      projectId: 'mobilisation-sante', apply: true,
      productionWriteAuthorized: true,
    });
  } finally {
    if (previous === undefined) delete process.env.FIRESTORE_EMULATOR_HOST;
    else process.env.FIRESTORE_EMULATOR_HOST = previous;
  }
});
