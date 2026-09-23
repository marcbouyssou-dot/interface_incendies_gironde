import '../models/operation.dart';
import '../models/organization.dart';
import '../models/organization_visibility.dart';
import 'legacy_organization_resolver.dart';

/// Résout l'unique visibilité effective d'une opération.
///
/// Une visibilité explicite est toujours prioritaire. L'utilisation de
/// [Organization.defaultVisibility] est limitée aux documents transitoires qui
/// n'ont pas encore de visibilité : ce défaut doit être copié à la création des
/// futures opérations et ne constitue pas un droit dynamique rétroactif.
class OperationVisibilityResolver {
  const OperationVisibilityResolver({
    LegacyOrganizationResolver legacyResolver =
        const LegacyOrganizationResolver(),
  }) : _legacyResolver = legacyResolver;

  final LegacyOrganizationResolver _legacyResolver;

  OrganizationVisibility resolve({
    required Operation operation,
    Organization? ownerOrganization,
  }) {
    final explicit = operation.visibility;
    if (explicit != null) return explicit;

    final ownerId = _legacyResolver.resolveOperationOrganizationId(operation);
    if (ownerId == LegacyOrganizationResolver.legacyOrganizationId) {
      return OrganizationVisibility.platform;
    }
    if (ownerOrganization == null || ownerOrganization.id != ownerId) {
      throw StateError(
        "L'organisation propriétaire est requise pour résoudre la visibilité.",
      );
    }
    return ownerOrganization.defaultVisibility;
  }

  /// Une découverte externe n'est possible que pour `platform`.
  ///
  /// `shared` reste volontairement fermé en l'absence de grants partenaires et
  /// `publicAccess` ne donne aucun accès brut aux collections métier.
  bool isPlatformDiscoverable({
    required Operation operation,
    Organization? ownerOrganization,
  }) =>
      resolve(operation: operation, ownerOrganization: ownerOrganization) ==
      OrganizationVisibility.platform;
}
