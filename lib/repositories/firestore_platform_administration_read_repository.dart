import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/platform_administrator_access.dart';
import '../models/user_display_identity.dart';
import '../utils/switch_latest.dart';
import 'platform_administration_read_repository.dart';
import 'user_display_identity_resolver.dart';

class FirestorePlatformAdministrationReadRepository
    implements PlatformAdministrationReadRepository {
  const FirestorePlatformAdministrationReadRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required UserDisplayIdentityResolver identityResolver,
  }) : _auth = auth,
       _firestore = firestore,
       _identityResolver = identityResolver;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final UserDisplayIdentityResolver _identityResolver;

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
        .asyncMap((snapshot) async {
          final identities = await _loadCoordinatorIdentities();
          final assignments = snapshot.docs
              .map(
                (document) => MobilizationCoordinatorAssignment.fromMap(
                  id: document.id,
                  data: document.data(),
                ),
              )
              .map(
                (assignment) =>
                    assignment.copyWithIdentity(identities[assignment.uid]),
              )
              .toList(growable: false);
          assignments.sort((left, right) {
            if (left.active != right.active) return left.active ? -1 : 1;
            return left.displayIdentity.displayName.compareTo(
              right.displayIdentity.displayName,
            );
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
        .asyncMap((snapshot) async {
          final identities = await _loadCoordinatorIdentities();
          final coordinators = snapshot.docs
              .map(
                (document) => ActivePlatformCoordinator.fromMap(
                  uid: document.id,
                  data: document.data(),
                ),
              )
              .map(
                (coordinator) =>
                    coordinator.copyWithIdentity(identities[coordinator.uid]),
              )
              .toList(growable: false);
          coordinators.sort(
            (left, right) => left.displayIdentity.displayName.compareTo(
              right.displayIdentity.displayName,
            ),
          );
          return coordinators;
        });
  }

  Future<Map<String, UserDisplayIdentity>> _loadCoordinatorIdentities() async {
    try {
      return await _identityResolver.listPlatformCoordinators();
    } catch (_) {
      return const {};
    }
  }
}
