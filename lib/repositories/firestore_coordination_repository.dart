import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/need.dart';
import '../models/volunteer_profile.dart';
import '../utils/switch_latest.dart';
import 'coordination_repository.dart';
import 'firestore_location_mapper.dart';
import 'firestore_mission_mapper.dart';

@visibleForTesting
bool canStartVolunteerEngagement({
  required bool hasUser,
  required bool isAnonymous,
}) => !hasUser || isAnonymous;

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

class FirestoreCoordinationRepository implements CoordinationRepository {
  FirestoreCoordinationRepository(
    this._firestore,
    this._auth, {
    FirebaseFirestore? responsibleFirestore,
    FirebaseAuth? responsibleAuth,
  }) : _responsibleFirestore = responsibleFirestore ?? _firestore,
       _responsibleAuth = responsibleAuth ?? _auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFirestore _responsibleFirestore;
  final FirebaseAuth _responsibleAuth;

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
            if (!snapshot.exists) return null;
            final data = snapshot.data()!;
            return ResponsibleAccess(
              uid: user.uid,
              role: data['role'] as String? ?? '',
              locationIds: Set<String>.from(
                data['locationIds'] as List? ?? const [],
              ),
              active: data['active'] as bool? ?? false,
            );
          });
    });
  }

  @override
  Future<ResponsibleAccess> signInResponsible({
    required String email,
    required String password,
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
      final roleSnapshot = await _responsibleFirestore
          .collection('roles')
          .doc(user.uid)
          .get();
      if (!roleSnapshot.exists) {
        await _restoreAnonymousSession();
        throw const RepositoryException(
          'Votre compte n’est pas autorisé à publier pour ce lieu.',
        );
      }
      final data = roleSnapshot.data()!;
      final access = ResponsibleAccess(
        uid: user.uid,
        role: data['role'] as String? ?? '',
        locationIds: Set<String>.from(data['locationIds'] as List? ?? const []),
        active: data['active'] as bool? ?? false,
      );
      if (!access.active) {
        await _restoreAnonymousSession();
        throw const RepositoryException(
          'Votre compte responsable est inactif.',
        );
      }
      if (!access.isCoordinator && !access.isSiteManager) {
        await _restoreAnonymousSession();
        throw const RepositoryException(
          'Votre compte n’est pas autorisé à publier pour ce lieu.',
        );
      }
      return access;
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
    return _firestore
        .collection('missions')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final missions = snapshot.docs
              .map(
                (document) => FirestoreMissionMapper.fromFirestore(
                  id: document.id,
                  data: document.data(),
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
        });
  }

  @override
  Stream<List<ResponsePlace>> watchLocations() {
    return _firestore
        .collection('locations')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => FirestoreLocationMapper.fromFirestore(
                  id: document.id,
                  data: document.data(),
                ),
              )
              .toList(),
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
    _validateRequiredProfileFields(
      email: profile.email,
      rpps: profile.rpps,
      cptsId: profile.cptsId,
      cptsLabel: profile.cptsLabel,
    );
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous || user.uid != profile.uid) {
      throw const RepositoryException(
        'Ce profil n’appartient pas à la session volontaire active.',
      );
    }
    final reference = _firestore.collection('volunteers').doc(user.uid);
    await _firestore
        .runTransaction((transaction) async {
          final existing = await transaction.get(reference);
          final now = FieldValue.serverTimestamp();
          transaction.set(reference, {
            ..._profileData(profile, now),
            'createdAt': existing.data()?['createdAt'] ?? now,
          });
        })
        .timeout(const Duration(seconds: 15));
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
            if (!snapshot.exists || data == null) return null;
            final profession = data['profession'] as String?;
            if (profession != VolunteerProfession.mk.name &&
                profession != VolunteerProfession.pp.name) {
              throw const RepositoryException(
                'La profession de cet engagement est invalide.',
              );
            }
            return EngagementInfo(
              missionId: missionId,
              volunteerId: user.uid,
              profession: VolunteerProfession.values.byName(profession!),
              status: _engagementStatus(data['status']),
              createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
              updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
            );
          });
    });
  }

  @override
  Stream<List<EngagementInfo>> watchMissionEngagements(String missionId) {
    return _responsibleFirestore
        .collection('engagements')
        .where('missionId', isEqualTo: missionId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) {
                final data = document.data();
                final profession = data['profession'] as String?;
                if (profession != VolunteerProfession.mk.name &&
                    profession != VolunteerProfession.pp.name) {
                  return null;
                }
                return EngagementInfo(
                  missionId: missionId,
                  volunteerId: data['volunteerId'] as String? ?? '',
                  profession: VolunteerProfession.values.byName(profession!),
                  status: _engagementStatus(data['status']),
                  createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
                  updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
                );
              })
              .whereType<EngagementInfo>()
              .toList(growable: false),
        );
  }

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
    if (data?['active'] != true || data?['role'] != 'coordinator') {
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
              final requiredMk = _int(mission['requiredMk']);
              final requiredPp = _int(mission['requiredPp']);
              var registeredMk = _int(mission['registeredMk']);
              var registeredPp = _int(mission['registeredPp']);
              final professionName = engagement['profession'] as String?;
              if (professionName != VolunteerProfession.mk.name &&
                  professionName != VolunteerProfession.pp.name) {
                throw const RepositoryException(
                  'La profession de cet engagement est invalide.',
                );
              }
              final profession = VolunteerProfession.values.byName(
                professionName!,
              );
              if ((profession == VolunteerProfession.mk &&
                      registeredMk >= requiredMk) ||
                  (profession == VolunteerProfession.pp &&
                      registeredPp >= requiredPp)) {
                throw const RepositoryException(
                  'Cette mission est désormais complète.',
                );
              }
              final delta = EngagementCounterTransition.delta(
                from: currentStatus,
                to: EngagementStatus.confirmed,
                profession: profession,
              );
              registeredMk += delta.mk;
              registeredPp += delta.pp;
              final now = FieldValue.serverTimestamp();
              transaction.update(reference, {
                'status': EngagementStatus.confirmed.name,
                'updatedAt': now,
              });
              transaction.update(missionReference, {
                'registeredMk': registeredMk,
                'registeredPp': registeredPp,
                'status': _statusFor(
                  requiredMk: requiredMk,
                  registeredMk: registeredMk,
                  requiredPp: requiredPp,
                  registeredPp: registeredPp,
                ).name,
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
              final requiredMk = _int(mission['requiredMk']);
              final requiredPp = _int(mission['requiredPp']);
              var registeredMk = _int(mission['registeredMk']);
              var registeredPp = _int(mission['registeredPp']);
              final professionName = engagement['profession'] as String?;
              if (professionName != VolunteerProfession.mk.name &&
                  professionName != VolunteerProfession.pp.name) {
                throw const RepositoryException(
                  'La profession de cet engagement est invalide.',
                );
              }
              final profession = VolunteerProfession.values.byName(
                professionName!,
              );
              if ((profession == VolunteerProfession.mk && registeredMk <= 0) ||
                  (profession == VolunteerProfession.pp && registeredPp <= 0)) {
                throw const RepositoryException(
                  'Le compteur correspondant est déjà à zéro.',
                );
              }
              final delta = EngagementCounterTransition.delta(
                from: currentStatus,
                to: status,
                profession: profession,
              );
              registeredMk += delta.mk;
              registeredPp += delta.pp;
              final now = FieldValue.serverTimestamp();
              transaction.update(reference, {
                'status': status.name,
                'updatedAt': now,
              });
              transaction.update(missionReference, {
                'registeredMk': registeredMk,
                'registeredPp': registeredPp,
                'status': _statusFor(
                  requiredMk: requiredMk,
                  registeredMk: registeredMk,
                  requiredPp: requiredPp,
                  registeredPp: registeredPp,
                ).name,
                'updatedAt': now,
              });
            })
            .timeout(const Duration(seconds: 15));
        return;
      }
      await reference
          .update({
            'status': status.name,
            'updatedAt': FieldValue.serverTimestamp(),
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
    if (!role.exists || role.data()?['active'] != true) {
      throw const RepositoryException('Votre compte responsable est inactif.');
    }
    final access = ResponsibleAccess(
      uid: user.uid,
      role: role.data()?['role'] as String? ?? '',
      locationIds: Set<String>.from(
        role.data()?['locationIds'] as List? ?? const [],
      ),
      active: true,
    );
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
  Future<EngagementCreationResult> createEngagement({
    required String missionId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    String? rpps,
    String? cptsId,
    String? cptsLabel,
    required VolunteerProfession profession,
    List<String> equipment = const [],
  }) async {
    _validateRequiredProfileFields(
      email: email,
      rpps: rpps,
      cptsId: cptsId,
      cptsLabel: cptsLabel,
    );
    if (!profession.isSupportedByCurrentMission) {
      throw const RepositoryException(
        'Cette profession n’est pas encore proposée pour cette mission.',
      );
    }
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
            final data = snapshot.data()!;
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
            final requiredMk = _int(data['requiredMk']);
            final requiredPp = _int(data['requiredPp']);
            var registeredMk = _int(data['registeredMk']);
            var registeredPp = _int(data['registeredPp']);
            if (profession == VolunteerProfession.mk) {
              if (registeredMk >= requiredMk) {
                throw const RepositoryException(
                  'Ce besoin est désormais couvert pour votre profession.',
                );
              }
              registeredMk++;
            } else {
              if (registeredPp >= requiredPp) {
                throw const RepositoryException(
                  'Ce besoin est désormais couvert pour votre profession.',
                );
              }
              registeredPp++;
            }
            final now = FieldValue.serverTimestamp();

            final volunteerData = <String, dynamic>{
              'uid': uid,
              'firstName': firstName.trim(),
              'lastName': lastName.trim(),
              'phone': phone.trim(),
              'profession': profession.name,
              'updatedAt': now,
              'equipment': equipment
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toSet()
                  .toList(),
            };
            final normalizedEmail = email?.trim();
            if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
              volunteerData['email'] = normalizedEmail;
            } else if (existingVolunteer.exists) {
              volunteerData['email'] = FieldValue.delete();
            }
            for (final entry in {
              'rpps': _normalizeRpps(rpps),
              'cptsId': _nullableTrim(cptsId),
              'cptsLabel': _nullableTrim(cptsLabel),
            }.entries) {
              if (entry.value != null) {
                volunteerData[entry.key] = entry.value;
              } else if (existingVolunteer.exists) {
                volunteerData[entry.key] = FieldValue.delete();
              }
            }
            transaction.set(volunteerRef, {
              ...volunteerData,
              'createdAt': existingVolunteer.data()?['createdAt'] ?? now,
            }, SetOptions(merge: true));
            if (isReengagement) {
              transaction.update(engagementRef, {
                'profession': profession.name,
                'updatedAt': now,
                'status': EngagementStatus.confirmed.name,
              });
            } else {
              transaction.set(engagementRef, {
                'missionId': missionId,
                'volunteerId': uid,
                'profession': profession.name,
                'createdAt': now,
                'updatedAt': now,
                'status': EngagementStatus.confirmed.name,
              });
            }
            transaction.update(missionRef, {
              'registeredMk': registeredMk,
              'registeredPp': registeredPp,
              'status': _statusFor(
                requiredMk: requiredMk,
                registeredMk: registeredMk,
                requiredPp: requiredPp,
                registeredPp: registeredPp,
              ).name,
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
            if (professionName != VolunteerProfession.mk.name &&
                professionName != VolunteerProfession.pp.name) {
              throw const RepositoryException(
                'Le désengagement n’a pas pu être enregistré. Réessayez.',
              );
            }
            final profession = VolunteerProfession.values.byName(
              professionName!,
            );
            final requiredMk = _int(mission['requiredMk']);
            final requiredPp = _int(mission['requiredPp']);
            var registeredMk = _int(mission['registeredMk']);
            var registeredPp = _int(mission['registeredPp']);
            if (profession == VolunteerProfession.mk) {
              if (registeredMk <= 0) {
                throw const RepositoryException(
                  'Le désengagement n’a pas pu être enregistré. Réessayez.',
                );
              }
              registeredMk--;
            } else {
              if (registeredPp <= 0) {
                throw const RepositoryException(
                  'Le désengagement n’a pas pu être enregistré. Réessayez.',
                );
              }
              registeredPp--;
            }
            transaction.update(engagementRef, {
              'status': EngagementStatus.cancelled.name,
              'updatedAt': now,
            });
            transaction.update(missionRef, {
              'registeredMk': registeredMk,
              'registeredPp': registeredPp,
              'status': _statusFor(
                requiredMk: requiredMk,
                registeredMk: registeredMk,
                requiredPp: requiredPp,
                registeredPp: registeredPp,
              ).name,
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

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static VolunteerProfile _profileFromFirestore(
    String uid,
    Map<String, dynamic> data,
  ) {
    final professionName = data['profession'] as String?;
    final profession = VolunteerProfession.values
        .where((value) => value.name == professionName)
        .firstOrNull;
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
      cptsId: _nullableTrim(data['cptsId'] as String?),
      cptsLabel: _nullableTrim(data['cptsLabel'] as String?),
      profession: profession,
      equipment: List<String>.from(data['equipment'] as List? ?? const []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> _profileData(
    VolunteerProfile profile,
    Object serverTimestamp,
  ) {
    final email = _nullableTrim(profile.email);
    final rpps = _normalizeRpps(profile.rpps);
    final cptsId = _nullableTrim(profile.cptsId);
    final cptsLabel = _nullableTrim(profile.cptsLabel);
    return {
      'uid': profile.uid,
      'firstName': profile.firstName.trim(),
      'lastName': profile.lastName.trim(),
      'phone': profile.phone.trim(),
      'email': ?email,
      'rpps': ?rpps,
      'cptsId': ?cptsId,
      'cptsLabel': ?cptsLabel,
      'profession': profile.profession.name,
      'equipment': profile.equipment
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(),
      'updatedAt': serverTimestamp,
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

  static void _validateRequiredProfileFields({
    required String? email,
    required String? rpps,
    required String? cptsId,
    required String? cptsLabel,
  }) {
    final normalizedEmail = _nullableTrim(email);
    if (normalizedEmail == null ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedEmail)) {
      throw const RepositoryException('Saisissez une adresse email valide.');
    }
    if (!RegExp(r'^\d{11}$').hasMatch(_normalizeRpps(rpps) ?? '')) {
      throw const RepositoryException(
        'Saisissez un numéro RPPS valide à 11 chiffres.',
      );
    }
    if (_nullableTrim(cptsId) == null || _nullableTrim(cptsLabel) == null) {
      throw const RepositoryException('Renseignez votre CPTS.');
    }
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

  static NeedStatus _statusFor({
    required int requiredMk,
    required int registeredMk,
    required int requiredPp,
    required int registeredPp,
  }) {
    if (registeredMk >= requiredMk && registeredPp >= requiredPp) {
      return NeedStatus.complete;
    }
    final required = requiredMk + requiredPp;
    final registered = registeredMk + registeredPp;
    if (required > 0 && registered / required < .5) {
      return NeedStatus.critical;
    }
    return NeedStatus.toComplete;
  }
}
