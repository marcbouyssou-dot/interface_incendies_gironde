import assert from 'node:assert/strict';
import test from 'node:test';

import {
  AdminInvitationManagementError,
  invitationManagementMutation,
  manageAdminInvitation,
  validateManagementRequest,
} from '../src/manage_admin_invitation.js';

const now = new Date('2030-01-10T10:00:00.000Z');

function invitation(overrides = {}) {
  return {
    email: 'manager@example.test',
    displayName: 'Responsable Test',
    role: 'site_manager',
    locationIds: ['merignac'],
    createdBy: 'coordinator',
    createdAt: new Date('2030-01-01T10:00:00.000Z'),
    expiresAt: new Date('2030-01-17T10:00:00.000Z'),
    status: 'pending',
    acceptedAt: null,
    ...overrides,
  };
}

function assertCode(action, code) {
  assert.throws(action, (error) => {
    assert.ok(error instanceof AdminInvitationManagementError);
    assert.equal(error.code, code);
    return true;
  });
}

test('validates all four management requests without accepting extra fields', () => {
  assert.equal(validateManagementRequest({
    invitationId: 'invitation', action: 'cancel',
  }, {now}).action, 'cancel');
  assert.equal(validateManagementRequest({
    invitationId: 'invitation', action: 'delete',
  }, {now}).action, 'delete');
  assert.equal(validateManagementRequest({
    invitationId: 'invitation',
    action: 'reactivate',
    expiresAtMillis: now.getTime() + 86_400_000,
  }, {now}).expiresAt.getTime(), now.getTime() + 86_400_000);
  assert.deepEqual(validateManagementRequest({
    invitationId: 'invitation',
    action: 'update',
    displayName: 'Nouveau nom',
    role: 'coordinator',
    locationIds: [],
  }, {now}).update, {
    displayName: 'Nouveau nom',
    role: 'coordinator',
    locationIds: [],
  });
  assertCode(() => validateManagementRequest({
    invitationId: 'invitation', action: 'delete', extra: true,
  }, {now}), 'invalid-argument');
});

test('refuses malformed updates and non-future reactivation dates', () => {
  assertCode(() => validateManagementRequest({
    invitationId: 'invitation',
    action: 'update',
    displayName: 'Responsable',
    role: 'site_manager',
    locationIds: [],
  }, {now}), 'invalid-argument');
  assertCode(() => validateManagementRequest({
    invitationId: 'invitation',
    action: 'reactivate',
    expiresAtMillis: now.getTime(),
  }, {now}), 'failed-precondition');
});

test('cancel only updates an active pending invitation', () => {
  assert.deepEqual(invitationManagementMutation({
    invitation: invitation(), action: 'cancel', now,
  }), {
    kind: 'update',
    fields: {status: 'cancelled'},
    result: {status: 'cancelled'},
  });
  for (const status of ['cancelled', 'expired']) {
    assertCode(() => invitationManagementMutation({
      invitation: invitation({status}), action: 'cancel', now,
    }), 'failed-precondition');
  }
});

test('reactivation preserves fields and only changes status and expiration', () => {
  const expiresAt = new Date('2030-01-24T10:00:00.000Z');
  const mutation = invitationManagementMutation({
    invitation: invitation({status: 'cancelled'}),
    action: 'reactivate',
    expiresAt,
    now,
  });
  assert.deepEqual(mutation.fields, {status: 'pending', expiresAt});
  assert.deepEqual(mutation.result, {
    status: 'pending', expiresAtMillis: expiresAt.getTime(),
  });
  assertCode(() => invitationManagementMutation({
    invitation: invitation(), action: 'reactivate', expiresAt, now,
  }), 'failed-precondition');
});

test('update accepts pending and cancelled invitations but never changes email', () => {
  const update = validateManagementRequest({
    invitationId: 'invitation',
    action: 'update',
    displayName: 'Nouveau nom',
    role: 'coordinator',
    locationIds: [],
  }, {now}).update;
  for (const status of ['pending', 'cancelled']) {
    const mutation = invitationManagementMutation({
      invitation: invitation({status}), action: 'update', update, now,
    });
    assert.deepEqual(mutation.fields, {
      displayName: 'Nouveau nom', role: 'coordinator', locationIds: [],
    });
    assert.equal(Object.hasOwn(mutation.fields, 'email'), false);
  }
});

test('delete is limited to invitations never accepted', () => {
  for (const status of ['pending', 'cancelled', 'expired']) {
    assert.deepEqual(invitationManagementMutation({
      invitation: invitation({status}), action: 'delete', now,
    }), {kind: 'delete', result: {deleted: true}});
  }
  assertCode(() => invitationManagementMutation({
    invitation: invitation({
      status: 'accepted',
      acceptedAt: new Date('2030-01-05T10:00:00.000Z'),
      acceptedUid: 'manager',
      provisionedAt: new Date('2030-01-05T10:00:00.000Z'),
      activationLinkGeneratedAt: new Date('2030-01-05T10:00:00.000Z'),
    }),
    action: 'delete',
    now,
  }), 'failed-precondition');
});

test('passes a validated request to the transactional service', async () => {
  const calls = [];
  const result = await manageAdminInvitation({
    callerUid: 'coordinator',
    data: {invitationId: 'invitation', action: 'cancel'},
    now,
    services: {
      async commitAdminInvitationManagement(value) {
        calls.push(value);
        return {status: 'cancelled'};
      },
    },
  });
  assert.deepEqual(result, {status: 'cancelled'});
  assert.equal(calls.length, 1);
  assert.equal(calls[0].callerUid, 'coordinator');
  assert.equal(calls[0].invitationId, 'invitation');
});

test('refuses unauthenticated callers before reaching the service', async () => {
  let called = false;
  await assert.rejects(() => manageAdminInvitation({
    callerUid: null,
    data: {invitationId: 'invitation', action: 'delete'},
    now,
    services: {
      async commitAdminInvitationManagement() {
        called = true;
      },
    },
  }), (error) => error.code === 'unauthenticated');
  assert.equal(called, false);
});
