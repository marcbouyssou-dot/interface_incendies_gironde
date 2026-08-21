import 'dart:collection';

import 'organization_role.dart';

/// Appartenance d'un utilisateur à une organisation MobSanté.
///
/// Un même UID peut disposer de plusieurs appartenances, chacune avec des rôles
/// différents. [locationIds] prépare les futurs périmètres de sites sans
/// modifier le modèle RC3 ni lui attribuer dès maintenant une sémantique
/// d'autorisation.
class OrganizationMembership {
  factory OrganizationMembership({
    required String organizationId,
    required String uid,
    required Iterable<OrganizationRole> roles,
    Iterable<String> locationIds = const [],
    required bool active,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int schemaVersion,
  }) {
    _validateIdentifier(organizationId, maxLength: 160);
    _validateIdentifier(uid, maxLength: 128);
    final roleValues = roles.toList(growable: false);
    final immutableRoles = Set<OrganizationRole>.unmodifiable(roleValues);
    if (immutableRoles.isEmpty || roleValues.length != immutableRoles.length) {
      throw const FormatException(
        "Une appartenance doit contenir des rôles uniques et non vides.",
      );
    }
    final locationValues = locationIds.toList(growable: false);
    final immutableLocationIds = Set<String>.unmodifiable(locationValues);
    if (locationValues.length != immutableLocationIds.length ||
        immutableLocationIds.length > 65) {
      throw const FormatException('Périmètre de sites invalide.');
    }
    for (final locationId in immutableLocationIds) {
      _validateIdentifier(locationId, maxLength: 160);
      if (locationId == '*') {
        throw const FormatException('Périmètre de sites invalide.');
      }
    }
    if (updatedAt.isBefore(createdAt)) {
      throw const FormatException("Dates d'appartenance invalides.");
    }
    if (schemaVersion < 1) {
      throw const FormatException("Version d'appartenance invalide.");
    }
    return OrganizationMembership._(
      organizationId: organizationId,
      uid: uid,
      roles: immutableRoles,
      locationIds: immutableLocationIds,
      active: active,
      createdAt: createdAt,
      updatedAt: updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  OrganizationMembership._({
    required this.organizationId,
    required this.uid,
    required Set<OrganizationRole> roles,
    required Set<String> locationIds,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
  }) : roles = UnmodifiableSetView(roles),
       locationIds = UnmodifiableSetView(locationIds);

  /// Reconstruit une appartenance depuis sa représentation de domaine.
  factory OrganizationMembership.fromMap(Map<String, Object?> data) {
    final rawRoles = _requiredList(data, 'roles');
    if (rawRoles.any((role) => role is! String)) {
      throw const FormatException("Rôles d'appartenance invalides.");
    }
    final parsedRoles = rawRoles.map(organizationRoleFromValue).toList();
    if (parsedRoles.toSet().length != parsedRoles.length) {
      throw const FormatException("Rôles d'appartenance dupliqués.");
    }
    final rawLocationIds = data['locationIds'] ?? const <Object?>[];
    if (rawLocationIds is! List ||
        rawLocationIds.any((locationId) => locationId is! String)) {
      throw const FormatException('Périmètre de sites invalide.');
    }
    return OrganizationMembership(
      organizationId: _requiredText(data, 'organizationId'),
      uid: _requiredText(data, 'uid'),
      roles: parsedRoles,
      locationIds: rawLocationIds.cast<String>(),
      active: _requiredValue<bool>(data, 'active'),
      createdAt: _requiredValue<DateTime>(data, 'createdAt'),
      updatedAt: _requiredValue<DateTime>(data, 'updatedAt'),
      schemaVersion: _requiredValue<int>(data, 'schemaVersion'),
    );
  }

  /// Organisation dans laquelle les rôles sont exercés.
  final String organizationId;

  /// UID Firebase canonique de l'utilisateur.
  final String uid;

  /// Rôles cumulables, limités à cette organisation.
  final Set<OrganizationRole> roles;

  /// Périmètre optionnel de sites, exprimé avec les identifiants RC3.
  final Set<String> locationIds;

  /// Indique si l'appartenance peut être utilisée par l'autorisation future.
  final bool active;

  /// Date de création logique du document.
  final DateTime createdAt;

  /// Date de dernière mise à jour logique du document.
  final DateTime updatedAt;

  /// Version additive du schéma de sérialisation.
  final int schemaVersion;

  /// Produit une représentation déterministe et indépendante du stockage.
  Map<String, Object?> toMap() {
    final orderedRoles = roles.toList(growable: false)
      ..sort((left, right) => left.index.compareTo(right.index));
    final orderedLocationIds = locationIds.toList(growable: false)..sort();
    return {
      'organizationId': organizationId,
      'uid': uid,
      'roles': orderedRoles.map((role) => role.serializedValue).toList(),
      'locationIds': orderedLocationIds,
      'active': active,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'schemaVersion': schemaVersion,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrganizationMembership &&
          organizationId == other.organizationId &&
          uid == other.uid &&
          _sameSet(roles, other.roles) &&
          _sameSet(locationIds, other.locationIds) &&
          active == other.active &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          schemaVersion == other.schemaVersion;

  @override
  int get hashCode {
    final roleValues = roles.map((role) => role.serializedValue).toList()
      ..sort();
    final locationValues = locationIds.toList()..sort();
    return Object.hash(
      organizationId,
      uid,
      Object.hashAll(roleValues),
      Object.hashAll(locationValues),
      active,
      createdAt,
      updatedAt,
      schemaVersion,
    );
  }
}

T _requiredValue<T>(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! T) {
    throw const FormatException("Appartenance d'organisation invalide.");
  }
  return value;
}

List<Object?> _requiredList(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! List) {
    throw const FormatException("Appartenance d'organisation invalide.");
  }
  return value.cast<Object?>();
}

String _requiredText(Map<String, Object?> data, String key) {
  final value = _requiredValue<String>(data, key);
  if (value.trim().isEmpty || value.trim() != value) {
    throw const FormatException("Appartenance d'organisation invalide.");
  }
  return value;
}

void _validateIdentifier(String value, {required int maxLength}) {
  if (value.trim().isEmpty ||
      value.trim() != value ||
      value.length > maxLength ||
      value.contains('/')) {
    throw const FormatException('Identifiant organisationnel invalide.');
  }
}

bool _sameSet<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);
