import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/services/firestore_seed_service.dart';

void main() {
  test(
    'an empty locations collection imports all 65 validated places',
    () async {
      final store = _MemoryLocationSeedStore();
      final service = FirestoreSeedService(store: store);

      expect(await service.seedLocationsIfEmpty(), SeedResult.imported);
      expect(store.documents, hasLength(65));
      expect(store.batchWrites, 1);
    },
  );

  test('a non-empty collection is never modified', () async {
    final store = _MemoryLocationSeedStore()
      ..documents['terrain-location'] = const {'name': 'Saisie terrain'};

    expect(
      await FirestoreSeedService(store: store).seedLocationsIfEmpty(),
      SeedResult.skipped,
    );
    expect(store.documents, hasLength(1));
    expect(store.batchWrites, 0);
  });

  test('two consecutive seeds are idempotent and keep stable IDs', () async {
    final store = _MemoryLocationSeedStore();
    final service = FirestoreSeedService(store: store);
    final firstIds = places
        .map(service.stableLocationId)
        .toList(growable: false);

    await service.seedLocationsIfEmpty();
    final importedIds = store.documents.keys.toList(growable: false);
    await service.seedLocationsIfEmpty();

    expect(store.documents, hasLength(65));
    expect(store.batchWrites, 1);
    expect(importedIds, firstIds);
    expect(
      places.map(service.stableLocationId).toList(growable: false),
      firstIds,
    );
  });

  test('partners and unique Pauillac keep their validated metadata', () async {
    final store = _MemoryLocationSeedStore();
    await FirestoreSeedService(store: store).seedLocationsIfEmpty();
    final documents = store.documents.values;

    expect(
      documents.where(
        (data) => data['name'] == 'Parc des Expositions de Bordeaux',
      ),
      hasLength(1),
    );
    expect(
      documents.where((data) => data['name'] == 'Croix-Rouge Bordeaux'),
      hasLength(1),
    );
    final pauillac = documents
        .where((data) => data['name'] == 'Pauillac')
        .single;
    expect(pauillac['group'], TerritorialGroup.medoc.name);
  });

  test('location seeding never writes a missions collection', () async {
    final store = _MemoryLocationSeedStore();
    await FirestoreSeedService(store: store).seedLocationsIfEmpty();

    expect(store.collectionsWritten, {'locations'});
  });
}

class _MemoryLocationSeedStore implements LocationSeedStore {
  final documents = <String, Map<String, Object?>>{};
  final collectionsWritten = <String>{};
  int batchWrites = 0;

  @override
  Future<bool> hasLocations() async => documents.isNotEmpty;

  @override
  Future<void> writeLocationBatch(
    List<LocationSeedDocument> seedDocuments,
  ) async {
    batchWrites++;
    collectionsWritten.add('locations');
    for (final document in seedDocuments) {
      documents[document.id] = document.data;
    }
  }
}
