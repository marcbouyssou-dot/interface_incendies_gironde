import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/organization.dart';
import 'package:interface_incendies_gironde/models/organization_category.dart';
import 'package:interface_incendies_gironde/models/organization_context.dart';
import 'package:interface_incendies_gironde/models/organization_membership.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/models/organization_visibility.dart';
import 'package:interface_incendies_gironde/models/territory.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/operation_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_scoped_mission_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_scoped_operation_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_scoped_platform_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_read_repository.dart';
import 'package:interface_incendies_gironde/services/legacy_organization_resolver.dart';

void main() {
  group('OrganizationScopedMissionReadRepository', () {
    test('legacy exposes Gironde and unlinked legacy missions', () async {
      final fixture = _Fixture()..selectLegacy();
      addTearDown(fixture.dispose);

      expect(await fixture.visibleMissionIds(), [
        'mission-gironde',
        'mission-legacy',
      ]);
      expect(fixture.missionDataSource.reads, 1);
    });

    test('test organization exposes only its linked mission', () async {
      final fixture = _Fixture()..selectTestOrganization();
      addTearDown(fixture.dispose);

      expect(await fixture.visibleMissionIds(), ['mission-test']);
      expect(fixture.missionDataSource.reads, 1);
    });

    test(
      'requested mobilizations are intersected before mission read',
      () async {
        final fixture = _Fixture()..selectLegacy();
        addTearDown(fixture.dispose);

        final missions = await fixture.repository.watchMissionsForMobilizations(
          {'mobilization-gironde', 'mobilization-test'},
        ).first;

        expect(missions.map((mission) => mission.id), ['mission-gironde']);
        expect(fixture.missionDataSource.requestedMobilizationIds.single, {
          'mobilization-gironde',
        });
      },
    );

    test('global platform admin keeps all missions', () async {
      final fixture = _Fixture()..selectGlobalPlatformAdmin();
      addTearDown(fixture.dispose);

      expect(await fixture.visibleMissionIds(), [
        'mission-gironde',
        'mission-test',
        'mission-legacy',
      ]);
    });

    test('contextualized platform admin is limited to selected org', () async {
      final fixture = _Fixture()..selectTestPlatformAdmin();
      addTearDown(fixture.dispose);

      expect(await fixture.visibleMissionIds(), ['mission-test']);

      fixture.selectLegacyPlatformAdmin();
      expect(await fixture.visibleMissionIds(), [
        'mission-gironde',
        'mission-legacy',
      ]);
    });

    test('absent or inactive context does not start a mission read', () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);

      expect(await fixture.visibleMissionIds(), isEmpty);
      expect(fixture.missionDataSource.reads, 0);

      fixture.selectInactiveTestMembership();
      expect(await fixture.visibleMissionIds(), isEmpty);
      expect(fixture.missionDataSource.reads, 0);
    });

    test('dynamic context change never emits a cross-org mission', () async {
      final fixture = _Fixture()..selectLegacy();
      addTearDown(fixture.dispose);
      final emissions = <List<String>>[];
      final subscription = fixture.repository.watchAllActiveMissions().listen(
        (missions) => emissions.add(
          missions.map((mission) => mission.id).toList(growable: false),
        ),
      );
      addTearDown(subscription.cancel);
      await _flushStreams();

      fixture.selectTestOrganization();
      await _flushStreams();

      expect(emissions, [
        ['mission-gironde', 'mission-legacy'],
        ['mission-test'],
      ]);
    });

    test(
      'targeted mission access uses one unit lookup and no mission list',
      () async {
        final fixture = _Fixture()..selectLegacy();
        addTearDown(fixture.dispose);

        final mission = await fixture.repository
            .watchAccessibleMission('mission-gironde')
            .first;

        expect(mission?.id, 'mission-gironde');
        expect(fixture.missionDataSource.unitReads, 1);
        expect(fixture.missionDataSource.globalReads, 0);
        expect(fixture.missionDataSource.reads, 0);
        expect(fixture.missionDataSource.requestedMobilizationIds, isEmpty);
      },
    );

    test(
      'targeted mission access fails closed outside the organization',
      () async {
        final fixture = _Fixture()..selectLegacy();
        addTearDown(fixture.dispose);

        final mission = await fixture.repository
            .watchAccessibleMission('mission-test')
            .first;

        expect(mission, isNull);
        expect(fixture.missionDataSource.unitReads, 1);
        expect(fixture.missionDataSource.globalReads, 0);
        expect(fixture.missionDataSource.reads, 0);
      },
    );

    test(
      'legacy mission query is bounded by mobilization and location',
      () async {
        final fixture = _Fixture()
          ..selectLegacySiteManager(withMembership: false);
        addTearDown(fixture.dispose);
        fixture.missionDataSource.missions.add(
          _mission(
            id: 'mission-other-site',
            mobilizationId: 'mobilization-legacy',
            locationId: 'location-other',
          ),
        );

        final missions = await fixture.repository.watchMissionsForLocations({
          'location-legacy',
        }).first;

        expect(missions.map((mission) => mission.id), ['mission-legacy']);
        final scope = fixture
            .missionDataSource
            .requestedMobilizationLocationScopes
            .single;
        expect(scope.mobilizationIds, {'mobilization-legacy'});
        expect(scope.locationIds, {'location-legacy'});
        expect(fixture.missionDataSource.reads, 1);
      },
    );

    test(
      'legacy site manager with membership uses the same bounded read',
      () async {
        final fixture = _Fixture()
          ..selectLegacySiteManager(withMembership: true);
        addTearDown(fixture.dispose);

        final missions = await fixture.repository.watchMissionsForLocations({
          'location-legacy',
        }).first;

        expect(missions.map((mission) => mission.id), ['mission-legacy']);
        final scope = fixture
            .missionDataSource
            .requestedMobilizationLocationScopes
            .single;
        expect(scope.mobilizationIds, {'mobilization-legacy'});
        expect(scope.locationIds, {'location-legacy'});
      },
    );
  });
}

