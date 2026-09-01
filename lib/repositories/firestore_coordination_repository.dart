import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/health_profession.dart';
import '../models/app_notification.dart';
import '../models/mobilization_context.dart';
import '../models/mobilization.dart';
import '../models/need.dart';
import '../models/platform_administrator_access.dart';
import '../models/professional_equipment.dart';
import '../models/professional_profile_validation.dart';
import '../models/profession_quotas.dart';
import '../models/volunteer_profile.dart';
import '../models/user_display_identity.dart';
import '../services/professional_verification_service.dart';
import '../services/accessible_mobilizations_provider.dart';
import '../services/current_mobilization_provider.dart';
import '../services/firebase_platform_administration_service.dart';
import '../services/operational_context_provider.dart';
import '../services/platform_administration_service.dart';
import '../services/push_token_chain_diagnostic.dart';
import '../utils/switch_latest.dart';
import 'admin_invitation_repository.dart';
import 'coordination_repository.dart';
import 'firestore_admin_invitation_repository.dart';
import 'firestore_location_mapper.dart';
import 'firestore_location_administration_repository.dart';
import 'firestore_mission_mapper.dart';
import 'firestore_operation_read_repository.dart';
import 'firestore_organization_read_repository.dart';
import 'organization_read_repository.dart';
import 'firestore_platform_administration_read_repository.dart';
import 'firebase_platform_actor_read_repository.dart';
import 'firestore_platform_read_repository.dart';
import 'professional_profile_v2_firestore_mapper.dart';
import 'firestore_responsible_access_administration_repository.dart';
import 'responsible_access_administration_repository.dart';
import 'location_administration_repository.dart';
import 'location_read_repository.dart';
import 'operation_read_repository.dart';
import 'platform_administration_read_repository.dart';
import 'platform_actor_read_repository.dart';
import 'platform_read_repository.dart';
import 'platform_runtime.dart';
import 'public_mobilization_read_repository.dart';
import 'user_display_identity_resolver.dart';

@visibleForTesting
bool canStartVolunteerEngagement({
  required bool hasUser,
  required bool isAnonymous,
}) => !hasUser || isAnonymous;

@visibleForTesting
ResponsibleAccess parseResponsibleAccessDocument({
  required String uid,
  required Map<String, Object?> data,
}) => ResponsibleAccessParser.parse(uid: uid, data: data);

@visibleForTesting
({bool ownerMatches, EngagementCreationResult? result})
classifyExistingEngagement(Map<String, dynamic> data, String uid) {
  if (data['volunteerId'] != uid) {
    return (ownerMatches: false, result: null);
  }
  final status = data['status'];
  return (
    ownerMatches: true,
    result: switch (status) {
      'cancelled' => null,
      'pending' => EngagementCreationResult.alreadyPending,
      'standby' => EngagementCreationResult.alreadyStandby,
      _ => EngagementCreationResult.alreadyConfirmed,
    },
  );
}

typedef MobilizationScopedDocument = ({String id, Map<String, dynamic> data});

@visibleForTesting
MobilizationContext requireActiveMobilizationContext(
  MobilizationContext? context,
) {
  if (context == null || !context.isActive) {
    throw const RepositoryException(
      'Aucune mobilisation active n’est disponible.',
    );
  }
  return context;
}

@visibleForTesting
List<CoordinationNeed> scopedMissionsFromDocuments({
  required Iterable<MobilizationScopedDocument> documents,
  required MobilizationContext context,
}) {
  final missions = documents
      .where(
        (document) =>
            document.data['mobilizationId'] == context.mobilizationId &&
            document.data['isActive'] == true,
      )
      .map(
        (document) => FirestoreMissionMapper.fromFirestore(
          id: document.id,
          data: document.data,
        ),
      )
      .where((mission) => mission.isActive)
      .toList();
  missions.sort((left, right) {
    final leftDate = left.startAt;
    final rightDate = right.startAt;
    if (leftDate == null && rightDate == null) {
      return left.id.compareTo(right.id);
    }
    if (leftDate == null) return 1;
    if (rightDate == null) return -1;
    return leftDate.compareTo(rightDate);
  });
  return missions;
}

@visibleForTesting
List<CoordinationNeed> multiScopedMissionsFromDocuments({
  required Iterable<MobilizationScopedDocument> documents,
  Set<String>? mobilizationIds,
  Set<String>? locationIds,
}) {
  final missions = documents
      .where(
        (document) =>
            document.data['isActive'] == true &&
            (mobilizationIds == null ||
                mobilizationIds.contains(document.data['mobilizationId'])) &&
            (locationIds == null ||
                locationIds.contains(document.data['locationId'])),
      )
      .map(
        (document) => FirestoreMissionMapper.fromFirestore(
          id: document.id,
          data: document.data,
        ),
      )
      .where((mission) => mission.isActive)
      .toList(growable: false);
  missions.sort((left, right) {
    final leftDate = left.startAt;
    final rightDate = right.startAt;
    if (leftDate == null && rightDate == null) {
      return left.id.compareTo(right.id);
    }
    if (leftDate == null) return 1;
    if (rightDate == null) return -1;
    return leftDate.compareTo(rightDate);
  });
  return missions;
}

@visibleForTesting
List<EngagementInfo> scopedEngagementsFromDocuments({
  required Iterable<MobilizationScopedDocument> documents,
  required String missionId,
  required MobilizationContext context,
}) {
  return documents
      .where(
        (document) =>
            document.data['missionId'] == missionId &&
            document.data['mobilizationId'] == context.mobilizationId,
      )
      .map((document) {
        final data = document.data;
        final profession = data['profession'] as String?;
        if (profession == null) return null;
        final VolunteerProfession parsedProfession;
        try {
          parsedProfession = volunteerProfessionFromId(profession);
        } on FormatException {
          return null;
        }
        return EngagementInfo(
          missionId: missionId,
          volunteerId: data['volunteerId'] as String? ?? '',
          profession: parsedProfession,
          status: FirestoreCoordinationRepository._engagementStatus(
            data['status'],
          ),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        );
      })
      .whereType<EngagementInfo>()
      .toList(growable: false);
}

@visibleForTesting
void requireDocumentsInActiveMobilization({
  required MobilizationContext context,
  required Map<String, dynamic> mission,
  Map<String, dynamic>? engagement,
}) {
  if (!context.isActive ||
      mission['mobilizationId'] != context.mobilizationId ||
      (engagement != null &&
          engagement['mobilizationId'] != context.mobilizationId) ||
      (engagement != null && engagement['missionId'] != mission['id'])) {
    throw const RepositoryException(
      'Cette opération n’appartient pas à la mobilisation active.',
    );
  }
}

@visibleForTesting
String requireMatchingMobilizationId({
  required Map<String, dynamic> mission,
  Map<String, dynamic>? engagement,
}) {
  final mobilizationId = mission['mobilizationId'];
  if (mobilizationId is! String ||
      mobilizationId.trim().isEmpty ||
      mobilizationId.contains('/') ||
      (engagement != null && engagement['mobilizationId'] != mobilizationId) ||
      (engagement != null && engagement['missionId'] != mission['id'])) {
    throw const RepositoryException(
      'Cette opération n’appartient pas à la mission.',
    );
  }
  return mobilizationId;
}

