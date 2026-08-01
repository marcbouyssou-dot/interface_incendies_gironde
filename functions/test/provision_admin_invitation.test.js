import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildActivationUrl,
  buildCustomActivationLink,
  invitationNotificationIdempotencyKey,
  NOTIFICATION_LEASE_DURATION_MS,
  ProvisioningError,
  provisionAdminInvitation,
} from '../src/provision_admin_invitation.js';
import {mergeResponsibleAccess} from '../src/responsible_access.js';

const now = new Date('2026-07-30T10:00:00.000Z');
const appUrl = 'http://127.0.0.1:5000';
const BLANK_LOCATION_ID_VECTORS = [
  '\u0009', '\u000A', '\u000B', '\u000C', '\u000D', '\u0020', '\u0085',
  '\u00A0', '\u1680', '\u2000', '\u2001', '\u2002', '\u2003', '\u2004',
  '\u2005', '\u2006', '\u2007', '\u2008', '\u2009', '\u200A', '\u2028',
  '\u2029', '\u202F', '\u205F', '\u3000', '\uFEFF',
];

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

function locations(start, count) {
  return Array.from(
    {length: count},
    (_, index) => `site-${String(start + index).padStart(3, '0')}`,
  );
}

function firebasePasswordResetLink(settings) {
  const url = new URL('https://test-project.firebaseapp.com/__/auth/action');
  url.searchParams.set('mode', 'resetPassword');
  url.searchParams.set('oobCode', 'test-action-code');
  url.searchParams.set('apiKey', 'public-test-api-key');
  url.searchParams.set('continueUrl', settings.url);
  url.searchParams.set('lang', 'fr');
  return url.toString();
}

function harness({
  callerRole = {role: 'coordinator', active: true, locationIds: []},
  invitationValue = invitation(),
  user,
  role,
  raceUser,
  failCommit = false,
  failLink = false,
  failNotification = false,
  generatedPasswordResetLink,
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
    notifications: [],
    notificationOptions: [],
    notificationReservations: [],
    notificationSent: [],
    notificationFailed: [],
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
      if (raceUser) {
        state.user = raceUser;
        const error = new Error('email already exists');
        error.code = 'auth/email-already-exists';
        throw error;
      }
      state.created.push(properties);
      state.user = {uid: 'created-uid', ...properties};
      return state.user;
    },
    async deleteUser(uid) {
      state.deleted.push(uid);
      state.user = null;
    },
    async generatePasswordResetLink(email, settings) {
      if (failLink) throw new Error('link failed');
      state.links.push({email, settings});
      return generatedPasswordResetLink ?? firebasePasswordResetLink(settings);
    },
    async commitProvisioning(value) {
      if (failCommit) throw new Error('firestore failed');
      const mergedRole = mergeResponsibleAccess(
        state.role,
        state.invitation,
      );
      state.role = {
        ...(state.role ?? {}),
        ...mergedRole,
        createdAt: state.role?.createdAt ?? now,
        createdBy: state.role?.createdBy ?? value.createdBy,
        updatedAt: now,
      };
      state.commits.push({...value, role: state.role});
      state.invitation = {
        ...state.invitation,
        status: 'accepted',
        acceptedUid: value.targetUid,
        notificationStatus: 'pending',
      };
    },
    async reserveNotificationDelivery(value) {
      if (state.invitation.notificationStatus === 'sent') {
        return {state: 'sent'};
      }
      const activeLease = state.invitation.notificationStatus === 'sending'
        && state.invitation.notificationAttemptId
        && state.invitation.notificationLeaseExpiresAt > value.reservedAt;
      if (activeLease) return {state: 'in-progress'};
      state.notificationReservations.push(value);
      state.invitation = {
        ...state.invitation,
        notificationStatus: 'sending',
        notificationAttemptId: value.attemptId,
        notificationReservedAt: value.reservedAt,
        notificationLeaseExpiresAt: value.leaseExpiresAt,
      };
      delete state.invitation.notificationErrorCode;
      delete state.invitation.notificationFailedAt;
      return {state: 'reserved'};
    },
    async markNotificationSent(value) {
      state.notificationSent.push(value);
      if (state.invitation.notificationStatus === 'sent') {
        return {state: 'sent'};
      }
      if (state.invitation.notificationAttemptId !== value.attemptId) {
        return {state: 'in-progress'};
      }
      state.invitation = {
        ...state.invitation,
        notificationStatus: 'sent',
        notificationProvider: value.provider,
        notificationProviderMessageId: value.providerMessageId,
      };
      delete state.invitation.notificationAttemptId;
      delete state.invitation.notificationReservedAt;
      delete state.invitation.notificationLeaseExpiresAt;
      return {state: 'sent'};
    },
    async markNotificationFailed(value) {
      state.notificationFailed.push(value);
      if (state.invitation.notificationStatus === 'sent') {
        return {state: 'sent'};
      }
      if (state.invitation.notificationAttemptId !== value.attemptId) {
        return {state: 'in-progress'};
      }
      state.invitation = {
        ...state.invitation,
        notificationStatus: 'failed',
        notificationErrorCode: value.errorCode,
      };
      delete state.invitation.notificationAttemptId;
      delete state.invitation.notificationReservedAt;
      delete state.invitation.notificationLeaseExpiresAt;
      return {state: 'failed'};
    },
  };
  const notificationService = {
    async send(value, options) {
      state.notifications.push(value);
      state.notificationOptions.push(options);
      if (failNotification) {
        const error = new Error('simulated notification failure');
        error.code = 'provider-failure';
        throw error;
      }
      return {
        success: true,
        provider: 'fake',
        providerMessageId: 'fake-message-id',
      };
    },
  };
  return {state, services, notificationService};
}

