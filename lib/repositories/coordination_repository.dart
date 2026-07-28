import '../models/need.dart';

abstract interface class CoordinationRepository {
  Stream<List<CoordinationNeed>> watchMissions();

  Stream<List<ResponsePlace>> watchLocations();

  Future<void> createEngagement({
    required String missionId,
    required String firstName,
    required String lastName,
    required String phone,
    required VolunteerProfession profession,
  });
}

class RepositoryException implements Exception {
  const RepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
