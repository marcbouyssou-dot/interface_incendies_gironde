import '../models/organization_context.dart';

/// Politique de lecture commune aux repositories contextualisés RC4.
///
/// Elle ne remplace pas les autorisations serveur. Elle garantit que les
/// projections applicatives partagent la même interprétation d'un contexte
/// global, legacy, actif ou inactif.
abstract final class OrganizationContextReadPolicy {
  static bool hasGlobalPlatformAccess(OrganizationContext? context) =>
      context?.isPlatformAdministrator == true &&
      !context!.hasSelectedOrganization;

  static String? readableOrganizationId(OrganizationContext? context) {
    final organizationId = context?.organization?.id;
    if (organizationId == null) return null;
    if (context!.isPlatformAdministrator ||
        context.isLegacy ||
        context.hasActiveMembership) {
      return organizationId;
    }
    return null;
  }
}
