import 'dart:async';

import '../data/mock_data.dart';
import '../models/need.dart';
import 'coordination_repository.dart';

class MockCoordinationRepository implements CoordinationRepository {
  MockCoordinationRepository({
    List<CoordinationNeed>? initialMissions,
    List<ResponsePlace>? initialLocations,
    List<EngagementInfo>? initialEngagements,
    ResponsibleAccess? responsibleAccess = _mockAccess,
  }) : _missions = List.of(initialMissions ?? needs),
       _locations = List.of(initialLocations ?? places),
       missionEngagements = List.of(
         initialEngagements ?? _mockMissionEngagements,
       ),
       _responsibleAccess = responsibleAccess;

  static final instance = MockCoordinationRepository();

  final List<CoordinationNeed> _missions;
  final List<ResponsePlace> _locations;
  final ResponsibleAccess? _responsibleAccess;
  final List<Volunteer> volunteers = [];
  final Map<String, EngagementInfo> engagements = {};
  final List<EngagementInfo> missionEngagements;

  final _missionUpdates = StreamController<List<CoordinationNeed>>.broadcast();
  static const _mockAccess = ResponsibleAccess(
    uid: 'mock-coordinator',
    role: 'coordinator',
    locationIds: {'*'},
    active: true,
  );
  static const _mockMissionEngagements = [
    EngagementInfo(
      missionId: 'mission-merignac',
      volunteerId: 'mock-pending',
      profession: VolunteerProfession.mk,
      status: EngagementStatus.pending,
    ),
    EngagementInfo(
      missionId: 'mission-merignac',
      volunteerId: 'mock-confirmed',
      profession: VolunteerProfession.pp,
    ),
    EngagementInfo(
      missionId: 'mission-langon',
      volunteerId: 'mock-standby',
      profession: VolunteerProfession.mk,
      status: EngagementStatus.standby,
    ),
    EngagementInfo(
      missionId: 'mission-libourne',
      volunteerId: 'mock-cancelled',
      profession: VolunteerProfession.pp,
      status: EngagementStatus.cancelled,
    ),
  ];

  CoordinationNeed? debugMission(String id) =>
      _missions.where((mission) => mission.id == id).firstOrNull;

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() =>
      Stream.value(_responsibleAccess);

  @override
  Future<ResponsibleAccess> signInResponsible({
    required String email,
    required String password,
  }) async => _responsibleAccess ?? _mockAccess;

  @override
  Future<void> signOutResponsible() async {}

  @override
  Stream<List<CoordinationNeed>> watchMissions() {
    return Stream.multi((controller) {
      controller.add(_activeMissions());
      final subscription = _missionUpdates.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    });
  }

  List<CoordinationNeed> _activeMissions() => List.unmodifiable(
    _missions.where((mission) => mission.isActive && !mission.isCancelled),
  );

