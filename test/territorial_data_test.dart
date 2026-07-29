import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';

void main() {
  test('all territorial groups have their expected French label', () {
    expect(
      TerritorialGroup.values.map((group) => group.label),
      containsAll([
        'Bordeaux Métropole',
        'Nord Bassin',
        'Sud Bassin',
        'Médoc',
        'Sud Gironde',
        'Libournais',
        'Haute Gironde',
        'Sites partenaires',
      ]),
    );
  });

  test('every place belongs to a territorial group', () {
    for (final group in TerritorialGroup.values) {
      expect(
        places.where((place) => place.group == group),
        isNotEmpty,
        reason: '${group.label} doit contenir au moins un lieu',
      );
    }
  });

  test('the real SDIS place catalogue is present', () {
    final names = places.map((place) => place.name).toSet();
    expect(
      names,
      containsAll([
        'Bordeaux Bastide',
        'Mérignac',
        'La Teste-de-Buch / Pyla-sur-Mer',
        'Langon',
        'Libourne',
        'Saint-André-de-Cubzac',
      ]),
    );
  });

  test('Pauillac is unique and belongs only to Médoc', () {
    final pauillac = places.where((place) => place.name == 'Pauillac').toList();
    expect(pauillac, hasLength(1));
    expect(pauillac.single.group, TerritorialGroup.medoc);
    expect(pauillac.single.type, ResponsePlaceType.sdisStation);
  });

  test('partner sites have the correct group and type', () {
    final exhibition = places.singleWhere(
      (place) => place.name == 'Parc des Expositions de Bordeaux',
    );
    final redCross = places.singleWhere(
      (place) =>
          place.name ==
          'Croix-Rouge française - Délégation territoriale de la Gironde',
    );

    expect(exhibition.group, TerritorialGroup.partnerSites);
    expect(exhibition.type, ResponsePlaceType.civilianReceptionSite);
    expect(redCross.group, TerritorialGroup.partnerSites);
    expect(redCross.type, ResponsePlaceType.redCross);
  });

  test('uncertain addresses remain explicitly identified', () {
    final cauderan = places.singleWhere(
      (place) => place.name == 'Bordeaux Caudéran',
    );
    final podensac = places.singleWhere((place) => place.name == 'Podensac');

    expect(cauderan.publicAddressLabel, 'Adresse à confirmer');
    expect(podensac.publicAddressLabel, 'Adresse à renseigner');
  });
}
