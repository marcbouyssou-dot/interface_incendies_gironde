import assert from 'node:assert/strict';
import {test} from 'node:test';
import {canManageOperationLocation, resolveOperationAccess} from
  '../src/operation_access.js';

const membership = (uid, roles) => ({uid, organizationId: 'org-a',
  roles, locationIds: roles.includes('site_manager') ? ['site-x', 'site-y'] : [],
  active: true, schemaVersion: 1});
const grant = (uid, operationId, roles, sites = []) => ({uid, operationId,
  organizationId: 'org-a', roles, locationIds: sites,
  active: true, schemaVersion: 1});
const access = (uid, operationId, member, scoped) => resolveOperationAccess({
  uid, operationId, organizationId: 'org-a', membership: member, grant: scoped,
});

test('coordinator needs a separate explicit grant for each Action', () => {
  const uid = 'coordinator';
  const member = membership(uid, ['coordinator']);
  const actionA = grant(uid, 'action-a', ['coordinator']);
  assert.equal(access(uid, 'action-a', member, actionA).coordinator, true);
  assert.equal(access(uid, 'action-b', member, actionA).coordinator, false);
  assert.equal(access(uid, 'action-b', member,
    grant(uid, 'action-b', ['coordinator'])).coordinator, true);
});

test('same physical site grants no rights in a different Action or site', () => {
  const uid = 'manager';
  const member = membership(uid, ['site_manager']);
  const actionA = grant(uid, 'action-a', ['site_manager'], ['site-x']);
  assert.equal(canManageOperationLocation(
    access(uid, 'action-a', member, actionA), 'site-x'), true);
  assert.equal(canManageOperationLocation(
    access(uid, 'action-a', member, actionA), 'site-y'), false);
  assert.equal(canManageOperationLocation(
    access(uid, 'action-b', member, actionA), 'site-x'), false);
});

test('inactive, malformed, or role-mismatched grants are closed', () => {
  const uid = 'manager';
  const member = membership(uid, ['site_manager']);
  const scoped = grant(uid, 'action-a', ['site_manager'], ['site-x']);
  for (const bad of [{...scoped, active: false},
    {...scoped, uid: 'other'}, {...scoped, locationIds: []},
    {...scoped, roles: ['coordinator']}]) {
    assert.equal(canManageOperationLocation(
      access(uid, 'action-a', member, bad), 'site-x'), false);
  }
});
