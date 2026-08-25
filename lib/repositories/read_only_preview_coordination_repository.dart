import '../models/admin_invitation.dart';
import '../models/admin_location.dart';
import '../models/app_notification.dart';
import '../models/need.dart';
import '../models/responsible_account.dart';
import '../models/volunteer_profile.dart';
import '../perspective/cross_role_perspective.dart';
import '../services/professional_verification_service.dart';
import 'admin_invitation_repository.dart';
import 'coordination_repository.dart';
import 'location_administration_repository.dart';
import 'responsible_access_administration_repository.dart';

const readOnlyPreviewMessage =
    'Cette action est désactivée dans la prévisualisation Administrateur.';

class ReadOnlyPreviewCoordinationRepository
    implements CoordinationRepository, PushSubscriptionReadRepository {
  ReadOnlyPreviewCoordinationRepository(this.source, {this.operationContext})
    : adminInvitationRepository = ReadOnlyPreviewAdminInvitationRepository(
        source.adminInvitationRepository,
      ),
      locationAdministrationRepository =
          ReadOnlyPreviewLocationAdministrationRepository(
            source.locationAdministrationRepository,
          ),
      responsibleAccessAdministrationRepository =
          ReadOnlyPreviewResponsibleAccessAdministrationRepository(
            source.responsibleAccessAdministrationRepository,
          );

  final CoordinationRepository source;
  final CrossRoleOperationContext? operationContext;

  @override
  final AdminInvitationRepository adminInvitationRepository;
  @override
  final LocationAdministrationRepository locationAdministrationRepository;
  @override
  final ResponsibleAccessAdministrationRepository
  responsibleAccessAdministrationRepository;

  Future<T> _blocked<T>() =>
      Future.error(const RepositoryException(readOnlyPreviewMessage));

  @override
  Stream<List<CoordinationNeed>> watchMissions() {
    final context = operationContext;
    if (context == null ||
        source is! MultiMobilizationCoordinationReadRepository) {
      return source.watchMissions();
    }
    return (source as MultiMobilizationCoordinationReadRepository)
        .watchMissionsForMobilizations(context.mobilizationIds);
  }

  @override
  Stream<List<ResponsePlace>> watchLocations() {
    final ids = operationContext?.locationIds;
    if (ids == null) return source.watchLocations();
    if (ids.isEmpty) return Stream.value(const []);
    return source.watchLocations().map(
      (locations) => locations
          .where((location) => ids.contains(location.id))
          .toList(growable: false),
    );
  }

  @override
  Future<VolunteerProfile?> getVolunteerProfile() =>
      source.getVolunteerProfile();
  @override
  Future<void> saveVolunteerProfile(VolunteerProfile profile) => _blocked();
  @override
  Future<VolunteerProfile> confirmProfessionalRpps(
    ProfessionalVerificationResult verification,
  ) => _blocked();
  @override
  Stream<EngagementInfo?> watchMyEngagement(String missionId) =>
      source.watchMyEngagement(missionId);
  @override
  Stream<List<EngagementInfo>> watchMissionEngagements(String missionId) =>
      source.watchMissionEngagements(missionId);
  @override
  Future<void> updateEngagementStatus({
    required String missionId,
    required String volunteerId,
    required EngagementStatus status,
  }) => _blocked();
  @override
  Future<String> createMission(MissionDraft draft) => _blocked();
  @override
  Future<void> updateMission(String missionId, MissionDraft draft) =>
      _blocked();
  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() =>
      source.watchResponsibleAccess();
  @override
  Future<ResponsibleAccess> signInResponsible({
    required String email,
    required String password,
  }) => _blocked();
  @override
  Future<void> signOutResponsible() => _blocked();
  @override
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
  }) => _blocked();
  @override
  Future<void> cancelEngagement(String missionId) => _blocked();
  @override
  Future<void> cancelMission(String missionId, String? reason) => _blocked();
  @override
  Future<CoordinationNeed?> getMission(String missionId) async {
    final mission = await source.getMission(missionId);
    final ids = operationContext?.mobilizationIds;
    if (ids != null && !ids.contains(mission?.mobilizationId)) return null;
    return mission;
  }

  @override
  Stream<List<AppNotification>> watchNotifications() =>
      source.watchNotifications();
  @override
  Future<void> setNotificationRead(
    String notificationId, {
    required bool read,
  }) => _blocked();
  @override
  Stream<NotificationPreferences> watchNotificationPreferences() =>
      source.watchNotificationPreferences();
  @override
  Future<void> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) => _blocked();
  @override
  Future<void> registerPushSubscription(
    PushSubscriptionRegistration registration,
  ) => _blocked();
  @override
  Future<bool> hasActivePushSubscription(String installationId) {
    final repository = source;
    return repository is PushSubscriptionReadRepository
        ? (repository as PushSubscriptionReadRepository)
              .hasActivePushSubscription(installationId)
        : Future.value(false);
  }

  @override
  Future<void> disablePushSubscription(String installationId) => _blocked();
}

class ReadOnlyPreviewAdminInvitationRepository
    implements AdminInvitationRepository {
  const ReadOnlyPreviewAdminInvitationRepository(this.source);
  final AdminInvitationRepository source;
  Future<T> _blocked<T>() =>
      Future.error(const RepositoryException(readOnlyPreviewMessage));

  @override
  Stream<List<AdminInvitation>> watchInvitations() => source.watchInvitations();
  @override
  Future<AdminInvitation?> getInvitation(String invitationId) =>
      source.getInvitation(invitationId);
  @override
  Future<AdminInvitation> createInvitation(AdminInvitationDraft draft) =>
      _blocked();
  @override
  Future<void> cancelInvitation(String invitationId) => _blocked();
  @override
  Future<AdminInvitation> updateInvitation(
    String invitationId,
    AdminInvitationUpdate update,
  ) => _blocked();
  @override
  Future<void> reactivateInvitation(String invitationId, DateTime expiresAt) =>
      _blocked();
  @override
  Future<void> deleteInvitation(String invitationId) => _blocked();
  @override
  Future<AdminProvisioningResult> provisionInvitation(
    String invitationId, {
    bool resend = false,
  }) => _blocked();
}

class ReadOnlyPreviewLocationAdministrationRepository
    implements LocationAdministrationRepository {
  const ReadOnlyPreviewLocationAdministrationRepository(this.source);
  final LocationAdministrationRepository source;
  Future<T> _blocked<T>() =>
      Future.error(const RepositoryException(readOnlyPreviewMessage));

  @override
  Future<List<AdminLocation>> listLocations() => source.listLocations();
  @override
  Future<AdminLocation> createLocation(AdminLocationDraft draft) => _blocked();
  @override
  Future<AdminLocation> updateLocation(AdminLocationDraft draft) => _blocked();
  @override
  Future<AdminLocation> setLocationActive({
    required String locationId,
    required bool active,
  }) => _blocked();
  @override
  Future<void> deleteLocation(String locationId) => _blocked();
}

class ReadOnlyPreviewResponsibleAccessAdministrationRepository
    implements ResponsibleAccessAdministrationRepository {
  const ReadOnlyPreviewResponsibleAccessAdministrationRepository(this.source);
  final ResponsibleAccessAdministrationRepository source;

  @override
  Future<List<ResponsibleAccount>> listAccounts() => source.listAccounts();
  @override
  Future<ResponsibleAccount> updateAccess(ResponsibleAccessUpdate update) =>
      Future.error(const RepositoryException(readOnlyPreviewMessage));
}