class FirestoreCoordinationRepository
    implements
        CoordinationRepository,
        PushSubscriptionReadRepository,
        PushActivationPersistenceRepository,
        AdministrativeIdentityReadRepository,
        OrganizationEngagementReadDataSource,
        OrganizationLocationReadDataSource,
        MultiMobilizationCoordinationReadRepository,
        MobilizationLocationMissionReadRepository,
        MultiMobilizationCoordinationMutationRepository,
        PlatformRuntime,
        MultiOperationPlatformRuntime,
        PlatformActorRuntime,
        OrganizationRuntime,
        PlatformAccountAuthenticator {
  FirestoreCoordinationRepository(
    this._firestore,
    this._auth, {
    required MobilizationContextProvider mobilizationProvider,
    FirebaseFirestore? responsibleFirestore,
    FirebaseAuth? responsibleAuth,
    FirebaseFunctions? responsibleFunctions,
    FirebaseFunctions? volunteerFunctions,
  }) : _mobilizationProvider = mobilizationProvider,
       _responsibleFirestore = responsibleFirestore ?? _firestore,
       _responsibleAuth = responsibleAuth ?? _auth,
       _responsibleFunctions =
           responsibleFunctions ??
           FirebaseFunctions.instanceFor(
             app: (responsibleAuth ?? _auth).app,
             region: 'europe-west1',
           ),
       _volunteerFunctions =
           volunteerFunctions ??
           FirebaseFunctions.instanceFor(
             app: _auth.app,
             region: 'europe-west1',
           ) {
    _identityResolver = FirebaseUserDisplayIdentityResolver(
      functions: _responsibleFunctions,
    );
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final MobilizationContextProvider _mobilizationProvider;
  final FirebaseFirestore _responsibleFirestore;
  final FirebaseAuth _responsibleAuth;
  final FirebaseFunctions _responsibleFunctions;
  final FirebaseFunctions _volunteerFunctions;
  late final UserDisplayIdentityResolver _identityResolver;
  late final PublicMobilizationReadRepository _publicMobilizationRepository =
      PublicMobilizationReadRepository(
        dataSource: FirestorePublicMobilizationReadDataSource(_firestore),
      );

  FirebaseAuth get _notificationAuth =>
      _responsibleAuth.currentUser?.isAnonymous == false
      ? _responsibleAuth
      : _auth;

  FirebaseFirestore get _notificationFirestore =>
      identical(_notificationAuth, _responsibleAuth)
      ? _responsibleFirestore
      : _firestore;

  String get _notificationUid {
    final uid = _notificationAuth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const RepositoryException('Authentification requise.');
    }
    return uid;
  }

  @override
  late final PlatformReadRepository platformReadRepository =
      FirestorePlatformReadRepository.withFirebase(
        firestore: _responsibleFirestore,
      );

  @override
  late final MobilizationContextProvider currentMobilizationProvider =
      CurrentMobilizationProvider(repository: platformReadRepository);

  @override
  late final PlatformAdministrationReadRepository
  platformAdministrationReadRepository =
      FirestorePlatformAdministrationReadRepository(
        auth: _responsibleAuth,
        firestore: _responsibleFirestore,
        identityResolver: _identityResolver,
      );

  @override
  late final PlatformAdministrationService platformAdministrationService =
      FirebasePlatformAdministrationService(
        functions: _responsibleFunctions,
        auth: _responsibleAuth,
      );

  @override
  late final OperationReadRepository operationReadRepository =
      FirestoreOperationReadRepository(_responsibleFirestore);

  @override
  late final OrganizationReadRepository organizationReadRepository =
      FirestoreOrganizationReadRepository.withFirestore(_responsibleFirestore);

  @override
  late final PlatformActorReadRepository platformActorReadRepository =
      FirebasePlatformActorReadRepository(
        auth: _responsibleAuth,
        functions: _responsibleFunctions,
      );

  @override
  late final AccessibleMobilizationsProvider accessibleMobilizationsProvider =
      DefaultAccessibleMobilizationsProvider(
        dataSource: FirestoreAccessibleMobilizationsDataSource(
          auth: _responsibleAuth,
          firestore: _responsibleFirestore,
        ),
      );

  @override
  late final OperationalContextProvider operationalContextProvider =
      DefaultOperationalContextProvider(
        FirestoreOperationalContextDataSource(_firestore),
      );

  Future<MobilizationContext> _requireActiveMobilization() async {
    try {
      final context = await _mobilizationProvider.watchContext().first.timeout(
        const Duration(seconds: 15),
      );
      return requireActiveMobilizationContext(context);
    } on RepositoryException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Échec lecture mobilisation active : $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const RepositoryException(
        'La mobilisation active est momentanément indisponible.',
      );
    }
  }

  @override
  late final AdminInvitationRepository adminInvitationRepository =
      FirestoreAdminInvitationRepository.withFirebase(
        firestore: _responsibleFirestore,
        auth: _responsibleAuth,
      );
  @override
  late final LocationAdministrationRepository locationAdministrationRepository =
      FirestoreLocationAdministrationRepository.withFirebase(
        auth: _responsibleAuth,
      );
  @override
  late final ResponsibleAccessAdministrationRepository
  responsibleAccessAdministrationRepository =
      FirestoreResponsibleAccessAdministrationRepository.withFirebase(
        auth: _responsibleAuth,
      );

  @override
  Stream<String?> watchAdministrativeUid() => _responsibleAuth
      .authStateChanges()
      .map((user) => user == null || user.isAnonymous ? null : user.uid)
      .distinct();

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() {
    return switchLatest(_responsibleAuth.authStateChanges(), (user) {
      if (user == null || user.isAnonymous) {
        return Stream<ResponsibleAccess?>.value(null);
      }
      return _responsibleFirestore
          .collection('roles')
          .doc(user.uid)
          .snapshots()
          .map((snapshot) {
            return ResponsibleAccessParser.parseOptional(
              uid: user.uid,
              data: snapshot.data(),
            );
          });
    });
  }

  @override
  Future<ResponsibleAccess> signInResponsible({
    required String email,
    required String password,
  }) async {
    final result = await _authenticateAdministrativeAccount(
      email: email,
      password: password,
      allowPlatformAdministrator: false,
    );
    return result.access!;
  }

  @override
  Future<void> signInPlatformOrResponsible({
    required String email,
    required String password,
  }) async {
    await _authenticateAdministrativeAccount(
      email: email,
      password: password,
      allowPlatformAdministrator: true,
    );
  }

  Future<({ResponsibleAccess? access, bool platformAdministrator})>
  _authenticateAdministrativeAccount({
    required String email,
    required String password,
    required bool allowPlatformAdministrator,
  }) async {
    try {
      final credential = await _responsibleAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const RepositoryException('Identifiants incorrects.');
      }
      final snapshots = await Future.wait([
        _responsibleFirestore.collection('roles').doc(user.uid).get(),
        _responsibleFirestore
            .collection('platformAdministrators')
            .doc(user.uid)
            .get(),
      ]);
      final roleSnapshot = snapshots[0];
      final administratorSnapshot = snapshots[1];
      var platformAdministrator = false;
      final administratorData = administratorSnapshot.data();
      if (administratorSnapshot.exists && administratorData != null) {
        try {
          platformAdministrator = PlatformAdministratorAccess.fromMap(
            uid: user.uid,
            data: administratorData,
          ).active;
        } on FormatException catch (error, stackTrace) {
          debugPrint('Autorisation plateforme invalide : $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      if (allowPlatformAdministrator && platformAdministrator) {
        return (access: null, platformAdministrator: true);
      }
      if (!roleSnapshot.exists) {
        await _restoreAnonymousSession();
        throw const RepositoryException(
          'Votre compte n’est pas autorisé à publier pour ce lieu.',
        );
      }
      late final ResponsibleAccess access;
      try {
        access = parseResponsibleAccessDocument(
          uid: user.uid,
          data: roleSnapshot.data()!,
        );
      } on ResponsibleAccessFormatException catch (error, stackTrace) {
        await _restoreAnonymousSession();
        debugPrint('Autorisation responsable invalide (${error.code.name})');
        debugPrintStack(stackTrace: stackTrace);
        throw const RepositoryException(
          'Votre autorisation responsable est invalide. '
          'Contactez la coordination.',
        );
      }
      if (!access.active) {
        await _restoreAnonymousSession();
        throw const RepositoryException(
          'Votre compte responsable est inactif.',
        );
      }
      if (!access.hasPrivilegedAccess) {
        await _restoreAnonymousSession();
        throw const RepositoryException(
          'Votre compte n’est pas autorisé à publier pour ce lieu.',
        );
      }
      return (access: access, platformAdministrator: platformAdministrator);
    } on RepositoryException {
      rethrow;
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint('Échec connexion responsable (${error.code})');
      debugPrintStack(stackTrace: stackTrace);
      throw const RepositoryException('Identifiants incorrects.');
    }
  }

  @override
  Future<void> signOutResponsible() => _restoreAnonymousSession();

  Future<void> _restoreAnonymousSession() async {
    await _responsibleAuth.signOut();
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  @override
  Stream<List<CoordinationNeed>> watchMissions() {
    return switchLatest(_mobilizationProvider.watchContext(), (context) {
      if (context == null || !context.isActive) {
        return Stream<List<CoordinationNeed>>.value(const []);
      }
      return _firestore
          .collection('missions')
          .where('mobilizationId', isEqualTo: context.mobilizationId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map(
            (snapshot) => scopedMissionsFromDocuments(
              documents: snapshot.docs.map(
                (document) => (id: document.id, data: document.data()),
              ),
              context: context,
            ),
          );
    });
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> mobilizationIds,
  ) {
    final ids = _validatedQueryIds(mobilizationIds, 'mobilisation');
    if (ids.isEmpty) return Stream<List<CoordinationNeed>>.value(const []);
    return _watchMissionsInMobilizationBatches(_responsibleFirestore, ids);
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForLocations(
    Set<String> locationIds,
  ) {
    final ids = _validatedQueryIds(locationIds, 'lieu', maxCount: 30);
    if (ids.isEmpty) return Stream<List<CoordinationNeed>>.value(const []);
    return switchLatest(
      _watchAdministrativeActiveMobilizationIds(_responsibleFirestore),
      (mobilizationIds) => _combineMissionStreams(
        mobilizationIds.map(
          (mobilizationId) => _watchMissionsInMobilization(
            _responsibleFirestore,
            mobilizationId,
            locationIds: ids,
          ),
        ),
      ),
    );
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizationsAndLocations({
    required Set<String> mobilizationIds,
    required Set<String> locationIds,
  }) {
    final mobilizations = _validatedQueryIds(mobilizationIds, 'mobilisation');
    final locations = _validatedQueryIds(locationIds, 'lieu', maxCount: 30);
    if (mobilizations.isEmpty || locations.isEmpty) {
      return Stream<List<CoordinationNeed>>.value(const []);
    }
    return _combineMissionStreams(
      mobilizations.map(
        (mobilizationId) => _watchMissionsInMobilization(
          _responsibleFirestore,
          mobilizationId,
          locationIds: locations,
        ),
      ),
    );
  }

  @override
  Stream<List<CoordinationNeed>> watchAllActiveMissions() {
    return switchLatest(
      _publicMobilizationRepository.watchActiveMobilizationIds(),
      (mobilizationIds) =>
          _watchMissionsInMobilizationBatches(_firestore, mobilizationIds),
    );
  }

  Stream<List<String>> _watchAdministrativeActiveMobilizationIds(
    FirebaseFirestore firestore,
  ) {
    return firestore
        .collection('mobilizations')
        .where('status', isEqualTo: MobilizationStatus.active.serializedValue)
        .snapshots()
        .map((snapshot) {
          final ids = snapshot.docs.map((document) => document.id).toList();
          ids.sort();
          return ids;
        });
  }

  Stream<List<CoordinationNeed>> _watchMissionsInMobilization(
    FirebaseFirestore firestore,
    String mobilizationId, {
    List<String>? locationIds,
  }) {
    Query<Map<String, dynamic>> query = firestore
        .collection('missions')
        .where('mobilizationId', isEqualTo: mobilizationId)
        .where('isActive', isEqualTo: true);
    if (locationIds != null) {
      query = query.where('locationId', whereIn: locationIds);
    }
    return query.snapshots().map(
      (snapshot) => multiScopedMissionsFromDocuments(
        documents: snapshot.docs.map(
          (document) => (id: document.id, data: document.data()),
        ),
        mobilizationIds: {mobilizationId},
        locationIds: locationIds?.toSet(),
      ),
    );
  }

  Stream<List<CoordinationNeed>> _watchMissionsInMobilizationBatches(
    FirebaseFirestore firestore,
    List<String> mobilizationIds,
  ) => _combineMissionStreams(
    _batchesOf(
      mobilizationIds,
      30,
    ).map((batch) => _watchMissionsInMobilizations(firestore, batch)),
  );

  Stream<List<CoordinationNeed>> _watchMissionsInMobilizations(
    FirebaseFirestore firestore,
    List<String> mobilizationIds,
  ) {
    final idSet = mobilizationIds.toSet();
    return firestore
        .collection('missions')
        .where('mobilizationId', whereIn: mobilizationIds)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => multiScopedMissionsFromDocuments(
            documents: snapshot.docs.map(
              (document) => (id: document.id, data: document.data()),
            ),
            mobilizationIds: idSet,
          ),
        );
  }

  Stream<List<CoordinationNeed>> _combineMissionStreams(
    Iterable<Stream<List<CoordinationNeed>>> sourceStreams,
  ) {
    final streams = sourceStreams.toList(growable: false);
    if (streams.isEmpty) {
      return Stream<List<CoordinationNeed>>.value(const []);
    }
    late final StreamController<List<CoordinationNeed>> controller;
    final subscriptions = <StreamSubscription<List<CoordinationNeed>>>[];
    final values = <int, List<CoordinationNeed>>{};

    void emit() {
      if (values.length != streams.length || controller.isClosed) return;
      final byId = <String, CoordinationNeed>{};
      for (final missions in values.values) {
        for (final mission in missions) {
          byId[mission.id] = mission;
        }
      }
      final missions = byId.values.toList(growable: false)
        ..sort((left, right) {
          final leftDate = left.startAt;
          final rightDate = right.startAt;
          if (leftDate == null && rightDate == null) {
            return left.id.compareTo(right.id);
          }
          if (leftDate == null) return 1;
          if (rightDate == null) return -1;
          return leftDate.compareTo(rightDate);
        });
      controller.add(missions);
    }

    controller = StreamController<List<CoordinationNeed>>(
      onListen: () {
        for (var index = 0; index < streams.length; index += 1) {
          subscriptions.add(
            streams[index].listen((missions) {
              values[index] = missions;
              emit();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  List<String> _validatedQueryIds(
    Set<String> values,
    String label, {
    int? maxCount,
  }) {
    if ((maxCount != null && values.length > maxCount) ||
        values.any(
          (value) =>
              value.isEmpty || value.trim() != value || value.contains('/'),
        )) {
      throw RepositoryException('Périmètre de $label invalide.');
    }
    final result = values.toList(growable: false)..sort();
    return result;
  }

  Iterable<List<T>> _batchesOf<T>(List<T> values, int size) sync* {
    for (var start = 0; start < values.length; start += size) {
      final end = (start + size).clamp(0, values.length);
      yield values.sublist(start, end);
    }
  }

  @override
  Stream<List<ResponsePlace>> watchLocations() {
    return _watchLocationsQuery(_firestore.collection('locations'));
  }

  @override
  Stream<List<ResponsePlace>> watchAllAdministrativeLocations() {
    return _watchLocationsQuery(_responsibleFirestore.collection('locations'));
  }

  @override
  Stream<List<ResponsePlace>> watchLocationsManagedByOrganization(
    String organizationId,
  ) {
    final id = organizationId.trim();
    if (id.isEmpty || id != organizationId || id.contains('/')) {
      return Stream<List<ResponsePlace>>.error(
        const RepositoryException('Organisation de sites invalide.'),
      );
    }
    return _watchLocationsQuery(
      _responsibleFirestore
          .collection('locations')
          .where('managingOrganizationId', isEqualTo: id),
    );
  }

  Stream<List<ResponsePlace>> _watchLocationsQuery(
    Query<Map<String, dynamic>> query,
  ) {
    return query.snapshots().map(
      (snapshot) => List<ResponsePlace>.unmodifiable(
        snapshot.docs.map(
          (document) => FirestoreLocationMapper.fromFirestore(
            id: document.id,
            data: document.data(),
          ),
        ),
      ),
    );
  }

  @override
  Future<VolunteerProfile?> getVolunteerProfile() async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw const RepositoryException(
        'Une session volontaire est nécessaire pour accéder au profil.',
      );
    }
    final snapshot = await _firestore
        .collection('volunteers')
        .doc(user.uid)
        .get()
        .timeout(const Duration(seconds: 15));
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return _profileFromFirestore(user.uid, data);
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
    final user = _auth.currentUser;
    if (user == null ||
        !user.isAnonymous ||
        (profile.uid.isNotEmpty && user.uid != profile.uid)) {
      throw const RepositoryException(
        'Ce profil n’appartient pas à la session volontaire active.',
      );
    }
    final reference = _firestore.collection('volunteers').doc(user.uid);
    await _firestore
        .runTransaction((transaction) async {
          final existing = await transaction.get(reference);
          final now = FieldValue.serverTimestamp();
          final existingData = existing.data();
          transaction.set(reference, {
            ..._profileData(profile, now, uid: user.uid),
            ...ProfessionalProfileV2FirestoreMapper.forSave(
              profile: profile,
              existingData: existingData,
            ),
            ..._verificationDataForClientSave(existingData, profile),
            'createdAt': existingData?['createdAt'] ?? now,
          });
        })
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<VolunteerProfile> confirmProfessionalRpps(
    ProfessionalVerificationResult verification,
  ) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw const RepositoryException(
        'Une session volontaire est nécessaire pour confirmer le RPPS.',
      );
    }
    try {
      final response = await _volunteerFunctions
          .httpsCallable('confirmProfessionalRpps')
          .call<Object?>({'rpps': verification.rpps.trim()})
          .timeout(const Duration(seconds: 20));
      final data = response.data;
      if (data is! Map || data['status'] != 'verified') {
        throw const RepositoryException(
          'La confirmation du RPPS n’a pas abouti.',
        );
      }
      final profile = await getVolunteerProfile();
      if (profile == null || !profile.hasVerifiedProfessionalIdentity) {
        throw const RepositoryException(
          'Le profil vérifié n’a pas pu être relu.',
        );
      }
      return profile;
    } on RepositoryException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Échec confirmation RPPS : ${error.runtimeType}');
      debugPrintStack(stackTrace: stackTrace);
      throw const RepositoryException(
        'La confirmation du RPPS est momentanément indisponible.',
      );
    }
  }

  @override
  Stream<EngagementInfo?> watchMyEngagement(String missionId) {
    return switchLatest(_auth.authStateChanges(), (user) {
      if (user == null || !user.isAnonymous) {
        return Stream<EngagementInfo?>.value(null);
      }
      return _firestore
          .collection('engagements')
          .doc('${missionId}_${user.uid}')
          .snapshots()
          .map((snapshot) {
            final data = snapshot.data();
            if (!snapshot.exists ||
                data == null ||
                data['missionId'] != missionId) {
              return null;
            }
            final profession = data['profession'] as String?;
            if (profession == null) {
              throw const RepositoryException(
                'La profession de cet engagement est invalide.',
              );
            }
            late final VolunteerProfession parsedProfession;
            try {
              parsedProfession = volunteerProfessionFromId(profession);
            } on FormatException {
              throw const RepositoryException(
                'La profession de cet engagement est invalide.',
              );
            }
            return EngagementInfo(
              missionId: missionId,
              volunteerId: user.uid,
              profession: parsedProfession,
              status: _engagementStatus(data['status']),
              createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
              updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
            );
          });
    });
  }

  @override
  Stream<List<EngagementInfo>> watchMissionEngagements(String missionId) {
    return switchLatest(watchResponsibleAccess(), (access) {
      if (access == null || !access.active) {
        return Stream<List<EngagementInfo>>.value(const []);
      }
      if (!access.isCoordinator) {
        return _responsibleFirestore
            .collection('missions')
            .doc(missionId)
            .snapshots()
            .asyncMap(
              (snapshot) => !snapshot.exists
                  ? const <EngagementInfo>[]
                  : _identityResolver.listMissionTeam(missionId),
            );
      }
      return watchAuthorizedMissionEngagements(missionId);
    });
  }

  @override
  Stream<List<EngagementInfo>> watchAuthorizedMissionEngagements(
    String missionId,
  ) => switchLatest(
    _responsibleFirestore.collection('missions').doc(missionId).snapshots(),
    (missionSnapshot) {
      final mission = missionSnapshot.data();
      if (!missionSnapshot.exists || mission == null) {
        return Stream<List<EngagementInfo>>.value(const []);
      }
      final mobilizationId = requireMatchingMobilizationId(mission: mission);
      return _responsibleFirestore
          .collection('engagements')
          .where('missionId', isEqualTo: missionId)
          .where('mobilizationId', isEqualTo: mobilizationId)
          .snapshots()
          .asyncMap((snapshot) async {
            final engagements = snapshot.docs
                .map((document) {
                  final data = document.data();
                  if (data['missionId'] != missionId) return null;
                  final profession = data['profession'];
                  final volunteerId = data['volunteerId'];
                  if (profession is! String || volunteerId is! String) {
                    throw const RepositoryException('Engagement invalide.');
                  }
                  return EngagementInfo(
                    missionId: missionId,
                    volunteerId: volunteerId,
                    profession: volunteerProfessionFromId(profession),
                    status: _engagementStatus(data['status']),
                    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
                    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
                  );
                })
                .whereType<EngagementInfo>()
                .toList(growable: false);
            try {
              final resolved = await _identityResolver.listMissionTeam(
                missionId,
              );
              final identities = {
                for (final engagement in resolved)
                  engagement.volunteerId: engagement.identity,
              };
              return engagements
                  .map(
                    (engagement) => engagement.copyWith(
                      identity:
                          identities[engagement.volunteerId] ??
                          UserDisplayIdentity(
                            uid: engagement.volunteerId,
                            displayName: 'Professionnel',
                            professionLabel: engagement.profession.label,
                          ),
                    ),
                  )
                  .toList(growable: false);
            } catch (_) {
              return engagements
                  .map(
                    (engagement) => engagement.copyWith(
                      identity: UserDisplayIdentity(
                        uid: engagement.volunteerId,
                        displayName: 'Professionnel',
                        professionLabel: engagement.profession.label,
                      ),
                    ),
                  )
                  .toList(growable: false);
            }
          });
    },
  );

  @override
  Future<void> updateEngagementStatus({
    required String missionId,
    required String volunteerId,
    required EngagementStatus status,
  }) async {
    final user = _responsibleAuth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const RepositoryException(
        'Vous devez vous connecter comme coordinateur.',
      );
    }
    final role = await _responsibleFirestore
        .collection('roles')
        .doc(user.uid)
        .get();
    final data = role.data();
    final access = data == null
        ? null
        : parseResponsibleAccessDocument(uid: user.uid, data: data);
    if (access?.isCoordinator != true) {
      throw const RepositoryException(
        'Seul un coordinateur peut modifier ce statut.',
      );
    }
    final reference = _responsibleFirestore
        .collection('engagements')
        .doc('${missionId}_$volunteerId');
    try {
      if (status == EngagementStatus.confirmed) {
        final missionReference = _responsibleFirestore
            .collection('missions')
            .doc(missionId);
        await _responsibleFirestore
            .runTransaction((transaction) async {
              final missionSnapshot = await transaction.get(missionReference);
              final engagementSnapshot = await transaction.get(reference);
              if (!missionSnapshot.exists || !engagementSnapshot.exists) {
                throw const RepositoryException('Engagement introuvable.');
              }
              final mission = missionSnapshot.data()!;
              final engagement = engagementSnapshot.data()!;
              requireMatchingMobilizationId(
                mission: mission,
                engagement: engagement,
              );
              final currentStatus = _engagementStatus(engagement['status']);
              if (currentStatus != EngagementStatus.pending &&
                  currentStatus != EngagementStatus.standby) {
                throw const RepositoryException(
                  'Cet engagement ne peut pas être confirmé.',
                );
              }
              if (mission['isActive'] != true ||
                  mission['status'] == 'cancelled') {
                throw const RepositoryException('Cette mission a été annulée.');
              }
              final endAt = mission['endAt'];
              if (endAt is Timestamp &&
                  !DateTime.now().isBefore(endAt.toDate())) {
                throw const RepositoryException(
                  'Le créneau de cette mission est terminé.',
                );
              }
              final professionName = engagement['profession'] as String?;
              if (professionName == null) {
                throw const RepositoryException(
                  'La profession de cet engagement est invalide.',
                );
              }
              late final String professionId;
              try {
                professionId = HealthProfessionId.normalize(professionName);
              } on FormatException {
                throw const RepositoryException(
                  'La profession de cet engagement est invalide.',
                );
              }
              var quotas = ProfessionQuotas.fromMissionData(mission);
              final quota = quotas.quotaFor(professionId);
              if (quota.registered >= quota.required) {
                throw const RepositoryException(
                  'Cette mission est désormais complète.',
                );
              }
              final delta = EngagementCounterTransition.amount(
                from: currentStatus,
                to: EngagementStatus.confirmed,
              );
              quotas = quotas.updateRegistered(professionId, delta);
              final now = FieldValue.serverTimestamp();
              transaction.update(reference, {
                'status': EngagementStatus.confirmed.name,
                'updatedAt': now,
              });
              transaction.update(missionReference, {
                ...quotas.toMissionUpdate(),
                'status': _statusForQuotas(quotas).name,
                'updatedAt': now,
              });
            })
            .timeout(const Duration(seconds: 15));
        return;
      }
      if (status == EngagementStatus.standby ||
          status == EngagementStatus.cancelled) {
        final missionReference = _responsibleFirestore
            .collection('missions')
            .doc(missionId);
        await _responsibleFirestore
            .runTransaction((transaction) async {
              final missionSnapshot = await transaction.get(missionReference);
              final engagementSnapshot = await transaction.get(reference);
              if (!missionSnapshot.exists || !engagementSnapshot.exists) {
                throw const RepositoryException('Engagement introuvable.');
              }
              final mission = missionSnapshot.data()!;
              final engagement = engagementSnapshot.data()!;
              requireMatchingMobilizationId(
                mission: mission,
                engagement: engagement,
              );
              final currentStatus = _engagementStatus(engagement['status']);
              final isWithoutCounter =
                  (currentStatus == EngagementStatus.pending &&
                      (status == EngagementStatus.standby ||
                          status == EngagementStatus.cancelled)) ||
                  (currentStatus == EngagementStatus.standby &&
                      status == EngagementStatus.cancelled);
              if (currentStatus != EngagementStatus.confirmed &&
                  !isWithoutCounter) {
                throw const RepositoryException(
                  'Seul un engagement confirmé peut changer de statut.',
                );
              }
              if (mission['isActive'] != true ||
                  mission['status'] == 'cancelled') {
                throw const RepositoryException('Cette mission a été annulée.');
              }
              final endAt = mission['endAt'];
              if (endAt is Timestamp &&
                  !DateTime.now().isBefore(endAt.toDate())) {
                throw const RepositoryException(
                  'Le créneau de cette mission est terminé.',
                );
              }
              if (isWithoutCounter) {
                transaction.update(reference, {
                  'status': status.name,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                return;
              }
              final professionName = engagement['profession'] as String?;
              if (professionName == null) {
                throw const RepositoryException(
                  'La profession de cet engagement est invalide.',
                );
              }
              late final String professionId;
              try {
                professionId = HealthProfessionId.normalize(professionName);
              } on FormatException {
                throw const RepositoryException(
                  'La profession de cet engagement est invalide.',
                );
              }
              var quotas = ProfessionQuotas.fromMissionData(mission);
              if (quotas.quotaFor(professionId).registered <= 0) {
                throw const RepositoryException(
                  'Le compteur correspondant est déjà à zéro.',
                );
              }
              final delta = EngagementCounterTransition.amount(
                from: currentStatus,
                to: status,
              );
              quotas = quotas.updateRegistered(professionId, delta);
              final now = FieldValue.serverTimestamp();
              transaction.update(reference, {
                'status': status.name,
                'updatedAt': now,
              });
              transaction.update(missionReference, {
                ...quotas.toMissionUpdate(),
                'status': _statusForQuotas(quotas).name,
                'updatedAt': now,
              });
            })
            .timeout(const Duration(seconds: 15));
        return;
      }
      final missionReference = _responsibleFirestore
          .collection('missions')
          .doc(missionId);
      await _responsibleFirestore
          .runTransaction((transaction) async {
            final missionSnapshot = await transaction.get(missionReference);
            final engagementSnapshot = await transaction.get(reference);
            if (!missionSnapshot.exists || !engagementSnapshot.exists) {
              throw const RepositoryException('Engagement introuvable.');
            }
            requireMatchingMobilizationId(
              mission: missionSnapshot.data()!,
              engagement: engagementSnapshot.data()!,
            );
            transaction.update(reference, {
              'status': status.name,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          })
          .timeout(const Duration(seconds: 15));
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Échec updateEngagementStatus (${error.code})');
      debugPrintStack(stackTrace: stackTrace);
      throw const RepositoryException(
        'Le statut n’a pas pu être mis à jour. Réessayez.',
      );
    }
  }

  @override
  Future<String> createMission(MissionDraft draft) async {
    final mobilization = await _requireActiveMobilization();
    return _createMissionInMobilization(mobilization.mobilizationId, draft);
  }

  @override
  Future<String> createMissionForMobilization(
    String mobilizationId,
    MissionDraft draft,
  ) {
    if (mobilizationId.trim().isEmpty || mobilizationId.contains('/')) {
      throw const RepositoryException('Mobilisation invalide.');
    }
    return _createMissionInMobilization(mobilizationId, draft);
  }

  Future<String> _createMissionInMobilization(
    String mobilizationId,
    MissionDraft draft,
  ) async {
    final user = _responsibleAuth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const RepositoryException(
        'Vous devez vous connecter pour déclarer un besoin.',
      );
    }
    final role = await _responsibleFirestore
        .collection('roles')
        .doc(user.uid)
        .get();
    final roleData = role.data();
    if (!role.exists || roleData == null) {
      throw const RepositoryException('Votre compte responsable est inactif.');
    }
    final access = parseResponsibleAccessDocument(
      uid: user.uid,
      data: roleData,
    );
    if (!access.active) {
      throw const RepositoryException('Votre compte responsable est inactif.');
    }
    if (!access.canManage(draft.location.id)) {
      throw const RepositoryException(
        'Votre compte n’est pas autorisé à publier pour ce lieu.',
      );
    }
    final reference = _responsibleFirestore.collection('missions').doc();
    debugPrint('Publication Firestore mission : début');
    debugPrint('Identifiant mission généré : ${reference.id}');
    try {
      await reference.set(
        FirestoreMissionMapper.toFirestore(
          id: reference.id,
          mobilizationId: mobilizationId,
          draft: draft,
          serverTimestamp: FieldValue.serverTimestamp(),
          createdBy: user.uid,
        ),
      );
      debugPrint('Publication Firestore mission réussie : ${reference.id}');
      return reference.id;
    } on FirebaseException catch (error, stackTrace) {
      if (error.code == 'permission-denied') {
        debugPrint(
          'Publication Firestore refusée (permission-denied). '
          'Vérifier les règles de la collection missions.',
        );
      }
      debugPrint('Erreur Firestore createMission : $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Erreur createMission : $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> updateMission(String missionId, MissionDraft draft) async {
    final user = _responsibleAuth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const RepositoryException(
        'Vous devez vous connecter pour modifier une mission.',
      );
    }
    try {
      await _responsibleFunctions
          .httpsCallable('updateMission')
          .call<Object?>(
            FirestoreMissionMapper.toUpdateCallableData(
              missionId: missionId,
              draft: draft,
            ),
          )
          .timeout(const Duration(seconds: 15));
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint('Échec updateMission (${error.code})');
      debugPrintStack(stackTrace: stackTrace);
      throw RepositoryException(_missionUpdateMessage(error.code));
    } on RepositoryException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Échec updateMission : $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const RepositoryException(
        'La mission n’a pas pu être mise à jour. Réessayez.',
      );
    }
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
    var user = _auth.currentUser;
    if (!canStartVolunteerEngagement(
      hasUser: user != null,
      isAnonymous: user?.isAnonymous ?? false,
    )) {
      throw const RepositoryException(
        'Une session volontaire est nécessaire pour s’engager.',
      );
    }
    if (user == null) {
      final credential = await _auth.signInAnonymously();
      user = credential.user;
    }
    if (user == null) {
      throw const RepositoryException(
        'Connexion sécurisée impossible. Réessayez.',
      );
    }
    final uid = user.uid;
    final missionRef = _firestore.collection('missions').doc(missionId);
    final volunteerRef = _firestore.collection('volunteers').doc(uid);
    final engagementRef = _firestore
        .collection('engagements')
        .doc('${missionId}_$uid');

    try {
      final result = await _firestore
          .runTransaction<EngagementCreationResult?>((transaction) async {
            final snapshot = await transaction.get(missionRef);
            if (!snapshot.exists) {
              throw const RepositoryException('Mission introuvable');
            }
            final existingEngagement = await transaction.get(engagementRef);
            final existingEngagementData = existingEngagement.data();
            final existing = existingEngagementData == null
                ? null
                : classifyExistingEngagement(existingEngagementData, uid);
            if (existing != null && !existing.ownerMatches) return null;
            if (existing?.result case final existingResult?) {
              if (existingResult != EngagementCreationResult.alreadyPending) {
                return existingResult;
              }
            }
            final isReengagement = existing != null;
            final existingVolunteer = await transaction.get(volunteerRef);
            final existingVolunteerData = existingVolunteer.data();
            final existingProfile = existingVolunteerData == null
                ? null
                : _profileFromFirestore(uid, existingVolunteerData);
            final data = snapshot.data()!;
            final mobilizationId = requireMatchingMobilizationId(
              mission: data,
              engagement: existingEngagementData,
            );
            if (data['status'] == 'cancelled') {
              throw const RepositoryException('Cette mission a été annulée.');
            }
            if (data['isActive'] == false) {
              throw const RepositoryException(
                'Cette mission est désormais complète.',
              );
            }
            final endAt = data['endAt'];
            if (endAt is Timestamp &&
                !DateTime.now().isBefore(endAt.toDate())) {
              throw const RepositoryException(
                'Le créneau de cette mission est terminé.',
              );
            }
            var quotas = ProfessionQuotas.fromMissionData(data);
            final professionId = profession.canonicalId!;
            final quota = quotas.quotaFor(professionId);
            if (quota.registered >= quota.required) {
              throw const RepositoryException(
                'Ce besoin est désormais couvert pour votre profession.',
              );
            }
            quotas = quotas.updateRegistered(professionId, 1);
            final now = FieldValue.serverTimestamp();

            final volunteerData = <String, dynamic>{
              'uid': uid,
              'firstName': firstName.trim(),
              'lastName': lastName.trim(),
              'phone': phone.trim(),
              'profession': profession.canonicalId,
              'updatedAt': now,
              'equipment': ProfessionalEquipmentRegistry.normalizeStoredValues(
                equipment,
              ),
            };
            final resolvedIdValue = normalizeProfessionalIdentifier(
              resolvedProfessionalIdType,
              resolvedProfessionalIdValue,
            );
            volunteerData['professionalIdType'] =
                resolvedProfessionalIdType.name;
            volunteerData['professionalIdValue'] = resolvedIdValue;
            final normalizedEmail = email?.trim();
            if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
              volunteerData['email'] = normalizedEmail;
            } else if (existingVolunteer.exists) {
              volunteerData['email'] = FieldValue.delete();
            }
            for (final entry in {
              'rpps': resolvedProfessionalIdType == ProfessionalIdType.rpps
                  ? resolvedIdValue
                  : null,
              'cptsId': _nullableTrim(cptsId),
              'cptsLabel': _nullableTrim(cptsLabel),
              'otherEquipmentDetails': _nullableTrim(otherEquipmentDetails),
            }.entries) {
              if (entry.value != null) {
                volunteerData[entry.key] = entry.value;
              } else if (existingVolunteer.exists) {
                volunteerData[entry.key] = FieldValue.delete();
              }
            }
            transaction.set(volunteerRef, {
              ...volunteerData,
              ..._verificationDataForProfileMerge(
                existing: existingProfile,
                profession: profession,
                professionalIdType: resolvedProfessionalIdType,
                professionalIdValue: resolvedIdValue,
              ),
              'createdAt': existingVolunteerData?['createdAt'] ?? now,
            }, SetOptions(merge: true));
            if (isReengagement) {
              transaction.update(engagementRef, {
                'profession': profession.canonicalId,
                'updatedAt': now,
                'status': EngagementStatus.confirmed.name,
              });
            } else {
              transaction.set(engagementRef, {
                'missionId': missionId,
                'mobilizationId': mobilizationId,
                'volunteerId': uid,
                'profession': profession.canonicalId,
                'createdAt': now,
                'updatedAt': now,
                'status': EngagementStatus.confirmed.name,
              });
            }
            transaction.update(missionRef, {
              ...quotas.toMissionUpdate(),
              'status': _statusForQuotas(quotas).name,
              'updatedAt': now,
            });
            return isReengagement
                ? EngagementCreationResult.reactivated
                : EngagementCreationResult.created;
          })
          .timeout(const Duration(seconds: 15));
      if (result == null) {
        debugPrint(
          'Incohérence engagement : volunteerId différent de l’UID courant.',
        );
        throw const RepositoryException(
          'Cet engagement appartient à un autre volontaire.',
        );
      }
      return result;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Erreur Firebase createEngagement '
        '(${error.plugin}/${error.code}) : ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Erreur createEngagement : $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> cancelEngagement(String missionId) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw const RepositoryException(
        'Vous n’êtes plus engagé sur cette mission.',
      );
    }
    final missionRef = _firestore.collection('missions').doc(missionId);
    final engagementRef = _firestore
        .collection('engagements')
        .doc('${missionId}_${user.uid}');
    try {
      await _firestore
          .runTransaction((transaction) async {
            final missionSnapshot = await transaction.get(missionRef);
            final engagementSnapshot = await transaction.get(engagementRef);
            if (!missionSnapshot.exists) {
              throw const RepositoryException('Mission introuvable.');
            }
            final mission = missionSnapshot.data()!;
            if (mission['isActive'] == false ||
                mission['status'] == 'cancelled') {
              throw const RepositoryException('Cette mission a été annulée.');
            }
            final endAt = mission['endAt'];
            if (endAt is Timestamp &&
                !DateTime.now().isBefore(endAt.toDate())) {
              throw const RepositoryException(
                'Le créneau de cette mission est terminé.',
              );
            }
            if (!engagementSnapshot.exists ||
                engagementSnapshot.data()?['volunteerId'] != user.uid) {
              throw const RepositoryException(
                'Vous n’êtes plus engagé sur cette mission.',
              );
            }
            final engagement = engagementSnapshot.data()!;
            requireMatchingMobilizationId(
              mission: mission,
              engagement: engagement,
            );
            final currentStatus = _engagementStatus(engagement['status']);
            if (currentStatus == EngagementStatus.cancelled) {
              throw const RepositoryException(
                'Vous n’êtes plus engagé sur cette mission.',
              );
            }
            final now = FieldValue.serverTimestamp();
            if (currentStatus == EngagementStatus.pending ||
                currentStatus == EngagementStatus.standby) {
              transaction.update(engagementRef, {
                'status': EngagementStatus.cancelled.name,
                'updatedAt': now,
              });
              return;
            }
            final professionName = engagement['profession'] as String?;
            if (professionName == null) {
              throw const RepositoryException(
                'Le désengagement n’a pas pu être enregistré. Réessayez.',
              );
            }
            late final String professionId;
            try {
              professionId = HealthProfessionId.normalize(professionName);
            } on FormatException {
              throw const RepositoryException(
                'Le désengagement n’a pas pu être enregistré. Réessayez.',
              );
            }
            var quotas = ProfessionQuotas.fromMissionData(mission);
            if (quotas.quotaFor(professionId).registered <= 0) {
              throw const RepositoryException(
                'Le désengagement n’a pas pu être enregistré. Réessayez.',
              );
            }
            quotas = quotas.updateRegistered(professionId, -1);
            transaction.update(engagementRef, {
              'status': EngagementStatus.cancelled.name,
              'updatedAt': now,
            });
            transaction.update(missionRef, {
              ...quotas.toMissionUpdate(),
              'status': _statusForQuotas(quotas).name,
              'updatedAt': now,
            });
          })
          .timeout(const Duration(seconds: 15));
    } on RepositoryException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Échec cancelEngagement : $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const RepositoryException(
        'Le désengagement n’a pas pu être enregistré. Réessayez.',
      );
    }
  }

  @override
  Future<void> cancelMission(String missionId, String? reason) async {
    final user = _responsibleAuth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const RepositoryException(
        'Vous devez vous connecter pour déclarer un besoin.',
      );
    }
    final missionRef = _responsibleFirestore
        .collection('missions')
        .doc(missionId);
    final roleRef = _responsibleFirestore.collection('roles').doc(user.uid);
    try {
      await _responsibleFirestore
          .runTransaction((transaction) async {
            final missionSnapshot = await transaction.get(missionRef);
            final roleSnapshot = await transaction.get(roleRef);
            if (!missionSnapshot.exists) {
              throw const RepositoryException('Mission introuvable.');
            }
            final mission = missionSnapshot.data()!;
            requireMatchingMobilizationId(mission: mission);
            if (mission['status'] == 'cancelled' ||
                mission['isActive'] == false) {
              throw const RepositoryException(
                'Cette mission a déjà été annulée.',
              );
            }
            if (!roleSnapshot.exists ||
                roleSnapshot.data()?['active'] != true ||
                mission['createdBy'] != user.uid) {
              throw const RepositoryException(
                'Seul le responsable ayant créé ce besoin peut l’annuler.',
              );
            }
            final now = FieldValue.serverTimestamp();
            transaction.update(
              missionRef,
              FirestoreMissionMapper.cancellationUpdate(
                cancelledBy: user.uid,
                reason: reason ?? '',
                serverTimestamp: now,
              ),
            );
          })
          .timeout(const Duration(seconds: 15));
    } on RepositoryException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Échec cancelMission : $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const RepositoryException(
        'L’annulation n’a pas pu être enregistrée. Réessayez.',
      );
    }
  }

  static VolunteerProfile _profileFromFirestore(
    String uid,
    Map<String, dynamic> data,
  ) {
    late final ProfessionalProfileV2Fields v2;
    try {
      v2 = ProfessionalProfileV2FirestoreMapper.fromFirestore(data);
    } on FormatException catch (error) {
      throw RepositoryException(error.message);
    }
    final professionName = data['profession'] as String?;
    VolunteerProfession? profession;
    if (professionName != null) {
      try {
        profession = volunteerProfessionFromId(professionName);
      } on FormatException {
        profession = null;
      }
    }
    if (profession == null) {
      throw const RepositoryException(
        'La profession enregistrée dans ce profil est invalide.',
      );
    }
    return VolunteerProfile(
      uid: uid,
      firstName: (data['firstName'] as String? ?? '').trim(),
      lastName: (data['lastName'] as String? ?? '').trim(),
      phone: (data['phone'] as String? ?? '').trim(),
      email: _nullableTrim(data['email'] as String?),
      rpps: _nullableTrim(data['rpps'] as String?),
      professionalIdType: _professionalIdTypeFromData(data),
      professionalIdValue: _professionalIdValueFromData(data),
      cptsId: _nullableTrim(data['cptsId'] as String?),
      cptsLabel: _nullableTrim(data['cptsLabel'] as String?),
      professionalAddressLine1: _nullableTrim(
        data['professionalAddressLine1'] as String?,
      ),
      professionalAddressLine2: _nullableTrim(
        data['professionalAddressLine2'] as String?,
      ),
      professionalPostalCode: _nullableTrim(
        data['professionalPostalCode'] as String?,
      ),
      professionalCity: _nullableTrim(data['professionalCity'] as String?),
      professionalCountryCode:
          _nullableTrim(data['professionalCountryCode'] as String?) ?? 'FR',
      profession: profession,
      equipment: ProfessionalEquipmentRegistry.normalizeStoredValues(
        List<String>.from(data['equipment'] as List? ?? const []),
      ),
      otherEquipmentDetails: _nullableTrim(
        data['otherEquipmentDetails'] as String?,
      ),
      verificationStatus: _nullableTrim(data['verificationStatus'] as String?),
      verificationSource: _nullableTrim(data['verificationSource'] as String?),
      verifiedFirstName: _nullableTrim(data['verifiedFirstName'] as String?),
      verifiedLastName: _nullableTrim(data['verifiedLastName'] as String?),
      verifiedProfessionCode: _nullableTrim(
        data['verifiedProfessionCode'] as String?,
      ),
      verifiedProfessionLabel: _nullableTrim(
        data['verifiedProfessionLabel'] as String?,
      ),
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      profileSchemaVersion: v2.profileSchemaVersion,
      competencies: v2.competencies,
      mobilizationPreferences: v2.mobilizationPreferences,
      communicationPreferences: v2.communicationPreferences,
      consentRecords: v2.consentRecords,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> _profileData(
    VolunteerProfile profile,
    Object serverTimestamp, {
    required String uid,
  }) {
    final email = _nullableTrim(profile.email);
    final professionalIdType = profile.effectiveProfessionalIdType;
    final professionalIdValue = normalizeProfessionalIdentifier(
      professionalIdType,
      profile.effectiveProfessionalIdValue,
    );
    final cptsId = _nullableTrim(profile.cptsId);
    final cptsLabel = _nullableTrim(profile.cptsLabel);
    final professionalAddress = profile.professionalAddress;
    return {
      'uid': uid,
      'firstName': profile.firstName.trim(),
      'lastName': profile.lastName.trim(),
      'phone': profile.phone.trim(),
      'email': ?email,
      'professionalIdType': professionalIdType.name,
      'professionalIdValue': professionalIdValue,
      'rpps': ?(professionalIdType == ProfessionalIdType.rpps
          ? professionalIdValue
          : null),
      'cptsId': ?cptsId,
      'cptsLabel': ?cptsLabel,
      'professionalAddressLine1': ?professionalAddress.normalizedLine1,
      'professionalAddressLine2': ?professionalAddress.normalizedLine2,
      'professionalPostalCode': ?professionalAddress.normalizedPostalCode,
      'professionalCity': ?professionalAddress.normalizedCity,
      'professionalCountryCode': professionalAddress.normalizedCountryCode,
      'profession': profile.profession.canonicalId,
      'equipment': ProfessionalEquipmentRegistry.normalizeStoredValues(
        profile.equipment,
      ),
      'otherEquipmentDetails': ?_nullableTrim(profile.otherEquipmentDetails),
      'verificationStatus': 'unverified',
      'updatedAt': serverTimestamp,
    };
  }

  static Map<String, dynamic> _verificationDataForClientSave(
    Map<String, dynamic>? existing,
    VolunteerProfile profile,
  ) {
    final existingProfile = existing == null
        ? null
        : _profileFromFirestore(profile.uid, existing);
    if (!ProfessionalProfileValidation.preservesVerification(
      existing: existingProfile,
      profession: profile.profession,
      professionalIdType: profile.effectiveProfessionalIdType,
      professionalIdValue: profile.effectiveProfessionalIdValue,
    )) {
      return const {'verificationStatus': 'unverified'};
    }
    return {
      'verificationStatus': 'verified',
      'verificationSource': existing?['verificationSource'],
      'verifiedFirstName': existing?['verifiedFirstName'],
      'verifiedLastName': existing?['verifiedLastName'],
      'verifiedProfessionCode': existing?['verifiedProfessionCode'],
      'verifiedProfessionLabel': existing?['verifiedProfessionLabel'],
      'verifiedAt': existing?['verifiedAt'],
    };
  }

  static Map<String, dynamic> _verificationDataForProfileMerge({
    required VolunteerProfile? existing,
    required VolunteerProfession profession,
    required ProfessionalIdType professionalIdType,
    required String professionalIdValue,
  }) {
    if (ProfessionalProfileValidation.preservesVerification(
      existing: existing,
      profession: profession,
      professionalIdType: professionalIdType,
      professionalIdValue: professionalIdValue,
    )) {
      return const {};
    }
    if (existing == null) {
      return const {'verificationStatus': 'unverified'};
    }
    return {
      'verificationStatus': 'unverified',
      'verificationSource': FieldValue.delete(),
      'verifiedFirstName': FieldValue.delete(),
      'verifiedLastName': FieldValue.delete(),
      'verifiedProfessionCode': FieldValue.delete(),
      'verifiedProfessionLabel': FieldValue.delete(),
      'verifiedAt': FieldValue.delete(),
    };
  }

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _normalizeRpps(String? value) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), '');
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static ProfessionalIdType _professionalIdTypeFromData(
    Map<String, dynamic> data,
  ) {
    final stored = data['professionalIdType'];
    if (stored is String) {
      return ProfessionalIdType.values
              .where((type) => type.name == stored)
              .firstOrNull ??
          ProfessionalIdType.none;
    }
    return _nullableTrim(data['rpps'] as String?) == null
        ? ProfessionalIdType.none
        : ProfessionalIdType.rpps;
  }

  static String _professionalIdValueFromData(Map<String, dynamic> data) {
    final type = _professionalIdTypeFromData(data);
    final stored = _nullableTrim(data['professionalIdValue'] as String?);
    if (stored != null) return stored;
    return type == ProfessionalIdType.rpps
        ? _normalizeRpps(data['rpps'] as String?) ?? ''
        : '';
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

  static EngagementStatus _engagementStatus(Object? value) {
    if (value is String) {
      return EngagementStatus.values
              .where((status) => status.name == value)
              .firstOrNull ??
          EngagementStatus.confirmed;
    }
    return EngagementStatus.confirmed;
  }

  @override
  Stream<List<AppNotification>> watchNotifications() {
    final uid = _notificationUid;
    return _notificationFirestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final values =
              snapshot.docs
                  .map((document) {
                    final data = document.data();
                    return AppNotification(
                      id: document.id,
                      eventId: data['eventId'] as String? ?? '',
                      type: appNotificationTypeFromValue(
                        data['eventType'] as String? ?? '',
                      ),
                      title: data['title'] as String? ?? 'Notification',
                      body: data['body'] as String? ?? '',
                      occurredAt:
                          (data['occurredAt'] as Timestamp?)?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0),
                      missionId: data['missionId'] as String? ?? '',
                      engagementId: data['engagementId'] as String?,
                      readAt: (data['readAt'] as Timestamp?)?.toDate(),
                    );
                  })
                  .toList(growable: false)
                ..sort(
                  (left, right) => right.occurredAt.compareTo(left.occurredAt),
                );
          return List.unmodifiable(values.take(50));
        });
  }

  @override
  Future<void> setNotificationRead(
    String notificationId, {
    required bool read,
  }) => _notificationFirestore
      .collection('notifications')
      .doc(notificationId)
      .update({'readAt': read ? FieldValue.serverTimestamp() : null});

  @override
  Future<CoordinationNeed?> getMission(String missionId) async {
    final document = await _notificationFirestore
        .collection('missions')
        .doc(missionId)
        .get();
    final data = document.data();
    return data == null
        ? null
        : FirestoreMissionMapper.fromFirestore(id: document.id, data: data);
  }

  @override
  Stream<NotificationPreferences> watchNotificationPreferences() {
    final uid = _notificationUid;
    return _notificationFirestore
        .collection('notificationPreferences')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null) return const NotificationPreferences();
          return NotificationPreferences(
            compatibleMissions: data['compatibleMissions'] as bool? ?? false,
            engagementUpdates: data['engagementUpdates'] as bool? ?? true,
            operationalAlerts: data['operationalAlerts'] as bool? ?? true,
            quietHoursStart: data['quietHoursStart'] as int? ?? 22,
            quietHoursEnd: data['quietHoursEnd'] as int? ?? 7,
          );
        });
  }

  @override
  Future<void> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) {
    final uid = _notificationUid;
    return _notificationFirestore
        .collection('notificationPreferences')
        .doc(uid)
        .set({
          'uid': uid,
          'compatibleMissions': preferences.compatibleMissions,
          'engagementUpdates': preferences.engagementUpdates,
          'operationalAlerts': preferences.operationalAlerts,
          'quietHoursStart': preferences.quietHoursStart,
          'quietHoursEnd': preferences.quietHoursEnd,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Future<void> registerPushSubscription(
    PushSubscriptionRegistration registration,
  ) => _registerPushSubscription(registration);

  @override
  Future<void> registerPushSubscriptionForActivation(
    PushSubscriptionRegistration registration, {
    required void Function(bool tokenChanged) onTokenCompared,
  }) =>
      _registerPushSubscription(registration, onTokenCompared: onTokenCompared);

  Future<void> _registerPushSubscription(
    PushSubscriptionRegistration registration, {
    void Function(bool tokenChanged)? onTokenCompared,
  }) async {
    final uid = _notificationUid;
    final reference = _notificationFirestore
        .collection('pushSubscriptions')
        .doc('${uid}_${registration.installationId}');
    bool? tokenChanged;
    await _notificationFirestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      tokenChanged = didPushTokenChange(
        existing.data()?['token'],
        registration.token,
      );
      final now = FieldValue.serverTimestamp();
      transaction.set(reference, {
        'uid': uid,
        'installationId': registration.installationId,
        'token': registration.token,
        'platform': registration.platform,
        'active': true,
        'lastUsedAt': now,
        'createdAt': existing.data()?['createdAt'] ?? now,
        'updatedAt': now,
      }, SetOptions(merge: true));
    });
    if (onTokenCompared != null) {
      unawaited(
        verifyPersistedPushTokenForDiagnostic(
          readFirestoreToken: () async {
            final snapshot = await reference.get();
            return snapshot.data()?['token'];
          },
        ).then(
          (stored) => emitPushTokenChainLifecycleTrace(
            debugPrint,
            PushTokenChainLifecycleTraceState.persistCompareStored,
            value: stored,
          ),
        ),
      );
    }
    if (onTokenCompared case final callback?) {
      try {
        callback(tokenChanged ?? true);
      } catch (_) {
        // Diagnostic output must never affect a committed subscription.
      }
    }
  }

  @override
  Future<PushSubscriptionState> readPushSubscriptionState(
    String installationId,
  ) async {
    if (installationId.isEmpty) return PushSubscriptionState.absent;
    final uid = _notificationUid;
    final snapshot = await _notificationFirestore
        .collection('pushSubscriptions')
        .doc('${uid}_$installationId')
        .get();
    final data = snapshot.data();
    final token = data?['token'];
    if (!snapshot.exists) return PushSubscriptionState.absent;
    final validIdentity =
        data?['uid'] == uid &&
        data?['installationId'] == installationId &&
        data?['platform'] == 'web' &&
        token is String &&
        token.trim().isNotEmpty;
    if (!validIdentity) return PushSubscriptionState.inactive;
    if (data?['active'] == true) return PushSubscriptionState.active;
    if (data?['disabledReason'] ==
        'messaging/registration-token-not-registered') {
      return PushSubscriptionState.stale;
    }
    return PushSubscriptionState.inactive;
  }

  @override
  Future<void> disablePushSubscription(String installationId) {
    final uid = _notificationUid;
    return _notificationFirestore
        .collection('pushSubscriptions')
        .doc('${uid}_$installationId')
        .update({
          'active': false,
          'lastUsedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  static String _missionUpdateMessage(String code) => switch (code) {
    'permission-denied' =>
      'Vous ne pouvez modifier que les missions de vos centres.',
    'not-found' => 'Mission introuvable.',
    'failed-precondition' =>
      'La mission ne peut pas être mise à jour avec ces informations.',
    'invalid-argument' => 'Les informations de la mission sont invalides.',
    'unauthenticated' => 'Vous devez vous connecter pour modifier une mission.',
    _ => 'La mission n’a pas pu être mise à jour. Réessayez.',
  };

  static NeedStatus _statusForQuotas(ProfessionQuotas quotas) {
    if (quotas.isCovered) return NeedStatus.complete;
    if (quotas.requiredTotal > 0 && quotas.coverage < .5) {
      return NeedStatus.critical;
    }
    return NeedStatus.toComplete;
  }
}