async function provision(setup = {}) {
  const value = harness(setup);
  const result = await provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    notificationService: value.notificationService,
    appUrl,
    now,
    createNotificationAttemptId: () => 'attempt-a',
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
  const {services, notificationService} = harness();
  await rejectsCode(
    () => provisionAdminInvitation({
      invitationId: 'invitation-a',
      callerUid: null,
      services,
      notificationService,
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
    const {services, notificationService} = harness({callerRole});
    await rejectsCode(
      () => provisionAdminInvitation({
        invitationId: 'invitation-a',
        callerUid: 'coord',
        services,
        notificationService,
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
  assert.deepEqual(state.deleted, []);
  assert.equal(result.emailDelivery, 'sent');
  assert.equal(result.accountProvisioned, true);
  assert.equal(result.invitationStatus, 'accepted');
  assert.deepEqual(Object.keys(result).sort(), [
    'accountProvisioned',
    'alreadyProvisioned',
    'emailDelivery',
    'invitationStatus',
  ]);
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
  const {services, notificationService} = harness({invitationValue: null});
  await rejectsCode(
    () => provisionAdminInvitation({
      invitationId: 'missing',
      callerUid: 'coord',
      services,
      notificationService,
      appUrl,
      now,
    }),
    'not-found',
  );
});

test('blank invitation location is refused before Auth or Firestore writes', async () => {
  for (const locationId of [
    ...BLANK_LOCATION_ID_VECTORS,
    '\u0009\u0020\u000A',
  ]) {
    const value = harness({
      invitationValue: invitation({locationIds: [locationId]}),
    });

    await rejectsCode(
      () => provisionAdminInvitation({
        invitationId: 'invitation-a',
        callerUid: 'coord',
        services: value.services,
        notificationService: value.notificationService,
        appUrl,
        now,
      }),
      'invalid-argument',
    );

    assert.equal(value.state.created.length, 0);
    assert.equal(value.state.commits.length, 0);
    assert.equal(value.state.notifications.length, 0);
  }
});

test('peripheral spaces and partial wildcard stay exact during provisioning', async () => {
  const locationIds = [
    ' bazas', 'bazas ', ' bazas ', 'ba zas', 'bazas', 'Bazas', 'bazas*',
    '\u00A0bazas', 'bazas\u0085',
    '\u0000', '\u001E', '\u007F', String.raw`\u001F`,
    '\u00E9', 'e\u0301', '\u2217', ' * ',
  ];

  const {state} = await provision({
    invitationValue: invitation({locationIds}),
  });

  assert.deepEqual(state.commits[0].role.locationIds, [...locationIds].sort());
});

for (const [label, value] of [
  ['expired', invitation({expiresAt: new Date('2026-07-29T10:00:00Z')})],
  ['cancelled', invitation({status: 'cancelled'})],
]) {
  test(`${label} invitation is refused`, async () => {
    const {services, notificationService} = harness({invitationValue: value});
    await rejectsCode(
      () => provisionAdminInvitation({
        invitationId: 'invitation-a',
        callerUid: 'coord',
        services,
        notificationService,
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
      notificationStatus: 'sent',
    }),
  });
  assert.equal(result.alreadyProvisioned, true);
  assert.equal(state.created.length, 0);
  assert.equal(state.commits.length, 0);
  assert.equal(state.links.length, 0);
  assert.equal(state.notifications.length, 0);
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

test('existing compatible role is rewritten canonically without loss', async () => {
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
  assert.deepEqual(state.role.roles, ['site_manager']);
  assert.equal(state.role.schemaVersion, 2);
});

test('existing coordinator receives the site manager role additively', async () => {
  const {state} = await provision({
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
    role: {role: 'coordinator', locationIds: [], active: true},
  });
  assert.deepEqual(state.role.roles, ['coordinator', 'site_manager']);
  assert.deepEqual(state.role.locationIds, ['site-a', 'site-b']);
  assert.equal(state.role.role, 'coordinator');
  assert.match(state.notifications[0].text, /Responsable de centre/);
  assert.doesNotMatch(
    state.notifications[0].text,
    /Coordinateur départemental/,
  );
});

test('existing site manager receives coordinator without losing locations', async () => {
  const {state} = await provision({
    invitationValue: invitation({role: 'coordinator', locationIds: []}),
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
    role: {
      role: 'site_manager',
      locationIds: ['site-b'],
      active: true,
    },
  });
  assert.deepEqual(state.role.roles, ['coordinator', 'site_manager']);
  assert.deepEqual(state.role.locationIds, ['site-b']);
});

test('provisioning writes an exact final limit of 65 locations', async () => {
  const existingLocations = locations(0, 64);
  const {state} = await provision({
    invitationValue: invitation({locationIds: locations(64, 1)}),
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
    role: {
      role: 'site_manager',
      roles: ['site_manager'],
      locationIds: existingLocations,
      active: true,
      schemaVersion: 2,
    },
  });
  assert.deepEqual(state.role.locationIds, locations(0, 65));
  assert.equal(state.commits.length, 1);
  assert.equal(state.notifications.length, 1);
});

test('provisioning refuses 66 locations before writes or notification', async () => {
  const existingRole = {
    role: 'site_manager',
    roles: ['site_manager'],
    locationIds: locations(0, 65),
    active: true,
    schemaVersion: 2,
  };
  const value = harness({
    invitationValue: invitation({locationIds: locations(65, 1)}),
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
    role: existingRole,
  });
  await rejectsCode(
    () => provisionAdminInvitation({
      invitationId: 'invitation-a',
      callerUid: 'coord',
      services: value.services,
      notificationService: value.notificationService,
      appUrl,
      now,
    }),
    'failed-precondition',
  );
  assert.deepEqual(value.state.role, existingRole);
  assert.equal(value.state.invitation.status, 'pending');
  assert.equal(value.state.commits.length, 0);
  assert.equal(value.state.notifications.length, 0);
  assert.deepEqual(value.state.deleted, []);
});

test('malformed existing role is refused without deleting existing Auth', async () => {
  const value = harness({
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
    role: {role: 'administrator', locationIds: [], active: true},
  });
  await rejectsCode(
    () => provisionAdminInvitation({
      invitationId: 'invitation-a',
      callerUid: 'coord',
      services: value.services,
      notificationService: value.notificationService,
      appUrl,
      now,
    }),
    'failed-precondition',
  );
  assert.equal(value.state.commits.length, 0);
  assert.deepEqual(value.state.deleted, []);
});

test('inactive existing role is refused without implicit reactivation', async () => {
  const value = harness({
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
    role: {role: 'coordinator', locationIds: [], active: false},
  });
  await rejectsCode(
    () => provisionAdminInvitation({
      invitationId: 'invitation-a',
      callerUid: 'coord',
      services: value.services,
      notificationService: value.notificationService,
      appUrl,
      now,
    }),
    'failed-precondition',
  );
  assert.equal(value.state.role.active, false);
  assert.deepEqual(value.state.deleted, []);
});

test('concurrent Auth creation reuses the account created by the winner', async () => {
  const {state} = await provision({
    raceUser: {
      uid: 'race-winner-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
  });
  assert.equal(state.created.length, 0);
  assert.equal(state.commits[0].targetUid, 'race-winner-uid');
  assert.deepEqual(state.deleted, []);
});

test('concurrent provisioning never deletes an adopted new Auth account', async () => {
  const targetEmail = 'concurrent@example.fr';
  const invitations = new Map([
    [
      'invitation-failure',
      invitation({email: targetEmail, locationIds: ['site-a']}),
    ],
    [
      'invitation-success',
      invitation({email: targetEmail, locationIds: ['site-b']}),
    ],
  ]);
  const state = {
    user: null,
    role: null,
    createAttempts: 0,
    createdAccounts: 0,
    deleted: [],
    notifications: [],
  };
  let initialLookups = 0;
  let releaseInitialLookups;
  let transactionFailureInjected = false;
  const initialLookupBarrier = new Promise((resolve) => {
    releaseInitialLookups = resolve;
  });
  const services = {
    async getRole(uid) {
      return uid === 'coord'
        ? {role: 'coordinator', active: true, locationIds: []}
        : state.role;
    },
    async getInvitation(id) {
      return invitations.get(id);
    },
    async getUserByEmail() {
      if (state.user) return state.user;
      initialLookups += 1;
      if (initialLookups === 2) releaseInitialLookups();
      await initialLookupBarrier;
      if (state.user) return state.user;
      const error = new Error('missing');
      error.code = 'auth/user-not-found';
      throw error;
    },
    async createUser(properties) {
      state.createAttempts += 1;
      if (state.user) {
        const error = new Error('email already exists');
        error.code = 'auth/email-already-exists';
        throw error;
      }
      state.createdAccounts += 1;
      state.user = {uid: 'concurrent-uid', ...properties};
      return state.user;
    },
    async deleteUser(uid) {
      state.deleted.push(uid);
      state.user = null;
    },
    async generatePasswordResetLink(email, settings) {
      return firebasePasswordResetLink(settings);
    },
    async commitProvisioning(value) {
      if (
        value.invitationId === 'invitation-failure'
        && !transactionFailureInjected
      ) {
        transactionFailureInjected = true;
        throw new Error('simulated transaction failure');
      }
      const current = invitations.get(value.invitationId);
      state.role = mergeResponsibleAccess(state.role, current);
      invitations.set(value.invitationId, {
        ...current,
        status: 'accepted',
        acceptedUid: value.targetUid,
        notificationStatus: 'pending',
      });
    },
    async reserveNotificationDelivery(value) {
      const current = invitations.get(value.invitationId);
      if (current.notificationStatus === 'sent') return {state: 'sent'};
      if (
        current.notificationStatus === 'sending'
        && current.notificationLeaseExpiresAt > value.reservedAt
      ) {
        return {state: 'in-progress'};
      }
      invitations.set(value.invitationId, {
        ...current,
        notificationStatus: 'sending',
        notificationAttemptId: value.attemptId,
        notificationReservedAt: value.reservedAt,
        notificationLeaseExpiresAt: value.leaseExpiresAt,
      });
      return {state: 'reserved'};
    },
    async markNotificationSent(value) {
      const current = invitations.get(value.invitationId);
      if (current.notificationStatus === 'sent') return {state: 'sent'};
      if (current.notificationAttemptId !== value.attemptId) {
        return {state: 'in-progress'};
      }
      invitations.set(value.invitationId, {
        ...current,
        notificationStatus: 'sent',
      });
      return {state: 'sent'};
    },
    async markNotificationFailed() {},
  };
  const notificationService = {
    async send(message) {
      state.notifications.push(message);
      return {
        success: true,
        provider: 'fake',
        providerMessageId: `message-${state.notifications.length}`,
      };
    },
  };
  const call = (invitationId) => provisionAdminInvitation({
    invitationId,
    callerUid: 'coord',
    services,
    notificationService,
    appUrl,
    now,
  });

  const results = await Promise.allSettled([
    call('invitation-failure'),
    call('invitation-success'),
  ]);
  assert.equal(
    results.filter((result) => result.status === 'fulfilled').length,
    1,
  );
  assert.equal(
    results.filter((result) => result.status === 'rejected').length,
    1,
  );
  assert.equal(state.createdAccounts, 1);
  assert.equal(state.createAttempts, 2);
  assert.equal(state.user.uid, 'concurrent-uid');
  assert.deepEqual(state.deleted, []);
  assert.equal(state.role.role, 'site_manager');
  assert.deepEqual(state.role.roles, ['site_manager']);
  assert.deepEqual(state.role.locationIds, ['site-b']);
  assert.equal(state.role.active, true);
  assert.equal(state.role.schemaVersion, 2);
  assert.equal(
    invitations.get('invitation-success').notificationStatus,
    'sent',
  );
  assert.equal(invitations.get('invitation-failure').status, 'pending');
  assert.equal(state.notifications.length, 1);

  await call('invitation-failure');
  assert.deepEqual(state.role.locationIds, ['site-a', 'site-b']);
  assert.equal(
    invitations.get('invitation-failure').notificationStatus,
    'sent',
  );
  assert.equal(state.notifications.length, 2);
  await call('invitation-failure');
  assert.equal(state.notifications.length, 2);
  assert.deepEqual(state.deleted, []);
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
      notificationService: value.notificationService,
      appUrl,
      now,
    }),
    'failed-precondition',
  );
});

test('Firestore failure preserves a new Auth account without accepting', async () => {
  const value = harness({failCommit: true});
  await assert.rejects(() => provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    notificationService: value.notificationService,
    appUrl,
    now,
  }));
  assert.deepEqual(value.state.deleted, []);
  assert.equal(value.state.user.uid, 'created-uid');
  assert.equal(value.state.invitation.status, 'pending');
  assert.equal(value.state.commits.length, 0);
  assert.equal(value.state.notifications.length, 0);
});

test('activation-link failure preserves a newly created account', async () => {
  const value = harness({failLink: true});
  await assert.rejects(() => provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    notificationService: value.notificationService,
    appUrl,
    now,
  }));
  assert.deepEqual(value.state.deleted, []);
  assert.equal(value.state.user.uid, 'created-uid');
  assert.equal(value.state.invitation.status, 'pending');
  assert.equal(value.state.commits.length, 0);
  assert.equal(value.state.notifications.length, 0);
});

test('activation-link failure never deletes a pre-existing account', async () => {
  const value = harness({
    failLink: true,
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
  });
  await assert.rejects(() => provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    notificationService: value.notificationService,
    appUrl,
    now,
  }));
  assert.deepEqual(value.state.deleted, []);
  assert.equal(value.state.invitation.status, 'pending');
});

