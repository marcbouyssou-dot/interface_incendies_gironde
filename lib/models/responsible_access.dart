import 'dart:collection';

abstract final class ResponsibleRole {
  static const coordinator = 'coordinator';
  static const siteManager = 'site_manager';

  static const canonicalOrder = <String>[coordinator, siteManager];
  static const allowed = <String>{coordinator, siteManager};
}

enum ResponsibleAccessFormatError {
  missingActive,
  invalidActive,
  invalidLegacyRole,
  invalidLegacyLocations,
  missingSchemaVersion,
  invalidSchemaVersion,
  invalidRoles,
  duplicateRoles,
  unknownRole,
  nonCanonicalRoleOrder,
  inconsistentLegacyProjection,
  invalidLocationIds,
  invalidRoleScope,
}

class ResponsibleAccessFormatException implements FormatException {
  const ResponsibleAccessFormatException(this.code, this.message);

  final ResponsibleAccessFormatError code;

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'ResponsibleAccessFormatException(${code.name})';
}

class ResponsibleAccess {
  const ResponsibleAccess({
    required this.uid,
    required String role,
    required Set<String> locationIds,
    required this.active,
  }) : roles = role == ResponsibleRole.coordinator
           ? const {ResponsibleRole.coordinator}
           : role == ResponsibleRole.siteManager
           ? const {ResponsibleRole.siteManager}
           : const {},
       locationIds = role == ResponsibleRole.coordinator
           ? const {}
           : locationIds,
       schemaVersion = 1;

  factory ResponsibleAccess.v2({
    required String uid,
    required List<String> roles,
    required Set<String> locationIds,
    required bool active,
  }) => ResponsibleAccessParser.parse(
    uid: uid,
    data: {
      'role': roles.contains(ResponsibleRole.coordinator)
          ? ResponsibleRole.coordinator
          : ResponsibleRole.siteManager,
      'roles': roles,
      'locationIds': locationIds.toList(growable: false),
      'active': active,
      'schemaVersion': 2,
    },
  );

  ResponsibleAccess._({
    required this.uid,
    required Set<String> roles,
    required Set<String> locationIds,
    required this.active,
    required this.schemaVersion,
  }) : roles = UnmodifiableSetView(roles),
       locationIds = UnmodifiableSetView(locationIds);

  final String uid;
  final Set<String> roles;
  final Set<String> locationIds;
  final bool active;
  final int schemaVersion;

  String get role => roles.contains(ResponsibleRole.coordinator)
      ? ResponsibleRole.coordinator
      : roles.contains(ResponsibleRole.siteManager)
      ? ResponsibleRole.siteManager
      : '';

  bool get isCoordinator =>
      active && roles.contains(ResponsibleRole.coordinator);

  bool get isSiteManager =>
      active && roles.contains(ResponsibleRole.siteManager);

  bool get hasPrivilegedAccess => isCoordinator || isSiteManager;

  bool get isCumulative =>
      roles.contains(ResponsibleRole.coordinator) &&
      roles.contains(ResponsibleRole.siteManager);

  bool get isLocationRestricted => isSiteManager && !isCoordinator;

  String? get singleManagedLocationId =>
      isLocationRestricted && locationIds.length == 1
      ? locationIds.single
      : null;

  bool canManage(String locationId) =>
      isCoordinator || (isSiteManager && locationIds.contains(locationId));
}

abstract final class ResponsibleAccessParser {
  static ResponsibleAccess parse({
    required String uid,
    required Map<String, Object?> data,
  }) {
    final active = _parseActive(data);
    final locationIds = _parseLocationIds(data);
    if (data.containsKey('roles')) {
      return _parseV2(
        uid: uid,
        data: data,
        active: active,
        locationIds: locationIds,
      );
    }
    return _parseLegacy(
      uid: uid,
      data: data,
      active: active,
      locationIds: locationIds,
    );
  }

