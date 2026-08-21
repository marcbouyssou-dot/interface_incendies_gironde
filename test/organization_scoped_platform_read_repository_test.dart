import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/organization.dart';
import 'package:interface_incendies_gironde/models/organization_category.dart';
import 'package:interface_incendies_gironde/models/organization_context.dart';
import 'package:interface_incendies_gironde/models/organization_membership.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/models/organization_visibility.dart';
import 'package:interface_incendies_gironde/models/territory.dart';
import 'package:interface_incendies_gironde/repositories/operation_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_scoped_operation_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_scoped_platform_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_read_repository.dart';
import 'package:interface_incendies_gironde/services/legacy_organization_resolver.dart';

void main() {
  group('OrganizationScopedPlatformReadRepository', () {
    test(
      'legacy sees Gironde-linked and unlinked legacy mobilizations',
      () async {
        final fixture = _Fixture()..selectLegacy();
        addTearDown(fixture.dispose);

        expect(await fixture.visibleMobilizationIds(), [
          'mobilization-gironde',
          'mobilization-legacy',
        ]);
      },
    );

    test(
      'test organization sees only mobilizations linked to its operation',
      () async {
        final fixture = _Fixture()..selectTestOrganization();
        addTearDown(fixture.dispose);

        expect(await fixture.visibleMobilizationIds(), ['mobilization-test']);
        expect(
          await fixture.repository.watchActiveMobilization().first,
          fixture.testMobilization,
        );
        expect(
          await fixture.repository.watchPlatformConfig().first,
          'mobilization-test',
        );
      },
    );

    test(
      'legacy excludes an active mobilization owned by test organization',
      () async {
        final fixture = _Fixture()..selectLegacy();
        addTearDown(fixture.dispose);

        expect(
          await fixture.repository.watchActiveMobilization().first,
          isNull,
        );
        expect(await fixture.repository.watchPlatformConfig().first, isNull);
      },
    );

    test(
      'global platform admin keeps the complete mobilization projection',
      () async {
        final fixture = _Fixture()..selectGlobalPlatformAdmin();
        addTearDown(fixture.dispose);

        expect(await fixture.visibleMobilizationIds(), [
          'mobilization-gironde',
          'mobilization-test',
          'mobilization-legacy',
        ]);
        expect(
          await fixture.repository.watchActiveMobilization().first,
          fixture.testMobilization,
        );
      },
    );

    test(
      'contextualized platform admin is bounded to selected organization',
      () async {
        final fixture = _Fixture()..selectTestPlatformAdmin();
        addTearDown(fixture.dispose);

        expect(await fixture.visibleMobilizationIds(), ['mobilization-test']);

        fixture.selectLegacyPlatformAdmin();
        expect(await fixture.visibleMobilizationIds(), [
          'mobilization-gironde',
          'mobilization-legacy',
        ]);
      },
    );

    test('absent or inactive context performs no mobilization read', () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);

      expect(await fixture.visibleMobilizationIds(), isEmpty);
      expect(fixture.platformDataSource.listReads, 0);

      fixture.selectInactiveTestMembership();
      expect(await fixture.visibleMobilizationIds(), isEmpty);
      expect(await fixture.repository.watchActiveMobilization().first, isNull);
      expect(fixture.platformDataSource.listReads, 0);
      expect(fixture.platformDataSource.activeReads, 0);
    });

    test(
      'dynamic context change never emits cross-organization data',
      () async {
        final fixture = _Fixture()..selectLegacy();
        addTearDown(fixture.dispose);
        final emissions = <List<String>>[];
        final subscription = fixture.repository
            .watchMobilizations(includeInactive: true)
            .listen(
              (mobilizations) => emissions.add(
                mobilizations.map((mobilization) => mobilization.id).toList(),
              ),
            );
        addTearDown(subscription.cancel);
        await _flushStreams();

        fixture.selectTestOrganization();
        await _flushStreams();

        expect(emissions, [
          ['mobilization-gironde', 'mobilization-legacy'],
          ['mobilization-test'],
        ]);
      },
    );

    test(
      'territory and lifecycle filters are forwarded before projection',
      () async {
        final fixture = _Fixture()..selectLegacy();
        addTearDown(fixture.dispose);

        await fixture.repository
            .watchMobilizations(territoryId: 'gironde', includeInactive: true)
            .first;

        expect(fixture.platformDataSource.lastTerritoryId, 'gironde');
        expect(fixture.platformDataSource.lastIncludeInactive, isTrue);
      },
    );
  });
}

