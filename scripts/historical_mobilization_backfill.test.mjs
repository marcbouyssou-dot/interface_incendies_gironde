import assert from 'node:assert/strict';
import test from 'node:test';

import {
  backfillProjectId,
  buildHistoricalMobilizationBackfillPlan,
  historicalMobilizationId,
  resolveBackfillExecution,
  runHistoricalMobilizationBackfill,
} from './historical_mobilization_backfill.mjs';

test('mission without mobilizationId is planned for update', () => {
  const plan = buildPlan({missions: [mission()]});
  assert.equal(plan.missions[0].action, 'update');
  assert.equal(plan.summary.missions.toModify, 1);
  assert.equal(plan.summary.global, 'GO');
});

test('mission already assigned to the historical mobilization is compliant', () => {
  const plan = buildPlan({
    missions: [mission({mobilizationId: historicalMobilizationId})],
  });
  assert.equal(plan.missions[0].action, 'compliant');
  assert.equal(plan.summary.missions.compliant, 1);
});

test('mission assigned to another mobilization is a blocking conflict', () => {
  const plan = buildPlan({
    missions: [mission({mobilizationId: 'another-mobilization'})],
  });
  assert.equal(plan.missions[0].action, 'conflict');
  assert.equal(plan.summary.global, 'NO-GO');
});

test('engagement without mobilizationId is planned when its mission is valid', () => {
  const plan = buildPlan({
    missions: [mission()],
    engagements: [engagement()],
  });
  assert.equal(plan.engagements[0].action, 'update');
  assert.equal(plan.summary.engagements.toModify, 1);
});

test('engagement already assigned to the historical mobilization is compliant', () => {
  const plan = buildPlan({
    missions: [mission({mobilizationId: historicalMobilizationId})],
    engagements: [engagement({mobilizationId: historicalMobilizationId})],
  });
  assert.equal(plan.engagements[0].action, 'compliant');
  assert.equal(plan.summary.engagements.compliant, 1);
});

test('engagement assigned to another mobilization is a blocking conflict', () => {
  const plan = buildPlan({
    missions: [mission()],
    engagements: [engagement({mobilizationId: 'another-mobilization'})],
  });
  assert.equal(plan.engagements[0].action, 'conflict');
  assert.equal(plan.summary.global, 'NO-GO');
});

test('engagement whose mission does not exist is an orphan', () => {
  const plan = buildPlan({engagements: [engagement()]});
  assert.equal(plan.engagements[0].action, 'orphan');
  assert.equal(plan.summary.engagements.orphans, 1);
  assert.equal(plan.summary.global, 'NO-GO');
});

test('mock apply is idempotent on rerun', async () => {
  const store = memoryStore({
    missions: [mission()],
    engagements: [engagement()],
  });
  const first = await execute(store, 'apply');
  const second = await execute(store, 'apply');

  assert.equal(first.writes, 2);
  assert.equal(first.after.summary.missions.toModify, 0);
  assert.equal(first.after.summary.engagements.toModify, 0);
  assert.equal(second.writes, 0);
  assert.equal(store.patches.length, 2);
});

test('dry-run performs zero writes', async () => {
  const store = memoryStore({
    missions: [mission()],
    engagements: [engagement()],
  });
  const result = await execute(store, 'dry-run');

  assert.equal(result.writes, 0);
  assert.equal(store.writeCalls, 0);
  assert.equal(store.patches.length, 0);
});

test('malformed documents are explicit blockers', () => {
  const missingMissionId = buildPlan({
    missions: [mission()],
    engagements: [{id: 'engagement-1', data: {}}],
  });
  const invalidMobilization = buildPlan({
    missions: [mission({mobilizationId: null})],
  });

  assert.equal(missingMissionId.engagements[0].action, 'malformed');
  assert.equal(invalidMobilization.missions[0].action, 'malformed');
  assert.equal(missingMissionId.summary.global, 'NO-GO');
  assert.equal(invalidMobilization.summary.global, 'NO-GO');
});

test('project is explicit, dry-run is default, and apply is explicit', () => {
  assert.deepEqual(
    resolveBackfillExecution(['--project', backfillProjectId]),
    {mode: 'dry-run', projectId: backfillProjectId},
  );
  assert.deepEqual(
    resolveBackfillExecution([
      '--project',
      backfillProjectId,
      '--apply',
    ]),
    {mode: 'apply', projectId: backfillProjectId},
  );
  assert.throws(() => resolveBackfillExecution([]), /Projet Firebase refusé/);
  assert.throws(
    () => resolveBackfillExecution([
      '--project',
      backfillProjectId,
      '--dry-run',
      '--apply',
    ]),
    /jamais les deux/,
  );
});

function buildPlan({missions = [], engagements = []}) {
  return buildHistoricalMobilizationBackfillPlan({missions, engagements});
}

function mission(overrides = {}) {
  return {id: 'mission-1', data: {name: 'Mission', ...overrides}};
}

function engagement(overrides = {}) {
  return {
    id: 'mission-1_volunteer-1',
    data: {missionId: 'mission-1', volunteerId: 'volunteer-1', ...overrides},
  };
}

function memoryStore(initial) {
  return {
    documents: structuredClone(initial),
    patches: [],
    writeCalls: 0,
  };
}

async function execute(store, mode) {
  return runHistoricalMobilizationBackfill({
    mode,
    readCollections: async () => structuredClone(store.documents),
    writePatches: async (patches) => {
      store.writeCalls++;
      for (const patch of patches) {
        const [collection, id] = patch.path.split('/');
        const document = store.documents[collection].find(
          (candidate) => candidate.id === id,
        );
        Object.assign(document.data, patch.fields);
        store.patches.push(patch);
      }
    },
    batchSize: 2,
  });
}