  static bool _parseActive(Map<String, Object?> data) {
    if (!data.containsKey('active')) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.missingActive,
        'Le champ active est obligatoire.',
      );
    }
    final active = data['active'];
    if (active is! bool) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.invalidActive,
        'Le champ active doit être un booléen.',
      );
    }
    return active;
  }

  static Set<String> _parseLocationIds(Map<String, Object?> data) {
    if (!data.containsKey('locationIds')) return const {};
    final raw = data['locationIds'];
    if (raw is! List || raw.any((value) => value is! String)) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.invalidLocationIds,
        'Le champ locationIds doit être une liste de chaînes.',
      );
    }
    final values = raw.cast<String>();
    if (values.any((value) => value.isEmpty) ||
        values.toSet().length != values.length) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.invalidLocationIds,
        'Les identifiants de lieux doivent être uniques et non vides.',
      );
    }
    return values.toSet();
  }

  static ResponsibleAccess _parseLegacy({
    required String uid,
    required Map<String, Object?> data,
    required bool active,
    required Set<String> locationIds,
  }) {
    if (data.containsKey('schemaVersion')) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.invalidSchemaVersion,
        'Un document legacy ne doit pas déclarer schemaVersion.',
      );
    }
    final role = data['role'];
    if (role is! String || !ResponsibleRole.allowed.contains(role)) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.invalidLegacyRole,
        'Le rôle legacy est invalide.',
      );
    }
    if (role == ResponsibleRole.coordinator) {
      final validScope =
          locationIds.isEmpty ||
          (locationIds.length == 1 && locationIds.single == '*');
      if (!validScope) {
        throw const ResponsibleAccessFormatException(
          ResponsibleAccessFormatError.invalidLegacyLocations,
          'La portée du coordinateur legacy est invalide.',
        );
      }
      return ResponsibleAccess._(
        uid: uid,
        roles: const {ResponsibleRole.coordinator},
        locationIds: const {},
        active: active,
        schemaVersion: 1,
      );
    }
    if (locationIds.isEmpty || locationIds.contains('*')) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.invalidLegacyLocations,
        'Un responsable de centre doit avoir au moins un lieu explicite.',
      );
    }
    return ResponsibleAccess._(
      uid: uid,
      roles: const {ResponsibleRole.siteManager},
      locationIds: locationIds,
      active: active,
      schemaVersion: 1,
    );
  }

  static ResponsibleAccess _parseV2({
    required String uid,
    required Map<String, Object?> data,
    required bool active,
    required Set<String> locationIds,
  }) {
    if (!data.containsKey('schemaVersion')) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.missingSchemaVersion,
        'schemaVersion est obligatoire avec roles.',
      );
    }
    final schemaVersion = data['schemaVersion'];
    if (schemaVersion is! int || schemaVersion != 2) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.invalidSchemaVersion,
        'La version du schéma de rôles est invalide.',
      );
    }
    final rawRoles = data['roles'];
    if (rawRoles is! List ||
        rawRoles.isEmpty ||
        rawRoles.any((role) => role is! String)) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.invalidRoles,
        'roles doit être une liste non vide de chaînes.',
      );
    }
    final orderedRoles = rawRoles.cast<String>();
    if (orderedRoles.toSet().length != orderedRoles.length) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.duplicateRoles,
        'Un rôle ne peut pas être dupliqué.',
      );
    }
    if (orderedRoles.any((role) => !ResponsibleRole.allowed.contains(role))) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.unknownRole,
        'Le document contient un rôle inconnu.',
      );
    }
    final canonical = ResponsibleRole.canonicalOrder
        .where(orderedRoles.contains)
        .toList(growable: false);
    if (!_sameOrderedValues(orderedRoles, canonical)) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.nonCanonicalRoleOrder,
        'Les rôles ne respectent pas l’ordre canonique.',
      );
    }
    final roles = orderedRoles.toSet();
    final projection = data['role'];
    final expectedProjection = roles.contains(ResponsibleRole.coordinator)
        ? ResponsibleRole.coordinator
        : ResponsibleRole.siteManager;
    if (projection != expectedProjection) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.inconsistentLegacyProjection,
        'La projection legacy du rôle est incohérente.',
      );
    }
    if (locationIds.contains('*') ||
        (roles.contains(ResponsibleRole.siteManager) && locationIds.isEmpty) ||
        (!roles.contains(ResponsibleRole.siteManager) &&
            locationIds.isNotEmpty)) {
      throw const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.invalidRoleScope,
        'La portée territoriale ne correspond pas aux rôles.',
      );
    }
    return ResponsibleAccess._(
      uid: uid,
      roles: roles,
      locationIds: locationIds,
      active: active,
      schemaVersion: 2,
    );
  }

  static bool _sameOrderedValues(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
