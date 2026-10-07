import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/public_mission_discovery.dart';

abstract interface class PublicMissionDiscoveryRepository {
  Stream<List<PublicMissionDiscovery>> watchMissions();
}

class EmptyPublicMissionDiscoveryRepository
    implements PublicMissionDiscoveryRepository {
  const EmptyPublicMissionDiscoveryRepository();

  @override
  Stream<List<PublicMissionDiscovery>> watchMissions() =>
      Stream.value(const []);
}

class FirestorePublicMissionDiscoveryRepository
    implements PublicMissionDiscoveryRepository {
  const FirestorePublicMissionDiscoveryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<PublicMissionDiscovery>> watchMissions() => _firestore
      .collection('publicMissionDiscovery')
      .orderBy('day')
      .snapshots()
      .map(
        (snapshot) => List<PublicMissionDiscovery>.unmodifiable(
          snapshot.docs.map(
            (document) => PublicMissionDiscovery.fromMap(
              documentId: document.id,
              data: document.data(),
            ),
          ),
        ),
      );
}
