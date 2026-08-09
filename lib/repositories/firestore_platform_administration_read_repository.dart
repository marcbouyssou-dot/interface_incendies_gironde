import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/platform_administrator_access.dart';
import '../utils/switch_latest.dart';
import 'platform_administration_read_repository.dart';

class FirestorePlatformAdministrationReadRepository
    implements PlatformAdministrationReadRepository {
  const FirestorePlatformAdministrationReadRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Stream<PlatformAdministratorAccess?> watchCurrentAdministrator() {
    return switchLatest(_auth.authStateChanges(), (user) {
      if (user == null || user.isAnonymous) {
        return Stream<PlatformAdministratorAccess?>.value(null);
      }
      return _firestore
          .collection('platformAdministrators')
          .doc(user.uid)
          .snapshots()
          .map((snapshot) {
            final data = snapshot.data();
            return !snapshot.exists || data == null
                ? null
                : PlatformAdministratorAccess.fromMap(
                    uid: snapshot.id,
                    data: data,
                  );
          });
    });
  }

  @override
  Stream<List<MobilizationCoordinatorAssignment>> watchMobilizationCoordinators(
    String mobilizationId,
  ) {
    if (mobilizationId.trim().isEmpty) {
      return Stream<List<MobilizationCoordinatorAssignment>>.error(
        const FormatException('Identifiant de mobilisation invalide.'),
      );
    }
    return _firestore
        .collection('mobilizationAssignments')
        .where('mobilizationId', isEqualTo: mobilizationId)
        .where('role', isEqualTo: 'coordinator')
        .snapshots()
        .map((snapshot) {
          final assignments = snapshot.docs
              .map(
                (document) => MobilizationCoordinatorAssignment.fromMap(
                  id: document.id,
                  data: document.data(),
                ),
              )
              .toList(growable: false);
          assignments.sort((left, right) {
            if (left.active != right.active) return left.active ? -1 : 1;
            return left.uid.compareTo(right.uid);
          });
          return assignments;
        });
  }

  @override
  Stream<List<ActivePlatformCoordinator>> watchActiveCoordinators() {
    return _firestore
        .collection('roles')
        .where('role', isEqualTo: 'coordinator')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final coordinators = snapshot.docs
              .map(
                (document) => ActivePlatformCoordinator.fromMap(
                  uid: document.id,
                  data: document.data(),
                ),
              )
              .toList(growable: false);
          coordinators.sort((left, right) => left.uid.compareTo(right.uid));
          return coordinators;
        });
  }
}
