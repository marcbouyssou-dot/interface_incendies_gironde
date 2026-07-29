import '../models/need.dart';

abstract interface class CoordinationRepository {
  Stream<List<CoordinationNeed>> watchMissions();

  Stream<List<ResponsePlace>> watchLocations();

  Stream<EngagementInfo?> watchMyEngagement(String missionId);

  Future<String> createMission(MissionDraft draft);

  Stream<ResponsibleAccess?> watchResponsibleAccess();

  Future<ResponsibleAccess> signInResponsible({
    required String email,
    required String password,
  });

  Future<void> signOutResponsible();

  Future<void> createEngagement({
    required String missionId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    required VolunteerProfession profession,
  });

  Future<void> cancelEngagement(String missionId);

  Future<void> cancelMission(String missionId, String? reason);
}

class EngagementInfo {
  const EngagementInfo({
    required this.missionId,
    required this.volunteerId,
    required this.profession,
  });

  final String missionId;
  final String volunteerId;
  final VolunteerProfession profession;
}

class ResponsibleAccess {
  const ResponsibleAccess({
    required this.uid,
    required this.role,
    required this.locationIds,
    required this.active,
  });

  final String uid;
  final String role;
  final Set<String> locationIds;
  final bool active;

  bool get isCoordinator => active && role == 'coordinator';
  bool get isSiteManager => active && role == 'site_manager';
  bool canManage(String locationId) =>
      isCoordinator || (isSiteManager && locationIds.contains(locationId));
}

class MissionDraft {
  const MissionDraft({
    required this.location,
    required this.startAt,
    required this.endAt,
    required this.requiredPhysiotherapists,
    required this.requiredPodiatrists,
    required this.equipment,
    required this.details,
  });

  final ResponsePlace location;
  final DateTime startAt;
  final DateTime endAt;
  final int requiredPhysiotherapists;
  final int requiredPodiatrists;
  final List<String> equipment;
  final String details;
}

class MissionSchedule {
  const MissionSchedule({required this.startAt, required this.endAt});

  final DateTime startAt;
  final DateTime endAt;

  factory MissionSchedule.fromLocal({
    required DateTime date,
    required int startMinutes,
    required int endMinutes,
  }) {
    if (startMinutes == endMinutes) {
      throw const FormatException(
        'L’heure de fin doit être postérieure à l’heure de début',
      );
    }
    final startAt = DateTime(
      date.year,
      date.month,
      date.day,
      startMinutes ~/ 60,
      startMinutes % 60,
    );
    var endAt = DateTime(
      date.year,
      date.month,
      date.day,
      endMinutes ~/ 60,
      endMinutes % 60,
    );
    if (endAt.isBefore(startAt)) {
      endAt = endAt.add(const Duration(days: 1));
    }
    return MissionSchedule(startAt: startAt, endAt: endAt);
  }
}

class RepositoryException implements Exception {
  const RepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