class _Fixture {
  _Fixture()
    : context = ValueNotifier<OrganizationContext?>(null),
      operationDataSource = _OperationRepository(_operations()),
      platformDataSource = _PlatformRepository(_mobilizations()) {
    operationRepository = OrganizationScopedOperationReadRepository(
      delegate: operationDataSource,
      context: context,
    );
    repository = OrganizationScopedPlatformReadRepository(
      delegate: platformDataSource,
      operationRepository: operationRepository,
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
  final _OperationRepository operationDataSource;
  final _PlatformRepository platformDataSource;
  late final OrganizationScopedOperationReadRepository operationRepository;
  late final OrganizationScopedPlatformReadRepository repository;

  Mobilization get testMobilization => platformDataSource.mobilizations
      .firstWhere((mobilization) => mobilization.id == 'mobilization-test');

  void selectLegacy() {
    context.value = resolver.resolveContext(
      uid: 'legacy-coordinator',
      selectedOrganization: LegacyOrganizationResolver.legacyOrganization,
      legacyRoleValues: const ['coordinator'],
    );
  }

  void selectTestOrganization() {
    context.value = resolver.resolveContext(
      uid: 'test-user',
      selectedOrganization: testOrganization,
      membership: _membership(active: true),
    );
  }

  void selectInactiveTestMembership() {
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
    context.value = resolver.resolveContext(
      uid: 'platform-admin',
      selectedOrganization: testOrganization,
      isPlatformAdministrator: true,
    );
  }

  void selectLegacyPlatformAdmin() {
    context.value = resolver.resolveContext(
      uid: 'platform-admin',
      selectedOrganization: LegacyOrganizationResolver.legacyOrganization,
      isPlatformAdministrator: true,
    );
  }

  Future<List<String>> visibleMobilizationIds() => repository
      .watchMobilizations(includeInactive: true)
      .first
      .then(
        (mobilizations) => mobilizations
            .map((mobilization) => mobilization.id)
            .toList(growable: false),
      );

  void dispose() => context.dispose();
}

class _OperationRepository implements OperationReadRepository {
  const _OperationRepository(this.operations);

  final List<Operation> operations;

  @override
  Stream<Operation?> watchOperation(String operationId) => Stream.value(
    operations.where((operation) => operation.id == operationId).firstOrNull,
  );

  @override
  Stream<List<Operation>> watchOperations({Set<OperationStatus>? statuses}) =>
      Stream.value(
        operations
            .where(
              (operation) =>
                  statuses == null || statuses.contains(operation.status),
            )
            .toList(growable: false),
      );
}

class _PlatformRepository implements PlatformReadRepository {
  _PlatformRepository(this.mobilizations);

  final List<Mobilization> mobilizations;
  int listReads = 0;
  int activeReads = 0;
  String? lastTerritoryId;
  bool? lastIncludeInactive;

  @override
  Stream<Mobilization?> watchActiveMobilization() {
    activeReads++;
    return Stream.value(
      mobilizations.firstWhere(
        (mobilization) => mobilization.id == 'mobilization-test',
      ),
    );
  }

  @override
  Stream<List<Mobilization>> watchMobilizations({
    String? territoryId,
    bool includeInactive = false,
  }) {
    listReads++;
    lastTerritoryId = territoryId;
    lastIncludeInactive = includeInactive;
    return Stream.value(
      mobilizations
          .where(
            (mobilization) =>
                (territoryId == null ||
                    mobilization.territoryId == territoryId) &&
                (includeInactive ||
                    mobilization.status == MobilizationStatus.active),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<String?> watchPlatformConfig() => Stream.value('mobilization-test');

  @override
  Stream<List<Territory>> watchTerritories() => Stream.value(const []);
}

List<Operation> _operations() => [
  _operation(id: 'operation-gironde', ownerOrganizationId: 'legacy-gironde'),
  _operation(id: 'operation-test', ownerOrganizationId: 'test-organization'),
];

List<Mobilization> _mobilizations() => [
  _mobilization(id: 'mobilization-gironde', operationId: 'operation-gironde'),
  _mobilization(id: 'mobilization-test', operationId: 'operation-test'),
  _mobilization(id: 'mobilization-legacy'),
];

Operation _operation({
  required String id,
  required String ownerOrganizationId,
}) => Operation.fromMap({
  'id': id,
  'name': 'Opération $id',
  'type': 'exercise',
  'status': 'active',
  'context': null,
  'startAt': DateTime.utc(2026, 8, 21),
  'endAt': null,
  'ownerOrganizationId': ownerOrganizationId,
  'scopeRefs': <Object?>['territories/gironde'],
  'createdBy': 'test',
  'createdAt': DateTime.utc(2026, 8, 21),
  'updatedBy': 'test',
  'updatedAt': DateTime.utc(2026, 8, 21),
  'schemaVersion': 3,
});

Mobilization _mobilization({required String id, String? operationId}) =>
    Mobilization.fromMap({
      'id': id,
      'territoryId': 'gironde',
      'name': 'Mobilisation $id',
      'subtitle': 'Test RC4.2D',
      'contextType': 'other',
      'status': 'active',
      'createdBy': 'test',
      'createdAt': DateTime.utc(2026, 8, 21),
      'updatedAt': DateTime.utc(2026, 8, 21),
      'schemaVersion': operationId == null ? 1 : 2,
      'operationId': ?operationId,
      if (operationId != null) 'scopeRefs': <Object?>['territories/gironde'],
    });

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