  @override
  Stream<EngagementInfo?> watchMyEngagement(String missionId) {
    return Stream.multi((controller) {
      void emit(_) => controller.add(engagements[missionId]);
      emit(null);
      final subscription = _missionUpdates.stream.listen(emit);
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<List<EngagementInfo>> watchMissionEngagements(String missionId) {
    return Stream.multi((controller) {
      void emit(_) => controller.add(
        List.unmodifiable(
          missionEngagements.where(
            (engagement) => engagement.missionId == missionId,
          ),
        ),
      );
      emit(null);
      final subscription = _missionUpdates.stream.listen(emit);
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> updateEngagementStatus({
    required String missionId,
    required String volunteerId,
    required EngagementStatus status,
  }) async {
    if (_responsibleAccess?.isCoordinator != true) {
      throw const RepositoryException(
        'Seul un coordinateur peut modifier ce statut.',
      );
    }
    final index = missionEngagements.indexWhere(
      (engagement) =>
          engagement.missionId == missionId &&
          engagement.volunteerId == volunteerId,
    );
    if (index < 0) {
      throw const RepositoryException('Engagement introuvable.');
    }
    final engagement = missionEngagements[index];
    if (status == EngagementStatus.confirmed &&
        (engagement.status == EngagementStatus.pending ||
            engagement.status == EngagementStatus.standby)) {
      final missionIndex = _missions.indexWhere(
        (mission) => mission.id == missionId,
      );
      if (missionIndex < 0) {
        throw const RepositoryException('Mission introuvable.');
      }
      final mission = _missions[missionIndex];
      if (!mission.isActive || mission.isCancelled) {
        throw const RepositoryException('Cette mission a été annulée.');
      }
      if (mission.endAt != null && !DateTime.now().isBefore(mission.endAt!)) {
        throw const RepositoryException(
          'Le créneau de cette mission est terminé.',
        );
      }
      final delta = EngagementCounterTransition.delta(
        from: engagement.status,
        to: status,
        profession: engagement.profession,
      );
      if ((delta.mk > 0 &&
              mission.registeredPhysiotherapists >=
                  mission.requiredPhysiotherapists) ||
          (delta.pp > 0 &&
              mission.registeredPodiatrists >= mission.requiredPodiatrists)) {
        throw const RepositoryException(
          'Le quota de cette profession est déjà atteint.',
        );
      }
      _missions[missionIndex] = mission.copyWith(
        registeredPhysiotherapists:
            mission.registeredPhysiotherapists + delta.mk,
        registeredPodiatrists: mission.registeredPodiatrists + delta.pp,
      );
    } else if (status == EngagementStatus.confirmed &&
        engagement.status != EngagementStatus.pending) {
      throw const RepositoryException(
        'Cet engagement ne peut pas être confirmé.',
      );
    }
    final isWithoutCounter =
        (engagement.status == EngagementStatus.pending &&
            (status == EngagementStatus.standby ||
                status == EngagementStatus.cancelled)) ||
        (engagement.status == EngagementStatus.standby &&
            status == EngagementStatus.cancelled);
    if (isWithoutCounter) {
      final mission = _missions
          .where((candidate) => candidate.id == missionId)
          .firstOrNull;
      if (mission == null) {
        throw const RepositoryException('Mission introuvable.');
      }
      if (!mission.isActive || mission.isCancelled) {
        throw const RepositoryException('Cette mission a été annulée.');
      }
      if (mission.endAt != null && !DateTime.now().isBefore(mission.endAt!)) {
        throw const RepositoryException(
          'Le créneau de cette mission est terminé.',
        );
      }
    } else if (status == EngagementStatus.standby ||
        status == EngagementStatus.cancelled) {
      if (engagement.status != EngagementStatus.confirmed) {
        throw const RepositoryException(
          'Seul un engagement confirmé peut changer de statut.',
        );
      }
      final missionIndex = _missions.indexWhere(
        (mission) => mission.id == missionId,
      );
      if (missionIndex < 0) {
        throw const RepositoryException('Mission introuvable.');
      }
      final mission = _missions[missionIndex];
      if (!mission.isActive || mission.isCancelled) {
        throw const RepositoryException('Cette mission a été annulée.');
      }
      if (mission.endAt != null && !DateTime.now().isBefore(mission.endAt!)) {
        throw const RepositoryException(
          'Le créneau de cette mission est terminé.',
        );
      }
      final delta = EngagementCounterTransition.delta(
        from: engagement.status,
        to: status,
        profession: engagement.profession,
      );
      if ((delta.mk < 0 && mission.registeredPhysiotherapists <= 0) ||
          (delta.pp < 0 && mission.registeredPodiatrists <= 0)) {
        throw const RepositoryException(
          'Le compteur correspondant est déjà à zéro.',
        );
      }
      _missions[missionIndex] = mission.copyWith(
        registeredPhysiotherapists:
            mission.registeredPhysiotherapists + delta.mk,
        registeredPodiatrists: mission.registeredPodiatrists + delta.pp,
      );
    }
    final updated = engagement.copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    missionEngagements[index] = updated;
    if (engagements[missionId]?.volunteerId == volunteerId) {
      engagements[missionId] = updated;
    }
    _missionUpdates.add(_activeMissions());
  }

  @override
  Stream<List<ResponsePlace>> watchLocations() {
    return Stream.value(List.unmodifiable(_locations));
  }

  @override
  Future<String> createMission(MissionDraft draft) async {
    final access = _responsibleAccess;
    if (access == null || !access.active) {
      throw const RepositoryException(
        'Vous devez vous connecter pour déclarer un besoin.',
      );
    }
    if (!access.canManage(draft.location.id)) {
      throw const RepositoryException(
        'Votre compte n’est pas autorisé à publier pour ce lieu.',
      );
    }
    final id = 'mock-mission-${_missions.length + 1}';
    final mission = CoordinationNeed(
      id: id,
      locationId: draft.location.id,
      place: draft.location.name,
      group: draft.location.group,
      date: _dateLabel(draft.startAt),
      time: '${_timeLabel(draft.startAt)} — ${_timeLabel(draft.endAt)}',
      startAt: draft.startAt,
      endAt: draft.endAt,
      requiredPhysiotherapists: draft.requiredPhysiotherapists,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: draft.requiredPodiatrists,
      registeredPodiatrists: 0,
      equipment: List.of(draft.equipment),
      details: draft.details,
    );
    _missions.add(mission);
    _missionUpdates.add(_activeMissions());
    return id;
  }

  @override
  Future<EngagementCreationResult> createEngagement({
    required String missionId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    required VolunteerProfession profession,
  }) async {
    final index = _missions.indexWhere((mission) => mission.id == missionId);
    if (index < 0) {
      throw const RepositoryException('Mission introuvable');
    }
    final mission = _missions[index];
    if (!mission.isActive || mission.isCancelled) {
      throw const RepositoryException('Cette mission a été annulée.');
    }
    if (mission.endAt != null && !DateTime.now().isBefore(mission.endAt!)) {
      throw const RepositoryException(
        'Le créneau de cette mission est terminé.',
      );
    }
    final existingEngagement = engagements[missionId];
    if (existingEngagement != null &&
        existingEngagement.status != EngagementStatus.cancelled) {
      if (existingEngagement.volunteerId != 'mock-volunteer') {
        throw const RepositoryException(
          'Cet engagement appartient à un autre volontaire.',
        );
      }
      return switch (existingEngagement.status) {
        EngagementStatus.pending => EngagementCreationResult.alreadyPending,
        EngagementStatus.confirmed => EngagementCreationResult.alreadyConfirmed,
        EngagementStatus.standby => EngagementCreationResult.alreadyStandby,
        EngagementStatus.cancelled => throw StateError('État inaccessible'),
      };
    }
    volunteers.add(
      Volunteer(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        phone: phone.trim(),
        email: _nullableTrim(email),
        profession: profession,
      ),
    );
    final engagement = EngagementInfo(
      missionId: missionId,
      volunteerId: 'mock-volunteer',
      profession: profession,
      status: EngagementStatus.pending,
      createdAt: existingEngagement?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    engagements[missionId] = engagement;
    final engagementIndex = missionEngagements.indexWhere(
      (candidate) =>
          candidate.missionId == missionId &&
          candidate.volunteerId == engagement.volunteerId,
    );
    if (engagementIndex < 0) {
      missionEngagements.add(engagement);
    } else {
      missionEngagements[engagementIndex] = engagement;
    }
    _missionUpdates.add(_activeMissions());
    return existingEngagement == null
        ? EngagementCreationResult.created
        : EngagementCreationResult.reactivated;
  }

  @override
  Future<void> cancelEngagement(String missionId) async {
    final index = _missions.indexWhere((mission) => mission.id == missionId);
    final engagement = engagements[missionId];
    if (index < 0 || engagement == null) {
      throw const RepositoryException(
        'Vous n’êtes plus engagé sur cette mission.',
      );
    }
    final mission = _missions[index];
    if (!mission.isActive || mission.isCancelled) {
      throw const RepositoryException('Cette mission a été annulée.');
    }
    if (mission.endAt != null && !DateTime.now().isBefore(mission.endAt!)) {
      throw const RepositoryException(
        'Le créneau de cette mission est terminé.',
      );
    }
    if (engagement.status == EngagementStatus.cancelled) {
      throw const RepositoryException(
        'Vous n’êtes plus engagé sur cette mission.',
      );
    }
    if (engagement.status == EngagementStatus.confirmed) {
      _missions[index] = switch (engagement.profession) {
        VolunteerProfession.mk when mission.registeredPhysiotherapists > 0 =>
          mission.copyWith(
            registeredPhysiotherapists: mission.registeredPhysiotherapists - 1,
          ),
        VolunteerProfession.pp when mission.registeredPodiatrists > 0 =>
          mission.copyWith(
            registeredPodiatrists: mission.registeredPodiatrists - 1,
          ),
        _ => throw const RepositoryException(
          'Le désengagement n’a pas pu être enregistré. Réessayez.',
        ),
      };
    }
    final cancelled = engagement.copyWith(
      status: EngagementStatus.cancelled,
      updatedAt: DateTime.now(),
    );
    engagements[missionId] = cancelled;
    final engagementIndex = missionEngagements.indexWhere(
      (candidate) =>
          candidate.missionId == missionId &&
          candidate.volunteerId == engagement.volunteerId,
    );
    if (engagementIndex >= 0) {
      missionEngagements[engagementIndex] = cancelled;
    }
    _missionUpdates.add(_activeMissions());
  }

  @override
  Future<void> cancelMission(String missionId, String? reason) async {
    final index = _missions.indexWhere((mission) => mission.id == missionId);
    if (index < 0) throw const RepositoryException('Mission introuvable.');
    final mission = _missions[index];
    if (mission.isCancelled || !mission.isActive) {
      throw const RepositoryException('Cette mission a déjà été annulée.');
    }
    if (_responsibleAccess?.canManage(mission.locationId ?? '') != true) {
      throw const RepositoryException(
        'Votre compte n’est pas autorisé à publier pour ce lieu.',
      );
    }
    _missions[index] = CoordinationNeed(
      id: mission.id,
      place: mission.place,
      group: mission.group,
      date: mission.date,
      time: mission.time,
      requiredPhysiotherapists: mission.requiredPhysiotherapists,
      registeredPhysiotherapists: mission.registeredPhysiotherapists,
      requiredPodiatrists: mission.requiredPodiatrists,
      registeredPodiatrists: mission.registeredPodiatrists,
      equipment: mission.equipment,
      locationId: mission.locationId,
      startAt: mission.startAt,
      endAt: mission.endAt,
      details: mission.details,
      isActive: false,
      isCancelled: true,
      cancelledAt: DateTime.now(),
      cancelledBy: _responsibleAccess!.uid,
      cancellationReason: reason?.trim(),
    );
    _missionUpdates.add(_activeMissions());
  }

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _dateLabel(DateTime value) {
    return '${_two(value.day)}/${_two(value.month)}/${value.year}';
  }

  static String _timeLabel(DateTime value) {
    return '${_two(value.hour)}:${_two(value.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
