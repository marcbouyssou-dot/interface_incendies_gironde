import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_scoped_engagement_read_repository.dart';

void main() {
  group('OrganizationScopedEngagementReadRepository', () {
    test('legacy exposes engagements of Gironde and legacy missions', () async {
      final fixture = _Fixture()..selectLegacy();
      addTearDown(fixture.dispose);

      expect(await fixture.volunteerIds('mission-gironde'), [
        'volunteer-gironde',
        'volunteer-pending',
        'volunteer-standby',
        'volunteer-cancelled',
      ]);
      expect(await fixture.volunteerIds('mission-legacy'), [
        'volunteer-legacy',
      ]);
      expect(await fixture.volunteerIds('mission-test'), isEmpty);
    });

    test('test organization excludes Gironde engagements', () async {
      final fixture = _Fixture()..selectTestOrganization();
      addTearDown(fixture.dispose);

      expect(await fixture.volunteerIds('mission-test'), ['volunteer-test']);
      expect(await fixture.volunteerIds('mission-gironde'), isEmpty);
      expect(await fixture.volunteerIds('mission-legacy'), isEmpty);
    });

    test(
      'cancelled engagement and all existing statuses are preserved',
      () async {
        final fixture = _Fixture()..selectLegacy();
        addTearDown(fixture.dispose);

        final engagements = await fixture.repository
            .watchMissionEngagements('mission-gironde')
            .first;

        expect(engagements.map((item) => item.status), [
          EngagementStatus.confirmed,
          EngagementStatus.pending,
          EngagementStatus.standby,
          EngagementStatus.cancelled,
        ]);
      },
    );

    test('global admin can read every accessible mission team', () async {
      final fixture = _Fixture()..selectGlobalAdmin();
      addTearDown(fixture.dispose);

      expect(await fixture.volunteerIds('mission-gironde'), isNotEmpty);
      expect(await fixture.volunteerIds('mission-test'), ['volunteer-test']);
      expect(await fixture.volunteerIds('mission-legacy'), [
        'volunteer-legacy',
      ]);
    });

    test('contextualized admin is limited to the selected org', () async {
      final fixture = _Fixture()..selectTestAdmin();
      addTearDown(fixture.dispose);

      expect(await fixture.volunteerIds('mission-test'), ['volunteer-test']);
      expect(await fixture.volunteerIds('mission-gironde'), isEmpty);

      fixture.selectLegacyAdmin();
      expect(await fixture.volunteerIds('mission-gironde'), isNotEmpty);
      expect(await fixture.volunteerIds('mission-test'), isEmpty);
    });

    test('absent or inactive context starts no engagement read', () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);

      expect(await fixture.volunteerIds('mission-gironde'), isEmpty);
      expect(fixture.engagementDataSource.reads, 0);

      fixture.selectInactive();
      expect(await fixture.volunteerIds('mission-test'), isEmpty);
      expect(fixture.engagementDataSource.reads, 0);
    });

    test(
      'dynamic context change cancels the previous engagement stream',
      () async {
        final fixture = _Fixture()..selectLegacy();
        addTearDown(fixture.dispose);
        final emissions = <List<String>>[];
        final subscription = fixture.repository
            .watchMissionEngagements('mission-gironde')
            .listen(
              (engagements) => emissions.add(
                engagements
                    .map((engagement) => engagement.volunteerId)
                    .toList(growable: false),
              ),
            );
        addTearDown(subscription.cancel);
        await _flushStreams();

        fixture.selectTestOrganization();
        await _flushStreams();

        expect(emissions, [
          [
            'volunteer-gironde',
            'volunteer-pending',
            'volunteer-standby',
            'volunteer-cancelled',
          ],
          <String>[],
        ]);
      },
    );

    test(
      'one mission team uses targeted access and one delegate read',
      () async {
        final fixture = _Fixture()..selectLegacy();
        addTearDown(fixture.dispose);

        await fixture.repository
            .watchMissionEngagements('mission-gironde')
            .first;

        expect(fixture.missionDataSource.listReads, 0);
        expect(fixture.missionDataSource.targetedReads, 1);
        expect(fixture.engagementDataSource.reads, 1);
        expect(fixture.engagementDataSource.requestedMissionIds, [
          'mission-gironde',
        ]);
      },
    );

    test(
      'N mission teams create no subscription to the global mission list',
      () async {
        final fixture = _Fixture()..selectLegacy();
        addTearDown(fixture.dispose);
        final subscriptions =
            ['mission-gironde', 'mission-legacy', 'mission-test']
                .map(
                  (missionId) => fixture.repository
                      .watchMissionEngagements(missionId)
                      .listen((_) {}),
                )
                .toList(growable: false);
        addTearDown(
          () => Future.wait(subscriptions.map((item) => item.cancel())),
        );

        await _flushStreams();

        expect(fixture.missionDataSource.listReads, 0);
        expect(fixture.missionDataSource.targetedReads, 3);
        expect(fixture.missionDataSource.requestedMissionIds, [
          'mission-gironde',
          'mission-legacy',
          'mission-test',
        ]);
        expect(fixture.engagementDataSource.reads, 2);
      },
    );

    test('delegate data for another mission is rejected defensively', () async {
      final fixture = _Fixture()..selectLegacy();
      addTearDown(fixture.dispose);
      fixture.engagementDataSource.injectCrossMissionResult = true;

      final engagements = await fixture.repository
          .watchMissionEngagements('mission-gironde')
          .first;

      expect(
        engagements.every((item) => item.missionId == 'mission-gironde'),
        isTrue,
      );
    });
  });
}

