import assert from 'node:assert/strict';
import test from 'node:test';
import {assertExecutableErasure, subjectManifest} from './privacy_operator_rights.mjs';

test('rights manifest is stable, excludes raw identifiers, and marks Auth last', () => {
  const input = {uid: 'case-person', caseId: 'CASE_001', action: 'erase',
    authRecord: {uid: 'case-person', email: 'person@example.test'},
    documents: [
      {path: 'volunteers/case-person', updateTime: '2026-10-09T10:00:00Z',
        data: {uid: 'case-person', phone: '0600000000'}},
      {path: 'professionalTargeting/case-person', updateTime: '2026-10-09T10:00:00Z',
        data: {uid: 'case-person', latitude: 44.8, longitude: -0.5}},
    ]};
  const first = subjectManifest(input);
  const second = subjectManifest(input);
  assert.equal(first.fingerprint, second.fingerprint);
  assert.equal(first.review.erasure.authLast, true);
  assert.deepEqual(assertExecutableErasure(first), [
    'professionalTargeting/case-person', 'volunteers/case-person',
  ]);
  assert.notEqual(subjectManifest({...input, documents: input.documents.map((doc) =>
    ({...doc, updateTime: '2026-10-09T11:00:00Z'}))}).fingerprint,
  first.fingerprint);
});

test('shared engagement refuses automatic erasure', () => {
  const manifest = subjectManifest({uid: 'case-person', caseId: 'CASE_002',
    action: 'erase', documents: [{path: 'engagements/m1_case-person',
      data: {volunteerId: 'case-person', missionId: 'm1', status: 'confirmed'}}],
    authRecord: {uid: 'case-person'}});
  assert.throws(() => assertExecutableErasure(manifest),
    /MANUAL_SHARED_REFERENCE_REVIEW_REQUIRED/);
});
