/// Niveau de visibilité par défaut d'une ressource organisationnelle.
///
/// `publicAccess` réserve une évolution future : ce niveau n'autorise à lui
/// seul aucune exposition de données métier ou personnelles.
enum OrganizationVisibility {
  organizationPrivate,
  shared,
  platform,
  publicAccess,
}

/// Représentation stable utilisée lors de la sérialisation du domaine.
extension OrganizationVisibilityValue on OrganizationVisibility {
  String get serializedValue => switch (this) {
    OrganizationVisibility.organizationPrivate => 'organization_private',
    OrganizationVisibility.shared => 'shared',
    OrganizationVisibility.platform => 'platform',
    OrganizationVisibility.publicAccess => 'public',
  };
}

/// Désérialise un niveau de visibilité connu du modèle.
OrganizationVisibility organizationVisibilityFromValue(Object? value) {
  return OrganizationVisibility.values.firstWhere(
    (visibility) => visibility.serializedValue == value,
    orElse: () =>
        throw const FormatException("Visibilité d'organisation invalide."),
  );
}
