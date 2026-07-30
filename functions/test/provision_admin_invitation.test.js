import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ProvisioningError,
  provisionAdminInvitation,
} from '../src/provision_admin_invitation.js';

const now = new Date('2026-07-30T10:00:00.000Z');
const appUrl = 'http://127.0.0.1:5000/activation';

function invitation(overrides = {}) {
  return {
    email: 'responsable@example.fr',
    displayName: 'Camille Martin',
    role: 'site_manager',
    locationIds: ['site-a', 'site-b'],
    status: 'pending',
    expiresAt: new Date('2026-08-06T10:00:00.000Z'),
    ...overrides,
  };
}

function harness({
  callerRole = {role: 'coordinator', active: true, locationIds: []},
  invitationValue = invitation(),
  user,
  role,
  failCommit = false,
} = {}) {
  const state = {
    callerRole,
    invitation: invitationValue,
    user,
    role,
    created: [],
    deleted: [],
    commits: [],
    links: [],
    mail: [],
  };
  const services = {
    async getRole(uid) {
      return uid === 'coord' ? state.callerRole : state.role;
    },
    async getInvitation() {
      return state.invitation;
    },
    async getUserByEmail() {
      if (!state.user) {
        const error = new Error('missing');
        error.code = 'auth/user-not-found';
        throw error;
      }
      return state.user;
    },
    async createUser(properties) {
      state.created.push(properties);
      state.user = {uid: 'created-uid', ...properties};
      return state.user;
    },
    async deleteUser(uid) {
      state.deleted.push(uid);
      state.user = null;
    },
    async generatePasswordResetLink(email, settings) {
      state.links.push({email, settings});
      return `http://127.0.0.1:9099/action?email=${email}`;
    },
    async commitProvisioning(value) {
      if (failCommit) throw new Error('firestore failed');
      state.commits.push(value);
      state.role = value.role;
      state.invitation = {
        ...state.invitation,
        status: 'accepted',
        acceptedUid: value.targetUid,
      };
    },
  };
  const mailer = {
    async prepare(value) {
      state.mail.push(value);
      return {delivery: 'pending'};
    },
  };
  return {state, services, mailer};
}

async function provision(setup = {}) {
  const value = harness(setup);
  const result = await provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    mailer: value.mailer,
    appUrl,
    now,
  });
  return {...value, result};
}

async function rejectsCode(action, code) {
  await assert.rejects(action, (error) => {
    assert.ok(error instanceof ProvisioningError);
    assert.equal(error.code, code);
    return true;
  });
}

test('unauthenticated caller is refused', async () => {
  const {services, mailer} = harness();
  await rejectsCode(
    () => provisionAdminInvitation({
      invitationId: 'invitation-a',
      callerUid: null,
      services,
      mailer,
      appUrl,
      now,
    }),
    'unauthenticated',
  );
});

for (const [label, callerRole] of [
  ['volunteer', null],
  ['site manager', {role: 'site_manager', active: true}],
  ['inactive coordinator', {role: 'coordinator', active: false}],
]) {
  test(`${label} is refused`, async () => {
    const {services, mailer} = harness({callerRole});
    await rejectsCode(
      () => provisionAdminInvitation({
        invitationId: 'invitation-a',
        callerUid: 'coord',
        services,
        mailer,
        appUrl,
        now,
      }),
      'permission-denied',
    );
  });
}

test('active coordinator provisions a new account and site manager role', async () => {
  const {state, result} = await provision();
  assert.equal(state.created.length, 1);
  assert.deepEqual(state.created[0], {
    email: 'responsable@example.fr',
    displayName: 'Camille Martin',
    emailVerified: false,
    disabled: false,
  });
  assert.deepEqual(state.commits[0].role.locationIds, ['site-a', 'site-b']);
  assert.equal(state.commits[0].role.role, 'site_manager');
  assert.equal(state.commits[0].role.active, true);
  assert.equal(result.emailDelivery, 'pending');
  assert.equal(result.accountProvisioned, true);
  assert.equal('activationLink' in result, false);
});

test('coordinator role is created without locations', async () => {
  const {state} = await provision({
    invitationValue: invitation({role: 'coordinator', locationIds: []}),
  });
  assert.deepEqual(state.commits[0].role.locationIds, []);
  assert.equal(state.commits[0].role.role, 'coordinator');
});

