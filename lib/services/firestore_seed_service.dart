import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/mock_data.dart';
import '../models/need.dart';

enum SeedResult { imported, skipped }

class LocationSeedDocument {
  const LocationSeedDocument({required this.id, required this.data});

  final String id;
  final Map<String, Object?> data;
}

abstract interface class LocationSeedStore {
  Future<bool> hasLocations();

  Future<void> writeLocationBatch(List<LocationSeedDocument> documents);
}

class FirestoreLocationSeedStore implements LocationSeedStore {
  FirestoreLocationSeedStore(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<bool> hasLocations() async {
    final snapshot = await _firestore.collection('locations').limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  @override
  Future<void> writeLocationBatch(List<LocationSeedDocument> documents) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection('locations');
    for (final document in documents) {
      batch.set(collection.doc(document.id), document.data);
    }
    await batch.commit();
  }
}

class FirestoreSeedService {
  FirestoreSeedService({
    required LocationSeedStore store,
    List<ResponsePlace>? validatedLocations,
  }) : _store = store,
       _validatedLocations = validatedLocations ?? places;

  final LocationSeedStore _store;
  final List<ResponsePlace> _validatedLocations;

  Future<SeedResult> seedLocationsIfEmpty() async {
    if (await _store.hasLocations()) return SeedResult.skipped;
    await _store.writeLocationBatch(
      _validatedLocations.map(toSeedDocument).toList(),
    );
    return SeedResult.imported;
  }

  LocationSeedDocument toSeedDocument(ResponsePlace location) {
    final id = stableLocationId(location);
    return LocationSeedDocument(
      id: id,
      data: {
        'id': id,
        'name': location.name,
        'group': location.group.name,
        'type': location.type.name,
        'address': location.address,
        'activeNeeds': location.activeNeeds,
      },
    );
  }

  String stableLocationId(ResponsePlace location) {
    var normalized = '${location.group.name}-${location.name}'.toLowerCase();
    const replacements = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'ç': 'c',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ÿ': 'y',
      'œ': 'oe',
    };
    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp('^-|-\$'), '');
  }
}
