import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
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
      mobilizationId: 'incendies-gironde-2026',
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
    expect(data['requiredByProfession'], {
      'physiotherapist': 2,
      'podiatrist': 1,
      'physician': 0,
      'nurse': 0,
      'veterinarian': 0,
      'other_health_professional': 0,
    });
    expect(data['registeredByProfession'], {
      'physiotherapist': 0,
      'podiatrist': 0,
      'physician': 0,
      'nurse': 0,
      'veterinarian': 0,
      'other_health_professional': 0,
    });
    expect(data['isActive'], isTrue);
    expect(data['priority'], 'standard');
    expect(data['mobilizationId'], 'incendies-gironde-2026');
    expect(data['createdBy'], 'manager-uid');
    expect(mission.locationId, places.first.id);
    expect(mission.place, places.first.name);
    expect(mission.startAt, start);
    expect(mission.endAt, end);
    expect(mission.time, '22:00 — 02:00');
    expect(mission.requiredPhysiotherapists, 2);
    expect(mission.requiredPodiatrists, 1);
    expect(mission.priority, NeedPriority.standard);
    expect(mission.createdAt, DateTime(2026, 7, 29));
    expect(mission.updatedAt, DateTime(2026, 7, 29));
  });

  test('mission update callable payload contains only editable inputs', () {
    final draft = MissionDraft(
      location: places.first,
      startAt: DateTime(2026, 8, 3, 8),
      endAt: DateTime(2026, 8, 3, 12),
      requiredByProfession: const {
        'physiotherapist': 2,
        'podiatrist': 1,
        'physician': 0,
        'nurse': 0,
        'veterinarian': 0,
        'other_health_professional': 0,
      },
      equipment: const ['Tables'],
      details: 'Accès nord',
    );

    final data = FirestoreMissionMapper.toUpdateCallableData(
      missionId: 'mission-stable',
      draft: draft,
    );

    expect(data.keys.toSet(), {
      'missionId',
      'locationId',
      'startAtMillis',
      'endAtMillis',
      'requiredByProfession',
      'priority',
      'equipment',
      'details',
    });
    expect(data['missionId'], 'mission-stable');
    expect(data['requiredByProfession'], draft.requiredByProfession);
    expect(data['priority'], 'standard');
    expect(data.containsKey('registeredByProfession'), isFalse);
    expect(data.containsKey('createdBy'), isFalse);
  });

  test('the four priorities round-trip and legacy falls back to standard', () {
    for (final priority in NeedPriority.values) {
      final draft = MissionDraft(
        location: places.first,
        startAt: DateTime(2026, 8, 3, 8),
        endAt: DateTime(2026, 8, 3, 12),
        requiredPhysiotherapists: 1,
        priority: priority,
        equipment: const [],
        details: '',
      );
      final data = FirestoreMissionMapper.toFirestore(
        id: 'priority-${priority.serializedValue}',
        mobilizationId: 'incendies-gironde-2026',
        draft: draft,
        serverTimestamp: Timestamp.fromDate(DateTime(2026, 8, 2)),
        createdBy: 'manager-uid',
      );

      expect(data['priority'], priority.serializedValue);
      expect(
        FirestoreMissionMapper.fromFirestore(
          id: 'priority-${priority.serializedValue}',
          data: data,
        ).priority,
        priority,
      );
    }

    expect(
      FirestoreMissionMapper.fromFirestore(
        id: 'legacy',
        data: const {'requiredMk': 1},
      ).priority,
      NeedPriority.standard,
    );
    expect(
      () => FirestoreMissionMapper.fromFirestore(
        id: 'invalid-priority',
        data: const {'requiredMk': 1, 'priority': 'information'},
      ),
      throwsFormatException,
    );
  });

  test('generic maps take priority without merging legacy fields', () {
    final mission = FirestoreMissionMapper.fromFirestore(
      id: 'generic',
      data: const {
        'locationName': 'Lieu',
        'requiredByProfession': {'physician': 2},
        'registeredByProfession': {'physician': 1},
        'requiredMk': 50,
        'registeredMk': 50,
        'requiredPp': 50,
        'registeredPp': 50,
      },
    );

    expect(mission.professionQuotas.requiredTotal, 2);
    expect(mission.professionQuotas.registeredTotal, 1);
    expect(mission.requiredPhysiotherapists, 0);
    expect(mission.requiredPodiatrists, 0);
  });

  test('a generic mission draft writes all quotas and legacy MK/PP fields', () {
    final draft = MissionDraft(
      location: places.first,
      startAt: DateTime(2026, 8, 1, 8),
      endAt: DateTime(2026, 8, 1, 12),
      requiredByProfession: const {
        'physiotherapist': 2,
        'podiatrist': 1,
        'physician': 3,
        'nurse': 4,
        'veterinarian': 5,
        'other_health_professional': 6,
      },
      equipment: const [],
      details: '',
    );

    final data = FirestoreMissionMapper.toFirestore(
      id: 'generic-draft',
      mobilizationId: 'incendies-gironde-2026',
      draft: draft,
      serverTimestamp: Timestamp.fromDate(DateTime(2026, 7, 29)),
      createdBy: 'manager-uid',
    );

    expect(data['requiredByProfession'], draft.requiredByProfession);
    expect(data['registeredByProfession'], {
      'physiotherapist': 0,
      'podiatrist': 0,
      'physician': 0,
      'nurse': 0,
      'veterinarian': 0,
      'other_health_professional': 0,
    });
    expect(data['requiredMk'], 2);
    expect(data['requiredPp'], 1);
  });

  test('a partial generic map treats absent keys as zero', () {
    final mission = FirestoreMissionMapper.fromFirestore(
      id: 'partial',
      data: const {
        'requiredByProfession': {'nurse': 1},
      },
    );

    expect(mission.professionQuotas.quotaFor('nurse').required, 1);
    expect(mission.professionQuotas.quotaFor('nurse').registered, 0);
    expect(mission.professionQuotas.quotaFor('physiotherapist').required, 0);
  });

  test('invalid generic map values fail explicitly', () {
    expect(
      () => FirestoreMissionMapper.fromFirestore(
        id: 'invalid',
        data: const {
          'requiredByProfession': {'nurse': -1},
          'registeredByProfession': <String, int>{},
        },
      ),
      throwsFormatException,
    );
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
