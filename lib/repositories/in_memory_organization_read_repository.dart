import '../models/organization.dart';
import '../models/organization_membership.dart';
import 'organization_read_repository.dart';

/// Source de lecture immuable destinée aux tests et aux compositions locales.
///
/// Elle applique la sémantique du contrat sans mutation ni dépendance réseau.
/// Une organisation legacy peut y être injectée comme toute autre organisation,
/// sans introduire de fallback particulier dans les consommateurs.
class InMemoryOrganizationReadRepository implements OrganizationReadRepository {
  InMemoryOrganizationReadRepository({
    Iterable<Organization> organizations = const [],
    Iterable<OrganizationMembership> memberships = const [],
  }) : _organizations = _indexOrganizations(organizations),
       _memberships = _indexMemberships(memberships) {
    for (final membership in _memberships.values) {
      if (!_organizations.containsKey(membership.organizationId)) {
        throw const FormatException(
          "Une appartenance référence une organisation inconnue.",
        );
      }
    }
  }

  final Map<String, Organization> _organizations;
  final Map<({String organizationId, String uid}), OrganizationMembership>
  _memberships;

  @override
  Stream<List<Organization>> watchAccessibleOrganizations({
    required String uid,
  }) {
    _validateLookupId(uid);
    final accessibleIds = _memberships.values
        .where((membership) => membership.uid == uid && membership.active)
        .map((membership) => membership.organizationId)
        .toSet();
    final organizations =
        _organizations.values
            .where(
              (organization) =>
                  organization.active &&
                  accessibleIds.contains(organization.id),
            )
            .toList(growable: false)
          ..sort(_compareOrganizations);
    return Stream<List<Organization>>.value(
      List<Organization>.unmodifiable(organizations),
    );
  }

  @override
  Stream<Organization?> watchOrganization(String organizationId) {
    _validateLookupId(organizationId);
    return Stream<Organization?>.value(_organizations[organizationId]);
  }

  @override
  Stream<List<OrganizationMembership>> watchMembershipsForUser(String uid) {
    _validateLookupId(uid);
    final memberships =
        _memberships.values
            .where((membership) => membership.uid == uid)
            .toList(growable: false)
          ..sort(
            (left, right) =>
                left.organizationId.compareTo(right.organizationId),
          );
    return Stream<List<OrganizationMembership>>.value(
      List<OrganizationMembership>.unmodifiable(memberships),
    );
  }

  @override
  Stream<OrganizationMembership?> watchMembership({
    required String organizationId,
    required String uid,
  }) {
    _validateLookupId(organizationId);
    _validateLookupId(uid);
    return Stream<OrganizationMembership?>.value(
      _memberships[(organizationId: organizationId, uid: uid)],
    );
  }
}

Map<String, Organization> _indexOrganizations(
  Iterable<Organization> organizations,
) {
  final result = <String, Organization>{};
  for (final organization in organizations) {
    if (result.containsKey(organization.id)) {
      throw const FormatException("Identifiant d'organisation dupliqué.");
    }
    result[organization.id] = organization;
  }
  return Map<String, Organization>.unmodifiable(result);
}

Map<({String organizationId, String uid}), OrganizationMembership>
_indexMemberships(Iterable<OrganizationMembership> memberships) {
  final result =
      <({String organizationId, String uid}), OrganizationMembership>{};
  for (final membership in memberships) {
    final key = (
      organizationId: membership.organizationId,
      uid: membership.uid,
    );
    if (result.containsKey(key)) {
      throw const FormatException("Appartenance d'organisation dupliquée.");
    }
    result[key] = membership;
  }
  return Map<
    ({String organizationId, String uid}),
    OrganizationMembership
  >.unmodifiable(result);
}

int _compareOrganizations(Organization left, Organization right) {
  final byName = left.name.compareTo(right.name);
  return byName != 0 ? byName : left.id.compareTo(right.id);
}

void _validateLookupId(String value) {
  if (value.trim().isEmpty || value.trim() != value || value.contains('/')) {
    throw const FormatException('Identifiant de lecture invalide.');
  }
}
