import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/organization.dart';
import 'package:interface_incendies_gironde/models/organization_category.dart';
import 'package:interface_incendies_gironde/models/organization_context.dart';
import 'package:interface_incendies_gironde/models/organization_membership.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/models/organization_visibility.dart';
import 'package:interface_incendies_gironde/repositories/location_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_scoped_location_read_repository.dart';
import 'package:interface_incendies_gironde/services/legacy_organization_resolver.dart';

void main() {
  group('OrganizationScopedLocationReadRepository', () {
    test('legacy includes implicit and explicitly Gironde sites', () async {
      final fixture = _Fixture()..selectLegacy(OrganizationRole.coordinator);
      addTearDown(fixture.dispose);

      final locations = await fixture.repository.watchLocations().first;

      expect(locations.map((location) => location.id), [
        'legacy-implicit',
        'legacy-explicit',
      ]);
      expect(() => locations.clear(), throwsUnsupportedError);
      expect(fixture.delegate.reads, 1);
      expect(fixture.delegate.organizationReads, isEmpty);
    });

    test(
      'an explicit organization takes priority over legacy fallback',
      () async {
        final fixture = _Fixture()..selectLegacy(OrganizationRole.siteManager);
        addTearDown(fixture.dispose);

        final locations = await fixture.repository.watchLocations().first;

        expect(
          locations.map((location) => location.id),
          isNot(contains('test')),
        );
        expect(
          const LegacyOrganizationResolver().resolveSiteOrganizationId(
            managingOrganizationId: 'test-organization',
          ),
          'test-organization',
        );
      },
    );

    test(
      'a normal organization sees only its explicitly managed sites',
      () async {
        final fixture = _Fixture()..selectTestOrganization();
        addTearDown(fixture.dispose);

        expect(await fixture.visibleIds(), ['test']);
        expect(fixture.delegate.organizationReads, ['test-organization']);
        expect(fixture.delegate.reads, 0);
      },
    );

    test('global platform admin keeps the complete site projection', () async {
      final fixture = _Fixture()..selectGlobalPlatformAdmin();
      addTearDown(fixture.dispose);

      expect(await fixture.visibleIds(), [
        'legacy-implicit',
        'legacy-explicit',
        'test',
      ]);
      expect(fixture.delegate.administrativeReads, 1);
      expect(fixture.delegate.reads, 0);
    });

    test(
      'contextualized platform admin is bounded to the selected org',
      () async {
        final fixture = _Fixture()..selectTestPlatformAdmin();
        addTearDown(fixture.dispose);

        expect(await fixture.visibleIds(), ['test']);

        fixture.selectLegacyPlatformAdmin();
        expect(await fixture.visibleIds(), [
          'legacy-implicit',
          'legacy-explicit',
        ]);
      },
    );

    test('absent or inactive context performs no location read', () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);

      expect(await fixture.visibleIds(), isEmpty);
      expect(fixture.delegate.reads, 0);

      fixture.selectInactiveMembership();
      expect(await fixture.visibleIds(), isEmpty);
      expect(fixture.delegate.reads, 0);
    });

    test('context changes never emit a cross-organization site', () async {
      final fixture = _Fixture()..selectLegacy(OrganizationRole.coordinator);
      addTearDown(fixture.dispose);
      final emissions = <List<String>>[];
      final subscription = fixture.repository.watchLocations().listen(
        (locations) => emissions.add(
          locations.map((location) => location.id).toList(growable: false),
        ),
      );
      addTearDown(subscription.cancel);
      await _flushStreams();

      fixture.selectTestOrganization();
      await _flushStreams();

      expect(emissions, [
        ['legacy-implicit', 'legacy-explicit'],
        ['test'],
      ]);
    });

    test('coordinator and responsible retain the same legacy sites', () async {
      for (final role in const [
        OrganizationRole.coordinator,
        OrganizationRole.siteManager,
      ]) {
        final fixture = _Fixture()..selectLegacy(role);
        expect(await fixture.visibleIds(), [
          'legacy-implicit',
          'legacy-explicit',
        ]);
        fixture.dispose();
      }
    });

    test('the same scoped stream supports a preview resubscription', () async {
      final fixture = _Fixture()..selectTestPlatformAdmin();
      addTearDown(fixture.dispose);
      final stream = fixture.repository.watchLocations();

      expect((await stream.first).map((location) => location.id), ['test']);
      expect((await stream.first).map((location) => location.id), ['test']);
    });
  });
}