test('retry after a transaction failure reuses the preserved Auth account', async () => {
  const value = harness({failCommit: true});
  await assert.rejects(() => provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    notificationService: value.notificationService,
    appUrl,
    now,
  }));
  assert.deepEqual(value.state.deleted, []);
  assert.equal(value.state.user.uid, 'created-uid');

  const retry = harness({
    invitationValue: value.state.invitation,
    user: value.state.user,
  });
  const result = await provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: retry.services,
    notificationService: retry.notificationService,
    appUrl,
    now,
  });
  assert.equal(retry.state.created.length, 0);
  assert.equal(retry.state.commits.length, 1);
  assert.equal(retry.state.commits[0].targetUid, 'created-uid');
  assert.equal(result.invitationStatus, 'accepted');
});

test('notification receives the custom Emulator activation URL only', async () => {
  const {state, result} = await provision();
  assert.equal(
    state.links[0].settings.url,
    'http://127.0.0.1:5000/activation',
  );
  assert.equal(state.links[0].settings.handleCodeInApp, true);
  assert.match(
    state.notifications[0].text,
    /http:\/\/127\.0\.0\.1:5000\/activation\?/,
  );
  assert.match(state.notifications[0].text, /mode=resetPassword/);
  assert.match(state.notifications[0].text, /oobCode=test-action-code/);
  assert.doesNotMatch(state.notifications[0].text, /firebaseapp\.com/);
  assert.equal(
    JSON.stringify(state.commits).includes('test-action-code'),
    false,
  );
  assert.equal(JSON.stringify(result).includes('test-action-code'), false);
});

