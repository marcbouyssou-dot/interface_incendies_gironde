import '../models/need.dart';
import '../models/profession_quotas.dart';
import '../models/responsible_access.dart';
import '../models/volunteer_profile.dart';
import '../models/user_display_identity.dart';
import '../models/app_notification.dart';
import '../services/professional_verification_service.dart';
import 'admin_invitation_repository.dart';
import 'location_administration_repository.dart';
import 'location_read_repository.dart';
import 'responsible_access_administration_repository.dart';

export '../models/responsible_access.dart';

abstract interface class MissionEngagementReadRepository {
  Stream<List<EngagementInfo>> watchMissionEngagements(String missionId);
}

/// Identité authentifiée du parcours administratif, indépendante de son rôle.
///
/// Ce contrat additif permet de résoudre une membership RC4 même lorsqu'aucun
/// document `roles/{uid}` legacy n'existe.
abstract interface class AdministrativeIdentityReadRepository {
  Stream<String?> watchAdministrativeUid();
}

/// Lecture bas niveau utilisée après validation du périmètre organisationnel.
///
/// Le repository contextualisé reste responsable de l'autorisation de la
/// mission avant d'appeler cette source.
abstract interface class OrganizationEngagementReadDataSource {
  Stream<List<EngagementInfo>> watchAuthorizedMissionEngagements(
    String missionId,
  );
}

/// Contrat ciblé indiquant si une mission reste lisible dans le contexte
/// organisationnel courant.
///
/// Une valeur nulle signifie que la mission n'existe pas ou qu'elle est hors
/// périmètre. Le flux doit réévaluer cet accès quand le contexte change.
abstract interface class MissionAccessReadRepository {
  Stream<CoordinationNeed?> watchAccessibleMission(String missionId);
}

/// Lecture ciblée de l'abonnement Push de l'installation courante.
enum PushSubscriptionState { absent, active, stale, inactive }

abstract interface class PushSubscriptionReadRepository {
  Future<PushSubscriptionState> readPushSubscriptionState(
    String installationId,
  );
}

abstract interface class CoordinationRepository
    implements MissionEngagementReadRepository, LocationReadRepository {
  AdminInvitationRepository get adminInvitationRepository;

  LocationAdministrationRepository get locationAdministrationRepository;

  ResponsibleAccessAdministrationRepository
  get responsibleAccessAdministrationRepository;

  Stream<List<CoordinationNeed>> watchMissions();

  Future<VolunteerProfile?> getVolunteerProfile();

  Future<void> saveVolunteerProfile(VolunteerProfile profile);

  Future<VolunteerProfile> confirmProfessionalRpps(
    ProfessionalVerificationResult verification,
  );

  Stream<EngagementInfo?> watchMyEngagement(String missionId);

  Future<void> updateEngagementStatus({
    required String missionId,
    required String volunteerId,
    required EngagementStatus status,
  });

  Future<String> createMission(MissionDraft draft);

  Future<void> updateMission(String missionId, MissionDraft draft);

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
    String? rpps,
    ProfessionalIdType? professionalIdType,
    String? professionalIdValue,
    String? cptsId,
    String? cptsLabel,
    required VolunteerProfession profession,
    List<String> equipment = const [],
    String? otherEquipmentDetails,
  });

  Future<void> cancelEngagement(String missionId);

  Future<void> cancelMission(String missionId, String? reason);

  Future<CoordinationNeed?> getMission(String missionId);

  Stream<List<AppNotification>> watchNotifications();

  Future<void> setNotificationRead(String notificationId, {required bool read});

  Stream<NotificationPreferences> watchNotificationPreferences();

  Future<void> saveNotificationPreferences(NotificationPreferences preferences);

  Future<void> registerPushSubscription(
    PushSubscriptionRegistration registration,
  );

  Future<void> disablePushSubscription(String installationId);
}

/// Contrat additif utilisé par RC3.5B. Le contrat historique reste inchangé
/// tant que les écrans utilisent encore la mobilisation legacy courante.
abstract interface class MultiMobilizationCoordinationReadRepository {
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> mobilizationIds,
  );

  Stream<List<CoordinationNeed>> watchMissionsForLocations(
    Set<String> locationIds,
  );

  Stream<List<CoordinationNeed>> watchAllActiveMissions();
}

