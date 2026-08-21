import 'dart:collection';

import 'organization.dart';
import 'organization_membership.dart';
import 'organization_role.dart';

/// Contexte organisationnel résolu pour un utilisateur.
///
/// Le contexte est volontairement indépendant de l'UI et des technologies de
/// persistance. Il distingue les privilèges plateforme des rôles limités à une
/// organisation et ne transforme jamais une membership inactive en droits.
class OrganizationContext {
  factory OrganizationContext.unselected({
    required String uid,
    bool isPlatformAdministrator = false,
  }) {
    _validateUid(uid);
    return OrganizationContext._(
      uid: uid,
      organization: null,
      membership: null,
      effectiveRoles: const {},
      isLegacy: false,
      isPlatformAdministrator: isPlatformAdministrator,
    );
  }

  factory OrganizationContext.selected({
    required String uid,
    required Organization organization,
    OrganizationMembership? membership,
    Iterable<OrganizationRole> effectiveRoles = const [],
    bool isLegacy = false,
    bool isPlatformAdministrator = false,
  }) {
    _validateUid(uid);
    if (membership != null &&
        (membership.uid != uid ||
            membership.organizationId != organization.id)) {
      throw const FormatException('Contexte organisationnel incohérent.');
    }
    final immutableRoles = Set<OrganizationRole>.unmodifiable(effectiveRoles);
    if (membership != null && !membership.active && immutableRoles.isNotEmpty) {
      throw const FormatException(
        'Une membership inactive ne peut pas exposer de rôle effectif.',
      );
    }
    if (membership != null &&
        membership.active &&
        !membership.roles.containsAll(immutableRoles)) {
      throw const FormatException(
        'Un rôle effectif doit provenir de la membership active.',
      );
    }
    if (!isLegacy && membership == null && immutableRoles.isNotEmpty) {
      throw const FormatException(
        'Une organisation RC4 requiert une membership pour exposer des rôles.',
      );
    }
    return OrganizationContext._(
      uid: uid,
      organization: organization,
      membership: membership,
      effectiveRoles: immutableRoles,
      isLegacy: isLegacy,
      isPlatformAdministrator: isPlatformAdministrator,
    );
  }

  OrganizationContext._({
    required this.uid,
    required this.organization,
    required this.membership,
    required Set<OrganizationRole> effectiveRoles,
    required this.isLegacy,
    required this.isPlatformAdministrator,
  }) : effectiveRoles = UnmodifiableSetView(effectiveRoles);

  /// UID Firebase canonique de l'utilisateur courant.
  final String uid;

  /// Organisation sélectionnée, ou `null` en contexte global/non sélectionné.
  final Organization? organization;

  /// Membership déclarée pour l'organisation sélectionnée, si elle existe.
  final OrganizationMembership? membership;

  /// Rôles actifs et utilisables dans l'organisation sélectionnée.
  final Set<OrganizationRole> effectiveRoles;

  /// Indique que le contexte utilise la compatibilité transitoire Gironde.
  final bool isLegacy;

  /// Privilège plateforme global, distinct des rôles organisationnels.
  final bool isPlatformAdministrator;

  bool get hasSelectedOrganization => organization != null;

  bool get hasActiveMembership => membership?.active == true;

  bool get hasInactiveMembership => membership?.active == false;

  bool hasRole(OrganizationRole role) => effectiveRoles.contains(role);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrganizationContext &&
          uid == other.uid &&
          organization == other.organization &&
          membership == other.membership &&
          _sameSet(effectiveRoles, other.effectiveRoles) &&
          isLegacy == other.isLegacy &&
          isPlatformAdministrator == other.isPlatformAdministrator;

  @override
  int get hashCode {
    final roles = effectiveRoles.map((role) => role.serializedValue).toList()
      ..sort();
    return Object.hash(
      uid,
      organization,
      membership,
      Object.hashAll(roles),
      isLegacy,
      isPlatformAdministrator,
    );
  }
}

void _validateUid(String value) {
  if (value.trim().isEmpty ||
      value.trim() != value ||
      value.length > 128 ||
      value.contains('/')) {
    throw const FormatException('UID de contexte invalide.');
  }
}

bool _sameSet<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);
