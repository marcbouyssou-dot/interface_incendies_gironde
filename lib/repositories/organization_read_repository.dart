import '../models/organization.dart';
import '../models/organization_membership.dart';
import '../models/organization_role.dart';

/// Contrat de lecture du domaine Organisation.
///
/// Les consommateurs dépendent uniquement de cette abstraction. Une future
/// implémentation Firestore pourra ainsi remplacer une source mémoire sans
/// introduire de lecture directe dans l'UI.
abstract interface class OrganizationReadRepository {
  /// Observe les organisations actives auxquelles [uid] appartient activement.
  Stream<List<Organization>> watchAccessibleOrganizations({
    required String uid,
  });

  /// Observe une organisation, active ou inactive, à partir de son identifiant.
  Stream<Organization?> watchOrganization(String organizationId);

  /// Observe toutes les appartenances de [uid], y compris les inactives.
  Stream<List<OrganizationMembership>> watchMembershipsForUser(String uid);

  /// Observe l'appartenance exacte définie par l'organisation et l'utilisateur.
  Stream<OrganizationMembership?> watchMembership({
    required String organizationId,
    required String uid,
  });
}

/// Projections de lecture dérivées du contrat canonique d'appartenance.
extension OrganizationMembershipReadProjections on OrganizationReadRepository {
  /// Indique si l'appartenance existe et est active.
  Stream<bool> watchMembershipIsActive({
    required String organizationId,
    required String uid,
  }) => watchMembership(
    organizationId: organizationId,
    uid: uid,
  ).map((membership) => membership?.active == true);

  /// Expose uniquement les rôles effectifs d'une appartenance active.
  ///
  /// Une appartenance absente ou inactive produit un ensemble vide afin que ses
  /// anciens rôles ne puissent pas être interprétés comme des droits actifs.
  Stream<Set<OrganizationRole>> watchActiveOrganizationRoles({
    required String organizationId,
    required String uid,
  }) => watchMembership(organizationId: organizationId, uid: uid).map(
    (membership) => membership?.active == true
        ? Set<OrganizationRole>.unmodifiable(membership!.roles)
        : const <OrganizationRole>{},
  );
}

/// Implémentation neutre utilisable tant qu'aucune source n'est configurée.
class NoOrganizationReadRepository implements OrganizationReadRepository {
  const NoOrganizationReadRepository();

  @override
  Stream<List<Organization>> watchAccessibleOrganizations({
    required String uid,
  }) => Stream<List<Organization>>.value(const []);

  @override
  Stream<Organization?> watchOrganization(String organizationId) =>
      Stream<Organization?>.value(null);

  @override
  Stream<List<OrganizationMembership>> watchMembershipsForUser(String uid) =>
      Stream<List<OrganizationMembership>>.value(const []);

  @override
  Stream<OrganizationMembership?> watchMembership({
    required String organizationId,
    required String uid,
  }) => Stream<OrganizationMembership?>.value(null);
}
