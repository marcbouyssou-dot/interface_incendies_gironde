import assert from 'node:assert/strict';
import test from 'node:test';

import {
  AdminInvitationValidationCode,
  AdminInvitationValidationError,
  validateProvisionableAdminInvitation,
} from '../src/admin_invitation_validation.js';

const now = new Date('2026-07-30T10:00:00.000Z');
const createdAt = new Date('2026-07-30T09:00:00.000Z');
const expiresAt = new Date('2026-08-06T10:00:00.000Z');
const BLANK_TEXT_VECTORS = [
  '', '\u0009', '\u000A', '\u000B', '\u000C', '\u000D', '\u0020',
  '\u0085', '\u00A0', '\u1680', '\u2000', '\u2001', '\u2002',
  '\u2003', '\u2004', '\u2005', '\u2006', '\u2007', '\u2008',
  '\u2009', '\u200A', '\u2028', '\u2029', '\u202F', '\u205F',
  '\u3000', '\uFEFF', '\u0009\u0020\u000A',
];

function pending(overrides = {}) {
  return {
    email: 'responsable@example.fr',
    displayName: 'Camille Martin',
    role: 'site_manager',
    locationIds: ['merignac'],
    createdBy: 'coordinator-a',
    createdAt,
    expiresAt,
    status: 'pending',
    acceptedAt: null,
    ...overrides,
  };
}

function accepted(overrides = {}) {
  return pending({
    status: 'accepted',
    acceptedAt: now,
    acceptedUid: 'responsible-a',
    provisionedAt: now,
    activationLinkGeneratedAt: now,
    ...overrides,
  });
}

function validate(value) {
  return validateProvisionableAdminInvitation(value, {now});
}

function assertValidationError(action, reason = AdminInvitationValidationCode.invalid) {
  assert.throws(action, (error) => {
    assert.ok(error instanceof AdminInvitationValidationError);
    assert.equal(error.reason, reason);
    return true;
  });
}

for (const [label, value] of [
  ['undefined', undefined],
  ['null', null],
  ['list', []],
  ['string', 'invitation'],
  ['empty map', {}],
]) {
  test(`refuses a global ${label} document`, () => {
    assertValidationError(() => validate(value));
  });
}

for (const field of [
  'email',
  'displayName',
  'role',
  'locationIds',
  'createdBy',
  'createdAt',
  'expiresAt',
  'status',
  'acceptedAt',
]) {
  test(`refuses pending invitation without required ${field}`, () => {
    const value = pending();
    delete value[field];
    assertValidationError(() => validate(value));
  });
}

for (const fields of [
  {roles: ['coordinator']},
  {admin: true},
  {isCoordinator: true},
  {locationId: 'merignac'},
  {uid: 'injected'},
  {acceptedBy: 'injected'},
  {arbitrary: {nested: true}},
  {Status: 'pending'},
  {roles: [], admin: true},
]) {
  test(`refuses unknown fields ${Object.keys(fields).join(',')}`, () => {
    assertValidationError(() => validate(pending(fields)));
  });
}

test('accepts and defensively copies a valid pending invitation', () => {
  const input = pending({
    email: ' RESPONSABLE@EXAMPLE.FR ',
    displayName: ' Camille Martin ',
    locationIds: ['site-b', 'site-a'],
    createdBy: ' coordinator-a ',
  });
  const before = structuredClone(input);
  const value = validate(input);

  assert.equal(value.email, 'responsable@example.fr');
  assert.equal(value.displayName, ' Camille Martin ');
  assert.equal(value.createdBy, ' coordinator-a ');
  assert.deepEqual(value.locationIds, ['site-a', 'site-b']);
  assert.equal(value.acceptedAt, null);
  assert.ok(Object.isFrozen(value));
  assert.ok(Object.isFrozen(value.locationIds));
  assert.notEqual(value.locationIds, input.locationIds);
  assert.deepEqual(input, before);
});

