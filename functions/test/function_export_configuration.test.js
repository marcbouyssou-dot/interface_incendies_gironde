import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import test from 'node:test';

function discoverExport(environment) {
  const script = [
    "const module = await import('./src/index.js');",
    'const endpoint = module.provisionAdminInvitation.__endpoint;',
    'console.log(JSON.stringify({',
    '  callable: endpoint.callableTrigger !== undefined,',
    '  region: endpoint.region,',
    '  secrets: endpoint.secretEnvironmentVariables,',
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
