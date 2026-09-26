import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/dev/role_preview.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/organization.dart';
import 'package:interface_incendies_gironde/models/organization_category.dart';
import 'package:interface_incendies_gironde/models/organization_context.dart';
import 'package:interface_incendies_gironde/models/organization_visibility.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/firestore_platform_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/operation_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_scoped_mission_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_scoped_operation_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_scoped_platform_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/coordinator_shell.dart';
import 'package:interface_incendies_gironde/services/accessible_mobilizations_provider.dart';
import 'package:interface_incendies_gironde/services/legacy_organization_resolver.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';

const _unavailable = 'Le cockpit opérationnel est temporairement indisponible.';

/// Firestore snapshot listeners never complete on their own.
Stream<T> _live<T>(T value) => Stream<T>.multi((controller) {
  controller.add(value);
});

FirebaseException _permissionDenied() => FirebaseException(
  plugin: 'cloud_firestore',
  code: 'permission-denied',
  message: 'Missing or insufficient permissions.',
);

/// Mimics the Firestore rules for an assigned Coordinator: `get` is allowed
/// on assigned mobilizations, the collection-wide `list` is always refused.
class _RulesLikeDataSource implements PlatformReadDataSource {
  _RulesLikeDataSource({required this.readableIds, this.failingIds = const {}});

  final Set<String> readableIds;
  final Set<String> failingIds;
  int listCalls = 0;
  final List<String> gets = [];

  @override
  Stream<List<PlatformReadDocument>> watchMobilizationDocuments({
    String? territoryId,
    required bool includeInactive,
  }) {
    listCalls++;
    return Stream.error(_permissionDenied());
  }

  @override
  Stream<PlatformReadDocument?> watchMobilizationDocument(String id) {
    gets.add(id);
    if (failingIds.contains(id)) return Stream.error(StateError('boom'));
    if (!readableIds.contains(id)) return Stream.error(_permissionDenied());
    return _live(
      PlatformReadDocument(
        id: id,
        data: _mobilizations().firstWhere((item) => item.id == id).toMap(),
      ),
    );
  }

  @override
  Stream<Map<String, Object?>?> watchPlatformConfigDocument() =>
      _live<Map<String, Object?>?>({
        'activeMobilizationId': 'mobilization-legacy',
      });

  @override
  Stream<List<PlatformReadDocument>> watchTerritoryDocuments() =>
      Stream.value(const []);
}

