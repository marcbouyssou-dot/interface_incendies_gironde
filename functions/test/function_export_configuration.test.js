import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import test from 'node:test';

function discoverExport(environment, exportName = 'provisionAdminInvitation') {
  const script = [
    "const module = await import('./src/index.js');",
    `const endpoint = module.${exportName}.__endpoint;`,
    `const trigger = module.${exportName}.__trigger;`,
    'console.log(JSON.stringify({',
    '  callable: endpoint.callableTrigger !== undefined,',
    '  region: endpoint.region,',
    '  secrets: endpoint.secretEnvironmentVariables,',
    '  appCheckEnforced: trigger?.httpsTrigger?.allowInsecure === false,',
    '}));',
  ].join('\n');
  const result = spawnSync(
    process.execPath,
    ['--input-type=module', '--eval', script],
    {
      cwd: process.cwd(),
      encoding: 'utf8',
      env: {
        PATH: process.env.PATH,
        HOME: process.env.HOME,
        ...environment,
      },
    },
  );
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout.trim());
}

test('Emulator discovery exports the callable without a secret binding', () => {
  const endpoint = discoverExport({
    FUNCTIONS_EMULATOR: 'true',
    GCLOUD_PROJECT: 'demo-mobsante',
  });

  assert.equal(endpoint.callable, true);
  assert.deepEqual(endpoint.region, ['europe-west1']);
  assert.deepEqual(endpoint.secrets, []);
});

test('production discovery keeps the Resend secret binding', () => {
  const endpoint = discoverExport({
    GCLOUD_PROJECT: 'mobilisation-sante',
  });

  assert.equal(endpoint.callable, true);
  assert.deepEqual(endpoint.region, ['europe-west1']);
  assert.deepEqual(endpoint.secrets, [{key: 'RESEND_API_KEY'}]);
});

test('mission update is a v2 callable without notification secrets', () => {
  const endpoint = discoverExport({
    GCLOUD_PROJECT: 'mobilisation-sante',
  }, 'updateMission');

  assert.equal(endpoint.callable, true);
  assert.deepEqual(endpoint.region, ['europe-west1']);
  assert.equal(endpoint.secrets, undefined);
});

test('RPPS verification is callable without secret during discovery', () => {
  const endpoint = discoverExport({
    FUNCTIONS_EMULATOR: 'true',
    GCLOUD_PROJECT: 'demo-mobsante',
  }, 'verifyProfessionalRpps');

  assert.equal(endpoint.callable, true);
  assert.deepEqual(endpoint.region, ['europe-west1']);
  assert.deepEqual(endpoint.secrets, []);
});

test('RPPS verification binds only the ANS secret in production', () => {
  const endpoint = discoverExport({
    GCLOUD_PROJECT: 'mobilisation-sante',
  }, 'verifyProfessionalRpps');

  assert.equal(endpoint.callable, true);
  assert.deepEqual(endpoint.region, ['europe-west1']);
  assert.deepEqual(endpoint.secrets, [{key: 'ESANTE_API_KEY'}]);
  assert.equal(endpoint.appCheckEnforced, true);
});

test('RPPS confirmation keeps callable, App Check, region and ANS secret', () => {
  const endpoint = discoverExport({
    GCLOUD_PROJECT: 'mobilisation-sante',
  }, 'confirmProfessionalRpps');

  assert.equal(endpoint.callable, true);
  assert.deepEqual(endpoint.region, ['europe-west1']);
  assert.deepEqual(endpoint.secrets, [{key: 'ESANTE_API_KEY'}]);
  assert.equal(endpoint.appCheckEnforced, true);
});

for (const exportName of [
  'createOperation',
  'updateOperation',
  'transitionOperation',
  'setOperationCoordinator',
  'createMobilization',
  'updateMobilization',
  'activateMobilization',
  'deactivateMobilization',
  'archiveMobilization',
  'assignMobilizationCoordinator',
  'removeMobilizationCoordinator',
]) {
  test(`${exportName} is an App Check enforced callable in europe-west1`, () => {
    const endpoint = discoverExport({
      GCLOUD_PROJECT: 'mobilisation-sante',
    }, exportName);

    assert.equal(endpoint.callable, true);
    assert.deepEqual(endpoint.region, ['europe-west1']);
    assert.equal(endpoint.secrets, undefined);
    assert.equal(endpoint.appCheckEnforced, true);
  });
}

for (const exportName of [
  'listMissionTeam',
  'listPlatformCoordinatorIdentities',
  'listPlatformActorDirectory',
]) {
  test(`${exportName} is an App Check enforced identity read`, () => {
    const endpoint = discoverExport({
      GCLOUD_PROJECT: 'mobilisation-sante',
    }, exportName);

    assert.equal(endpoint.callable, true);
    assert.deepEqual(endpoint.region, ['europe-west1']);
    assert.equal(endpoint.secrets, undefined);
    assert.equal(endpoint.appCheckEnforced, true);
  });
}
