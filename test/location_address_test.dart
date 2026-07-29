import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/repositories/firestore_location_mapper.dart';
import 'package:interface_incendies_gironde/services/firestore_seed_service.dart';

void main() {
  test('an old location without address remains readable', () {
    final place = FirestoreLocationMapper.fromFirestore(
      id: 'old',
      data: const {
        'name': 'Ancien site',
        'group': 'medoc',
        'type': 'sdisStation',
      },
    );
    expect(place.structuredAddress, isNull);
    expect(place.publicAddressLabel, 'Adresse à renseigner');
  });

  test('a structured official address is parsed and calculated', () {
    final place = FirestoreLocationMapper.fromFirestore(
      id: 'park',
      data: const {
        'name': 'Parc',
        'group': 'partnerSites',
        'type': 'civilianReceptionSite',
        'addressLine1': 'Cours Jules Ladoumègue',
        'postalCode': '33300',
        'city': 'Bordeaux',
        'country': 'France',
        'addressStatus': 'verified_official',
        'addressSourceUrl': 'https://official.example',
      },
    );
    expect(
      place.verifiedAddress,
      'Cours Jules Ladoumègue, 33300 Bordeaux, France',
    );
    expect(place.publicAddressLabel, place.verifiedAddress);
    expect(place.publicAddressLabel, isNot(contains('official.example')));
  });

  test('an uncertain address gets an explicit public label', () {
    final place = FirestoreLocationMapper.fromFirestore(
      id: 'uncertain',
      data: const {
        'name': 'Site',
        'group': 'partnerSites',
        'type': 'redCross',
        'addressStatus': 'needs_confirmation',
      },
    );
    expect(place.publicAddressLabel, 'Adresse à confirmer');
  });

  test('the reference catalogue keeps exactly 65 stable unique IDs', () {
    final service = FirestoreSeedService(store: _UnusedStore());
    final ids = places.map(service.stableLocationId).toList();
    expect(ids, hasLength(65));
    expect(ids.toSet(), hasLength(65));
    expect(places.where((place) => place.name == 'Pauillac'), hasLength(1));
  });
}

class _UnusedStore implements LocationSeedStore {
  @override
  Future<bool> hasLocations() => throw UnimplementedError();

  @override
  Future<void> writeLocationBatch(List<LocationSeedDocument> documents) =>
      throw UnimplementedError();
}
