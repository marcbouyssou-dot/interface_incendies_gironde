import '../models/need.dart';

abstract interface class CoordinationRepository {
  Stream<List<CoordinationNeed>> watchMissions();

  Stream<List<ResponsePlace>> watchLocations();

  Future<String> createMission(MissionDraft draft);

  Future<void> createEngagement({
    required String missionId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    required VolunteerProfession profession,
  });
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
