import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/responsible_access.dart';
import 'package:interface_incendies_gironde/repositories/firestore_coordination_repository.dart';

void main() {
  ResponsibleAccess parse(Map<String, Object?> data) =>
      ResponsibleAccessParser.parse(uid: 'user-a', data: data);

  Map<String, Object?> legacy({
    Object? role = 'coordinator',
    Object? locationIds = const <String>[],
    Object? active = true,
  }) => {'role': role, 'locationIds': locationIds, 'active': active};

  Map<String, Object?> v2({
    Object? role = 'coordinator',
    Object? roles = const <String>['coordinator'],
    Object? locationIds = const <String>[],
    Object? active = true,
    Object? schemaVersion = 2,
  }) => {
    'role': role,
    'roles': roles,
    'locationIds': locationIds,
    'active': active,
    'schemaVersion': schemaVersion,
  };

  Matcher failsWith(ResponsibleAccessFormatError code) => throwsA(
    isA<ResponsibleAccessFormatException>().having(
      (error) => error.code,
      'code',
      code,
    ),
  );

  group('legacy role documents', () {
    test('coordinator with wildcard has global access and no local centre', () {
      final access = parse(legacy(locationIds: const ['*']));

      expect(access.roles, {ResponsibleRole.coordinator});
      expect(access.locationIds, isEmpty);
      expect(access.schemaVersion, 1);
      expect(access.isCoordinator, isTrue);
      expect(access.canManage('anywhere'), isTrue);
    });

    test('coordinator with an empty scope remains global', () {
      final access = parse(legacy());

      expect(access.isCoordinator, isTrue);
      expect(access.isSiteManager, isFalse);
      expect(access.locationIds, isEmpty);
    });

    test('single-site manager retains its centre', () {
      final access = parse(
        legacy(role: 'site_manager', locationIds: const ['bazas']),
      );

      expect(access.roles, {ResponsibleRole.siteManager});
      expect(access.singleManagedLocationId, 'bazas');
      expect(access.canManage('bazas'), isTrue);
      expect(access.canManage('bassens'), isFalse);
    });

    test('multi-site manager retains all explicit centres', () {
      final access = parse(
        legacy(role: 'site_manager', locationIds: const ['bazas', 'bassens']),
      );

      expect(access.locationIds, {'bazas', 'bassens'});
      expect(access.singleManagedLocationId, isNull);
    });

    test('site manager with an empty scope is refused', () {
      expect(
        () => parse(legacy(role: 'site_manager')),
        failsWith(ResponsibleAccessFormatError.invalidLegacyLocations),
      );
    });

    test('site manager with wildcard scope is refused', () {
      expect(
        () => parse(legacy(role: 'site_manager', locationIds: const ['*'])),
        failsWith(ResponsibleAccessFormatError.invalidLegacyLocations),
      );
    });

    test('missing role is refused', () {
      expect(
        () => parse({'active': true, 'locationIds': const []}),
        failsWith(ResponsibleAccessFormatError.invalidLegacyRole),
      );
    });

    test('unknown legacy role is refused', () {
      expect(
        () => parse(legacy(role: 'viewer')),
        failsWith(ResponsibleAccessFormatError.invalidLegacyRole),
      );
    });

    test('missing locationIds stays compatible for a coordinator', () {
      final access = parse({'role': 'coordinator', 'active': true});

      expect(access.locationIds, isEmpty);
      expect(access.isCoordinator, isTrue);
    });
  });

  group('V2 role documents', () {
    test('coordinator V2 is parsed', () {
      final access = parse(v2());

      expect(access.roles, {ResponsibleRole.coordinator});
      expect(access.schemaVersion, 2);
      expect(access.role, ResponsibleRole.coordinator);
    });

    test('site manager V2 is parsed', () {
      final access = parse(
        v2(
          role: 'site_manager',
          roles: const ['site_manager'],
          locationIds: const ['bazas'],
        ),
      );

      expect(access.isSiteManager, isTrue);
      expect(access.isCoordinator, isFalse);
    });

    test('cumulative V2 role preserves local centres', () {
      final access = parse(
        v2(
          roles: const ['coordinator', 'site_manager'],
          locationIds: const ['bazas', 'bassens'],
        ),
      );

      expect(access.isCumulative, isTrue);
      expect(access.isCoordinator, isTrue);
      expect(access.isSiteManager, isTrue);
      expect(access.locationIds, {'bazas', 'bassens'});
    });

    test('coherent legacy projection is accepted', () {
      expect(
        parse(
          v2(
            role: 'site_manager',
            roles: const ['site_manager'],
            locationIds: const ['bazas'],
          ),
        ).role,
        'site_manager',
      );
    });

    test('incoherent cumulative legacy projection is refused', () {
      expect(
        () => parse(
          v2(
            role: 'site_manager',
            roles: const ['coordinator', 'site_manager'],
            locationIds: const ['bazas'],
          ),
        ),
        failsWith(ResponsibleAccessFormatError.inconsistentLegacyProjection),
      );
    });

    test('incoherent site manager legacy projection is refused', () {
      expect(
        () => parse(
          v2(
            role: 'coordinator',
            roles: const ['site_manager'],
            locationIds: const ['bazas'],
          ),
        ),
        failsWith(ResponsibleAccessFormatError.inconsistentLegacyProjection),
      );
    });

    test('empty roles is refused without legacy fallback', () {
      expect(
        () => parse(v2(roles: const [])),
        failsWith(ResponsibleAccessFormatError.invalidRoles),
      );
    });

    test('unknown V2 role is refused', () {
      expect(
        () => parse(v2(role: 'viewer', roles: const ['viewer'])),
        failsWith(ResponsibleAccessFormatError.unknownRole),
      );
    });

    test('duplicate V2 roles are refused', () {
      expect(
        () => parse(v2(roles: const ['coordinator', 'coordinator'])),
        failsWith(ResponsibleAccessFormatError.duplicateRoles),
      );
    });

    test('non-canonical role order is refused', () {
      expect(
        () => parse(
          v2(
            roles: const ['site_manager', 'coordinator'],
            locationIds: const ['bazas'],
          ),
        ),
        failsWith(ResponsibleAccessFormatError.nonCanonicalRoleOrder),
      );
    });

    test('missing schemaVersion with roles is refused', () {
      final data = v2()..remove('schemaVersion');
      expect(
        () => parse(data),
        failsWith(ResponsibleAccessFormatError.missingSchemaVersion),
      );
    });

    test('incorrect schemaVersion is refused', () {
      expect(
        () => parse(v2(schemaVersion: 3)),
        failsWith(ResponsibleAccessFormatError.invalidSchemaVersion),
      );
    });

    test('roles with a non-string value are refused', () {
      expect(
        () => parse(v2(roles: const ['coordinator', 3])),
        failsWith(ResponsibleAccessFormatError.invalidRoles),
      );
    });

    test('cumulative coordinator is never limited by local centres', () {
      final access = ResponsibleAccess.v2(
        uid: 'cumulative',
        roles: const ['coordinator', 'site_manager'],
        locationIds: const {'bazas'},
        active: true,
      );

      expect(access.canManage('bazas'), isTrue);
      expect(access.canManage('libourne'), isTrue);
      expect(access.singleManagedLocationId, isNull);
      expect(access.isLocationRestricted, isFalse);
    });
  });

  group('shared strict fields', () {
    test('missing active is refused', () {
      expect(
        () => parse({'role': 'coordinator', 'locationIds': const []}),
        failsWith(ResponsibleAccessFormatError.missingActive),
      );
    });

    test('non-boolean active is refused', () {
      expect(
        () => parse(legacy(active: 'true')),
        failsWith(ResponsibleAccessFormatError.invalidActive),
      );
    });

    test('invalid locationIds type is refused', () {
      expect(
        () => parse(legacy(locationIds: 'bazas')),
        failsWith(ResponsibleAccessFormatError.invalidLocationIds),
      );
    });

    test('non-string location id is refused', () {
      expect(
        () => parse(legacy(locationIds: const ['bazas', 12])),
        failsWith(ResponsibleAccessFormatError.invalidLocationIds),
      );
    });

    test('inactive document is valid but grants no privilege', () {
      final access = parse(legacy(active: false));

      expect(access.active, isFalse);
      expect(access.isCoordinator, isFalse);
      expect(access.isSiteManager, isFalse);
      expect(access.hasPrivilegedAccess, isFalse);
    });

    test('roles takes precedence and never falls back to legacy role', () {
      expect(
        () => parse(v2(roles: 'coordinator')),
        failsWith(ResponsibleAccessFormatError.invalidRoles),
      );
    });
  });

  test('legacy and V2 coordinator documents expose equivalent semantics', () {
    final legacyAccess = parse(legacy(locationIds: const ['*']));
    final v2Access = parse(v2());

    expect(v2Access.isCoordinator, legacyAccess.isCoordinator);
    expect(v2Access.isSiteManager, legacyAccess.isSiteManager);
    expect(v2Access.locationIds, legacyAccess.locationIds);
    expect(v2Access.canManage('langon'), legacyAccess.canManage('langon'));
  });

  test('Firestore mapper loads legacy and V2 documents identically', () {
    final legacyAccess = parseResponsibleAccessDocument(
      uid: 'legacy',
      data: legacy(locationIds: const ['*']),
    );
    final v2Access = parseResponsibleAccessDocument(uid: 'v2', data: v2());

    expect(legacyAccess.schemaVersion, 1);
    expect(v2Access.schemaVersion, 2);
    expect(legacyAccess.isCoordinator, v2Access.isCoordinator);
    expect(legacyAccess.locationIds, v2Access.locationIds);
  });

  test(
    'repository mapping follows a switch from legacy to cumulative V2',
    () async {
      final documents = Stream<Map<String, Object?>>.fromIterable([
        legacy(role: 'site_manager', locationIds: const ['bazas']),
        v2(
          roles: const ['coordinator', 'site_manager'],
          locationIds: const ['bazas'],
        ),
      ]);

      final accesses = await documents
          .map(
            (data) =>
                parseResponsibleAccessDocument(uid: 'same-user', data: data),
          )
          .toList();

      expect(accesses.first.isLocationRestricted, isTrue);
      expect(accesses.last.isCumulative, isTrue);
      expect(accesses.last.isLocationRestricted, isFalse);
    },
  );
}
