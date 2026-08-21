import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/organization.dart';
import 'package:interface_incendies_gironde/models/organization_category.dart';
import 'package:interface_incendies_gironde/models/organization_context.dart';
import 'package:interface_incendies_gironde/models/organization_membership.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/models/organization_visibility.dart';
import 'package:interface_incendies_gironde/models/territory.dart';
import 'package:interface_incendies_gironde/repositories/platform_read_repository.dart';
import 'package:interface_incendies_gironde/services/accessible_mobilizations_provider.dart';
import 'package:interface_incendies_gironde/services/legacy_organization_resolver.dart';
import 'package:interface_incendies_gironde/services/organization_scoped_accessible_mobilizations_provider.dart';

void main() {
  test(
    'RC4 coordinator receives only active organization mobilizations',
    () async {
      final context = ValueNotifier<OrganizationContext?>(
        _context(roles: const {OrganizationRole.coordinator}),
      );
      addTearDown(context.dispose);
      final legacy = _LegacyProvider();
      final platform = _PlatformRepository();
      final provider = OrganizationScopedAccessibleMobilizationsProvider(
        legacyDelegate: legacy,
        organizationRepository: platform,
        context: context,
      );

      expect(
        (await provider.watchAccessibleMobilizations().first).map(
          (item) => item.id,
        ),
        ['organization-active'],
      );
      expect(platform.reads, 1);
      expect(legacy.reads, 0);
    },
  );

  test(
    'site manager and inactive coordinator receive no mobilization',
    () async {
      for (final context in [
        _context(roles: const {OrganizationRole.siteManager}),
        _context(roles: const {OrganizationRole.coordinator}, active: false),
      ]) {
        final notifier = ValueNotifier<OrganizationContext?>(context);
        final legacy = _LegacyProvider();
        final platform = _PlatformRepository();
        final provider = OrganizationScopedAccessibleMobilizationsProvider(
          legacyDelegate: legacy,
          organizationRepository: platform,
          context: notifier,
        );

        expect(await provider.watchAccessibleMobilizations().first, isEmpty);
        expect(platform.reads, 0);
        expect(legacy.reads, 0);
        notifier.dispose();
      }
    },
  );

  test('legacy context retains the assignment provider', () async {
    final context = ValueNotifier<OrganizationContext?>(
      const LegacyOrganizationResolver().resolveContext(
        uid: 'legacy-user',
        selectedOrganization: LegacyOrganizationResolver.legacyOrganization,
        legacyRoleValues: const ['coordinator'],
      ),
    );
    addTearDown(context.dispose);
    final legacy = _LegacyProvider();
    final platform = _PlatformRepository();
    final provider = OrganizationScopedAccessibleMobilizationsProvider(
      legacyDelegate: legacy,
      organizationRepository: platform,
      context: context,
    );

    expect(
      (await provider.watchAccessibleMobilizations().first).single.id,
      'legacy-assigned',
    );
    expect(legacy.reads, 1);
    expect(platform.reads, 0);
  });
}

OrganizationContext _context({
  required Set<OrganizationRole> roles,
  bool active = true,
}) {
  final organization = Organization(
    id: 'organization-a',
    name: 'Organisation A',
    category: OrganizationCategory.other,
    defaultVisibility: OrganizationVisibility.organizationPrivate,
    active: true,
    createdAt: DateTime.utc(2026, 8, 21),
    updatedAt: DateTime.utc(2026, 8, 21),
    schemaVersion: 1,
  );
  final membership = OrganizationMembership(
    organizationId: organization.id,
    uid: 'same-user',
    roles: roles,
    locationIds: roles.contains(OrganizationRole.siteManager)
        ? const {'site-a'}
        : const {},
    active: active,
    createdAt: DateTime.utc(2026, 8, 21),
    updatedAt: DateTime.utc(2026, 8, 21),
    schemaVersion: 1,
  );
  return OrganizationContext.selected(
    uid: 'same-user',
    organization: organization,
    membership: membership,
    effectiveRoles: active ? roles : const {},
  );
}

class _LegacyProvider implements AccessibleMobilizationsProvider {
  int reads = 0;

  @override
  Stream<List<Mobilization>> watchAccessibleMobilizations() {
    reads++;
    return Stream.value([_mobilization('legacy-assigned')]);
  }
}

class _PlatformRepository implements PlatformReadRepository {
  int reads = 0;

  @override
  Stream<List<Mobilization>> watchMobilizations({
    String? territoryId,
    bool includeInactive = false,
  }) {
    reads++;
    return Stream.value([
      _mobilization('organization-active'),
      _mobilization('organization-inactive', active: false),
    ]);
  }

  @override
  Stream<Mobilization?> watchActiveMobilization() => Stream.value(null);

  @override
  Stream<String?> watchPlatformConfig() => Stream.value(null);

  @override
  Stream<List<Territory>> watchTerritories() => Stream.value(const []);
}

Mobilization _mobilization(String id, {bool active = true}) => Mobilization(
  id: id,
  territoryId: 'gironde',
  name: id,
  subtitle: id,
  contextType: MobilizationContextType.other,
  status: active ? MobilizationStatus.active : MobilizationStatus.inactive,
  createdBy: 'admin',
  createdAt: DateTime.utc(2026, 8, 21),
  updatedAt: DateTime.utc(2026, 8, 21),
  schemaVersion: 1,
);