/// Lecture Responsable bornée simultanément par mobilisation et par site.
///
/// Les deux périmètres doivent être portés par la requête serveur : ce contrat
/// ne permet pas de récupérer une collection plus large puis de la filtrer en
/// mémoire.
abstract interface class MobilizationLocationMissionReadRepository {
  Stream<List<CoordinationNeed>> watchMissionsForMobilizationsAndLocations({
    required Set<String> mobilizationIds,
    required Set<String> locationIds,
  });
}

/// Mutation explicite dans une mobilisation sélectionnée. Le contrat legacy
/// [CoordinationRepository.createMission] reste disponible pendant la
/// transition.
abstract interface class MultiMobilizationCoordinationMutationRepository {
  Future<String> createMissionForMobilization(
    String mobilizationId,
    MissionDraft draft,
  );
}

class EngagementInfo {
  const EngagementInfo({
    required this.missionId,
    required this.volunteerId,
    required this.profession,
    this.identity,
    this.status = EngagementStatus.confirmed,
    this.createdAt,
    this.updatedAt,
  });

  final String missionId;
  final String volunteerId;
  final VolunteerProfession profession;
  final UserDisplayIdentity? identity;
  final EngagementStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get documentId => '${missionId}_$volunteerId';

  EngagementInfo copyWith({
    VolunteerProfession? profession,
    UserDisplayIdentity? identity,
    EngagementStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => EngagementInfo(
    missionId: missionId,
    volunteerId: volunteerId,
    profession: profession ?? this.profession,
    identity: identity ?? this.identity,
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
  static int amount({
    required EngagementStatus from,
    required EngagementStatus to,
  }) => switch ((from, to)) {
    (EngagementStatus.pending, EngagementStatus.confirmed) => 1,
    (EngagementStatus.confirmed, EngagementStatus.standby) => -1,
    (EngagementStatus.confirmed, EngagementStatus.cancelled) => -1,
    (EngagementStatus.standby, EngagementStatus.confirmed) => 1,
    _ => 0,
  };

  static ({int mk, int pp}) delta({
    required EngagementStatus from,
    required EngagementStatus to,
    required VolunteerProfession profession,
  }) {
    final amount = EngagementCounterTransition.amount(from: from, to: to);
    return switch (profession) {
      VolunteerProfession.mk => (mk: amount, pp: 0),
      VolunteerProfession.pp => (mk: 0, pp: amount),
      VolunteerProfession.doctor ||
      VolunteerProfession.nurse ||
      VolunteerProfession.veterinarian ||
      VolunteerProfession.otherHealthProfessional => (mk: 0, pp: 0),
    };
  }
}

class MissionDraft {
  MissionDraft({
    required this.location,
    required this.startAt,
    required this.endAt,
    int requiredPhysiotherapists = 0,
    int requiredPodiatrists = 0,
    Map<String, int>? requiredByProfession,
    this.priority = NeedPriority.standard,
    required this.equipment,
    required this.details,
  }) : professionQuotas = requiredByProfession == null
           ? ProfessionQuotas.fromLegacyMkPp(
               requiredMk: requiredPhysiotherapists,
               registeredMk: 0,
               requiredPp: requiredPodiatrists,
               registeredPp: 0,
             )
           : ProfessionQuotas.fromMaps(
               requiredByProfession: requiredByProfession,
               registeredByProfession: const {},
             );

  final ResponsePlace location;
  final DateTime startAt;
  final DateTime endAt;
  final ProfessionQuotas professionQuotas;
  final NeedPriority priority;
  final List<String> equipment;
  final String details;

  Map<String, int> get requiredByProfession =>
      professionQuotas.requiredByProfession;
  int get requiredPhysiotherapists =>
      professionQuotas.quotaFor('physiotherapist').required;
  int get requiredPodiatrists =>
      professionQuotas.quotaFor('podiatrist').required;
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
    if (endMinutes <= startMinutes) {
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
    final endAt = DateTime(
      date.year,
      date.month,
      date.day,
      endMinutes ~/ 60,
      endMinutes % 60,
    );
    return MissionSchedule(startAt: startAt, endAt: endAt);
  }
}

class RepositoryException implements Exception {
  const RepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