test('production notification receives a MobSanté activation URL', async () => {
  const value = harness();
  await provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    notificationService: value.notificationService,
    appUrl: 'https://mobsante.netlify.app',
    now,
  });

  assert.match(
    value.state.notifications[0].text,
    /https:\/\/mobsante\.netlify\.app\/activation\?/,
  );
  assert.match(value.state.notifications[0].text, /mode=resetPassword/);
  assert.match(value.state.notifications[0].text, /oobCode=test-action-code/);
  assert.doesNotMatch(value.state.notifications[0].text, /firebaseapp\.com/);
});

test('custom activation link copies all supported Firebase parameters', () => {
  const result = buildCustomActivationLink({
    firebaseActionLink: firebasePasswordResetLink({
      url: 'https://mobsante.netlify.app/activation',
    }),
    activationUrl: 'https://mobsante.netlify.app/activation',
  });
  const url = new URL(result);

  assert.equal(url.origin, 'https://mobsante.netlify.app');
  assert.equal(url.pathname, '/activation');
  assert.equal(url.searchParams.get('mode'), 'resetPassword');
  assert.equal(url.searchParams.get('oobCode'), 'test-action-code');
  assert.equal(url.searchParams.get('apiKey'), 'public-test-api-key');
  assert.equal(url.searchParams.get('lang'), 'fr');
  assert.equal(url.searchParams.has('continueUrl'), false);
});

