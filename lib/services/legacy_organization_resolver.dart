import '../models/operation.dart';
import '../models/mobilization.dart';
import '../models/organization.dart';
import '../models/organization_category.dart';
import '../models/organization_context.dart';
import '../models/organization_membership.dart';
import '../models/organization_role.dart';
import '../models/organization_visibility.dart';

/// Résout toute la compatibilité organisationnelle transitoire de RC3.
///
/// Aucun consommateur ne doit réimplémenter le fallback Gironde. La suppression
/// future de la compatibilité se fera en retirant ce service, sans modifier les
/// écrans ni les repositories métier RC3.
class LegacyOrganizationResolver {
  const LegacyOrganizationResolver();

  /// Identifiant stable de l'organisation virtuelle portant les données RC3.
  static const legacyOrganizationId = 'legacy-gironde';

  /// Organisation canonique utilisée pendant la transition additive RC4.
  static final Organization legacyOrganization = Organization(
    id: legacyOrganizationId,
    name: 'Périmètre legacy Gironde',
    category: OrganizationCategory.other,
    defaultVisibility: OrganizationVisibility.platform,
    active: true,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    schemaVersion: 1,
  );

  /// Retourne le propriétaire explicite ou l'organisation legacy par défaut.
  String resolveOperationOrganizationId(Operation operation) =>
      _resolveOrganizationId(operation.ownerOrganizationId);

  /// Vérifie le rattachement d'une mobilisation sans dupliquer le fallback RC3.
  ///
  /// Une mobilisation liée hérite de l'organisation de son opération, déjà
  /// bornée par le repository Opération. Une mobilisation sans `operationId`
  /// reste exclusivement rattachée au périmètre legacy Gironde.
  bool isMobilizationAccessible({
    required Mobilization mobilization,
    required String organizationId,
    required Set<String> accessibleOperationIds,
  }) {
    final operationId = mobilization.operationId;
    return operationId == null
        ? organizationId == legacyOrganizationId
        : accessibleOperationIds.contains(operationId);
  }

  /// Retourne le gestionnaire explicite d'un site ou le fallback legacy.
  ///
  /// Le paramètre reste découplé du modèle RC3 des sites afin de ne pas modifier
  /// leurs écrans, mappers ou repositories dans ce lot.
  String resolveSiteOrganizationId({String? managingOrganizationId}) =>
      _resolveOrganizationId(managingOrganizationId);

  /// Construit un contexte sélectionné ou global à partir des données connues.
  ///
  /// Les rôles globaux RC3 ne sont projetés que sur l'organisation legacy, et
  /// seulement si aucune membership RC4 explicite n'existe. Une membership
  /// inactive prévaut donc toujours sur le fallback.
  OrganizationContext resolveContext({
    required String uid,
    Organization? selectedOrganization,
    OrganizationMembership? membership,
    Iterable<String> legacyRoleValues = const [],
    bool isPlatformAdministrator = false,
  }) {
    if (selectedOrganization == null) {
      if (membership != null) {
        throw const FormatException(
          'Une membership requiert une organisation sélectionnée.',
        );
      }
      return OrganizationContext.unselected(
        uid: uid,
        isPlatformAdministrator: isPlatformAdministrator,
      );
    }

    final isLegacy = selectedOrganization.id == legacyOrganizationId;
    final roles = membership != null
        ? membership.active
              ? membership.roles
              : const <OrganizationRole>{}
        : isLegacy
        ? _legacyRoles(legacyRoleValues)
        : const <OrganizationRole>{};
    return OrganizationContext.selected(
      uid: uid,
      organization: isLegacy ? legacyOrganization : selectedOrganization,
      membership: membership,
      effectiveRoles: roles,
      isLegacy: isLegacy,
      isPlatformAdministrator: isPlatformAdministrator,
    );
  }

  String _resolveOrganizationId(String? explicitOrganizationId) {
    if (explicitOrganizationId == null) return legacyOrganizationId;
    if (explicitOrganizationId.trim().isEmpty ||
        explicitOrganizationId.trim() != explicitOrganizationId ||
        explicitOrganizationId.length > 160 ||
        explicitOrganizationId.contains('/')) {
      throw const FormatException("Identifiant d'organisation invalide.");
    }
    return explicitOrganizationId;
  }

  Set<OrganizationRole> _legacyRoles(Iterable<String> values) {
    final roles = <OrganizationRole>{};
    for (final value in values) {
      switch (value) {
        case 'coordinator':
          roles.add(OrganizationRole.coordinator);
        case 'site_manager':
          roles.add(OrganizationRole.siteManager);
      }
    }
    return Set<OrganizationRole>.unmodifiable(roles);
  }
}