for (const value of [...BLANK_TEXT_VECTORS, 42, false, null, {}, []]) {
  test(`refuses invalid email ${JSON.stringify(value)}`, () => {
    assertValidationError(() => validate(pending({email: value})));
  });
}

for (const value of [
  'invalid',
  'a@b',
  '@example.fr',
  'a@example',
  'user name@example.com',
  'user@example .com',
  'user@@example.com',
  'user@',
]) {
  test(`refuses malformed email ${value}`, () => {
    assertValidationError(() => validate(pending({email: value})));
  });
}

for (const [email, expected] of Object.entries({
  'a@b.c': 'a@b.c',
  'user@example.com': 'user@example.com',
  ' user@example.com': 'user@example.com',
  'user@example.com ': 'user@example.com',
  ' user@example.com ': 'user@example.com',
  'user..name@example.com': 'user..name@example.com',
  'user+tag@example.com': 'user+tag@example.com',
  'USER@example.com': 'user@example.com',
  'utilisateur@exemple.fr': 'utilisateur@exemple.fr',
})) {
  test(`accepts and normalizes historical email ${JSON.stringify(email)}`, () => {
    assert.equal(validate(pending({email})).email, expected);
  });
}

for (const value of [...BLANK_TEXT_VECTORS, 42, false, null, {}, []]) {
  test(`refuses invalid displayName ${JSON.stringify(value)}`, () => {
    assertValidationError(() => validate(pending({displayName: value})));
  });
}

test('preserves accepted displayName characters exactly', () => {
  const displayName = '  Élodie\u0000 Martin  ';
  assert.equal(validate(pending({displayName})).displayName, displayName);
});

for (const displayName of [
  ' Marc ',
  'Marc',
  'Marc Bouyssou',
  '👨‍⚕️ Marc',
]) {
  test(`preserves valid displayName ${JSON.stringify(displayName)}`, () => {
    assert.equal(validate(pending({displayName})).displayName, displayName);
  });
}

for (const value of [...BLANK_TEXT_VECTORS, 42, false, null, {}, []]) {
  test(`refuses invalid createdBy ${JSON.stringify(value)}`, () => {
    assertValidationError(() => validate(pending({createdBy: value})));
  });
}

test('accepts a different non-blank creator from the current caller', () => {
  assert.equal(validate(pending({createdBy: 'coordinator-b'})).createdBy, 'coordinator-b');
});

for (const field of ['createdAt', 'expiresAt']) {
  for (const value of [null, '2026-07-30', 42, {}, [], new Date('invalid')]) {
    test(`refuses invalid ${field} ${JSON.stringify(value)}`, () => {
      assertValidationError(() => validate(pending({[field]: value})));
    });
  }
}

test('accepts Firestore-like timestamps without retaining their objects', () => {
  const createdTimestamp = {toDate: () => createdAt};
  const expiresTimestamp = {toDate: () => expiresAt};
  const value = validate(pending({
    createdAt: createdTimestamp,
    expiresAt: expiresTimestamp,
  }));
  assert.deepEqual(value.createdAt, createdAt);
  assert.deepEqual(value.expiresAt, expiresAt);
  assert.notEqual(value.createdAt, createdAt);
  assert.notEqual(value.expiresAt, expiresAt);
});

test('refuses createdAt in the future', () => {
  assertValidationError(() => validate(pending({
    createdAt: new Date(now.getTime() + 1),
  })));
});

test('refuses expiresAt equal to createdAt', () => {
  assertValidationError(() => validate(pending({expiresAt: createdAt})));
});

test('refuses expiresAt before createdAt', () => {
  assertValidationError(() => validate(pending({
    expiresAt: new Date(createdAt.getTime() - 1),
  })));
});

test('refuses a pending invitation exactly at expiration', () => {
  assertValidationError(
    () => validate(pending({expiresAt: now})),
    AdminInvitationValidationCode.expired,
  );
});

test('refuses a pending invitation after expiration', () => {
  assertValidationError(
    () => validate(pending({expiresAt: new Date(now.getTime() - 1)})),
    AdminInvitationValidationCode.expired,
  );
});

