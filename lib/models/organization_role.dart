/// Rôle qu'un utilisateur peut exercer dans une organisation.
///
/// Les rôles sont cumulables et leur portée est limitée à l'organisation de
/// l'appartenance. Les valeurs `coordinator` et `site_manager` restent alignées
/// sur les rôles RC3 existants.
enum OrganizationRole {
  organizationAdmin,
  coordinator,
  siteManager,
  professional,
}

/// Représentation stable utilisée lors de la sérialisation du domaine.
extension OrganizationRoleValue on OrganizationRole {
  String get serializedValue => switch (this) {
    OrganizationRole.organizationAdmin => 'organization_admin',
    OrganizationRole.coordinator => 'coordinator',
    OrganizationRole.siteManager => 'site_manager',
    OrganizationRole.professional => 'professional',
  };
}

/// Désérialise un rôle organisationnel connu du modèle.
OrganizationRole organizationRoleFromValue(Object? value) {
  return OrganizationRole.values.firstWhere(
    (role) => role.serializedValue == value,
    orElse: () => throw const FormatException("Rôle d'organisation invalide."),
  );
}
