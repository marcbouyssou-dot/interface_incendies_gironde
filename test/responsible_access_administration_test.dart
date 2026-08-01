import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/responsible_access.dart';
import 'package:interface_incendies_gironde/models/responsible_account.dart';
import 'package:interface_incendies_gironde/repositories/firestore_responsible_access_administration_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_responsible_access_administration_repository.dart';
import 'package:interface_incendies_gironde/repositories/responsible_access_administration_repository.dart';

void main() {
  group('ResponsibleAccessUpdate', () {
    test('serializes the three canonical access combinations', () {
      final coordinator = ResponsibleAccessUpdate(
        targetUid: 'target',
        roles: const [ResponsibleRole.coordinator],
        locationIds: const {},
        active: true,
      );
      final manager = ResponsibleAccessUpdate(
        targetUid: 'target',
        roles: const [ResponsibleRole.siteManager],
        locationIds: const {'site-b', 'site-a'},
        active: false,
      );
      final cumulative = ResponsibleAccessUpdate(
        targetUid: 'target',
        roles: const [ResponsibleRole.coordinator, ResponsibleRole.siteManager],
        locationIds: const {'site-a'},
        active: true,
      );

      expect(coordinator.toMap()['locationIds'], isEmpty);
      expect(manager.toMap()['locationIds'], ['site-a', 'site-b']);
      expect(cumulative.toMap()['roles'], [
        ResponsibleRole.coordinator,
        ResponsibleRole.siteManager,
      ]);
    });

    test('rejects an invalid site manager scope', () {
      expect(
        () => ResponsibleAccessUpdate(
          targetUid: 'target',
          roles: const [ResponsibleRole.siteManager],
          locationIds: const {},
          active: true,
        ),
        throwsA(isA<ResponsibleAccessFormatException>()),
      );
    });
  });

  group('FirestoreResponsibleAccessAdministrationRepository', () {
    test('lists, parses and sorts accounts returned by the callable', () async {
      final dataSource = _DataSource(
        listResponse: {
          'accounts': [
            _accountMap(uid: 'z', displayName: 'Zoé'),
            _accountMap(uid: 'a', displayName: 'Alice'),
          ],
        },
      );
      final repository = FirestoreResponsibleAccessAdministrationRepository(
        dataSource: dataSource,
      );

      final accounts = await repository.listAccounts();

      expect(accounts.map((value) => value.uid), ['a', 'z']);
      expect(dataSource.listCalls, 1);
    });

    test('forwards only the canonical update payload', () async {
      final dataSource = _DataSource(
        updateResponse: {'account': _accountMap(uid: 'target', active: false)},
      );
      final repository = FirestoreResponsibleAccessAdministrationRepository(
        dataSource: dataSource,
      );
      final update = ResponsibleAccessUpdate(
        targetUid: 'target',
        roles: const [ResponsibleRole.coordinator],
        locationIds: const {},
        active: false,
      );

      final account = await repository.updateAccess(update);

      expect(account.access.active, isFalse);
      expect(dataSource.lastUpdate, update.toMap());
    });

    test('requires a responsible session before calling the backend', () async {
      final dataSource = _DataSource(currentUserId: null);
      final repository = FirestoreResponsibleAccessAdministrationRepository(
        dataSource: dataSource,
      );

      await expectLater(
        repository.listAccounts(),
        throwsA(
          isA<ResponsibleAccessAdministrationException>().having(
            (error) => error.message,
            'message',
            'Session coordinateur requise.',
          ),
        ),
      );
      expect(dataSource.listCalls, 0);
    });

    test('fails closed on a malformed callable response', () async {
      final repository = FirestoreResponsibleAccessAdministrationRepository(
        dataSource: _DataSource(listResponse: {'accounts': 'invalid'}),
      );

      await expectLater(
        repository.listAccounts(),
        throwsA(isA<ResponsibleAccessAdministrationException>()),
      );
    });
  });

  group('MockResponsibleAccessAdministrationRepository', () {
    test(
      'deactivates, reactivates and changes roles without deleting account',
      () async {
        final repository = MockResponsibleAccessAdministrationRepository(
          initialAccounts: [_managerAccount()],
        );

        final disabled = await repository.updateAccess(
          ResponsibleAccessUpdate(
            targetUid: 'manager',
            roles: const [ResponsibleRole.siteManager],
            locationIds: const {'merignac'},
            active: false,
          ),
        );
        final reactivated = await repository.updateAccess(
          ResponsibleAccessUpdate(
            targetUid: 'manager',
            roles: const [
              ResponsibleRole.coordinator,
              ResponsibleRole.siteManager,
            ],
            locationIds: const {'merignac', 'langon'},
            active: true,
          ),
        );

        expect(disabled.access.active, isFalse);
        expect(reactivated.access.isCumulative, isTrue);
        expect(reactivated.access.locationIds, {'merignac', 'langon'});
        expect((await repository.listAccounts()).single.uid, 'manager');
      },
    );

    test('blocks self-management', () async {
      final repository = MockResponsibleAccessAdministrationRepository(
        currentUid: 'manager',
        initialAccounts: [_managerAccount()],
      );

      await expectLater(
        repository.updateAccess(
          ResponsibleAccessUpdate(
            targetUid: 'manager',
            roles: const [ResponsibleRole.siteManager],
            locationIds: const {'merignac'},
            active: false,
          ),
        ),
        throwsA(
          isA<ResponsibleAccessAdministrationException>().having(
            (error) => error.message,
            'message',
            'Votre propre accès doit être géré par un autre coordinateur.',
          ),
        ),
      );
    });
  });
}

Map<String, Object?> _accountMap({
  required String uid,
  String? displayName,
  bool active = true,
}) => {
  'uid': uid,
  'displayName': displayName,
  'email': '$uid@example.test',
  'role': ResponsibleRole.coordinator,
  'roles': [ResponsibleRole.coordinator],
  'locationIds': <String>[],
  'active': active,
  'schemaVersion': 2,
};

ResponsibleAccount _managerAccount() => ResponsibleAccount(
  access: ResponsibleAccess.v2(
    uid: 'manager',
    roles: const [ResponsibleRole.siteManager],
    locationIds: const {'merignac'},
    active: true,
  ),
  displayName: 'Responsable Mérignac',
  email: 'manager@example.test',
);

class _DataSource implements ResponsibleAccessAdministrationDataSource {
  _DataSource({
    this.currentUserId = 'coordinator',
    this.listResponse = const {'accounts': <Object>[]},
    this.updateResponse = const {},
  });

  @override
  final String? currentUserId;
  final Map<String, Object?> listResponse;
  final Map<String, Object?> updateResponse;
  int listCalls = 0;
  Map<String, Object?>? lastUpdate;

  @override
  Future<Map<String, Object?>> listAccounts() async {
    listCalls += 1;
    return listResponse;
  }

  @override
  Future<Map<String, Object?>> updateAccess(Map<String, Object?> data) async {
    lastUpdate = data;
    return updateResponse;
  }
}
