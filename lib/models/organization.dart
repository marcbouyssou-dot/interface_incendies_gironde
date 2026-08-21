import 'organization_category.dart';
import 'organization_visibility.dart';

/// Organisation propriétaire ou partenaire d'opérations MobSanté.
///
/// Ce modèle de domaine ne confère aucun droit par lui-même. Les autorisations
/// seront portées par les appartenances et contrôlées par les futures couches
/// d'accès RC4. Les versions de schéma supérieures à 1 et les champs inconnus
/// sont acceptés en lecture afin de préserver la compatibilité ascendante.
class Organization {
  factory Organization({
    required String id,
    required String name,
    required OrganizationCategory category,
    required OrganizationVisibility defaultVisibility,
    required bool active,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int schemaVersion,
  }) {
    _validateOrganizationId(id);
    _validateOrganizationName(name);
    _validateOrganizationDates(createdAt: createdAt, updatedAt: updatedAt);
    _validateSchemaVersion(schemaVersion);
    return Organization._(
      id: id,
      name: name,
      category: category,
      defaultVisibility: defaultVisibility,
      active: active,
      createdAt: createdAt,
      updatedAt: updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  const Organization._({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultVisibility,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
  });

  /// Reconstruit une organisation depuis sa représentation de domaine.
  factory Organization.fromMap(Map<String, Object?> data) => Organization(
    id: _requiredText(data, 'id'),
    name: _requiredText(data, 'name'),
    category: organizationCategoryFromValue(data['category']),
    defaultVisibility: organizationVisibilityFromValue(
      data['defaultVisibility'],
    ),
    active: _requiredValue<bool>(data, 'active'),
    createdAt: _requiredValue<DateTime>(data, 'createdAt'),
    updatedAt: _requiredValue<DateTime>(data, 'updatedAt'),
    schemaVersion: _requiredValue<int>(data, 'schemaVersion'),
  );

  /// Identifiant canonique et stable de l'organisation.
  final String id;

  /// Nom affiché de l'organisation.
  final String name;

  /// Nature institutionnelle de l'organisation.
  final OrganizationCategory category;

  /// Politique de visibilité proposée par défaut aux nouvelles ressources.
  final OrganizationVisibility defaultVisibility;

  /// Indique si l'organisation peut encore être utilisée opérationnellement.
  final bool active;

  /// Date de création logique du document.
  final DateTime createdAt;

  /// Date de dernière mise à jour logique du document.
  final DateTime updatedAt;

  /// Version additive du schéma de sérialisation.
  final int schemaVersion;

  /// Produit une représentation indépendante de toute technologie de stockage.
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'category': category.serializedValue,
    'defaultVisibility': defaultVisibility.serializedValue,
    'active': active,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'schemaVersion': schemaVersion,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Organization &&
          id == other.id &&
          name == other.name &&
          category == other.category &&
          defaultVisibility == other.defaultVisibility &&
          active == other.active &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          schemaVersion == other.schemaVersion;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    defaultVisibility,
    active,
    createdAt,
    updatedAt,
    schemaVersion,
  );
}

T _requiredValue<T>(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! T) throw const FormatException('Organisation invalide.');
  return value;
}

String _requiredText(Map<String, Object?> data, String key) {
  final value = _requiredValue<String>(data, key);
  if (value.trim().isEmpty || value.trim() != value) {
    throw const FormatException('Organisation invalide.');
  }
  return value;
}

void _validateOrganizationId(String value) {
  if (value.length > 160 || value.contains('/')) {
    throw const FormatException("Identifiant d'organisation invalide.");
  }
}

void _validateOrganizationName(String value) {
  if (value.length > 160) {
    throw const FormatException("Nom d'organisation invalide.");
  }
}

void _validateOrganizationDates({
  required DateTime createdAt,
  required DateTime updatedAt,
}) {
  if (updatedAt.isBefore(createdAt)) {
    throw const FormatException("Dates d'organisation invalides.");
  }
}

void _validateSchemaVersion(int value) {
  if (value < 1) {
    throw const FormatException("Version d'organisation invalide.");
  }
}
