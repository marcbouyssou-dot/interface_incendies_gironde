import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/public_mission_discovery.dart';

void main() {
  final data = {
    'publicId': 'public-safe',
    'day': '2026-10-08',
    'sectorLabel': 'Bordeaux Métropole',
    'professions': ['physiotherapist', 'nurse'],
    'status': 'open',
  };

  test('public model reads only its explicit presentation contract', () {
    final model = PublicMissionDiscovery.fromMap(
      documentId: 'public-safe',
      data: data,
    );
    expect(model.publicId, 'public-safe');
    expect(model.professionLabels, ['Masseur-kinésithérapeute', 'Infirmier']);
    expect(data.keys.toSet(), PublicMissionDiscovery.allowedFields);
  });

  test('unexpected operational fields fail closed', () {
    for (final field in [
      'address',
      'latitude',
      'longitude',
      'contactPhone',
      'availableEquipmentOnSite',
      'requestedEquipmentByProfession',
      'createdBy',
      'details',
      'registeredByProfession',
    ]) {
      expect(
        () => PublicMissionDiscovery.fromMap(
          documentId: 'public-safe',
          data: {...data, field: 'sensitive'},
        ),
        throwsFormatException,
      );
    }
    expect(
      () => PublicMissionDiscovery.fromMap(documentId: 'different', data: data),
      throwsFormatException,
    );
  });
}