test('custom activation link accepts a missing apiKey', () => {
  const firebaseUrl = new URL(firebasePasswordResetLink({url: appUrl}));
  firebaseUrl.searchParams.delete('apiKey');
  const result = new URL(buildCustomActivationLink({
    firebaseActionLink: firebaseUrl.toString(),
    activationUrl: `${appUrl}/activation`,
  }));

  assert.equal(result.searchParams.has('apiKey'), false);
  assert.equal(result.searchParams.get('oobCode'), 'test-action-code');
});

test('custom activation link accepts a missing lang', () => {
  const firebaseUrl = new URL(firebasePasswordResetLink({url: appUrl}));
  firebaseUrl.searchParams.delete('lang');
  const result = new URL(buildCustomActivationLink({
    firebaseActionLink: firebaseUrl.toString(),
    activationUrl: `${appUrl}/activation`,
  }));

  assert.equal(result.searchParams.has('lang'), false);
  assert.equal(result.searchParams.get('oobCode'), 'test-action-code');
});

test('custom activation link preserves existing parameters and encodes values', () => {
  const firebaseUrl = new URL('https://test-project.firebaseapp.com/action');
  firebaseUrl.searchParams.set('mode', 'resetPassword');
  firebaseUrl.searchParams.set('oobCode', 'code +/=?&é');
  const result = new URL(buildCustomActivationLink({
    firebaseActionLink: firebaseUrl.toString(),
    activationUrl: 'https://mobsante.netlify.app/activation?source=invitation',
  }));

  assert.equal(result.searchParams.get('source'), 'invitation');
  assert.equal(result.searchParams.get('oobCode'), 'code +/=?&é');
});

for (const [label, generatedPasswordResetLink] of [
  ['malformed URL', 'not-a-url'],
  ['missing mode', 'https://test-project.firebaseapp.com/action?oobCode=code'],
  [
    'unexpected mode',
    'https://test-project.firebaseapp.com/action?mode=verifyEmail&oobCode=code',
  ],
  ['missing oobCode', 'https://test-project.firebaseapp.com/action?mode=resetPassword'],
  [
    'empty oobCode',
    'https://test-project.firebaseapp.com/action?mode=resetPassword&oobCode=',
  ],
]) {
  test(`invalid Firebase action link is refused before notification: ${label}`, async () => {
    const value = harness({generatedPasswordResetLink});
    await rejectsCode(
      () => provisionAdminInvitation({
        invitationId: 'invitation-a',
        callerUid: 'coord',
        services: value.services,
        notificationService: value.notificationService,
        appUrl,
        now,
      }),
      'internal',
    );
    assert.equal(value.state.notifications.length, 0);
    assert.equal(value.state.commits.length, 0);
    assert.deepEqual(value.state.deleted, []);
    assert.equal(value.state.user.uid, 'created-uid');
  });
}

test('activation URL is normalized safely', () => {
  assert.equal(
    buildActivationUrl('https://mobsante.netlify.app'),
    'https://mobsante.netlify.app/activation',
  );
  assert.equal(
    buildActivationUrl('https://mobsante.netlify.app/'),
    'https://mobsante.netlify.app/activation',
  );
  assert.equal(
    buildActivationUrl('https://mobsante.netlify.app/activation/'),
    'https://mobsante.netlify.app/activation',
  );
  assert.equal(
    buildActivationUrl('https://mobsante.example/'),
    'https://mobsante.example/activation',
  );
  assert.equal(
    buildActivationUrl('https://mobsante.example/activation/'),
    'https://mobsante.example/activation',
  );
  assert.equal(
    buildActivationUrl('http://localhost:5000'),
    'http://localhost:5000/activation',
  );
});

