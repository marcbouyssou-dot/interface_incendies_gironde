/// Catégorie institutionnelle d'une organisation MobSanté.
///
/// Les valeurs couvrent les structures identifiées par l'ADR RC4.0B sans
/// présumer de leurs droits, qui sont portés par `OrganizationRole`.
enum OrganizationCategory {
  sdis,
  ars,
  cpts,
  healthEstablishment,
  association,
  localAuthority,
  eventOrganizer,
  nationalOrganization,
  other,
}

/// Représentation stable utilisée lors de la sérialisation du domaine.
extension OrganizationCategoryValue on OrganizationCategory {
  String get serializedValue => switch (this) {
    OrganizationCategory.sdis => 'sdis',
    OrganizationCategory.ars => 'ars',
    OrganizationCategory.cpts => 'cpts',
    OrganizationCategory.healthEstablishment => 'health_establishment',
    OrganizationCategory.association => 'association',
    OrganizationCategory.localAuthority => 'local_authority',
    OrganizationCategory.eventOrganizer => 'event_organizer',
    OrganizationCategory.nationalOrganization => 'national_organization',
    OrganizationCategory.other => 'other',
  };
}

/// Désérialise une catégorie et refuse les valeurs non contractuelles.
OrganizationCategory organizationCategoryFromValue(Object? value) {
  return OrganizationCategory.values.firstWhere(
    (category) => category.serializedValue == value,
    orElse: () =>
        throw const FormatException("Catégorie d'organisation invalide."),
  );
}
