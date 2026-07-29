import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/location_address_registry.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
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

  test('all verification levels from the audited source are preserved', () {
    final statuses = verifiedLocationRegistry.values
        .map((record) => record.address.status)
        .toList();

    expect(
      statuses.where((status) => status == AddressStatus.verifiedOfficial),
      hasLength(32),
    );
    expect(
      statuses.where((status) => status == AddressStatus.verifiedCrossSource),
      hasLength(11),
    );
    expect(
      statuses.where((status) => status == AddressStatus.needsConfirmation),
      hasLength(16),
    );
    expect(
      statuses.where((status) => status == AddressStatus.notFound),
      hasLength(6),
    );
  });

  test('official partner addresses and source metadata are retained', () {
    final park = places.singleWhere(
      (place) => place.name == 'Parc des Expositions de Bordeaux',
    );
    final redCross = places.singleWhere(
      (place) => place.type == ResponsePlaceType.redCross,
    );

    expect(park.structuredAddress?.addressLine1, 'Cours Charles Bricaud');
    expect(park.structuredAddress?.latitude, closeTo(44.896337, 0.000001));
    expect(park.structuredAddress?.secondSourceUrl, isNotEmpty);
    expect(
      redCross.name,
      'Croix-Rouge française - Délégation territoriale de la Gironde',
    );
    expect(redCross.structuredAddress?.addressLine1, '5 Avenue Gay-Lussac');
    expect(redCross.structuredAddress?.city, 'Artigues-près-Bordeaux');
  });

  test('non autonomous or closed sites cannot receive new missions', () {
    final unavailable = places.where((place) => !place.isOperational).toList();
    expect(unavailable, hasLength(18));
    expect(
      unavailable.every(
        (place) => place.type == ResponsePlaceType.interventionSector,
      ),
      isTrue,
    );
    expect(
      unavailable.map((place) => place.name),
      containsAll(['Bordeaux Benauge', 'Podensac', 'Cavignac']),
    );
  });

  test('different implantation cities are preserved without normalization', () {
    final castillon = places.singleWhere(
      (place) => place.name == 'Castillon-la-Bataille',
    );
    final cadillac = places.singleWhere((place) => place.name == 'Cadillac');

    expect(castillon.structuredAddress?.city, 'Saint-Magne-de-Castillon');
    expect(cadillac.structuredAddress?.city, 'Béguey');
  });
}

class _UnusedStore implements LocationSeedStore {
  @override
  Future<bool> hasLocations() => throw UnimplementedError();

  @override
  Future<void> writeLocationBatch(List<LocationSeedDocument> documents) =>
      throw UnimplementedError();
}