class _Fixture {
  _Fixture()
    : context = ValueNotifier<OrganizationContext?>(null),
      missionDataSource = _MissionRepository(_missions()) {
    final operationRepository = OrganizationScopedOperationReadRepository(
      delegate: _OperationRepository(_operations()),
      context: context,
    );
    final platformRepository = OrganizationScopedPlatformReadRepository(
      delegate: _PlatformRepository(_mobilizations()),
      operationRepository: operationRepository,
      context: context,
    );
    repository = OrganizationScopedMissionReadRepository(
      delegate: missionDataSource,
      platformRepository: platformRepository,
      missionLookup: missionDataSource.getMission,
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
  final _MissionRepository missionDataSource;
  late final OrganizationScopedMissionReadRepository repository;

  void selectLegacy() {
    context.value = resolver.resolveContext(
      uid: 'legacy-coordinator',
      selectedOrganization: LegacyOrganizationResolver.legacyOrganization,
      legacyRoleValues: const ['coordinator'],
    );
  }

  void selectLegacySiteManager({required bool withMembership}) {
    context.value = resolver.resolveContext(
      uid: 'legacy-manager',
      selectedOrganization: LegacyOrganizationResolver.legacyOrganization,
      membership: withMembership ? _legacyMembership() : null,
      legacyRoleValues: withMembership ? const [] : const ['site_manager'],
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

  Future<List<String>> visibleMissionIds() =>
      repository.watchAllActiveMissions().first.then(
        (missions) =>
            missions.map((mission) => mission.id).toList(growable: false),
      );

  void dispose() => context.dispose();
}

class _MissionRepository
    implements
        MultiMobilizationCoordinationReadRepository,
        MobilizationLocationMissionReadRepository {
  _MissionRepository(this.missions);

  final List<CoordinationNeed> missions;
  final List<Set<String>> requestedMobilizationIds = [];
  final List<({Set<String> mobilizationIds, Set<String> locationIds})>
  requestedMobilizationLocationScopes = [];
  int reads = 0;
  int globalReads = 0;
  int unitReads = 0;

  Future<CoordinationNeed?> getMission(String missionId) async {
    unitReads++;
    return missions.where((mission) => mission.id == missionId).firstOrNull;
  }

  @override
  Stream<List<CoordinationNeed>> watchAllActiveMissions() {
    reads++;
    globalReads++;
    return Stream.value(missions);
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForLocations(
    Set<String> locationIds,
  ) {
    throw UnsupportedError('The scoped repository must use mobilization IDs.');
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> mobilizationIds,
  ) {
    reads++;
    requestedMobilizationIds.add(Set.unmodifiable(mobilizationIds));
    return Stream.value(
      missions
          .where((mission) => mobilizationIds.contains(mission.mobilizationId))
          .toList(growable: false),
    );
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizationsAndLocations({
    required Set<String> mobilizationIds,
    required Set<String> locationIds,
  }) {
    reads++;
    requestedMobilizationLocationScopes.add((
      mobilizationIds: Set.unmodifiable(mobilizationIds),
      locationIds: Set.unmodifiable(locationIds),
    ));
    return Stream.value(
      missions
          .where(
            (mission) =>
                mobilizationIds.contains(mission.mobilizationId) &&
                mission.locationId != null &&
                locationIds.contains(mission.locationId),
          )
          .toList(growable: false),
    );
  }
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
  const _PlatformRepository(this.mobilizations);

  final List<Mobilization> mobilizations;

  @override
  Stream<Mobilization?> watchActiveMobilization() => Stream.value(
    mobilizations.firstWhere(
      (mobilization) => mobilization.id == 'mobilization-legacy',
    ),
  );

  @override
  Stream<List<Mobilization>> watchMobilizations({
    String? territoryId,
    bool includeInactive = false,
  }) => Stream.value(
    mobilizations
        .where(
          (mobilization) =>
              includeInactive ||
              mobilization.status == MobilizationStatus.active,
        )
        .toList(growable: false),
  );

  @override
  Stream<String?> watchPlatformConfig() => Stream.value(null);

  @override
  Stream<List<Territory>> watchTerritories() => Stream.value(const []);
}

List<Operation> _operations() => [
  _operation(id: 'operation-gironde', owner: 'legacy-gironde'),
  _operation(id: 'operation-test', owner: 'test-organization'),
];

List<Mobilization> _mobilizations() => [
  _mobilization(id: 'mobilization-gironde', operationId: 'operation-gironde'),
  _mobilization(id: 'mobilization-test', operationId: 'operation-test'),
  _mobilization(id: 'mobilization-legacy'),
];

List<CoordinationNeed> _missions() => [
  _mission(
    id: 'mission-gironde',
    mobilizationId: 'mobilization-gironde',
    locationId: 'location-gironde',
  ),
  _mission(
    id: 'mission-test',
    mobilizationId: 'mobilization-test',
    locationId: 'location-test',
  ),
  _mission(
    id: 'mission-legacy',
    mobilizationId: 'mobilization-legacy',
    locationId: 'location-legacy',
  ),
];

Operation _operation({required String id, required String owner}) =>
    Operation.fromMap({
      'id': id,
      'name': 'Opération $id',
      'type': 'exercise',
      'status': 'active',
      'context': null,
      'startAt': DateTime.utc(2026, 8, 21),
      'endAt': null,
      'ownerOrganizationId': owner,
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
      'subtitle': 'Test RC4.2E',
      'contextType': 'other',
      'status': 'active',
      'createdBy': 'test',
      'createdAt': DateTime.utc(2026, 8, 21),
      'updatedAt': DateTime.utc(2026, 8, 21),
      'schemaVersion': operationId == null ? 1 : 2,
      'operationId': ?operationId,
      if (operationId != null) 'scopeRefs': <Object?>['territories/gironde'],
    });

CoordinationNeed _mission({
  required String id,
  required String mobilizationId,
  required String locationId,
}) => CoordinationNeed(
  id: id,
  place: id,
  group: TerritorialGroup.bordeauxMetropole,
  date: '21 août 2026',
  time: '08:00 — 12:00',
  requiredPhysiotherapists: 1,
  registeredPhysiotherapists: 0,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  equipment: const [],
  mobilizationId: mobilizationId,
  locationId: locationId,
);

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

OrganizationMembership _legacyMembership() => OrganizationMembership(
  organizationId: LegacyOrganizationResolver.legacyOrganizationId,
  uid: 'legacy-manager',
  roles: const {OrganizationRole.siteManager},
  locationIds: const {'location-legacy'},
  active: true,
  createdAt: DateTime.utc(2026, 8, 21),
  updatedAt: DateTime.utc(2026, 8, 21),
  schemaVersion: 1,
);

Future<void> _flushStreams() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
