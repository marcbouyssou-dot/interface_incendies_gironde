import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/need.dart';
import 'coordination_repository.dart';
import 'firestore_location_mapper.dart';
import 'firestore_mission_mapper.dart';

class FirestoreCoordinationRepository implements CoordinationRepository {
  FirestoreCoordinationRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null || user.isAnonymous) {
        return Stream<ResponsibleAccess?>.value(null);
      }
      return _firestore.collection('roles').doc(user.uid).snapshots().map((
        snapshot,
      ) {
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
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const RepositoryException('Identifiants incorrects.');
      }
      final roleSnapshot = await _firestore
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
    await _auth.signOut();
    await _auth.signInAnonymously();
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
  Stream<EngagementInfo?> watchMyEngagement(String missionId) {
    final user = _auth.currentUser;
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
            return null;
          }
          return EngagementInfo(
            missionId: missionId,
            volunteerId: user.uid,
            profession: VolunteerProfession.values.byName(profession!),
            status: _engagementStatus(data['status']),
            updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
          );
        });
  }

  @override
  Stream<List<EngagementInfo>> watchMissionEngagements(String missionId) {
    return _firestore
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
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const RepositoryException(
        'Vous devez vous connecter comme coordinateur.',
      );
    }
    final role = await _firestore.collection('roles').doc(user.uid).get();
    final data = role.data();
    if (data?['active'] != true || data?['role'] != 'coordinator') {
      throw const RepositoryException(
        'Seul un coordinateur peut modifier ce statut.',
      );
    }
    final reference = _firestore
        .collection('engagements')
        .doc('${missionId}_$volunteerId');
    try {
      if (status == EngagementStatus.confirmed) {
        final missionReference = _firestore
            .collection('missions')
            .doc(missionId);
        await _firestore
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
        final missionReference = _firestore
            .collection('missions')
            .doc(missionId);
        await _firestore
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
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const RepositoryException(
        'Vous devez vous connecter pour déclarer un besoin.',
      );
    }
    final role = await _firestore.collection('roles').doc(user.uid).get();
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
    final reference = _firestore.collection('missions').doc();
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
  Future<void> createEngagement({
    required String missionId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    required VolunteerProfession profession,
  }) async {
    // ignore: avoid_print
    print('STEP 1 - CREATE ENGAGEMENT START');
    var user = _auth.currentUser;
    if (user == null) {
      // ignore: avoid_print
      print('STEP 2 - BEFORE ANONYMOUS SIGN IN');
      final credential = await _auth.signInAnonymously();
      // ignore: avoid_print
      print('STEP 3 - AFTER ANONYMOUS SIGN IN');
      user = credential.user;
    }
    // ignore: avoid_print
    print('STEP 4 - AUTH USER CHECK');
    if (user == null) {
      throw const RepositoryException(
        'Connexion sécurisée impossible. Réessayez.',
      );
    }
    // ignore: avoid_print
    print('STEP 5 - BUILD FIRESTORE REFERENCES');
    final uid = user.uid;
    final missionRef = _firestore.collection('missions').doc(missionId);
    final volunteerRef = _firestore.collection('volunteers').doc(uid);
    final engagementRef = _firestore
        .collection('engagements')
        .doc('${missionId}_$uid');

    try {
      // ignore: avoid_print
      print('STEP 6 - BEFORE TRANSACTION');
      // ignore: avoid_print
      print('BEFORE TRANSACTION');
      await _firestore
          .runTransaction((transaction) async {
            // ignore: avoid_print
            print('STEP 7 - INSIDE TRANSACTION');
            // ignore: avoid_print
            print('INSIDE TRANSACTION');
            // ignore: avoid_print
            print('STEP 8 - BEFORE MISSION READ');
            final snapshot = await transaction.get(missionRef);
            // ignore: avoid_print
            print('STEP 9 - AFTER MISSION READ');
            if (!snapshot.exists) {
              throw const RepositoryException('Mission introuvable');
            }
            // ignore: avoid_print
            print('STEP 10 - BEFORE ENGAGEMENT READ');
            final existingEngagement = await transaction.get(engagementRef);
            // ignore: avoid_print
            print('STEP 11 - AFTER ENGAGEMENT READ');
            if (existingEngagement.exists) {
              throw const RepositoryException(
                'Vous êtes déjà engagé sur cette mission.',
              );
            }
            // ignore: avoid_print
            print('STEP 12 - BEFORE VOLUNTEER READ');
            final existingVolunteer = await transaction.get(volunteerRef);
            // ignore: avoid_print
            print('STEP 13 - AFTER VOLUNTEER READ');
            final data = snapshot.data()!;
            // ignore: avoid_print
            print('STEP 14 - VALIDATE MISSION');
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
            final now = FieldValue.serverTimestamp();

            final volunteerData = <String, dynamic>{
              'uid': uid,
              'firstName': firstName.trim(),
              'lastName': lastName.trim(),
              'phone': phone.trim(),
              'profession': profession.name,
              'updatedAt': now,
            };
            final normalizedEmail = email?.trim();
            if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
              volunteerData['email'] = normalizedEmail;
            }
            // ignore: avoid_print
            print('STEP 15 - BEFORE VOLUNTEER SET');
            transaction.set(volunteerRef, {
              ...volunteerData,
              'createdAt': existingVolunteer.data()?['createdAt'] ?? now,
              'equipment': <String>[],
            }, SetOptions(merge: true));
            // ignore: avoid_print
            print('STEP 16 - AFTER VOLUNTEER SET');
            // ignore: avoid_print
            print('STEP 17 - BEFORE ENGAGEMENT SET');
            transaction.set(engagementRef, {
              'missionId': missionId,
              'volunteerId': uid,
              'profession': profession.name,
              'createdAt': now,
              'updatedAt': now,
              'status': EngagementStatus.pending.name,
            });
            // ignore: avoid_print
            print('STEP 18 - AFTER ENGAGEMENT SET');
            // ignore: avoid_print
            print('STEP 19 - BEFORE TRANSACTION COMMIT');
          })
          .timeout(const Duration(seconds: 15));
      // ignore: avoid_print
      print('STEP 20 - AFTER TRANSACTION');
      // ignore: avoid_print
      print('AFTER TRANSACTION');
      // ignore: avoid_print
      print('STEP 21 - CREATE ENGAGEMENT END');
    } on FirebaseException catch (error, stackTrace) {
      // ignore: avoid_print
      print(
        'CREATE_ENGAGEMENT_FIREBASE '
        'code=${error.code} '
        'message=${error.message} '
        'plugin=${error.plugin}',
      );
      // ignore: avoid_print
      print(stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      // ignore: avoid_print
      print(
        'CREATE_ENGAGEMENT_UNKNOWN '
        'type=${error.runtimeType} '
        'error=$error',
      );
      // ignore: avoid_print
      print(stackTrace);
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
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const RepositoryException(
        'Vous devez vous connecter pour déclarer un besoin.',
      );
    }
    final missionRef = _firestore.collection('missions').doc(missionId);
    final roleRef = _firestore.collection('roles').doc(user.uid);
    try {
      await _firestore
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
            final role = roleSnapshot.data();
            final access = ResponsibleAccess(
              uid: user.uid,
              role: role?['role'] as String? ?? '',
              locationIds: Set<String>.from(
                role?['locationIds'] as List? ?? const [],
              ),
              active: role?['active'] as bool? ?? false,
            );
            if (!access.canManage(mission['locationId'] as String? ?? '')) {
              throw const RepositoryException(
                'Votre compte n’est pas autorisé à publier pour ce lieu.',
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
