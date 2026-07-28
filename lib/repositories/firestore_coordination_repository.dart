import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/need.dart';
import 'coordination_repository.dart';
import 'firestore_mission_mapper.dart';

class FirestoreCoordinationRepository implements CoordinationRepository {
  FirestoreCoordinationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<CoordinationNeed>> watchMissions() {
    return _firestore.collection('missions').snapshots().map((snapshot) {
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
        .map((snapshot) => snapshot.docs.map(_locationFromDocument).toList());
  }

  @override
  Future<String> createMission(MissionDraft draft) async {
    final reference = _firestore.collection('missions').doc();
    debugPrint('Publication Firestore mission : début');
    debugPrint('Identifiant mission généré : ${reference.id}');
    try {
      await reference.set(
        FirestoreMissionMapper.toFirestore(
          id: reference.id,
          draft: draft,
          serverTimestamp: FieldValue.serverTimestamp(),
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
    final missionRef = _firestore.collection('missions').doc(missionId);
    final volunteerRef = _firestore.collection('volunteers').doc();
    final engagementRef = _firestore.collection('engagements').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(missionRef);
      if (!snapshot.exists) {
        throw const RepositoryException('Mission introuvable');
      }
      final data = snapshot.data()!;
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
          registeredMk++;
        case VolunteerProfession.pp:
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
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phone': phone.trim(),
        'profession': profession.name,
        'createdAt': now,
      };
      final normalizedEmail = email?.trim();
      if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
        volunteerData['email'] = normalizedEmail;
      }
      transaction.set(volunteerRef, volunteerData);
      transaction.set(engagementRef, {
        'missionId': missionId,
        'volunteerId': volunteerRef.id,
        'profession': profession.name,
        'createdAt': now,
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

  ResponsePlace _locationFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return ResponsePlace(
      id: document.id,
      name: data['name'] as String? ?? 'À renseigner',
      type: _enumByName(
        ResponsePlaceType.values,
        data['type'] as String?,
        ResponsePlaceType.otherPartnerSite,
      ),
      group: _enumByName(
        TerritorialGroup.values,
        data['group'] as String?,
        TerritorialGroup.partnerSites,
      ),
      activeNeeds: _int(data['activeNeeds']),
      address: data['address'] as String?,
    );
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
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
