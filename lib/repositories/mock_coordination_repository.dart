import 'dart:async';

import '../data/mock_data.dart';
import '../models/need.dart';
import 'coordination_repository.dart';

class MockCoordinationRepository implements CoordinationRepository {
  MockCoordinationRepository({
    List<CoordinationNeed>? initialMissions,
    List<ResponsePlace>? initialLocations,
  }) : _missions = List.of(initialMissions ?? needs),
       _locations = List.of(initialLocations ?? places);

  static final instance = MockCoordinationRepository();

  final List<CoordinationNeed> _missions;
  final List<ResponsePlace> _locations;
  final List<Volunteer> volunteers = [];

  final _missionUpdates = StreamController<List<CoordinationNeed>>.broadcast();

  @override
  Stream<List<CoordinationNeed>> watchMissions() {
    return Stream.multi((controller) {
      controller.add(List.unmodifiable(_missions));
      final subscription = _missionUpdates.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<List<ResponsePlace>> watchLocations() {
    return Stream.value(List.unmodifiable(_locations));
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
    _missionUpdates.add(List.unmodifiable(_missions));
  }

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
