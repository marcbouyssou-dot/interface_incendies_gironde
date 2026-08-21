import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/organization.dart';
import 'package:interface_incendies_gironde/models/organization_category.dart';
import 'package:interface_incendies_gironde/models/organization_context.dart';
import 'package:interface_incendies_gironde/models/organization_membership.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/models/organization_visibility.dart';
import 'package:interface_incendies_gironde/models/responsible_access.dart';
import 'package:interface_incendies_gironde/services/legacy_organization_resolver.dart';
import 'package:interface_incendies_gironde/services/organization_responsible_access_resolver.dart';

void main() {
  const resolver = OrganizationResponsibleAccessResolver();

  test('coordinator A is recognized only in organization A', () {
    final inA = resolver.resolve(
      context: _context(
        organization: _organizationA,
        membership: _membership(
          organizationId: 'organization-a',
          roles: const {
            OrganizationRole.coordinator,
            OrganizationRole.professional,
          },
        ),
      ),
      legacyAccess: null,
    );
    final inB = resolver.resolve(
      context: _context(organization: _organizationB),
      legacyAccess: null,
    );

    expect(inA?.isCoordinator, isTrue);
    expect(inA?.roles, {ResponsibleRole.coordinator});
    expect(inB, isNull);
  });

  test('site manager keeps only the membership location scope', () {
    final access = resolver.resolve(
      context: _context(
        organization: _organizationB,
        membership: _membership(
          organizationId: 'organization-b',
          roles: const {OrganizationRole.siteManager},
          locationIds: const {'site-b'},
        ),
      ),
      legacyAccess: null,
    );

    expect(access?.isSiteManager, isTrue);
    expect(access?.canManage('site-b'), isTrue);
    expect(access?.canManage('site-a'), isFalse);
  });

  test(
    'organization admin plus coordinator stays coordinator, not platform',
    () {
      final access = resolver.resolve(
        context: _context(
          organization: _organizationA,
          membership: _membership(
            organizationId: 'organization-a',
            roles: const {
              OrganizationRole.organizationAdmin,
              OrganizationRole.coordinator,
            },
          ),
        ),
        legacyAccess: null,
      );

      expect(access?.isCoordinator, isTrue);
      expect(access?.roles, {ResponsibleRole.coordinator});
    },
  );

  test('same UID can be coordinator in A and site manager in B', () {
    final inA = resolver.resolve(
      context: _context(
        organization: _organizationA,
        membership: _membership(
          organizationId: 'organization-a',
          roles: const {OrganizationRole.coordinator},
        ),
      ),
      legacyAccess: null,
    );
    final inB = resolver.resolve(
      context: _context(
        organization: _organizationB,
        membership: _membership(
          organizationId: 'organization-b',
          roles: const {OrganizationRole.siteManager},
          locationIds: const {'site-b'},
        ),
      ),
      legacyAccess: null,
    );

    expect(inA?.isCoordinator, isTrue);
    expect(inA?.isSiteManager, isFalse);
    expect(inB?.isCoordinator, isFalse);
    expect(inB?.isSiteManager, isTrue);
  });

  test('inactive or malformed site manager membership fails closed', () {
    final inactive = resolver.resolve(
      context: _context(
        organization: _organizationA,
        membership: _membership(
          organizationId: 'organization-a',
          roles: const {OrganizationRole.coordinator},
          active: false,
        ),
      ),
      legacyAccess: null,
    );
    final emptyScope = resolver.resolve(
      context: _context(
        organization: _organizationA,
        membership: _membership(
          organizationId: 'organization-a',
          roles: const {OrganizationRole.siteManager},
        ),
      ),
      legacyAccess: null,
    );

    expect(inactive, isNull);
    expect(emptyScope, isNull);
  });

  test('legacy role applies only without an explicit membership', () {
    const legacyAccess = ResponsibleAccess(
      uid: 'same-user',
      role: ResponsibleRole.coordinator,
      locationIds: {},
      active: true,
    );
    final fallback = resolver.resolve(
      context: const LegacyOrganizationResolver().resolveContext(
        uid: 'same-user',
        selectedOrganization: LegacyOrganizationResolver.legacyOrganization,
        legacyRoleValues: const [ResponsibleRole.coordinator],
      ),
      legacyAccess: legacyAccess,
    );
    final explicitInactive = resolver.resolve(
      context: _context(
        organization: LegacyOrganizationResolver.legacyOrganization,
        membership: _membership(
          organizationId: LegacyOrganizationResolver.legacyOrganizationId,
          roles: const {OrganizationRole.coordinator},
          active: false,
        ),
        isLegacy: true,
      ),
      legacyAccess: legacyAccess,
    );

    expect(fallback, same(legacyAccess));
    expect(explicitInactive, isNull);
  });
}

final _organizationA = _organization('organization-a');
final _organizationB = _organization('organization-b');

Organization _organization(String id) => Organization(
  id: id,
  name: id,
  category: OrganizationCategory.other,
  defaultVisibility: OrganizationVisibility.organizationPrivate,
  active: true,
  createdAt: DateTime.utc(2026, 8, 21),
  updatedAt: DateTime.utc(2026, 8, 21),
  schemaVersion: 1,
);

OrganizationContext _context({
  required Organization organization,
  OrganizationMembership? membership,
  bool isLegacy = false,
}) => OrganizationContext.selected(
  uid: 'same-user',
  organization: organization,
  membership: membership,
  effectiveRoles: membership?.active == true ? membership!.roles : const {},
  isLegacy: isLegacy,
);

OrganizationMembership _membership({
  required String organizationId,
  required Set<OrganizationRole> roles,
  Set<String> locationIds = const {},
  bool active = true,
}) => OrganizationMembership(
  organizationId: organizationId,
  uid: 'same-user',
  roles: roles,
  locationIds: locationIds,
  active: active,
  createdAt: DateTime.utc(2026, 8, 21),
  updatedAt: DateTime.utc(2026, 8, 21),
  schemaVersion: 1,
);
