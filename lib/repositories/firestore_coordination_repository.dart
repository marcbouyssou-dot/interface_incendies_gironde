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
    var user = _auth.currentUser;
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

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(missionRef);
      if (!snapshot.exists) {
        throw const RepositoryException('Mission introuvable');
      }
      final existingEngagement = await transaction.get(engagementRef);
      if (existingEngagement.exists) {
        throw const RepositoryException(
          'Vous êtes déjà engagé sur cette mission.',
        );
      }
      final existingVolunteer = await transaction.get(volunteerRef);
      final data = snapshot.data()!;
      if (data['isActive'] == false) {
        throw const RepositoryException(
          'Cette mission est désormais complète.',
        );
      }
      final usesCurrentSchema = data.containsKey('requiredMk');
      final requiredMk = _int(
        data['requiredMk'] ?? data['requiredPhysiotherapists'],
      );
      final requiredPp = _int(
        data['requiredPp'] ?? data['requiredPodiatrists'],
      );
      var registeredMk = _int(
        data['registeredMk'] ?? data['registeredPhysiotherapists'],
      );
      var registeredPp = _int(
        data['registeredPp'] ?? data['registeredPodiatrists'],
      );

      switch (profession) {
        case VolunteerProfession.mk:
          if (registeredMk >= requiredMk) {
            throw const RepositoryException(
              'Cette mission est désormais complète.',
            );
          }
          registeredMk++;
        case VolunteerProfession.pp:
          if (registeredPp >= requiredPp) {
            throw const RepositoryException(
              'Cette mission est désormais complète.',
            );
          }
          registeredPp++;
      }

      final status = _statusFor(
        requiredMk: requiredMk,
        registeredMk: registeredMk,
        requiredPp: requiredPp,
        registeredPp: registeredPp,
      );
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
      transaction.set(volunteerRef, {
        ...volunteerData,
        'createdAt': existingVolunteer.data()?['createdAt'] ?? now,
        'equipment': <String>[],
      }, SetOptions(merge: true));
      transaction.set(engagementRef, {
        'missionId': missionId,
        'volunteerId': uid,
        'profession': profession.name,
        'createdAt': now,
        'status': 'confirmed',
      });
      transaction.update(missionRef, {
        usesCurrentSchema ? 'registeredMk' : 'registeredPhysiotherapists':
            registeredMk,
        usesCurrentSchema ? 'registeredPp' : 'registeredPodiatrists':
            registeredPp,
        'status': status.name,
        'updatedAt': now,
      });
    });
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

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
