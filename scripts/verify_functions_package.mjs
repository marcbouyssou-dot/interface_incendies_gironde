#!/usr/bin/env node

// Inspect the exact ZIP selected by the installed Firebase CLI before any Functions deploy.
import {createRequire} from 'node:module';
import {readFileSync, unlinkSync} from 'node:fs';
import {resolve} from 'node:path';
import {spawnSync} from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const sourceDir = resolve(root, 'functions');
const requireFromFunctions = createRequire(resolve(sourceDir, 'package.json'));
const {prepareFunctionsUpload} = requireFromFunctions(
  'firebase-tools/lib/deploy/functions/prepareFunctionsUpload.js',
);

function category(name) {
  const parts = name.toLowerCase().split('/');
  if (parts.some((part) => /^\.env(?:\..*)?$/.test(part))) return 'ENV';
  if (parts.some((part) => /(?:^|[._-])(?:backups?|privates?)(?:[._-]|$)/.test(part))) {
    return 'PRIVATE_BACKUP';
  }
  if (parts.some((part) => /(?:^|[._-])(?:secrets?|credentials?|service[-_]?accounts?|firebase[-_]?adminsdk|api[-_]?keys?)(?:[._-]|$)|\.(?:pem|p12|pfx|key)$|^\.(?:npmrc|pypirc)$|^id_(?:rsa|ed25519)$/.test(part))) {
    return 'SECRET';
  }
  return null;
}

async function main() {
  const config = JSON.parse(readFileSync(resolve(root, 'firebase.json'), 'utf8')).functions;
  if (config.source !== 'functions') throw new Error('Unexpected Functions source');
  const packaged = await prepareFunctionsUpload(
    root, sourceDir, {...config, ignore: [...(config.ignore || [])]}, [], undefined, {},
  );
  try {
    const listing = spawnSync('unzip', ['-Z1', packaged.pathToSource], {encoding: 'utf8'});
    if (listing.status !== 0) throw new Error('Could not inspect Functions package');
    const names = listing.stdout.trim().split('\n').filter(Boolean);
    const findings = names.map((name) => ({name, category: category(name)}))
      .filter((entry) => entry.category);
    const count = (type) => findings.filter((entry) => entry.category === type).length;
    console.log(JSON.stringify({
      packageFileCount: names.length,
      envFileCount: count('ENV'),
      privateBackupCount: count('PRIVATE_BACKUP'),
      secretFileCount: count('SECRET'),
    }));
    if (findings.length) {
      console.error(`Functions package rejected: ${findings.map((entry) => entry.name).join(', ')}`);
      process.exitCode = 1;
    }
  } finally {
    unlinkSync(packaged.pathToSource);
  }
}

main().catch((error) => {
  console.error(`Functions package check failed: ${error.message}`);
  process.exitCode = 1;
});