test('unknown invitation is refused', async () => {
  const {services, mailer} = harness({invitationValue: null});
  await rejectsCode(
    () => provisionAdminInvitation({
      invitationId: 'missing',
      callerUid: 'coord',
      services,
      mailer,
      appUrl,
      now,
    }),
    'not-found',
  );
});

for (const [label, value] of [
  ['expired', invitation({expiresAt: new Date('2026-07-29T10:00:00Z')})],
  ['cancelled', invitation({status: 'cancelled'})],
]) {
  test(`${label} invitation is refused`, async () => {
    const {services, mailer} = harness({invitationValue: value});
    await rejectsCode(
      () => provisionAdminInvitation({
        invitationId: 'invitation-a',
        callerUid: 'coord',
        services,
        mailer,
        appUrl,
        now,
      }),
      'failed-precondition',
    );
  });
}

test('accepted invitation is idempotent', async () => {
  const {state, result} = await provision({
    invitationValue: invitation({
      status: 'accepted',
      acceptedUid: 'existing-uid',
    }),
  });
  assert.equal(result.alreadyProvisioned, true);
  assert.equal(result.uid, 'existing-uid');
  assert.equal(state.created.length, 0);
  assert.equal(state.commits.length, 0);
  assert.equal(state.links.length, 0);
});

test('existing account without role receives the expected role', async () => {
  const {state} = await provision({
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
  });
  assert.equal(state.created.length, 0);
  assert.equal(state.commits[0].targetUid, 'existing-uid');
});

test('existing compatible role is accepted idempotently', async () => {
  const compatible = {
    role: 'site_manager',
    locationIds: ['site-b', 'site-a'],
    active: true,
  };
  const {state} = await provision({
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
    role: compatible,
  });
  assert.equal(state.commits.length, 1);
  assert.equal(state.created.length, 0);
});

test('incompatible role is refused without mutation', async () => {
  const value = harness({
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
    role: {role: 'coordinator', locationIds: [], active: true},
  });
  await rejectsCode(
    () => provisionAdminInvitation({
      invitationId: 'invitation-a',
      callerUid: 'coord',
      services: value.services,
      mailer: value.mailer,
      appUrl,
      now,
    }),
    'already-exists',
  );
  assert.equal(value.state.commits.length, 0);
});

test('disabled existing account is refused', async () => {
  const value = harness({
    user: {
      uid: 'disabled-uid',
      email: 'responsable@example.fr',
      disabled: true,
    },
  });
  await rejectsCode(
    () => provisionAdminInvitation({
      invitationId: 'invitation-a',
      callerUid: 'coord',
      services: value.services,
      mailer: value.mailer,
      appUrl,
      now,
    }),
    'failed-precondition',
  );
});

test('Firestore failure compensates new Auth account and does not accept', async () => {
  const value = harness({failCommit: true});
  await assert.rejects(() => provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    mailer: value.mailer,
    appUrl,
    now,
  }));
  assert.deepEqual(value.state.deleted, ['created-uid']);
  assert.equal(value.state.invitation.status, 'pending');
  assert.equal(value.state.commits.length, 0);
});

test('activation link uses Emulator URL and is captured but never persisted', async () => {
  const {state, result} = await provision();
  assert.equal(state.links[0].settings.url, appUrl);
  assert.match(state.mail[0].activationLink, /^http:\/\/127\.0\.0\.1:9099/);
  assert.equal(
    JSON.stringify(state.commits).includes('127.0.0.1:9099'),
    false,
  );
  assert.equal(JSON.stringify(result).includes('127.0.0.1:9099'), false);
});

test('production mail transport remains pending and sends nothing', async () => {
  const {state, result} = await provision();
  assert.equal(state.mail.length, 1);
  assert.equal(result.emailDelivery, 'pending');
});

test('MOBSANTE_APP_URL is mandatory', async () => {
  const {services, mailer} = harness();
  await rejectsCode(
    () => provisionAdminInvitation({
      invitationId: 'invitation-a',
      callerUid: 'coord',
      services,
      mailer,
      appUrl: '',
      now,
    }),
    'failed-precondition',
  );
});
