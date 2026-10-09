import assert from 'node:assert/strict';
import {test} from 'node:test';

import {
  createProfessionalInvitation,
  normalizeProfessionalInvitationEmail,
} from '../src/professional_admission.js';

test('professional invitation email uses only trim and lowercase', () => {
  assert.equal(normalizeProfessionalInvitationEmail(' A.Name+tag@Example.TEST '),
    'a.name+tag@example.test');
  assert.equal(normalizeProfessionalInvitationEmail('a.name@gmail.com'),
    'a.name@gmail.com');
  assert.equal(normalizeProfessionalInvitationEmail('aname@gmail.com'),
    'aname@gmail.com');
  for (const invalid of [null, '', 'name', 'a@@example.test', 'a@', ' a b@example.test ']) {
    assert.equal(normalizeProfessionalInvitationEmail(invalid), null);
  }
});

test('creation requires a recipient before any invitation write', async () => {
  let writes = 0;
  let created;
  const db = {
    collection(name) {
      return {doc() {
        return {
          async get() {
            return name === 'platformAdministrators'
              ? {exists: true, data: () => ({active: true})}
              : {exists: true, data: () => ({
                ownerOrganizationId: 'org-a', status: 'active', purpose: 'operational',
              })};
          },
          async create(value) { writes++; created = value; },
        };
      }};
    },
    doc() { return {get: async () => ({data: () => ({admissionMode: 'invitation_only'})})}; },
  };
  await assert.rejects(() => createProfessionalInvitation({
    db, callerUid: 'admin', data: {
      organizationId: 'org-a', operationId: 'op-a',
      expectedProfession: 'mk',
      expiresAt: new Date(Date.now() + 86_400_000).toISOString(),
    },
  }), {code: 'invalid-argument'});
  assert.equal(writes, 0);
  const result = await createProfessionalInvitation({
    db, callerUid: 'admin', data: {
      organizationId: 'org-a', operationId: 'op-a',
      expectedProfession: 'mk', targetEmail: ' Target+MK@Example.TEST ',
      expiresAt: new Date(Date.now() + 86_400_000).toISOString(),
    },
  });
  assert.equal(writes, 1);
  assert.equal(created.targetEmailNormalized, 'target+mk@example.test');
  assert.equal(created.expectedProfession, 'physiotherapist');
  assert.equal(created.code, undefined);
  assert.match(result.code, /^[A-Za-z0-9_-]{43}$/);
  assert.notEqual(result.invitationId, result.code);
});

test('invitation preparation refuses invalid admission modes before writing', async () => {
  for (const admissionMode of [null, 'unexpected']) {
    let writes = 0;
    const db = {
      collection() {
        return {doc() {
          return {
            get: async () => ({exists: true, data: () => ({active: true})}),
            create: async () => { writes++; },
          };
        }};
      },
      doc() {
        return {get: async () => ({data: () => ({admissionMode})})};
      },
    };
    await assert.rejects(() => createProfessionalInvitation({
      db, callerUid: 'admin', data: {},
    }), {code: 'failed-precondition'});
    assert.equal(writes, 0);
  }
});
