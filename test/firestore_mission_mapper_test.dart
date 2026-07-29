import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/firestore_mission_mapper.dart';

void main() {
  test('a newly serialized mission can be read by the Firestore parser', () {
    final start = DateTime(2026, 7, 30, 22);
    final end = DateTime(2026, 7, 31, 2);
    final draft = MissionDraft(
      location: places.first,
      startAt: start,
      endAt: end,
      requiredPhysiotherapists: 2,
      requiredPodiatrists: 1,
      equipment: const ['Tables', 'Gels froids'],
      details: 'Entrée nord',
    );

    final data = FirestoreMissionMapper.toFirestore(
      id: 'mission-stable',
      draft: draft,
      serverTimestamp: Timestamp.fromDate(DateTime(2026, 7, 29)),
      createdBy: 'manager-uid',
    );
    final mission = FirestoreMissionMapper.fromFirestore(
      id: 'mission-stable',
      data: data,
    );

    expect(data['startAt'], isA<Timestamp>());
    expect(data['endAt'], isA<Timestamp>());
    expect(data['requiredMk'], 2);
    expect(data['requiredPp'], 1);
    expect(data['registeredMk'], 0);
    expect(data['registeredPp'], 0);
    expect(data['isActive'], isTrue);
    expect(data['createdBy'], 'manager-uid');
    expect(mission.locationId, places.first.id);
    expect(mission.place, places.first.name);
    expect(mission.startAt, start);
    expect(mission.endAt, end);
    expect(mission.time, '22:00 — 02:00');
    expect(mission.requiredPhysiotherapists, 2);
    expect(mission.requiredPodiatrists, 1);
  });

  test('old and cancelled missions parse optional cancellation fields', () {
    final oldMission = FirestoreMissionMapper.fromFirestore(
      id: 'old',
      data: const {
        'locationName': 'Ancien lieu',
        'requiredMk': 1,
        'registeredMk': 0,
        'requiredPp': 0,
        'registeredPp': 0,
      },
    );
    expect(oldMission.isCancelled, isFalse);
    expect(oldMission.cancelledAt, isNull);

    final cancelledAt = DateTime(2026, 7, 29, 10);
    final cancelled = FirestoreMissionMapper.fromFirestore(
      id: 'cancelled',
      data: {
        'locationName': 'Lieu',
        'requiredMk': 1,
        'registeredMk': 1,
        'requiredPp': 0,
        'registeredPp': 0,
        'status': 'cancelled',
        'isActive': false,
        'cancelledAt': Timestamp.fromDate(cancelledAt),
        'cancelledBy': 'manager',
        'cancellationReason': 'Vent violent',
      },
    );
    expect(cancelled.isCancelled, isTrue);
    expect(cancelled.isActive, isFalse);
    expect(cancelled.cancelledAt, cancelledAt);
    expect(cancelled.cancelledBy, 'manager');
    expect(cancelled.cancellationReason, 'Vent violent');

    final update = FirestoreMissionMapper.cancellationUpdate(
      cancelledBy: 'manager',
      reason: ' Vent violent ',
      serverTimestamp: Timestamp.fromDate(cancelledAt),
    );
    expect(update['status'], 'cancelled');
    expect(update['isActive'], isFalse);
    expect(update['cancelledBy'], 'manager');
    expect(update['cancellationReason'], 'Vent violent');
    expect(update['cancelledAt'], Timestamp.fromDate(cancelledAt));
  });
}
