import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/admin_location.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/firestore_location_administration_repository.dart';
import 'package:interface_incendies_gironde/repositories/location_administration_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_location_administration_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

void main() {
  const legacy = <String, Object?>{
    'id': 'merignac',
    'name': 'Mérignac',
    'group': 'bordeauxMetropole',
    'type': 'sdisStation',
    'addressLine1': '12 rue du Test',
    'addressLine2': null,
    'postalCode': '33700',
    'city': 'Mérignac',
    'country': 'France',
    'contactName': null,
    'contactPhone': null,
    'latitude': 44.84,
    'longitude': -0.64,
    'active': true,
    'isOperational': true,
    'canDelete': false,
  };

  test('admin location parses the safe callable projection', () {
    final location = AdminLocation.fromMap(legacy);

    expect(location.id, 'merignac');
    expect(location.group, TerritorialGroup.bordeauxMetropole);
    expect(location.type, ResponsePlaceType.sdisStation);
    expect(location.addressLabel, '12 rue du Test, 33700 Mérignac, France');
    expect(location.active, isTrue);
    expect(location.canDelete, isFalse);
  });

  test('draft sends only the strict editable contract', () {
    final data = AdminLocation.fromMap(legacy).toDraft().toCallableData();

    expect(data.keys, {
      'name',
      'group',
      'type',
      'addressLine1',
      'addressLine2',
      'postalCode',
      'city',
      'country',
      'contactName',
      'contactPhone',
      'latitude',
      'longitude',
    });
    expect(data, isNot(contains('id')));
    expect(data, isNot(contains('active')));
  });

  test('Firestore repository lists legacy-compatible projections', () async {
    final source = _DataSource(
      listResult: {
        'locations': [legacy],
      },
    );
    final repository = FirestoreLocationAdministrationRepository(
      dataSource: source,
    );

    final locations = await repository.listLocations();

    expect(locations.single.name, 'Mérignac');
    expect(source.listCalls, 1);
  });

  test('Firestore repository sends exact create and delete payloads', () async {
    final source = _DataSource(
      manageResult: {'action': 'create', 'location': legacy},
    );
    final repository = FirestoreLocationAdministrationRepository(
      dataSource: source,
    );
    final draft = AdminLocation.fromMap(legacy).toDraft();

    await repository.createLocation(draft);
    expect(source.requests.single['action'], 'create');
    expect(source.requests.single['locationId'], 'merignac');
    expect(source.requests.single['data'], draft.toCallableData());

    await repository.deleteLocation('merignac');
    expect(source.requests.last, {
      'action': 'delete',
      'locationId': 'merignac',
    });
  });

  test('Firestore repository requires a responsible session', () async {
    final repository = FirestoreLocationAdministrationRepository(
      dataSource: _DataSource(currentUserId: null),
    );

    await expectLater(
      repository.listLocations(),
      throwsA(
        isA<LocationAdministrationException>().having(
          (error) => error.message,
          'message',
          'Session coordinateur requise.',
        ),
      ),
    );
  });

  test('Firestore repository translates callable deletion refusal', () async {
    final repository = FirestoreLocationAdministrationRepository(
      dataSource: _DataSource(errorCode: 'failed-precondition'),
    );

    await expectLater(
      repository.deleteLocation('merignac'),
      throwsA(
        isA<LocationAdministrationException>().having(
          (error) => error.message,
          'message',
          contains('encore utilisé'),
        ),
      ),
    );
  });

  test('Mock repository supports the complete lifecycle', () async {
    final repository = MockLocationAdministrationRepository();
    const draft = AdminLocationDraft(
      id: 'nouveau-centre',
      name: 'Nouveau centre',
      group: TerritorialGroup.medoc,
      type: ResponsePlaceType.sdisStation,
    );

    final created = await repository.createLocation(draft);
    expect(created.active, isTrue);
    await expectLater(
      repository.createLocation(draft),
      throwsA(isA<LocationAdministrationException>()),
    );

    final inactive = await repository.setLocationActive(
      locationId: draft.id,
      active: false,
    );
    expect(inactive.active, isFalse);

    final updated = await repository.updateLocation(
      const AdminLocationDraft(
        id: 'nouveau-centre',
        name: 'Centre renommé',
        group: TerritorialGroup.medoc,
        type: ResponsePlaceType.sdisStation,
      ),
    );
    expect(updated.name, 'Centre renommé');
    expect(updated.active, isFalse);

    await repository.deleteLocation(draft.id);
    expect(await repository.listLocations(), isEmpty);
  });

  test(
    'Mock coordination stream refreshes after an administrative write',
    () async {
      final coordination = MockCoordinationRepository(
        initialLocations: const [],
      );
      final emissions = coordination.watchLocations().take(2).toList();
      await Future<void>.delayed(Duration.zero);

      await coordination.locationAdministrationRepository.createLocation(
        const AdminLocationDraft(
          id: 'nouveau-centre',
          name: 'Nouveau centre',
          group: TerritorialGroup.medoc,
          type: ResponsePlaceType.sdisStation,
        ),
      );

      final values = await emissions;
      expect(values.first, isEmpty);
      expect(values.last.single.id, 'nouveau-centre');
      expect(values.last.single.isEnabled, isTrue);
    },
  );
}

class _DataSource implements LocationAdministrationDataSource {
  _DataSource({
    this.currentUserId = 'coordinator',
    this.listResult = const {'locations': <Object?>[]},
    this.manageResult = const <String, Object?>{},
    this.errorCode,
  });

  @override
  final String? currentUserId;
  final Map<String, Object?> listResult;
  final Map<String, Object?> manageResult;
  final String? errorCode;
  int listCalls = 0;
  final requests = <Map<String, Object?>>[];

  @override
  Future<Map<String, Object?>> listLocations() async {
    listCalls++;
    _throwIfNeeded();
    return listResult;
  }

  @override
  Future<Map<String, Object?>> manageLocation(Map<String, Object?> data) async {
    requests.add(Map.of(data));
    _throwIfNeeded();
    return manageResult;
  }

  void _throwIfNeeded() {
    if (errorCode != null) {
      throw FirebaseFunctionsException(code: errorCode!, message: 'test');
    }
  }
}
