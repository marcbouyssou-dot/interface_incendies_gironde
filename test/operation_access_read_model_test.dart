import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/organization.dart';
import 'package:interface_incendies_gironde/models/organization_category.dart';
import 'package:interface_incendies_gironde/models/organization_context.dart';
import 'package:interface_incendies_gironde/models/organization_membership.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/models/organization_visibility.dart';
import 'package:interface_incendies_gironde/repositories/operation_access_read_repository.dart';

void main() {
  test('one site in Action A does not authorize site Y or Action B', () {
    final organization = Organization(
      id: 'org-a',
      name: 'Organisation A',
      category: OrganizationCategory.other,
      defaultVisibility: OrganizationVisibility.organizationPrivate,
      active: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      schemaVersion: 1,
    );
    final membership = OrganizationMembership(
      uid: 'manager',
      organizationId: 'org-a',
      roles: const {OrganizationRole.siteManager},
      locationIds: const {'site-x', 'site-y'},
      active: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      schemaVersion: 1,
    );
    final context = OrganizationContext.selected(
      uid: 'manager',
      organization: organization,
      membership: membership,
      effectiveRoles: const {OrganizationRole.siteManager},
    );
    final scope = OperationAccess.fromMap('action-a_manager', {
      'operationId': 'action-a',
      'organizationId': 'org-a',
      'uid': 'manager',
      'roles': ['site_manager'],
      'locationIds': ['site-x'],
      'active': true,
      'schemaVersion': 1,
    });
    expect(scope.canReadSite(context, 'site-x'), isTrue);
    expect(scope.canReadSite(context, 'site-y'), isFalse);
    expect(scope.operationId, isNot('action-b'));
  });
}
