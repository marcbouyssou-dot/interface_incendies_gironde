import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/mobilization_context.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/firestore_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/firestore_mission_mapper.dart';

void main() {
  const activeId = 'incendies-gironde-2026';
  const context = MobilizationContext(
    mobilizationId: activeId,
    territoryId: 'gironde',
    status: MobilizationStatus.active,
  );

  test('watchMissions mapping keeps only the active mobilization', () {
    final missions = scopedMissionsFromDocuments(
      context: context,
      documents: [
        _missionDocument('active', activeId),
        _missionDocument('other', 'another-mobilization'),
      ],
    );

    expect(missions.map((mission) => mission.id), ['active']);
  });

  test('mission from another mobilization is excluded defensively', () {
    final missions = scopedMissionsFromDocuments(
      context: context,
      documents: [_missionDocument('other', 'another-mobilization')],
    );

    expect(missions, isEmpty);
  });

  test('professional multi-scope list merges three active mobilizations', () {
    final missions = multiScopedMissionsFromDocuments(
      documents: [
        _missionDocument('a1', 'mobilization-a1'),
        _missionDocument('a2', 'mobilization-a2'),
        _missionDocument('b1', 'mobilization-b1'),
      ],
    );

    expect(missions.map((mission) => mission.id), ['a1', 'a2', 'b1']);
  });

  test('responsible multi-scope list remains limited to its centers', () {
    final missions = multiScopedMissionsFromDocuments(
      locationIds: const {'langon'},
      documents: [
        _missionDocument('a1', 'mobilization-a1', locationId: 'langon'),
        _missionDocument('b1', 'mobilization-b1', locationId: 'langon'),
        _missionDocument('other', 'mobilization-a2', locationId: 'merignac'),
      ],
    );

    expect(missions.map((mission) => mission.id), ['a1', 'b1']);
  });

  test('mission creation is refused without an active mobilization', () {
    expect(
      () => requireActiveMobilizationContext(null),
      throwsA(isA<RepositoryException>()),
    );
    expect(
      () => requireActiveMobilizationContext(
        const MobilizationContext(
          mobilizationId: activeId,
          territoryId: 'gironde',
          status: MobilizationStatus.inactive,
        ),
      ),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('new mission serialization writes the active mobilization id', () {
    final data = FirestoreMissionMapper.toFirestore(
      id: 'new-mission',
      mobilizationId: activeId,
      draft: MissionDraft(
        location: places.first,
        startAt: DateTime.utc(2026, 8, 11, 8),
        endAt: DateTime.utc(2026, 8, 11, 12),
        requiredPhysiotherapists: 1,
        requiredPodiatrists: 0,
        equipment: const [],
        details: '',
      ),
      serverTimestamp: Timestamp.fromDate(DateTime.utc(2026, 8, 10)),
      createdBy: 'manager',
    );

    expect(data['mobilizationId'], activeId);
  });

  test('engagement readings keep only the active mobilization', () {
    final engagements = scopedEngagementsFromDocuments(
      context: context,
      missionId: 'mission-1',
      documents: [
        _engagementDocument('active', activeId),
        _engagementDocument('other', 'another-mobilization'),
      ],
    );

    expect(engagements.map((engagement) => engagement.volunteerId), ['active']);
  });

  test('engagement inconsistent with its mission is refused', () {
    expect(
      () => requireDocumentsInActiveMobilization(
        context: context,
        mission: const {'id': 'mission-1', 'mobilizationId': activeId},
        engagement: const {
          'missionId': 'mission-1',
          'mobilizationId': 'another-mobilization',
        },
      ),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('multi-operation engagement derives its scope from the mission', () {
    expect(
      requireMatchingMobilizationId(
        mission: const {
          'id': 'mission-2',
          'mobilizationId': 'mobilization-selected',
        },
        engagement: const {
          'missionId': 'mission-2',
          'mobilizationId': 'mobilization-selected',
        },
      ),
      'mobilization-selected',
    );
  });

  test('multi-operation engagement refuses a cross-mobilization document', () {
    expect(
      () => requireMatchingMobilizationId(
        mission: const {
          'id': 'mission-2',
          'mobilizationId': 'mobilization-selected',
        },
        engagement: const {
          'missionId': 'mission-2',
          'mobilizationId': 'mobilization-other',
        },
      ),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('engagement from another mobilization is excluded', () {
    final engagements = scopedEngagementsFromDocuments(
      context: context,
      missionId: 'mission-1',
      documents: [_engagementDocument('other', 'another-mobilization')],
    );

    expect(engagements, isEmpty);
  });
}

MobilizationScopedDocument _missionDocument(
  String id,
  String mobilizationId, {
  String locationId = 'langon',
}) {
  return (
    id: id,
    data: {
      'id': id,
      'mobilizationId': mobilizationId,
      'locationId': locationId,
      'locationName': 'Lieu',
      'isActive': true,
      'requiredMk': 1,
      'requiredPp': 0,
      'registeredMk': 0,
      'registeredPp': 0,
    },
  );
}

MobilizationScopedDocument _engagementDocument(
  String volunteerId,
  String mobilizationId,
) {
  return (
    id: 'mission-1_$volunteerId',
    data: {
      'missionId': 'mission-1',
      'mobilizationId': mobilizationId,
      'volunteerId': volunteerId,
      'profession': 'physiotherapist',
      'status': 'confirmed',
    },
  );
}