test('refuses a pending invitation with non-null acceptedAt', () => {
  assertValidationError(() => validate(pending({acceptedAt: now})));
});

test('refuses a cancelled invitation with its stable reason', () => {
  assertValidationError(
    () => validate(pending({status: 'cancelled'})),
    AdminInvitationValidationCode.cancelled,
  );
});

test('refuses an explicitly expired invitation with its stable reason', () => {
  assertValidationError(
    () => validate(pending({status: 'expired'})),
    AdminInvitationValidationCode.expired,
  );
});

for (const status of [null, 42, 'unknown', 'Pending']) {
  test(`refuses invalid status ${JSON.stringify(status)}`, () => {
    assertValidationError(() => validate(pending({status})));
  });
}

for (const field of [
  'acceptedUid',
  'provisionedAt',
  'activationLinkGeneratedAt',
]) {
  test(`refuses accepted invitation without ${field}`, () => {
    const value = accepted();
    delete value[field];
    assertValidationError(() => validate(value));
  });
}

for (const value of [...BLANK_TEXT_VECTORS, 42, null, {}, []]) {
  test(`refuses invalid acceptedUid ${JSON.stringify(value)}`, () => {
    assertValidationError(() => validate(accepted({acceptedUid: value})));
  });
}

for (const field of [
  'acceptedAt',
  'provisionedAt',
  'activationLinkGeneratedAt',
]) {
  for (const value of [null, '2026-07-30', 42, {}, []]) {
    test(`refuses invalid accepted ${field} ${JSON.stringify(value)}`, () => {
      assertValidationError(() => validate(accepted({[field]: value})));
    });
  }
}

for (const overrides of [
  {acceptedAt: new Date(createdAt.getTime() - 1)},
  {acceptedAt: expiresAt},
  {provisionedAt: new Date(now.getTime() - 1)},
  {activationLinkGeneratedAt: new Date(now.getTime() - 1)},
  {acceptedAt: new Date(now.getTime() + 1)},
  {provisionedAt: new Date(now.getTime() + 1)},
  {activationLinkGeneratedAt: new Date(now.getTime() + 1)},
]) {
  test(`refuses incoherent accepted chronology ${Object.keys(overrides)[0]}`, () => {
    assertValidationError(() => validate(accepted(overrides)));
  });
}

test('accepted invitation remains replayable after its expiration', () => {
  const afterExpiration = new Date(expiresAt.getTime() + 1);
  const value = validateProvisionableAdminInvitation(accepted(), {
    now: afterExpiration,
  });
  assert.equal(value.status, 'accepted');
});

for (const [label, overrides] of [
  ['coordinator', {role: 'coordinator', locationIds: []}],
  ['site manager', {role: 'site_manager', locationIds: ['merignac']}],
  ['65 centers', {
    locationIds: Array.from({length: 65}, (_, index) => `site-${index}`),
  }],
]) {
  test(`accepts valid ${label} assignment`, () => {
    assert.doesNotThrow(() => validate(pending(overrides)));
  });
}

for (const [label, overrides] of [
  ['unknown role', {role: 'admin'}],
  ['cumulative role', {role: ['coordinator', 'site_manager']}],
  ['66 centers', {
    locationIds: Array.from({length: 66}, (_, index) => `site-${index}`),
  }],
  ['duplicate center', {locationIds: ['merignac', 'merignac']}],
  ['wildcard', {locationIds: ['*']}],
  ['separator', {locationIds: ['merignac\u001Fother']}],
  ['wrong location type', {locationIds: [42]}],
  ['coordinator with center', {role: 'coordinator'}],
  ['site manager without center', {locationIds: []}],
]) {
  test(`refuses invalid ${label} assignment`, () => {
    assertValidationError(() => validate(pending(overrides)));
  });
}

for (const blank of BLANK_TEXT_VECTORS) {
  test(`refuses canonical blank location ${JSON.stringify(blank)}`, () => {
    assertValidationError(() => validate(pending({locationIds: [blank]})));
  });
}

