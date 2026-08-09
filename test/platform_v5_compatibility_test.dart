import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/firestore_mission_mapper.dart';

void main() {
  test('legacy mission data remains readable without a mobilization id', () {
    final mission = FirestoreMissionMapper.fromFirestore(
      id: 'legacy-mission',
      data: const {
        'place': 'Centre historique',
        'group': 'bordeauxMetropole',
        'date': '9 août',
        'time': '08:00 — 12:00',
        'requiredMk': 2,
        'registeredMk': 1,
        'requiredPp': 1,
        'registeredPp': 0,
        'equipment': ['Tables'],
      },
    );

    expect(mission.id, 'legacy-mission');
    expect(mission.place, 'Centre historique');
    expect(mission.group, TerritorialGroup.bordeauxMetropole);
    expect(mission.requiredPeople, 3);
    expect(mission.registeredPeople, 1);
    expect(mission.isActive, isTrue);
  });

  test('legacy engagement identity remains mission and volunteer based', () {
    const engagement = EngagementInfo(
      missionId: 'legacy-mission',
      volunteerId: 'volunteer-uid',
      profession: VolunteerProfession.mk,
    );

    expect(engagement.documentId, 'legacy-mission_volunteer-uid');
    expect(engagement.status, EngagementStatus.confirmed);
  });
}