for (const value of [
  'http://mobsante.example',
  'ftp://mobsante.example',
  'https://user:secret@mobsante.example',
  'https://mobsante.example?redirect=https://evil.example',
  'not-an-url',
]) {
  test(`unsafe activation URL is refused: ${value}`, () => {
    assert.throws(
      () => buildActivationUrl(value),
      (error) =>
        error instanceof ProvisioningError
        && error.code === 'failed-precondition',
    );
  });
}

test('notification is sent once through the injected service', async () => {
  const {state, result} = await provision();
  assert.equal(state.notifications.length, 1);
  assert.equal(state.notificationSent.length, 1);
  assert.equal(result.emailDelivery, 'sent');
  assert.equal(state.notifications[0].recipient, 'responsable@example.fr');
  assert.match(state.notifications[0].text, /Rôle attribué/);
  assert.match(state.notifications[0].text, /Ne transférez pas ce lien/);
  assert.match(state.notifications[0].html, /MobSanté/);
  assert.equal(
    /InterfaceRecup33|interfacerecup33\.netlify\.app|mot de passe/i
      .test(JSON.stringify(state.notifications[0])),
    false,
  );
  assert.equal(state.invitation.notificationStatus, 'sent');
  assert.equal(
    state.invitation.notificationProviderMessageId,
    'fake-message-id',
  );
  assert.equal(
    JSON.stringify(state.invitation).includes('Votre compte responsable'),
    false,
  );
  assert.equal(
    state.notificationOptions[0].idempotencyKey,
    invitationNotificationIdempotencyKey('invitation-a'),
  );
});

test('invitation idempotency key is stable, distinct and provider-compatible', () => {
  assert.equal(
    invitationNotificationIdempotencyKey('invitation-a'),
    'admin-invitation:'
      + '7f2bbb548dc956b1bde7d361dac54d8c1a0a261ba66f8b1fc5c486e2987a7d49'
      + ':activation',
  );
  assert.equal(
    invitationNotificationIdempotencyKey('invitation-a'),
    invitationNotificationIdempotencyKey('invitation-a'),
  );
  assert.notEqual(
    invitationNotificationIdempotencyKey('invitation-a'),
    invitationNotificationIdempotencyKey('invitation-b'),
  );
  assert.match(
    invitationNotificationIdempotencyKey('invitation-a'),
    /^[A-Za-z0-9:_-]{1,256}$/,
  );
});

test('two concurrent calls on an accepted failed invitation send once', async () => {
  const value = harness({
    invitationValue: invitation({
      status: 'accepted',
      acceptedUid: 'existing-uid',
      notificationStatus: 'failed',
    }),
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
  });
  let releaseFirstSend;
  let firstSendStarted;
  const started = new Promise((resolve) => {
    firstSendStarted = resolve;
  });
  const released = new Promise((resolve) => {
    releaseFirstSend = resolve;
  });
  value.notificationService.send = async (message, options) => {
    value.state.notifications.push(message);
    value.state.notificationOptions.push(options);
    firstSendStarted();
    await released;
    return {
      success: true,
      provider: 'fake',
      providerMessageId: 'concurrent-message-id',
    };
  };
  const call = (attemptId) => provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    notificationService: value.notificationService,
    appUrl,
    now,
    createNotificationAttemptId: () => attemptId,
  });

  const first = call('attempt-first');
  await started;
  const second = await call('attempt-second');
  assert.equal(second.emailDelivery, 'pending');
  assert.equal(value.state.notifications.length, 1);
  releaseFirstSend();
  const firstResult = await first;
  assert.equal(firstResult.emailDelivery, 'sent');
  assert.equal(value.state.invitation.notificationStatus, 'sent');
  assert.equal(value.state.notificationReservations.length, 1);
});

test('two concurrent calls on a pending invitation send once after role assignment', async () => {
  const value = harness({
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
  });
  let releaseFirstSend;
  let firstSendStarted;
  const started = new Promise((resolve) => {
    firstSendStarted = resolve;
  });
  const released = new Promise((resolve) => {
    releaseFirstSend = resolve;
  });
  value.notificationService.send = async (message, options) => {
    value.state.notifications.push(message);
    value.state.notificationOptions.push(options);
    firstSendStarted();
    await released;
    return {
      success: true,
      provider: 'fake',
      providerMessageId: 'pending-concurrent-message-id',
    };
  };
  const call = (attemptId) => provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    notificationService: value.notificationService,
    appUrl,
    now,
    createNotificationAttemptId: () => attemptId,
  });
  const first = call('pending-attempt-one');
  const second = call('pending-attempt-two');
  await started;
  const secondResult = await second;
  assert.equal(secondResult.emailDelivery, 'pending');
  assert.equal(value.state.notifications.length, 1);
  releaseFirstSend();
  const firstResult = await first;
  assert.equal(firstResult.emailDelivery, 'sent');
  assert.equal(value.state.invitation.notificationStatus, 'sent');
});

