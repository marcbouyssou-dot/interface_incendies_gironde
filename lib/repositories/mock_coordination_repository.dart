import 'dart:async';

import '../data/mock_data.dart';
import '../models/need.dart';
import 'coordination_repository.dart';

class MockCoordinationRepository implements CoordinationRepository {
  MockCoordinationRepository({
    List<CoordinationNeed>? initialMissions,
    List<ResponsePlace>? initialLocations,
    ResponsibleAccess? responsibleAccess = _mockAccess,
  }) : _missions = List.of(initialMissions ?? needs),
       _locations = List.of(initialLocations ?? places),
       _responsibleAccess = responsibleAccess;

  static final instance = MockCoordinationRepository();

  final List<CoordinationNeed> _missions;
  final List<ResponsePlace> _locations;
  final ResponsibleAccess? _responsibleAccess;
  final List<Volunteer> volunteers = [];
  final Map<String, EngagementInfo> engagements = {};

  final _missionUpdates = StreamController<List<CoordinationNeed>>.broadcast();
  static const _mockAccess = ResponsibleAccess(
    uid: 'mock-coordinator',
    role: 'coordinator',
    locationIds: {'*'},
    active: true,
  );

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
  Stream<List<ResponsePlace>> watchLocations() {
    return Stream.value(List.unmodifiable(_locations));
  }

  @override
  Future<String> createMission(MissionDraft draft) async {
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
  Future<void> createEngagement({
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
    if (engagements.containsKey(missionId)) {
      throw const RepositoryException(
        'Vous êtes déjà engagé sur cette mission.',
      );
    }
    final updated = switch (profession) {
      VolunteerProfession.mk => mission.copyWith(
        registeredPhysiotherapists: mission.registeredPhysiotherapists + 1,
      ),
      VolunteerProfession.pp => mission.copyWith(
        registeredPodiatrists: mission.registeredPodiatrists + 1,
      ),
    };
    _missions[index] = updated;
    volunteers.add(
      Volunteer(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        phone: phone.trim(),
        email: _nullableTrim(email),
        profession: profession,
      ),
    );
    engagements[missionId] = EngagementInfo(
      missionId: missionId,
      volunteerId: 'mock-volunteer',
      profession: profession,
    );
    _missionUpdates.add(_activeMissions());
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
    final updated = switch (engagement.profession) {
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
    _missions[index] = updated;
    engagements.remove(missionId);
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
