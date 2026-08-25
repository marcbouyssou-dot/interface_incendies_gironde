import 'dart:async';

import '../data/mock_data.dart';
import '../models/admin_location.dart';
import '../models/app_notification.dart';
import '../models/need.dart';
import '../models/professional_equipment.dart';
import '../models/professional_profile_validation.dart';
import '../models/profession_quotas.dart';
import '../models/volunteer_profile.dart';
import '../models/user_display_identity.dart';
import '../services/professional_verification_service.dart';
import '../utils/french_date_time.dart';
import 'admin_invitation_repository.dart';
import 'coordination_repository.dart';
import 'mock_admin_invitation_repository.dart';
import 'location_administration_repository.dart';
import 'mock_location_administration_repository.dart';
import 'mock_responsible_access_administration_repository.dart';
import 'responsible_access_administration_repository.dart';

class MockCoordinationRepository
    implements CoordinationRepository, PushSubscriptionReadRepository {
  MockCoordinationRepository({
    List<CoordinationNeed>? initialMissions,
    List<ResponsePlace>? initialLocations,
    List<EngagementInfo>? initialEngagements,
    Map<String, VolunteerProfile>? initialProfiles,
    List<AppNotification>? initialNotifications,
    AdminInvitationRepository? adminInvitationRepository,
    LocationAdministrationRepository? locationAdministrationRepository,
    ResponsibleAccessAdministrationRepository?
    responsibleAccessAdministrationRepository,
    this.volunteerUid = 'mock-volunteer',
    ResponsibleAccess? responsibleAccess = _mockAccess,
  }) : _missions = List.of(initialMissions ?? needs),
       _locations = List.of(initialLocations ?? places),
       missionEngagements = List.of(
         initialEngagements ?? _mockMissionEngagements,
       ),
       volunteerProfiles = Map.of(initialProfiles ?? const {}),
       notifications = List.of(initialNotifications ?? const []),
       _responsibleAccess = responsibleAccess,
       adminInvitationRepository =
           adminInvitationRepository ??
           MockAdminInvitationRepository(
             coordinatorUid: responsibleAccess?.uid ?? 'mock-coordinator',
           ),
       responsibleAccessAdministrationRepository =
           responsibleAccessAdministrationRepository ??
           MockResponsibleAccessAdministrationRepository(
             currentUid: responsibleAccess?.uid ?? 'mock-coordinator',
           ) {
    this.locationAdministrationRepository =
        locationAdministrationRepository ??
        MockLocationAdministrationRepository.fromResponsePlaces(
          _locations,
          onChanged: _replaceLocations,
        );
  }

  static final instance = MockCoordinationRepository();

  final List<CoordinationNeed> _missions;
  @override
  final AdminInvitationRepository adminInvitationRepository;
  @override
  late final LocationAdministrationRepository locationAdministrationRepository;
  @override
  final ResponsibleAccessAdministrationRepository
  responsibleAccessAdministrationRepository;
  final List<ResponsePlace> _locations;
  final ResponsibleAccess? _responsibleAccess;
  final String volunteerUid;
  final List<Volunteer> volunteers = [];
  final Map<String, VolunteerProfile> volunteerProfiles;
  final Map<String, EngagementInfo> engagements = {};
  final List<EngagementInfo> missionEngagements;
  final List<AppNotification> notifications;
  NotificationPreferences notificationPreferences =
      const NotificationPreferences();
  final Map<String, PushSubscriptionRegistration> pushSubscriptions = {};
  int pushSubscriptionReadCalls = 0;
  final _notificationUpdates =
      StreamController<List<AppNotification>>.broadcast();
  final _preferenceUpdates =
      StreamController<NotificationPreferences>.broadcast();

  final _missionUpdates = StreamController<List<CoordinationNeed>>.broadcast();
  final _locationUpdates = StreamController<List<ResponsePlace>>.broadcast();
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
      identity: UserDisplayIdentity(
        uid: 'mock-pending',
        displayName: 'Camille Martin',
        professionLabel: 'Masseur-Kinésithérapeute',
      ),
    ),
    EngagementInfo(
      missionId: 'mission-merignac',
      volunteerId: 'mock-confirmed',
      profession: VolunteerProfession.pp,
      identity: UserDisplayIdentity(
        uid: 'mock-confirmed',
        displayName: 'Marc BOUYSSOU',
        professionLabel: 'Pédicure-Podologue',
      ),
    ),
    EngagementInfo(
      missionId: 'mission-langon',
      volunteerId: 'mock-standby',
      profession: VolunteerProfession.mk,
      status: EngagementStatus.standby,
      identity: UserDisplayIdentity(
        uid: 'mock-standby',
        displayName: 'Sophie Bernard',
        professionLabel: 'Masseur-Kinésithérapeute',
      ),
    ),
    EngagementInfo(
      missionId: 'mission-libourne',
      volunteerId: 'mock-cancelled',
      profession: VolunteerProfession.pp,
      status: EngagementStatus.cancelled,
      identity: UserDisplayIdentity(
        uid: 'mock-cancelled',
        displayName: 'Alex Robin',
        professionLabel: 'Pédicure-Podologue',
      ),
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
  Stream<List<AppNotification>> watchNotifications() =>
      Stream.multi((controller) {
        controller.add(List.unmodifiable(notifications));
        final subscription = _notificationUpdates.stream.listen(controller.add);
        controller.onCancel = subscription.cancel;
      });

  @override
  Future<void> setNotificationRead(
    String notificationId, {
    required bool read,
  }) async {
    final index = notifications.indexWhere((item) => item.id == notificationId);
    if (index < 0) throw const RepositoryException('Notification introuvable.');
    final current = notifications[index];
    notifications[index] = AppNotification(
      id: current.id,
      eventId: current.eventId,
      type: current.type,
      title: current.title,
      body: current.body,
      occurredAt: current.occurredAt,
      missionId: current.missionId,
      engagementId: current.engagementId,
      readAt: read ? DateTime.now() : null,
    );
    _notificationUpdates.add(List.unmodifiable(notifications));
  }

  @override
  Future<CoordinationNeed?> getMission(String missionId) async =>
      debugMission(missionId);

  @override
  Stream<NotificationPreferences> watchNotificationPreferences() =>
      Stream.multi((controller) {
        controller.add(notificationPreferences);
        final subscription = _preferenceUpdates.stream.listen(controller.add);
        controller.onCancel = subscription.cancel;
      });

  @override
  Future<void> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    notificationPreferences = preferences;
    _preferenceUpdates.add(preferences);
  }

  @override
  Future<void> registerPushSubscription(
    PushSubscriptionRegistration registration,
  ) async {
    pushSubscriptions[registration.installationId] = registration;
  }

  @override
  Future<bool> hasActivePushSubscription(String installationId) async {
    pushSubscriptionReadCalls += 1;
    final registration = pushSubscriptions[installationId];
    return registration != null &&
        registration.platform == 'web' &&
        registration.token.trim().isNotEmpty;
  }

  @override
  Future<void> disablePushSubscription(String installationId) async {
    pushSubscriptions.remove(installationId);
  }

  @override
  Stream<List<CoordinationNeed>> watchMissions() {
    return Stream.multi((controller) {
      controller.add(_activeMissions());
      final subscription = _missionUpdates.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<VolunteerProfile?> getVolunteerProfile() async {
    final profile = volunteerProfiles[volunteerUid];
    if (profile == null) return null;
    return profile.copyWith(
      equipment: ProfessionalEquipmentRegistry.normalizeStoredValues(
        profile.equipment,
      ),
    );
  }

  @override
  Future<void> saveVolunteerProfile(VolunteerProfile profile) async {
    _validateProfileFields(
      email: profile.email,
      professionalIdType: profile.effectiveProfessionalIdType,
      professionalIdValue: profile.effectiveProfessionalIdValue,
      cptsId: profile.cptsId,
      cptsLabel: profile.cptsLabel,
      professionalAddressLine1: profile.professionalAddressLine1,
      professionalAddressLine2: profile.professionalAddressLine2,
      professionalPostalCode: profile.professionalPostalCode,
      professionalCity: profile.professionalCity,
      professionalCountryCode: profile.professionalCountryCode,
      equipment: profile.equipment,
      otherEquipmentDetails: profile.otherEquipmentDetails,
    );
    if (profile.uid.isNotEmpty && profile.uid != volunteerUid) {
      throw const RepositoryException(
        'Ce profil n’appartient pas à la session volontaire active.',
      );
    }
    final existing = volunteerProfiles[volunteerUid];
    final preservesVerification =
        ProfessionalProfileValidation.preservesVerification(
          existing: existing,
          profession: profile.profession,
          professionalIdType: profile.effectiveProfessionalIdType,
          professionalIdValue: profile.effectiveProfessionalIdValue,
        );
    final now = DateTime.now();
    volunteerProfiles[volunteerUid] = VolunteerProfile(
      uid: volunteerUid,
      firstName: profile.firstName.trim(),
      lastName: profile.lastName.trim(),
      phone: profile.phone.trim(),
      email: _nullableTrim(profile.email),
      rpps: profile.effectiveProfessionalIdType == ProfessionalIdType.rpps
          ? _normalizeRpps(profile.effectiveProfessionalIdValue)
          : null,
      professionalIdType: profile.effectiveProfessionalIdType,
      professionalIdValue: normalizeProfessionalIdentifier(
        profile.effectiveProfessionalIdType,
        profile.effectiveProfessionalIdValue,
      ),
      cptsId: _nullableTrim(profile.cptsId),
      cptsLabel: _nullableTrim(profile.cptsLabel),
      professionalAddressLine1: profile.professionalAddress.normalizedLine1,
      professionalAddressLine2: profile.professionalAddress.normalizedLine2,
      professionalPostalCode: profile.professionalAddress.normalizedPostalCode,
      professionalCity: profile.professionalAddress.normalizedCity,
      professionalCountryCode:
          profile.professionalAddress.normalizedCountryCode,
      profession: profile.profession,
      equipment: ProfessionalEquipmentRegistry.normalizeStoredValues(
        profile.equipment,
      ),
      otherEquipmentDetails: _nullableTrim(profile.otherEquipmentDetails),
      verificationStatus: preservesVerification ? 'verified' : 'unverified',
      verificationSource: preservesVerification
          ? existing?.verificationSource
          : null,
      verifiedFirstName: preservesVerification
          ? existing?.verifiedFirstName
          : null,
      verifiedLastName: preservesVerification
          ? existing?.verifiedLastName
          : null,
      verifiedProfessionCode: preservesVerification
          ? existing?.verifiedProfessionCode
          : null,
      verifiedProfessionLabel: preservesVerification
          ? existing?.verifiedProfessionLabel
          : null,
      verifiedAt: preservesVerification ? existing?.verifiedAt : null,
      profileSchemaVersion:
          profile.profileSchemaVersion ?? existing?.profileSchemaVersion,
      competencies: profile.competencies ?? existing?.competencies,
      mobilizationPreferences:
          profile.mobilizationPreferences ?? existing?.mobilizationPreferences,
      communicationPreferences:
          profile.communicationPreferences ??
          existing?.communicationPreferences,
      consentRecords: profile.consentRecords ?? existing?.consentRecords,
      createdAt: existing?.createdAt ?? profile.createdAt ?? now,
      updatedAt: now,
    );
  }

  @override
  Future<VolunteerProfile> confirmProfessionalRpps(
    ProfessionalVerificationResult verification,
  ) async {
    final existing = volunteerProfiles[volunteerUid];
    if (existing == null ||
        verification.status != ProfessionalVerificationStatus.verified ||
        !_professionMatchesCode(
          existing.profession,
          verification.professionCode,
        )) {
      throw const RepositoryException(
        'La confirmation du RPPS n’a pas abouti.',
      );
    }
    final now = DateTime.now();
    final verified = VolunteerProfile(
      uid: existing.uid,
      firstName: existing.firstName,
      lastName: existing.lastName,
      phone: existing.phone,
      email: existing.email,
      rpps: verification.rpps,
      professionalIdType: ProfessionalIdType.rpps,
      professionalIdValue: verification.rpps,
      cptsId: existing.cptsId,
      cptsLabel: existing.cptsLabel,
      professionalAddressLine1: existing.professionalAddressLine1,
      professionalAddressLine2: existing.professionalAddressLine2,
      professionalPostalCode: existing.professionalPostalCode,
      professionalCity: existing.professionalCity,
      professionalCountryCode: existing.professionalCountryCode,
      profession: existing.profession,
      equipment: existing.equipment,
      otherEquipmentDetails: existing.otherEquipmentDetails,
      verificationStatus: 'verified',
      verificationSource: 'ans_rpps',
      verifiedFirstName: verification.firstName.trim(),
      verifiedLastName: verification.lastName.trim(),
      verifiedProfessionCode: verification.professionCode.trim(),
      verifiedProfessionLabel: verification.professionLabel.trim(),
      verifiedAt: now,
      profileSchemaVersion: existing.profileSchemaVersion,
      competencies: existing.competencies,
      mobilizationPreferences: existing.mobilizationPreferences,
      communicationPreferences: existing.communicationPreferences,
      consentRecords: existing.consentRecords,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    volunteerProfiles[volunteerUid] = verified;
    return verified;
  }

  static bool _professionMatchesCode(
    VolunteerProfession profession,
    String code,
  ) => switch (profession) {
    VolunteerProfession.doctor => code == '10',
    VolunteerProfession.nurse => code == '60',
    VolunteerProfession.mk => code == '70',
    VolunteerProfession.pp => code == '80',
    VolunteerProfession.veterinarian ||
    VolunteerProfession.otherHealthProfessional => false,
  };

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
          missionEngagements
              .where((engagement) => engagement.missionId == missionId)
              .map(_withDisplayIdentity),
        ),
      );
      emit(null);
      final subscription = _missionUpdates.stream.listen(emit);
      controller.onCancel = subscription.cancel;
    });
  }

  EngagementInfo _withDisplayIdentity(EngagementInfo engagement) {
    if (engagement.identity != null) return engagement;
    final profile = volunteerProfiles[engagement.volunteerId];
    final identity = profile == null
        ? UserDisplayIdentity(
            uid: engagement.volunteerId,
            displayName: 'Professionnel',
            professionLabel: engagement.profession.label,
          )
        : UserDisplayIdentity(
            uid: profile.uid,
            displayName: profile.displayName.isEmpty
                ? 'Professionnel'
                : profile.displayName,
            professionLabel:
                profile.verifiedProfessionLabel?.trim().isNotEmpty == true
                ? profile.verifiedProfessionLabel!.trim()
                : profile.profession.label,
            organizationLabel: profile.cptsLabel,
          );
    return engagement.copyWith(identity: identity);
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
      final delta = EngagementCounterTransition.amount(
        from: engagement.status,
        to: status,
      );
      final professionId = engagement.profession.canonicalId!;
      final quota = mission.professionQuotas.quotaFor(professionId);
      if (delta > 0 && quota.registered >= quota.required) {
        throw const RepositoryException(
          'Le quota de cette profession est déjà atteint.',
        );
      }
      _missions[missionIndex] = mission.withProfessionQuotas(
        mission.professionQuotas.updateRegistered(professionId, delta),
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
      final delta = EngagementCounterTransition.amount(
        from: engagement.status,
        to: status,
      );
      final professionId = engagement.profession.canonicalId!;
      if (delta < 0 &&
          mission.professionQuotas.quotaFor(professionId).registered <= 0) {
        throw const RepositoryException(
          'Le compteur correspondant est déjà à zéro.',
        );
      }
      _missions[missionIndex] = mission.withProfessionQuotas(
        mission.professionQuotas.updateRegistered(professionId, delta),
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
    return Stream.multi((controller) {
      controller.add(List.unmodifiable(_locations));
      final subscription = _locationUpdates.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    });
  }

  void _replaceLocations(List<AdminLocation> locations) {
    final existing = {for (final location in _locations) location.id: location};
    _locations
      ..clear()
      ..addAll(
        locations.map((location) {
          final previous = existing[location.id];
          final hasAddress = [
            location.addressLine1,
            location.addressLine2,
            location.postalCode,
            location.city,
          ].any((value) => value?.trim().isNotEmpty == true);
          return ResponsePlace(
            id: location.id,
            name: location.name,
            type: location.type,
            group: location.group,
            activeNeeds: previous?.activeNeeds ?? 0,
            structuredAddress: LocationAddress(
              addressLine1: location.addressLine1,
              addressLine2: location.addressLine2,
              postalCode: location.postalCode,
              city: location.city,
              country: location.country,
              latitude: location.latitude,
              longitude: location.longitude,
              status:
                  previous?.structuredAddress?.status ??
                  (hasAddress
                      ? AddressStatus.needsConfirmation
                      : AddressStatus.notFound),
              sourceUrl: previous?.structuredAddress?.sourceUrl,
              sourceLabel: previous?.structuredAddress?.sourceLabel,
              secondSourceUrl: previous?.structuredAddress?.secondSourceUrl,
              secondSourceLabel: previous?.structuredAddress?.secondSourceLabel,
              verifiedAt: previous?.structuredAddress?.verifiedAt,
              notes: previous?.structuredAddress?.notes,
            ),
            contactName: location.contactName,
            contactPhone: location.contactPhone,
            isOperational: location.isOperational,
            isEnabled: location.active,
          );
        }),
      );
    _locationUpdates.add(List.unmodifiable(_locations));
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
      date: FrenchDateTime.date(draft.startAt),
      time: FrenchDateTime.timeRange(draft.startAt, draft.endAt),
      startAt: draft.startAt,
      endAt: draft.endAt,
      requiredPhysiotherapists: draft.requiredPhysiotherapists,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: draft.requiredPodiatrists,
      registeredPodiatrists: 0,
      professionQuotas: draft.professionQuotas,
      equipment: List.of(draft.equipment),
      priority: draft.priority,
      details: draft.details,
      createdBy: _responsibleAccess?.uid,
    );
    _missions.add(mission);
    _missionUpdates.add(_activeMissions());
    return id;
  }

  @override
  Future<void> updateMission(String missionId, MissionDraft draft) async {
    final access = _responsibleAccess;
    final index = _missions.indexWhere((mission) => mission.id == missionId);
    if (index < 0) throw const RepositoryException('Mission introuvable.');
    final mission = _missions[index];
    final sourceLocationId = mission.locationId;
    if (access == null ||
        !access.active ||
        (!access.isCoordinator &&
            (sourceLocationId == null ||
                !access.canManage(sourceLocationId))) ||
        !access.canManage(draft.location.id)) {
      throw const RepositoryException(
        'Vous ne pouvez modifier que les missions de vos centres.',
      );
    }
    if (!mission.isActive || mission.isCancelled) {
      throw const RepositoryException(
        'Cette mission ne peut plus être modifiée.',
      );
    }
    final changesLocation = draft.location.id != sourceLocationId;
    if (changesLocation &&
        (!draft.location.isEnabled || !draft.location.isOperational)) {
      throw const RepositoryException('Le lieu sélectionné est inactif.');
    }
    for (final quota in draft.professionQuotas.values) {
      final confirmed = missionEngagements
          .where(
            (engagement) =>
                engagement.missionId == missionId &&
                engagement.status == EngagementStatus.confirmed &&
                engagement.profession.canonicalId == quota.professionId,
          )
          .length;
      final minimum = mission.professionQuotas
          .quotaFor(quota.professionId)
          .registered
          .clamp(confirmed, 1 << 31);
      if (quota.required < minimum) {
        throw const RepositoryException(
          'Le besoin ne peut pas être inférieur aux engagements confirmés.',
        );
      }
    }
    final quotas = ProfessionQuotas.fromMaps(
      requiredByProfession: draft.requiredByProfession,
      registeredByProfession: mission.professionQuotas.registeredByProfession,
    );
    final mk = quotas.quotaFor('physiotherapist');
    final pp = quotas.quotaFor('podiatrist');
    _missions[index] = CoordinationNeed(
      id: mission.id,
      locationId: draft.location.id,
      place: draft.location.name,
      group: draft.location.group,
      date: FrenchDateTime.date(draft.startAt),
      time: FrenchDateTime.timeRange(draft.startAt, draft.endAt),
      startAt: draft.startAt,
      endAt: draft.endAt,
      requiredPhysiotherapists: mk.required,
      registeredPhysiotherapists: mk.registered,
      requiredPodiatrists: pp.required,
      registeredPodiatrists: pp.registered,
      professionQuotas: quotas,
      equipment: List.of(draft.equipment),
      priority: draft.priority,
      details: draft.details.trim(),
      isActive: mission.isActive,
      isCancelled: mission.isCancelled,
      cancelledAt: mission.cancelledAt,
      cancelledBy: mission.cancelledBy,
      cancellationReason: mission.cancellationReason,
      createdBy: mission.createdBy,
    );
    _missionUpdates.add(_activeMissions());
  }

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
  }) async {
    final resolvedProfessionalIdType =
        professionalIdType ??
        ((rpps?.trim().isNotEmpty ?? false)
            ? ProfessionalIdType.rpps
            : ProfessionalIdType.none);
    final resolvedProfessionalIdValue = professionalIdValue ?? rpps ?? '';
    if (!isValidProfessionalIdentifier(
      resolvedProfessionalIdType,
      resolvedProfessionalIdValue,
    )) {
      throw const RepositoryException(
        'Complétez votre profil avec un numéro RPPS ou ordinal avant de '
        'participer.',
      );
    }
    _validateProfileFields(
      email: email,
      professionalIdType: resolvedProfessionalIdType,
      professionalIdValue: resolvedProfessionalIdValue,
      cptsId: cptsId,
      cptsLabel: cptsLabel,
      equipment: equipment,
      otherEquipmentDetails: otherEquipmentDetails,
    );
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
        existingEngagement.volunteerId != volunteerUid) {
      throw const RepositoryException(
        'Cet engagement appartient à un autre volontaire.',
      );
    }
    if (existingEngagement != null &&
        existingEngagement.status != EngagementStatus.cancelled &&
        existingEngagement.status != EngagementStatus.pending) {
      return switch (existingEngagement.status) {
        EngagementStatus.pending => throw StateError('État inaccessible'),
        EngagementStatus.confirmed => EngagementCreationResult.alreadyConfirmed,
        EngagementStatus.standby => EngagementCreationResult.alreadyStandby,
        EngagementStatus.cancelled => throw StateError('État inaccessible'),
      };
    }
    final professionId = profession.canonicalId!;
    final quota = mission.professionQuotas.quotaFor(professionId);
    final hasAvailableQuota = quota.registered < quota.required;
    if (!hasAvailableQuota) {
      throw const RepositoryException(
        'Ce besoin est désormais couvert pour votre profession.',
      );
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
    final existingProfile = volunteerProfiles[volunteerUid];
    final preservesVerification =
        ProfessionalProfileValidation.preservesVerification(
          existing: existingProfile,
          profession: profession,
          professionalIdType: resolvedProfessionalIdType,
          professionalIdValue: resolvedProfessionalIdValue,
        );
    final now = DateTime.now();
    volunteerProfiles[volunteerUid] = VolunteerProfile(
      uid: volunteerUid,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: phone.trim(),
      email: _nullableTrim(email),
      rpps: resolvedProfessionalIdType == ProfessionalIdType.rpps
          ? _normalizeRpps(resolvedProfessionalIdValue)
          : null,
      professionalIdType: resolvedProfessionalIdType,
      professionalIdValue: normalizeProfessionalIdentifier(
        resolvedProfessionalIdType,
        resolvedProfessionalIdValue,
      ),
      cptsId: _nullableTrim(cptsId),
      cptsLabel: _nullableTrim(cptsLabel),
      professionalAddressLine1: existingProfile?.professionalAddressLine1,
      professionalAddressLine2: existingProfile?.professionalAddressLine2,
      professionalPostalCode: existingProfile?.professionalPostalCode,
      professionalCity: existingProfile?.professionalCity,
      professionalCountryCode: existingProfile?.professionalCountryCode ?? 'FR',
      profession: profession,
      equipment: ProfessionalEquipmentRegistry.normalizeStoredValues(equipment),
      otherEquipmentDetails: _nullableTrim(otherEquipmentDetails),
      verificationStatus: preservesVerification ? 'verified' : 'unverified',
      verificationSource: preservesVerification
          ? existingProfile?.verificationSource
          : null,
      verifiedFirstName: preservesVerification
          ? existingProfile?.verifiedFirstName
          : null,
      verifiedLastName: preservesVerification
          ? existingProfile?.verifiedLastName
          : null,
      verifiedProfessionCode: preservesVerification
          ? existingProfile?.verifiedProfessionCode
          : null,
      verifiedProfessionLabel: preservesVerification
          ? existingProfile?.verifiedProfessionLabel
          : null,
      verifiedAt: preservesVerification ? existingProfile?.verifiedAt : null,
      profileSchemaVersion: existingProfile?.profileSchemaVersion,
      competencies: existingProfile?.competencies,
      mobilizationPreferences: existingProfile?.mobilizationPreferences,
      communicationPreferences: existingProfile?.communicationPreferences,
      consentRecords: existingProfile?.consentRecords,
      createdAt: existingProfile?.createdAt ?? now,
      updatedAt: now,
    );
    final engagement = EngagementInfo(
      missionId: missionId,
      volunteerId: volunteerUid,
      profession: profession,
      status: EngagementStatus.confirmed,
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
    _missions[index] = mission.withProfessionQuotas(
      mission.professionQuotas.updateRegistered(professionId, 1),
    );
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
      final professionId = engagement.profession.canonicalId!;
      if (mission.professionQuotas.quotaFor(professionId).registered <= 0) {
        throw const RepositoryException(
          'Le désengagement n’a pas pu être enregistré. Réessayez.',
        );
      }
      _missions[index] = mission.withProfessionQuotas(
        mission.professionQuotas.updateRegistered(professionId, -1),
      );
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
    if (_responsibleAccess == null ||
        mission.createdBy != _responsibleAccess.uid) {
      throw const RepositoryException(
        'Seul le responsable ayant créé ce besoin peut l’annuler.',
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
      cancelledBy: _responsibleAccess.uid,
      cancellationReason: reason?.trim(),
      createdBy: mission.createdBy,
    );
    _missionUpdates.add(_activeMissions());
  }

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _normalizeRpps(String? value) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), '');
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static void _validateProfileFields({
    required String? email,
    required ProfessionalIdType professionalIdType,
    required String professionalIdValue,
    required String? cptsId,
    required String? cptsLabel,
    String? professionalAddressLine1,
    String? professionalAddressLine2,
    String? professionalPostalCode,
    String? professionalCity,
    String professionalCountryCode = 'FR',
    List<String> equipment = const [],
    String? otherEquipmentDetails,
  }) {
    final error = ProfessionalProfileValidation.persistenceError(
      email: email,
      professionalIdType: professionalIdType,
      professionalIdValue: professionalIdValue,
      cptsId: cptsId,
      cptsLabel: cptsLabel,
      professionalAddressLine1: professionalAddressLine1,
      professionalAddressLine2: professionalAddressLine2,
      professionalPostalCode: professionalPostalCode,
      professionalCity: professionalCity,
      professionalCountryCode: professionalCountryCode,
      equipment: equipment,
      otherEquipmentDetails: otherEquipmentDetails,
    );
    if (error != null) throw RepositoryException(error);
  }
}
