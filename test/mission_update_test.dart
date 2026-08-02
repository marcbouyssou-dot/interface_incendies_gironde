import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

void main() {
  CoordinationNeed mission(
    ResponsePlace location, {
    int required = 2,
    int registered = 1,
  }) => CoordinationNeed(
    id: 'mission-edit',
    locationId: location.id,
    place: location.name,
    group: location.group,
    date: '03/08/2026',
    time: '08:00 — 12:00',
    startAt: DateTime(2026, 8, 3, 8),
    endAt: DateTime(2026, 8, 3, 12),
    requiredPhysiotherapists: required,
    registeredPhysiotherapists: registered,
    requiredPodiatrists: 0,
    registeredPodiatrists: 0,
    equipment: const ['Tables'],
    details: 'Avant',
    createdBy: 'original-creator',
  );

  MissionDraft draft(ResponsePlace location, {int required = 3}) =>
      MissionDraft(
        location: location,
        startAt: DateTime(2026, 8, 4, 9),
        endAt: DateTime(2026, 8, 4, 13),
        requiredByProfession: {
          'physiotherapist': required,
          'podiatrist': 0,
          'physician': 0,
          'nurse': 0,
          'veterinarian': 0,
          'other_health_professional': 0,
        },
        equipment: const ['Serviettes'],
        details: 'Après',
      );

  test(
    'Mock update preserves counters and emits the changed mission',
    () async {
      final source = places.first;
      final destination = places
          .where(
            (location) => location.id != source.id && location.isOperational,
          )
          .first;
      final repository = MockCoordinationRepository(
        initialMissions: [mission(source)],
        initialLocations: [source, destination],
      );
      final emissions = <List<CoordinationNeed>>[];
      final subscription = repository.watchMissions().listen(emissions.add);

      await repository.updateMission('mission-edit', draft(destination));
      await Future<void>.delayed(Duration.zero);

      final updated = repository.debugMission('mission-edit')!;
      expect(updated.locationId, destination.id);
      expect(updated.place, destination.name);
      expect(updated.registeredPhysiotherapists, 1);
      expect(updated.requiredPhysiotherapists, 3);
      expect(updated.createdBy, 'original-creator');
      expect(updated.details, 'Après');
      expect(emissions.last.single.locationId, destination.id);
      await subscription.cancel();
    },
  );

  test(
    'Mock site manager must own current and destination locations',
    () async {
      final source = places.first;
      final destination = places
          .where(
            (location) => location.id != source.id && location.isOperational,
          )
          .first;
      for (final allowed in [
        {source.id},
        {destination.id},
      ]) {
        final repository = MockCoordinationRepository(
          initialMissions: [mission(source)],
          initialLocations: [source, destination],
          responsibleAccess: ResponsibleAccess.v2(
            uid: 'manager',
            roles: const ['site_manager'],
            locationIds: allowed,
            active: true,
          ),
        );
        await expectLater(
          repository.updateMission('mission-edit', draft(destination)),
          throwsA(
            isA<RepositoryException>().having(
              (error) => error.message,
              'message',
              'Vous ne pouvez modifier que les missions de vos centres.',
            ),
          ),
        );
        expect(repository.debugMission('mission-edit')!.locationId, source.id);
      }
    },
  );

  test('Mock refuses quotas below counters or confirmed engagements', () async {
    final location = places.first;
    final repository = MockCoordinationRepository(
      initialMissions: [mission(location, registered: 1)],
      initialLocations: [location],
      initialEngagements: const [
        EngagementInfo(
          missionId: 'mission-edit',
          volunteerId: 'volunteer-1',
          profession: VolunteerProfession.mk,
          status: EngagementStatus.confirmed,
        ),
        EngagementInfo(
          missionId: 'mission-edit',
          volunteerId: 'volunteer-2',
          profession: VolunteerProfession.mk,
          status: EngagementStatus.confirmed,
        ),
      ],
    );
    await expectLater(
      repository.updateMission('mission-edit', draft(location, required: 1)),
      throwsA(isA<RepositoryException>()),
    );
    expect(
      repository.debugMission('mission-edit')!.requiredPhysiotherapists,
      2,
    );
  });

  test('Mock preserves an inactive historical location', () async {
    final historical = places.first;
    final inactive = ResponsePlace(
      id: historical.id,
      name: historical.name,
      type: historical.type,
      group: historical.group,
      activeNeeds: historical.activeNeeds,
      isOperational: false,
      isEnabled: false,
    );
    final repository = MockCoordinationRepository(
      initialMissions: [mission(inactive)],
      initialLocations: [inactive],
    );

    await repository.updateMission('mission-edit', draft(inactive));

    expect(repository.debugMission('mission-edit')!.locationId, inactive.id);
  });
}