class _Fixture {
  _Fixture()
    : context = ValueNotifier<OrganizationContext?>(null),
      delegate = _LocationRepository(_locations()) {
    repository = OrganizationScopedLocationReadRepository(
      delegate: delegate,
      context: context,
    );
  }

  static const resolver = LegacyOrganizationResolver();
  static final testOrganization = Organization(
    id: 'test-organization',
    name: 'Organisation de test',
    category: OrganizationCategory.other,
    defaultVisibility: OrganizationVisibility.organizationPrivate,
    active: true,
    createdAt: DateTime.utc(2026, 8, 21),
    updatedAt: DateTime.utc(2026, 8, 21),
    schemaVersion: 1,
  );

  final ValueNotifier<OrganizationContext?> context;
  final _LocationRepository delegate;
  late final OrganizationScopedLocationReadRepository repository;

  void selectLegacy(OrganizationRole role) {
    context.value = resolver.resolveContext(
      uid: 'legacy-user',
      selectedOrganization: LegacyOrganizationResolver.legacyOrganization,
      legacyRoleValues: [role.serializedValue],
    );
  }

  void selectTestOrganization() {
    context.value = resolver.resolveContext(
      uid: 'test-user',
      selectedOrganization: testOrganization,
      membership: _membership(active: true),
    );
  }

  void selectInactiveMembership() {
    context.value = resolver.resolveContext(
      uid: 'test-user',
      selectedOrganization: testOrganization,
      membership: _membership(active: false),
    );
  }

  void selectGlobalPlatformAdmin() {
    context.value = OrganizationContext.unselected(
      uid: 'platform-admin',
      isPlatformAdministrator: true,
    );
  }

  void selectTestPlatformAdmin() {
    context.value = OrganizationContext.selected(
      uid: 'platform-admin',
      organization: testOrganization,
      isPlatformAdministrator: true,
    );
  }

  void selectLegacyPlatformAdmin() {
    context.value = OrganizationContext.selected(
      uid: 'platform-admin',
      organization: LegacyOrganizationResolver.legacyOrganization,
      isLegacy: true,
      isPlatformAdministrator: true,
    );
  }

  Future<List<String>> visibleIds() => repository.watchLocations().first.then(
    (locations) =>
        locations.map((location) => location.id).toList(growable: false),
  );

  void dispose() => context.dispose();
}

class _LocationRepository implements OrganizationLocationReadDataSource {
  _LocationRepository(this.locations);

  final List<ResponsePlace> locations;
  int reads = 0;
  int administrativeReads = 0;
  final List<String> organizationReads = [];

  @override
  Stream<List<ResponsePlace>> watchLocations() {
    reads++;
    return Stream.value(locations);
  }

  @override
  Stream<List<ResponsePlace>> watchAllAdministrativeLocations() {
    administrativeReads++;
    return Stream.value(locations);
  }

  @override
  Stream<List<ResponsePlace>> watchLocationsManagedByOrganization(
    String organizationId,
  ) {
    organizationReads.add(organizationId);
    return Stream.value(
      locations
          .where(
            (location) => location.managingOrganizationId == organizationId,
          )
          .toList(growable: false),
    );
  }
}

List<ResponsePlace> _locations() => const [
  ResponsePlace(
    id: 'legacy-implicit',
    name: 'Site RC3',
    type: ResponsePlaceType.sdisStation,
    group: TerritorialGroup.bordeauxMetropole,
    activeNeeds: 0,
  ),
  ResponsePlace(
    id: 'legacy-explicit',
    name: 'Site Gironde explicite',
    type: ResponsePlaceType.sdisStation,
    group: TerritorialGroup.bordeauxMetropole,
    activeNeeds: 0,
    managingOrganizationId: 'legacy-gironde',
  ),
  ResponsePlace(
    id: 'test',
    name: 'Site organisation test',
    type: ResponsePlaceType.otherPartnerSite,
    group: TerritorialGroup.partnerSites,
    activeNeeds: 0,
    managingOrganizationId: 'test-organization',
  ),
];

OrganizationMembership _membership({required bool active}) =>
    OrganizationMembership(
      organizationId: 'test-organization',
      uid: 'test-user',
      roles: const {OrganizationRole.organizationAdmin},
      active: active,
      createdAt: DateTime.utc(2026, 8, 21),
      updatedAt: DateTime.utc(2026, 8, 21),
      schemaVersion: 1,
    );

Future<void> _flushStreams() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