enum _Scope { absent, inactive, legacy, test, global }

class _Fixture {
  _Fixture()
    : scope = ValueNotifier(_Scope.absent),
      engagementDataSource = _EngagementRepository(_engagements()) {
    missionDataSource = _ScopedMissionRepository(scope, _missions());
    repository = OrganizationScopedEngagementReadRepository(
      delegate: engagementDataSource,
      missionRepository: missionDataSource,
    );
  }

  final ValueNotifier<_Scope> scope;
  late final _ScopedMissionRepository missionDataSource;
  final _EngagementRepository engagementDataSource;
  late final OrganizationScopedEngagementReadRepository repository;

  void selectLegacy() => scope.value = _Scope.legacy;
  void selectTestOrganization() => scope.value = _Scope.test;
  void selectGlobalAdmin() => scope.value = _Scope.global;
  void selectTestAdmin() => scope.value = _Scope.test;
  void selectLegacyAdmin() => scope.value = _Scope.legacy;
  void selectInactive() => scope.value = _Scope.inactive;

  Future<List<String>> volunteerIds(String missionId) => repository
      .watchMissionEngagements(missionId)
      .first
      .then(
        (engagements) => engagements
            .map((engagement) => engagement.volunteerId)
            .toList(growable: false),
      );

  void dispose() => scope.dispose();
}

class _ScopedMissionRepository
    implements
        MultiMobilizationCoordinationReadRepository,
        MissionAccessReadRepository {
  _ScopedMissionRepository(this.scope, this.missions);

  final ValueListenable<_Scope> scope;
  final List<CoordinationNeed> missions;
  int listReads = 0;
  int targetedReads = 0;
  final List<String> requestedMissionIds = [];

  @override
  Stream<CoordinationNeed?> watchAccessibleMission(String missionId) {
    targetedReads++;
    requestedMissionIds.add(missionId);
    return Stream<CoordinationNeed?>.multi((controller) {
      void emit() {
        final mission = missions
            .where((item) => item.id == missionId)
            .firstOrNull;
        final isAccessible =
            mission != null &&
            switch (scope.value) {
              _Scope.legacy => mission.id != 'mission-test',
              _Scope.test => mission.id == 'mission-test',
              _Scope.global => true,
              _Scope.absent || _Scope.inactive => false,
            };
        controller.add(isAccessible ? mission : null);
      }

      emit();
      scope.addListener(emit);
      controller.onCancel = () => scope.removeListener(emit);
    });
  }

  @override
  Stream<List<CoordinationNeed>> watchAllActiveMissions() {
    listReads++;
    return Stream<List<CoordinationNeed>>.multi((controller) {
      void emit() => controller.add(
        missions
            .where((mission) {
              return switch (scope.value) {
                _Scope.legacy => mission.id != 'mission-test',
                _Scope.test => mission.id == 'mission-test',
                _Scope.global => true,
                _Scope.absent || _Scope.inactive => false,
              };
            })
            .toList(growable: false),
      );

      emit();
      scope.addListener(emit);
      controller.onCancel = () => scope.removeListener(emit);
    });
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForLocations(
    Set<String> locationIds,
  ) => throw UnsupportedError('Not used by engagement scoping.');

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> mobilizationIds,
  ) => throw UnsupportedError('Not used by engagement scoping.');
}

class _EngagementRepository implements MissionEngagementReadRepository {
  _EngagementRepository(this.engagements);

  final List<EngagementInfo> engagements;
  final List<String> requestedMissionIds = [];
  int reads = 0;
  bool injectCrossMissionResult = false;

  @override
  Stream<List<EngagementInfo>> watchMissionEngagements(String missionId) {
    reads++;
    requestedMissionIds.add(missionId);
    final values = engagements
        .where(
          (engagement) =>
              engagement.missionId == missionId || injectCrossMissionResult,
        )
        .toList(growable: false);
    return Stream.value(values);
  }
}

List<CoordinationNeed> _missions() => [
  _mission('mission-gironde', 'mobilization-gironde'),
  _mission('mission-test', 'mobilization-test'),
  _mission('mission-legacy', 'mobilization-legacy'),
];

List<EngagementInfo> _engagements() => const [
  EngagementInfo(
    missionId: 'mission-gironde',
    volunteerId: 'volunteer-gironde',
    profession: VolunteerProfession.mk,
    status: EngagementStatus.confirmed,
  ),
  EngagementInfo(
    missionId: 'mission-gironde',
    volunteerId: 'volunteer-pending',
    profession: VolunteerProfession.mk,
    status: EngagementStatus.pending,
  ),
  EngagementInfo(
    missionId: 'mission-gironde',
    volunteerId: 'volunteer-standby',
    profession: VolunteerProfession.pp,
    status: EngagementStatus.standby,
  ),
  EngagementInfo(
    missionId: 'mission-gironde',
    volunteerId: 'volunteer-cancelled',
    profession: VolunteerProfession.pp,
    status: EngagementStatus.cancelled,
  ),
  EngagementInfo(
    missionId: 'mission-test',
    volunteerId: 'volunteer-test',
    profession: VolunteerProfession.nurse,
  ),
  EngagementInfo(
    missionId: 'mission-legacy',
    volunteerId: 'volunteer-legacy',
    profession: VolunteerProfession.doctor,
  ),
];

CoordinationNeed _mission(String id, String mobilizationId) => CoordinationNeed(
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
);

Future<void> _flushStreams() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
