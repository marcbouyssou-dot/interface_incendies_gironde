import assert from 'node:assert/strict';
import test from 'node:test';

import {
  assertTargetProject,
  buildMigrationPlan,
  writableChanges,
} from './location_address_migration.mjs';

const projectId = 'mobilisation-sante';

function row(overrides = {}) {
  return {
    location_id: 'medoc-test',
    name: 'Test',
    display_name: 'Test',
    territorial_group: 'medoc',
    previous_location_type: 'sdisStation',
    location_type: 'sdisStation',
    address_line_1: '1 rue du Test',
    address_line_2: '',
    postal_code: '33000',
    city: 'Bordeaux',
    country: 'France',
    full_address: '1 rue du Test, 33000 Bordeaux, France',
    latitude: '44.8',
    longitude: '-0.5',
    address_status: 'verified_official',
    source_label: 'Source officielle',
    source_url: 'https://example.test',
    second_source_label: '',
    second_source_url: '',
    verified_at: '2026-07-29',
    notes: '',
    ...overrides,
  };
}

function document(overrides = {}) {
  return {
    id: 'medoc-test',
    data: {
      name: 'Test',
      group: 'medoc',
      type: 'sdisStation',
      ...overrides,
    },
  };
}

function plan(rows, documents) {
  return buildMigrationPlan({projectId, rows, documents});
}

test('verified incomplete location is migrable without a write', () => {
  const result = plan([row()], [document()]);
  assert.equal(result.entries[0].category, 'incomplet_migrable');
  assert.equal(writableChanges(result).length, 1);
  assert.equal(result.entries[0].contactPhonePresent, false);
});

test('existing address is never overwritten', () => {
  const result = plan(
    [row()],
    [document({addressLine1: '2 rue existante'})],
  );
  assert.equal(result.entries[0].category, 'complet_mais_different');
  assert.deepEqual(result.entries[0].conflicts, ['addressLine1']);
  assert.equal(
    Object.hasOwn(result.entries[0].additions, 'addressLine1'),
    false,
  );
});

test('needs_confirmation and not_found are excluded', () => {
  const result = plan(
    [
      row({location_id: 'medoc-needs', address_status: 'needs_confirmation'}),
      row({location_id: 'medoc-missing', address_status: 'not_found'}),
    ],
    [
      {id: 'medoc-needs', data: document().data},
      {id: 'medoc-missing', data: document().data},
    ],
  );
  assert.deepEqual(
    result.entries.map((entry) => entry.category),
    ['needs_confirmation', 'not_found'],
  );
  assert.equal(writableChanges(result).length, 0);
});

test('contacts are preserved and never enter the patch', () => {
  const result = plan(
    [row()],
    [document({contactName: 'Référent', contactPhone: 'confidentiel'})],
  );
  const entry = result.entries[0];
  assert.equal(entry.contactNamePresent, true);
  assert.equal(entry.contactPhonePresent, true);
  assert.equal(Object.hasOwn(entry.additions, 'contactName'), false);
  assert.equal(Object.hasOwn(entry.additions, 'contactPhone'), false);
});

test('ambiguous metadata is reported and not migrated', () => {
  const result = plan([row()], [document({name: 'Autre lieu'})]);
  assert.equal(result.entries[0].category, 'correspondance_ambigue');
  assert.equal(writableChanges(result).length, 0);
});

test('planning is idempotent after applying missing fields', () => {
  const first = plan([row()], [document()]);
  const applied = document({...first.entries[0].additions});
  const second = plan([row()], [applied]);
  assert.equal(second.entries[0].category, 'complet_identique');
  assert.equal(writableChanges(second).length, 0);
});

test('incorrect Firebase project is refused', () => {
  assert.throws(
    () => assertTargetProject('interfacerecup33'),
    /Projet Firebase refusé/,
  );
});

test('dry-run planning never invokes a writer', () => {
  let writes = 0;
  const result = plan([row()], [document()]);
  assert.equal(writes, 0);
  assert.equal(writableChanges(result).length, 1);
});
