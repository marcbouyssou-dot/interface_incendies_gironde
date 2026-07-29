import '../models/need.dart';

abstract interface class CoordinationRepository {
  Stream<List<CoordinationNeed>> watchMissions();

  Stream<List<ResponsePlace>> watchLocations();

  Stream<EngagementInfo?> watchMyEngagement(String missionId);

  Stream<List<EngagementInfo>> watchMissionEngagements(String missionId);

  Future<void> updateEngagementStatus({
    required String missionId,
    required String volunteerId,
    required EngagementStatus status,
  });

  Future<String> createMission(MissionDraft draft);

  Stream<ResponsibleAccess?> watchResponsibleAccess();

  Future<ResponsibleAccess> signInResponsible({
    required String email,
    required String password,
  });

  Future<void> signOutResponsible();

  Future<EngagementCreationResult> createEngagement({
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
    this.status = EngagementStatus.confirmed,
    this.createdAt,
    this.updatedAt,
  });

  final String missionId;
  final String volunteerId;
  final VolunteerProfession profession;
  final EngagementStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get documentId => '${missionId}_$volunteerId';

  EngagementInfo copyWith({
    VolunteerProfession? profession,
    EngagementStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => EngagementInfo(
    missionId: missionId,
    volunteerId: volunteerId,
    profession: profession ?? this.profession,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

// `pending` and `standby` remain readable for historical RC1.4 records.
// New engagements and re-engagements are created directly as `confirmed`.
enum EngagementStatus { pending, confirmed, standby, cancelled }

enum EngagementCreationResult {
  created,
  reactivated,
  alreadyPending,
  alreadyConfirmed,
  alreadyStandby,
}

extension EngagementCreationResultMessage on EngagementCreationResult {
  String? get existingMessage => switch (this) {
    EngagementCreationResult.alreadyPending =>
      'Votre demande est déjà en attente.',
    EngagementCreationResult.alreadyConfirmed =>
      'Votre participation est déjà confirmée.',
    EngagementCreationResult.alreadyStandby =>
      'Vous êtes déjà inscrit comme renfort.',
    EngagementCreationResult.created ||
    EngagementCreationResult.reactivated => null,
  };
}

extension EngagementStatusLabel on EngagementStatus {
  String get label => switch (this) {
    EngagementStatus.pending => 'En attente',
    EngagementStatus.confirmed => 'Confirmé',
    EngagementStatus.standby => 'Renfort',
    EngagementStatus.cancelled => 'Annulé',
  };

  bool get incrementsCountersOnCreation => this != EngagementStatus.pending;
}

abstract final class EngagementCounterTransition {
  static ({int mk, int pp}) delta({
    required EngagementStatus from,
    required EngagementStatus to,
    required VolunteerProfession profession,
  }) {
    final amount = switch ((from, to)) {
      (EngagementStatus.pending, EngagementStatus.confirmed) => 1,
      (EngagementStatus.confirmed, EngagementStatus.standby) => -1,
      (EngagementStatus.confirmed, EngagementStatus.cancelled) => -1,
      (EngagementStatus.standby, EngagementStatus.confirmed) => 1,
      _ => 0,
    };
    return switch (profession) {
      VolunteerProfession.mk => (mk: amount, pp: 0),
      VolunteerProfession.pp => (mk: 0, pp: amount),
    };
  }
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
  String? get singleManagedLocationId =>
      isSiteManager && locationIds.length == 1 ? locationIds.single : null;
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