test('two simultaneous reservations have exactly one owner', async () => {
  const value = harness({
    invitationValue: invitation({
      status: 'accepted',
      acceptedUid: 'existing-uid',
      notificationStatus: 'pending',
    }),
  });
  const reserve = (attemptId) => value.services.reserveNotificationDelivery({
    invitationId: 'invitation-a',
    targetUid: 'existing-uid',
    attemptId,
    reservedAt: now,
    leaseExpiresAt: new Date(now.getTime() + NOTIFICATION_LEASE_DURATION_MS),
  });
  const results = await Promise.all([
    reserve('attempt-one'),
    reserve('attempt-two'),
  ]);
  assert.deepEqual(
    results.map((result) => result.state).sort(),
    ['in-progress', 'reserved'],
  );
  assert.equal(value.state.notificationReservations.length, 1);
});

test('active notification lease skips provider delivery', async () => {
  const value = harness({
    invitationValue: invitation({
      status: 'accepted',
      acceptedUid: 'existing-uid',
      notificationStatus: 'sending',
      notificationAttemptId: 'current-attempt',
      notificationReservedAt: now,
      notificationLeaseExpiresAt: new Date(
        now.getTime() + NOTIFICATION_LEASE_DURATION_MS,
      ),
    }),
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
  });
  const result = await provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    notificationService: value.notificationService,
    appUrl,
    now,
    createNotificationAttemptId: () => 'other-attempt',
  });
  assert.equal(result.emailDelivery, 'pending');
  assert.equal(value.state.notifications.length, 0);
  assert.equal(value.state.invitation.notificationAttemptId, 'current-attempt');
});

test('expired abandoned lease can be reclaimed', async () => {
  const value = harness({
    invitationValue: invitation({
      status: 'accepted',
      acceptedUid: 'existing-uid',
      notificationStatus: 'failed',
    }),
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
  });
  await value.services.reserveNotificationDelivery({
    invitationId: 'invitation-a',
    targetUid: 'existing-uid',
    attemptId: 'abandoned-attempt',
    reservedAt: now,
    leaseExpiresAt: new Date(now.getTime() + NOTIFICATION_LEASE_DURATION_MS),
  });

  const result = await provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    notificationService: value.notificationService,
    appUrl,
    now: new Date(now.getTime() + NOTIFICATION_LEASE_DURATION_MS + 1),
    createNotificationAttemptId: () => 'replacement-attempt',
  });
  assert.equal(result.emailDelivery, 'sent');
  assert.equal(value.state.notifications.length, 1);
  assert.equal(value.state.notificationReservations.length, 2);
  assert.equal(value.state.invitation.notificationStatus, 'sent');
});

test('only the current reservation owner can finalize success', async () => {
  const value = harness({
    invitationValue: invitation({
      status: 'accepted',
      acceptedUid: 'existing-uid',
      notificationStatus: 'pending',
    }),
  });
  await value.services.reserveNotificationDelivery({
    invitationId: 'invitation-a',
    targetUid: 'existing-uid',
    attemptId: 'old-attempt',
    reservedAt: now,
    leaseExpiresAt: new Date(now.getTime() + NOTIFICATION_LEASE_DURATION_MS),
  });
  const retryAt = new Date(now.getTime() + NOTIFICATION_LEASE_DURATION_MS + 1);
  await value.services.reserveNotificationDelivery({
    invitationId: 'invitation-a',
    targetUid: 'existing-uid',
    attemptId: 'current-attempt',
    reservedAt: retryAt,
    leaseExpiresAt: new Date(
      retryAt.getTime() + NOTIFICATION_LEASE_DURATION_MS,
    ),
  });
  const stale = await value.services.markNotificationSent({
    invitationId: 'invitation-a',
    targetUid: 'existing-uid',
    attemptId: 'old-attempt',
    provider: 'fake',
    providerMessageId: 'stale-message-id',
    sentAt: retryAt,
  });
  assert.equal(stale.state, 'in-progress');
  assert.equal(value.state.invitation.notificationStatus, 'sending');
  assert.equal(
    value.state.invitation.notificationAttemptId,
    'current-attempt',
  );
  await value.services.markNotificationSent({
    invitationId: 'invitation-a',
    targetUid: 'existing-uid',
    attemptId: 'current-attempt',
    provider: 'fake',
    providerMessageId: 'current-message-id',
    sentAt: retryAt,
  });
  assert.equal(value.state.invitation.notificationStatus, 'sent');
  assert.equal(
    value.state.invitation.notificationProviderMessageId,
    'current-message-id',
  );
});