class _MissionSource
    implements
        MultiMobilizationCoordinationReadRepository,
        MobilizationLocationMissionReadRepository {
  final List<Set<String>> requestedMobilizationIds = [];
  int reads = 0;

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> mobilizationIds,
  ) {
    reads++;
    requestedMobilizationIds.add(Set.unmodifiable(mobilizationIds));
    return Stream.value(
      _missions()
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
    return Stream.value(
      _missions()
          .where(
            (mission) =>
                mobilizationIds.contains(mission.mobilizationId) &&
                locationIds.contains(mission.locationId),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForLocations(
    Set<String> locationIds,
  ) => throw UnsupportedError('Not used: mobilization IDs only.');

  @override
  Stream<List<CoordinationNeed>> watchAllActiveMissions() {
    reads++;
    return Stream.value(_missions());
  }
}

class _Operations implements OperationReadRepository {
  @override
  Stream<Operation?> watchOperation(String operationId) => Stream.value(
    _operations().where((item) => item.id == operationId).firstOrNull,
  );

  @override
  Stream<List<Operation>> watchOperations({Set<OperationStatus>? statuses}) =>
      Stream.value(_operations());
}

class _Fixture {
  _Fixture({
    Set<String> readableIds = const {
      'mobilization-gironde',
      'mobilization-legacy',
      'mobilization-test',
    },
    Set<String> failingIds = const {},
  }) : dataSource = _RulesLikeDataSource(
         readableIds: readableIds,
         failingIds: failingIds,
       ) {
    final platform = OrganizationScopedPlatformReadRepository(
      delegate: FirestorePlatformReadRepository(dataSource: dataSource),
      operationRepository: OrganizationScopedOperationReadRepository(
        delegate: _Operations(),
        context: context,
      ),
      context: context,
    );
    platformRepository = platform;
    repository = OrganizationScopedMissionReadRepository(
      delegate: missions,
      platformRepository: platform,
      missionLookup: (id) async =>
          _missions().where((item) => item.id == id).firstOrNull,
    );
  }

  static const resolver = LegacyOrganizationResolver();
  final context = ValueNotifier<OrganizationContext?>(null);
  final _MissionSource missions = _MissionSource();
  final _RulesLikeDataSource dataSource;
  late final OrganizationScopedPlatformReadRepository platformRepository;
  late final OrganizationScopedMissionReadRepository repository;

  void selectLegacyCoordinator() {
    context.value = resolver.resolveContext(
      uid: 'legacy-coordinator',
      selectedOrganization: LegacyOrganizationResolver.legacyOrganization,
      legacyRoleValues: const ['coordinator'],
    );
  }

  void selectLegacySiteManager() {
    context.value = resolver.resolveContext(
      uid: 'legacy-manager',
      selectedOrganization: LegacyOrganizationResolver.legacyOrganization,
      legacyRoleValues: const ['site_manager'],
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
      selectedOrganization: Organization(
        id: 'test-organization',
        name: 'Organisation de test',
        category: OrganizationCategory.other,
        defaultVisibility: OrganizationVisibility.organizationPrivate,
        active: true,
        createdAt: DateTime.utc(2026, 8, 21),
        updatedAt: DateTime.utc(2026, 8, 21),
        schemaVersion: 1,
      ),
      isPlatformAdministrator: true,
    );
  }

  Future<List<String>> missionIds(Set<String> mobilizationIds) => repository
      .watchMissionsForMobilizations(mobilizationIds)
      .first
      .then((items) => items.map((item) => item.id).toList(growable: false));

  void dispose() => context.dispose();
}

void main() {
  group(
    'watchMissionsForMobilizations without a global mobilizations list',
    () {
      test(
        'works even though listing mobilizations is permission-denied',
        () async {
          final fixture = _Fixture()..selectLegacyCoordinator();
          addTearDown(fixture.dispose);

          expect(await fixture.missionIds({'mobilization-gironde'}), [
            'mission-gironde',
          ]);
          expect(fixture.dataSource.listCalls, 0);
          expect(fixture.dataSource.gets, ['mobilization-gironde']);
        },
      );

      test(
        'assigned coordinator: unit get allowed, missions of both IDs read',
        () async {
          final fixture = _Fixture()..selectLegacyCoordinator();
          addTearDown(fixture.dispose);

          expect(
            await fixture.missionIds({
              'mobilization-gironde',
              'mobilization-legacy',
            }),
            ['mission-gironde', 'mission-legacy'],
          );
          expect(fixture.missions.requestedMobilizationIds.single, {
            'mobilization-gironde',
            'mobilization-legacy',
          });
          expect(fixture.dataSource.listCalls, 0);
        },
      );

      test(
        'a mobilization the rules refuse is excluded, not a global failure',
        () async {
          final fixture = _Fixture(
            readableIds: {'mobilization-gironde', 'mobilization-legacy'},
          )..selectLegacyCoordinator();
          addTearDown(fixture.dispose);

          final ids = await fixture.missionIds({
            'mobilization-gironde',
            'mobilization-forbidden',
          });

          expect(ids, ['mission-gironde']);
          expect(fixture.missions.requestedMobilizationIds.single, {
            'mobilization-gironde',
          });
        },
      );

      test(
        'only refused mobilizations: empty result and no mission read',
        () async {
          final fixture = _Fixture(readableIds: const {})
            ..selectLegacyCoordinator();
          addTearDown(fixture.dispose);

          expect(await fixture.missionIds({'mobilization-gironde'}), isEmpty);
          expect(fixture.missions.reads, 0);
        },
      );

      test(
        'a readable mobilization of another organization stays excluded',
        () async {
          final fixture = _Fixture()..selectLegacyCoordinator();
          addTearDown(fixture.dispose);

          final ids = await fixture.missionIds({
            'mobilization-gironde',
            'mobilization-test',
          });

          expect(ids, ['mission-gironde']);
          expect(fixture.missions.requestedMobilizationIds.single, {
            'mobilization-gironde',
          });
        },
      );

      test('a non-permission failure is not swallowed', () async {
        final fixture = _Fixture(failingIds: {'mobilization-gironde'})
          ..selectLegacyCoordinator();
        addTearDown(fixture.dispose);

        await expectLater(
          fixture.repository.watchMissionsForMobilizations({
            'mobilization-gironde',
          }),
          emitsError(isA<StateError>()),
        );
      });

      test('no context: nothing is read', () async {
        final fixture = _Fixture();
        addTearDown(fixture.dispose);

        expect(await fixture.missionIds({'mobilization-gironde'}), isEmpty);
        expect(fixture.missions.reads, 0);
      });

      test(
        'site manager keeps its bounded location read (non-regression)',
        () async {
          final fixture = _Fixture()..selectLegacySiteManager();
          addTearDown(fixture.dispose);

          final missions = await fixture.repository.watchMissionsForLocations({
            'location-legacy',
          }).first;

          expect(missions.map((mission) => mission.id), ['mission-legacy']);
          expect(fixture.dataSource.listCalls, 0);
        },
      );

      test(
        'global platform admin keeps every requested mobilization',
        () async {
          final fixture = _Fixture()..selectGlobalPlatformAdmin();
          addTearDown(fixture.dispose);

          expect(
            await fixture.missionIds({
              'mobilization-gironde',
              'mobilization-test',
            }),
            ['mission-gironde', 'mission-test'],
          );
        },
      );

      test(
        'contextualized platform admin stays limited to its organization',
        () async {
          final fixture = _Fixture()..selectTestPlatformAdmin();
          addTearDown(fixture.dispose);

          expect(
            await fixture.missionIds({
              'mobilization-gironde',
              'mobilization-test',
            }),
            ['mission-test'],
          );
        },
      );
    },
  );

  group('Cockpit Coordinateur — real shell', () {
    Future<void> pumpShell(
      WidgetTester tester, {
      required OrganizationScopedMissionReadRepository repository,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final mock = MockCoordinationRepository(initialLocations: places);
      await tester.pumpWidget(
        RepositoryScope(
          repository: mock,
          child: LiveCoordinationDataScope(
            data: LiveCoordinationData(mock),
            child: RolePreviewScope(
              child: MaterialApp(
                theme: AppTheme.light,
                home: CoordinatorShell(
                  accessibleMobilizationsProvider: _Provider(),
                  multiMobilizationRepository: repository,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'Cockpit → Territoire → Cockpit never shows the unavailable message',
      (tester) async {
        final fixture = _Fixture()..selectLegacyCoordinator();
        addTearDown(fixture.dispose);
        await pumpShell(tester, repository: fixture.repository);

        expect(find.text(_unavailable), findsNothing);
        expect(fixture.dataSource.listCalls, 0);

        await tester.tap(find.text('Territoire'));
        await tester.pumpAndSettle();
        expect(find.text(_unavailable), findsNothing);

        await tester.tap(find.text('Cockpit'));
        await tester.pumpAndSettle();
        expect(find.text(_unavailable), findsNothing);
        expect(fixture.dataSource.listCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _Provider implements AccessibleMobilizationsProvider {
  @override
  Stream<List<Mobilization>> watchAccessibleMobilizations() {
    final controller = StreamController<List<Mobilization>>();
    controller.onListen = () => controller.add([_mobilizations().first]);
    return controller.stream;
  }
}

List<Operation> _operations() => [
  _operation(id: 'operation-gironde', owner: 'legacy-gironde'),
  _operation(id: 'operation-test', owner: 'test-organization'),
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

List<Mobilization> _mobilizations() => [
  _mobilization(id: 'mobilization-gironde', operationId: 'operation-gironde'),
  _mobilization(id: 'mobilization-test', operationId: 'operation-test'),
  _mobilization(id: 'mobilization-legacy'),
];

Mobilization _mobilization({required String id, String? operationId}) =>
    Mobilization.fromMap({
      'id': id,
      'territoryId': 'gironde',
      'name': 'Mobilisation $id',
      'subtitle': 'Test',
      'contextType': 'other',
      'status': 'active',
      'createdBy': 'test',
      'createdAt': DateTime.utc(2026, 8, 21),
      'updatedAt': DateTime.utc(2026, 8, 21),
      'schemaVersion': operationId == null ? 1 : 2,
      'operationId': ?operationId,
      if (operationId != null) 'scopeRefs': <Object?>['territories/gironde'],
    });

List<CoordinationNeed> _missions() => [
  _mission('mission-gironde', 'mobilization-gironde', 'location-gironde'),
  _mission('mission-test', 'mobilization-test', 'location-test'),
  _mission('mission-legacy', 'mobilization-legacy', 'location-legacy'),
];

CoordinationNeed _mission(
  String id,
  String mobilizationId,
  String locationId,
) => CoordinationNeed(
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
