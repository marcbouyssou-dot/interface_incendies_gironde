import assert from 'node:assert/strict';
import test from 'node:test';
import {buildSubjectReview, DRY_RUN_REQUIRED} from './privacy_subject_review.mjs';

test('exports only allowlisted subject fields and excludes push secrets', () => {
  const review = buildSubjectReview({
    uid: 'user-A',
    authRecord: {uid: 'user-A', email: 'a@example.test', passwordHash: 'secret'},
    documents: [
      {path: 'volunteers/user-A', data: {firstName: 'Alice', phone: '0100',
        pushToken: 'secret-a', secret: 'secret-b',
        communicationPreferences: {enabled: true, fcmToken: 'nested-secret'}}},
      {path: 'volunteers/user-B', data: {firstName: 'Bob', phone: '0200',
        pushToken: 'secret-b'}},
      {path: 'pushSubscriptions/push-A', data: {uid: 'user-A',
        token: 'secret-c', status: 'active'}},
      {path: 'engagements/eng-A', data: {volunteerId: 'user-A',
        missionId: 'mission-1', status: 'confirmed', otherPerson: 'Bob'}},
      {path: 'missions/mission-1', data: {createdBy: 'user-A',
        patientName: 'Patient X', otherProfessional: 'Bob'}},
    ],
  });
  assert.equal(review.partial, true);
  assert.equal(review.auth.email, 'a@example.test');
  assert.equal(review.exported.length, 3);
  assert.deepEqual(review.erasure.quotaRecalculationMissions, ['mission-1']);
  assert.deepEqual(review.erasure.pushTokensToRevoke,
    [{path: 'pushSubscriptions/push-A', tokenExcluded: true}]);
  assert.deepEqual(review.sharedReferences,
    [{path: 'missions/mission-1', fields: ['createdBy']}]);
  const json = JSON.stringify(review);
  for (const forbidden of ['secret-a', 'secret-b', 'secret-c', 'nested-secret', '0200',
    'Patient X']) assert.equal(json.includes(forbidden), false);
});

test('nested and composite references are flagged without exporting shared data', () => {
  const review = buildSubjectReview({uid: 'user-A', documents: [
    {path: 'missions/user-A__mission-2', data: {details: 'other private text'}},
    {path: 'engagements/eng-B', data: {professionalUid: 'user-B',
      audit: {uid: 'user-A'}, details: 'another private text'}},
  ]});
  assert.equal(review.exported.length, 0);
  assert.equal(review.sharedReferences.length, 2);
  assert.equal(JSON.stringify(review).includes('private text'), false);
});

test('dry-run cannot execute and Auth stays last', () => {
  const review = buildSubjectReview({uid: 'user-A', documents: [],
    authRecord: {uid: 'user-A'}});
  assert.equal(DRY_RUN_REQUIRED, true);
  assert.equal(review.erasure.executable, false);
  assert.equal(review.erasure.authLast, true);
});

test('rejects mismatched Auth subject and duplicate snapshot paths', () => {
  assert.throws(() => buildSubjectReview({uid: 'user-A', documents: [],
    authRecord: {uid: 'user-B'}}), /AUTH_SUBJECT_MISMATCH/);
  assert.throws(() => buildSubjectReview({uid: 'user-A', documents: [
    {path: 'roles/user-A', data: {}}, {path: 'roles/user-A', data: {}}],
  }), /INVALID_SUBJECT_REVIEW_SNAPSHOT/);
  assert.throws(() => buildSubjectReview({uid: 'user-A', documents: [
    {path: 'professionalTargeting/user-A', data: {uid: 'user-B'}},
  ]}), /SUBJECT_DOCUMENT_UID_MISMATCH/);
});

test('private targeting, preferences and Action admission stay subject-bound', () => {
  const review = buildSubjectReview({uid: 'user-A', documents: [
    {path: 'professionalTargeting/user-A', data: {
      uid: 'user-A', enabled: true, radiusKm: 20,
      latitude: 44.84, longitude: -0.58, source: 'selected_point',
      geocodingProvider: 'ign_geoplateforme',
      geocodingPrecision: 'housenumber', confirmedAt: '2026-10-08',
      addressQuery: 'private raw address',
    }},
    {path: 'professionalTargeting/user-B', data: {
      uid: 'user-B', latitude: 48.86, longitude: 2.35,
    }},
    {path: 'notificationPreferences/user-A', data: {
      uid: 'user-A', compatibleMissions: true, engagementUpdates: false,
      quietHoursStart: 22, quietHoursEnd: 7,
    }},
    {path: 'professionalAdmissions/action-1_user-A', data: {
      uid: 'user-A', operationId: 'action-1', status: 'active',
      sourceInvitationId: 'invitation-digest',
    }},
    {path: 'professionalInvitations/invitation-digest', data: {
      consumedBy: 'user-A', organizationId: 'org-1',
      privateNote: 'third-party information',
    }},
  ]});
  assert.deepEqual(review.exported.map((item) => item.path), [
    'professionalTargeting/user-A',
    'notificationPreferences/user-A',
    'professionalAdmissions/action-1_user-A',
  ]);
  assert.equal(review.exported[0].data.latitude, 44.84);
  assert.equal(review.exported[0].data.radiusKm, 20);
  assert.equal(review.exported[1].data.compatibleMissions, true);
  assert.equal(review.exported[2].data.sourceInvitationId,
    'invitation-digest');
  assert.deepEqual(review.sharedReferences, [
    {path: 'professionalInvitations/invitation-digest', fields: ['consumedBy']},
  ]);
  assert.deepEqual(review.erasure.deleteCandidates.map((item) => item.path), [
    'professionalTargeting/user-A',
    'notificationPreferences/user-A',
    'professionalAdmissions/action-1_user-A',
  ]);
  const json = JSON.stringify(review);
  for (const forbidden of ['private raw address', 'third-party information',
    '48.86', '2.35']) assert.equal(json.includes(forbidden), false);
});