test('late failure from an expired attempt cannot overwrite retry success', async () => {
  const value = harness({
    invitationValue: invitation({
      status: 'accepted',
      acceptedUid: 'existing-uid',
      notificationStatus: 'failed',
    }),
    user: {
      uid: 'existing-uid',
      email: 'responsable@example.fr',
      disabled: false,
    },
  });
  let rejectOldSend;
  let oldSendStarted;
  const started = new Promise((resolve) => {
    oldSendStarted = resolve;
  });
  const oldSend = new Promise((resolve, reject) => {
    rejectOldSend = reject;
  });
  value.notificationService.send = async (message, options) => {
    value.state.notifications.push(message);
    value.state.notificationOptions.push(options);
    if (value.state.notifications.length === 1) {
      oldSendStarted();
      return oldSend;
    }
    return {
      success: true,
      provider: 'fake',
      providerMessageId: 'retry-message-id',
    };
  };
  const oldCall = provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    notificationService: value.notificationService,
    appUrl,
    now,
    createNotificationAttemptId: () => 'old-attempt',
  });
  await started;
  const retry = await provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    notificationService: value.notificationService,
    appUrl,
    now: new Date(now.getTime() + NOTIFICATION_LEASE_DURATION_MS + 1),
    createNotificationAttemptId: () => 'retry-attempt',
  });
  assert.equal(retry.emailDelivery, 'sent');
  rejectOldSend(Object.assign(new Error('late provider failure'), {
    code: 'provider-failure',
  }));
  await rejectsCode(() => oldCall, 'unavailable');
  assert.equal(value.state.invitation.notificationStatus, 'sent');
  assert.equal(
    value.state.invitation.notificationProviderMessageId,
    'retry-message-id',
  );
  assert.equal(value.state.notificationOptions.length, 2);
  assert.equal(
    value.state.notificationOptions[0].idempotencyKey,
    value.state.notificationOptions[1].idempotencyKey,
  );
});

for (const notificationStatus of [undefined, 'pending', 'failed']) {
  test(`historical accepted invitation ${notificationStatus ?? 'without status'} is retryable`, async () => {
    const invitationValue = invitation({
      status: 'accepted',
      acceptedUid: 'existing-uid',
      ...(notificationStatus === undefined ? {} : {notificationStatus}),
    });
    const {state, result} = await provision({
      invitationValue,
      user: {
        uid: 'existing-uid',
        email: 'responsable@example.fr',
        disabled: false,
      },
    });
    assert.equal(result.emailDelivery, 'sent');
    assert.equal(state.notifications.length, 1);
    assert.equal(state.invitation.notificationStatus, 'sent');
  });
}

test('notification failure preserves provisioned account and role', async () => {
  const value = harness({failNotification: true});
  await rejectsCode(
    () => provisionAdminInvitation({
      invitationId: 'invitation-a',
      callerUid: 'coord',
      services: value.services,
      notificationService: value.notificationService,
      appUrl,
      now,
    }),
    'unavailable',
  );
  assert.equal(value.state.deleted.length, 0);
  assert.equal(value.state.commits.length, 1);
  assert.equal(value.state.role.role, 'site_manager');
  assert.equal(value.state.invitation.status, 'accepted');
  assert.equal(value.state.invitation.notificationStatus, 'failed');
  assert.equal(
    value.state.invitation.notificationErrorCode,
    'provider-failure',
  );
  assert.equal(
    JSON.stringify(value.state.invitation).includes('simulated'),
    false,
  );
});

test('delivery finalization failure keeps the lease instead of marking failed', async () => {
  const value = harness();
  value.services.markNotificationSent = async () => {
    throw new Error('firestore finalization unavailable');
  };

  await assert.rejects(() => provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: value.services,
    notificationService: value.notificationService,
    appUrl,
    now,
    createNotificationAttemptId: () => 'attempt-owner',
  }));

  assert.equal(value.state.notifications.length, 1);
  assert.equal(value.state.notificationFailed.length, 0);
  assert.equal(value.state.invitation.notificationStatus, 'sending');
  assert.equal(
    value.state.invitation.notificationAttemptId,
    'attempt-owner',
  );
});

test('retry after notification failure sends without recreating account or role', async () => {
  const first = harness({failNotification: true});
  await assert.rejects(() => provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: first.services,
    notificationService: first.notificationService,
    appUrl,
    now,
  }));

  const retry = harness({
    invitationValue: first.state.invitation,
    user: first.state.user,
    role: first.state.role,
  });
  const result = await provisionAdminInvitation({
    invitationId: 'invitation-a',
    callerUid: 'coord',
    services: retry.services,
    notificationService: retry.notificationService,
    appUrl,
    now,
  });
  assert.equal(retry.state.created.length, 0);
  assert.equal(retry.state.commits.length, 0);
  assert.equal(retry.state.notifications.length, 1);
  assert.equal(retry.state.invitation.notificationStatus, 'sent');
  assert.equal(result.alreadyProvisioned, true);
  assert.equal(result.emailDelivery, 'sent');
  assert.equal(
    retry.state.notificationOptions[0].idempotencyKey,
    first.state.notificationOptions[0].idempotencyKey,
  );
});

test('captured logs and public result never expose activation secrets', async () => {
  const originalLog = console.log;
  const originalError = console.error;
  const logs = [];
  console.log = (...values) => logs.push(values);
  console.error = (...values) => logs.push(values);
  try {
    const {state, result} = await provision();
    const serialized = JSON.stringify({logs, result, commits: state.commits});
    assert.equal(serialized.includes('oobCode'), false);
    assert.equal(serialized.includes('127.0.0.1:9099'), false);
    assert.equal('activationLink' in result, false);
  } finally {
    console.log = originalLog;
    console.error = originalError;
  }
});

test('MOBSANTE_APP_URL is mandatory', async () => {
  const {services, notificationService} = harness();
  await rejectsCode(
    () => provisionAdminInvitation({
      invitationId: 'invitation-a',
      callerUid: 'coord',
      services,
      notificationService,
      appUrl: '',
      now,
    }),
    'failed-precondition',
  );
});