for (const notificationStatus of [undefined, 'pending', 'failed']) {
  test(`accepts historical accepted notification ${notificationStatus ?? 'absent'}`, () => {
    const value = accepted(notificationStatus === undefined
      ? {}
      : {notificationStatus});
    assert.equal(validate(value).notificationStatus, notificationStatus);
  });
}

test('accepts a complete sending notification lease', () => {
  const value = validate(accepted({
    notificationStatus: 'sending',
    notificationAttemptId: 'attempt-a',
    notificationReservedAt: now,
    notificationLeaseExpiresAt: new Date(now.getTime() + 300_000),
  }));
  assert.equal(value.notificationAttemptId, 'attempt-a');
});

for (const overrides of [
  {},
  {notificationAttemptId: 'attempt-a'},
  {notificationReservedAt: now},
  {notificationLeaseExpiresAt: new Date(now.getTime() + 300_000)},
]) {
  test(`accepts recoverable incomplete sending fields ${Object.keys(overrides).join(',')}`, () => {
    assert.doesNotThrow(() => validate(accepted({
      notificationStatus: 'sending',
      ...overrides,
    })));
  });
}

test('refuses an inverted notification lease', () => {
  assertValidationError(() => validate(accepted({
    notificationStatus: 'sending',
    notificationReservedAt: now,
    notificationLeaseExpiresAt: new Date(now.getTime() - 1),
  })));
});

test('refuses notification reservation before acceptance or in the future', () => {
  for (const notificationReservedAt of [
    new Date(accepted().acceptedAt.getTime() - 1),
    new Date(now.getTime() + 1),
  ]) {
    assertValidationError(() => validate(accepted({
      notificationStatus: 'sending',
      notificationReservedAt,
    })));
  }
});

test('accepts failed notification metadata when present', () => {
  const value = validate(accepted({
    notificationStatus: 'failed',
    notificationErrorCode: 'provider_failure',
    notificationFailedAt: now,
  }));
  assert.equal(value.notificationErrorCode, 'provider_failure');
});

test('accepts complete sent notification metadata', () => {
  const value = validate(accepted({
    notificationStatus: 'sent',
    notificationSentAt: now,
    notificationProvider: 'fake',
    notificationProviderMessageId: 'message-a',
  }));
  assert.equal(value.notificationProviderMessageId, 'message-a');
});

test('refuses failed or sent timestamps outside the accepted interval', () => {
  assertValidationError(() => validate(accepted({
    notificationStatus: 'failed',
    notificationFailedAt: new Date(now.getTime() + 1),
  })));
  assertValidationError(() => validate(accepted({
    notificationStatus: 'sent',
    notificationSentAt: new Date(accepted().acceptedAt.getTime() - 1),
  })));
});

test('sent without providerMessageId remains valid and terminal', () => {
  const value = validate(accepted({
    notificationStatus: 'sent',
    notificationSentAt: now,
    notificationProvider: 'historical-provider',
  }));
  assert.equal(value.notificationStatus, 'sent');
  assert.equal('notificationProviderMessageId' in value, false);
});

for (const [label, overrides] of [
  ['unknown notification status', {notificationStatus: 'queued'}],
  ['invalid attempt', {
    notificationStatus: 'sending',
    notificationAttemptId: '   ',
  }],
  ['invalid reserved timestamp', {
    notificationStatus: 'sending',
    notificationReservedAt: 'today',
  }],
  ['invalid failure code', {
    notificationStatus: 'failed',
    notificationErrorCode: 'bad code',
  }],
  ['invalid provider id', {
    notificationStatus: 'sent',
    notificationProviderMessageId: 42,
  }],
  ['failed field on sent', {
    notificationStatus: 'sent',
    notificationErrorCode: 'failure',
  }],
  ['reservation field on pending', {
    notificationStatus: 'pending',
    notificationAttemptId: 'attempt-a',
  }],
]) {
  test(`refuses ${label}`, () => {
    assertValidationError(() => validate(accepted(overrides)));
  });
}
