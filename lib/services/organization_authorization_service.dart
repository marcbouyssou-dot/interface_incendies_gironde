import 'dart:collection';

import '../models/organization_context.dart';
import '../models/organization_membership.dart';
import '../models/organization_role.dart';

/// Capacités organisationnelles préparées pour les futures mutations RC4.
///
/// Ces capacités restent distinctes des privilèges `platform_admin`. Leur
/// déclaration ici évite que chaque callable ou écran reconstruise sa propre
/// interprétation de `organization_admin`.
enum OrganizationPermission {
  readOrganization,
  readOperations,
  manageOperations,
  manageCoordinators,
  manageSiteManagers,
  manageSites,
  viewActors,
  viewStatistics,
  viewHistory,
  exportData,
  manageInvitations,
}

/// Décision d'autorisation immutable pour un UID dans une organisation.
class OrganizationAuthorization {
  OrganizationAuthorization._({
    required this.organizationId,
    required this.uid,
    required this.hasActiveMembership,
    required this.usesLegacyFallback,
    required this.isPlatformAdministrator,
    required Set<OrganizationRole> roles,
  }) : roles = UnmodifiableSetView(roles);

  final String organizationId;
  final String uid;

  /// Une membership RC4 active est la source de vérité des rôles RC4.
  final bool hasActiveMembership;

  /// Indique que les rôles proviennent exclusivement de `roles/{uid}` dans le
  /// périmètre legacy. Une membership présente, même inactive, désactive ce
  /// fallback afin d'éviter deux sources concurrentes.
  final bool usesLegacyFallback;

  /// Privilège global distinct : il ne transforme jamais l'utilisateur en
  /// `organization_admin` d'une organisation.
  final bool isPlatformAdministrator;

  final Set<OrganizationRole> roles;

  bool get hasOrganizationAccess =>
      isPlatformAdministrator || hasActiveMembership || usesLegacyFallback;

  bool get isOrganizationAdmin =>
      hasActiveMembership && roles.contains(OrganizationRole.organizationAdmin);

  bool get isCoordinator => roles.contains(OrganizationRole.coordinator);

  bool get isSiteManager => roles.contains(OrganizationRole.siteManager);

  bool get isProfessional => roles.contains(OrganizationRole.professional);

  bool hasRole(OrganizationRole role) => roles.contains(role);

  /// Évalue uniquement les capacités organisationnelles validées par RC4.3C.
  ///
  /// Les rôles Coordinateur et Responsable conservent leurs droits RC3 dans
  /// les couches existantes. Ils ne reçoivent pas implicitement ici les
  /// capacités d'administration futures.
  bool allows(OrganizationPermission permission) {
    if (isPlatformAdministrator) return true;
    return switch (permission) {
      OrganizationPermission.readOrganization ||
      OrganizationPermission.readOperations => hasOrganizationAccess,
      _ => isOrganizationAdmin,
    };
  }
}

/// Source unique de résolution des rôles organisationnels côté Dart.
class OrganizationAuthorizationService {
  const OrganizationAuthorizationService();

  OrganizationAuthorization resolve({
    required String organizationId,
    required String uid,
    OrganizationMembership? membership,
    Iterable<String> legacyRoleValues = const [],
    bool isLegacyOrganization = false,
    bool isPlatformAdministrator = false,
  }) {
    _validateIdentifier(organizationId, maxLength: 160);
    _validateIdentifier(uid, maxLength: 128);
    if (membership != null &&
        (membership.organizationId != organizationId ||
            membership.uid != uid)) {
      throw const FormatException('Membership d’autorisation incohérente.');
    }

    final hasActiveMembership =
        membership != null &&
        membership.active &&
        _hasValidRoleScope(membership);
    final legacyRoles = membership == null && isLegacyOrganization
        ? _legacyRoles(legacyRoleValues)
        : const <OrganizationRole>{};
    final usesLegacyFallback = legacyRoles.isNotEmpty;
    final roles = hasActiveMembership
        ? membership.roles
        : usesLegacyFallback
        ? legacyRoles
        : const <OrganizationRole>{};
    return OrganizationAuthorization._(
      organizationId: organizationId,
      uid: uid,
      hasActiveMembership: hasActiveMembership,
      usesLegacyFallback: usesLegacyFallback,
      isPlatformAdministrator: isPlatformAdministrator,
      roles: Set<OrganizationRole>.unmodifiable(roles),
    );
  }

  /// Adapte un contexte déjà résolu sans relire ni réinterpréter sa membership.
  OrganizationAuthorization fromContext(OrganizationContext context) {
    final organization = context.organization;
    if (organization == null) {
      throw StateError(
        'Une autorisation organisationnelle requiert une organisation.',
      );
    }
    return OrganizationAuthorization._(
      organizationId: organization.id,
      uid: context.uid,
      hasActiveMembership: context.hasActiveMembership,
      usesLegacyFallback:
          context.isLegacy &&
          context.membership == null &&
          context.effectiveRoles.isNotEmpty,
      isPlatformAdministrator: context.isPlatformAdministrator,
      roles: Set<OrganizationRole>.unmodifiable(context.effectiveRoles),
    );
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

  bool _hasValidRoleScope(OrganizationMembership membership) =>
      membership.roles.contains(OrganizationRole.siteManager)
      ? membership.locationIds.isNotEmpty
      : membership.locationIds.isEmpty;
}

void _validateIdentifier(String value, {required int maxLength}) {
  if (value.trim().isEmpty ||
      value.trim() != value ||
      value.length > maxLength ||
      value.contains('/')) {
    throw const FormatException('Identifiant d’autorisation invalide.');
  }
}
