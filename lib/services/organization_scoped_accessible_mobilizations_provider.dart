import 'package:flutter/foundation.dart';

import '../models/mobilization.dart';
import '../models/organization_context.dart';
import '../models/organization_role.dart';
import '../repositories/platform_read_repository.dart';
import '../repositories/operation_access_read_repository.dart';
import '../utils/switch_latest.dart';
import '../utils/value_listenable_stream.dart';
import 'accessible_mobilizations_provider.dart';

/// Adapte le sélecteur de mobilisations du Coordinateur au contexte RC4.
///
/// Une membership `coordinator` active voit les mobilisations actives déjà
/// bornées par le repository de plateforme de son organisation. Le fallback
/// legacy conserve exactement les affectations RC3 existantes.
class OrganizationScopedAccessibleMobilizationsProvider
    implements AccessibleMobilizationsProvider {
  const OrganizationScopedAccessibleMobilizationsProvider({
    required AccessibleMobilizationsProvider legacyDelegate,
    required PlatformReadRepository organizationRepository,
    required ValueListenable<OrganizationContext?> context,
    OperationAccessReadRepository accessRepository =
        const EmptyOperationAccessReadRepository(),
  }) : _legacyDelegate = legacyDelegate,
       _organizationRepository = organizationRepository,
       _context = context,
       _accessRepository = accessRepository;

  final AccessibleMobilizationsProvider _legacyDelegate;
  final PlatformReadRepository _organizationRepository;
  final ValueListenable<OrganizationContext?> _context;
  final OperationAccessReadRepository _accessRepository;

  @override
  Stream<List<Mobilization>> watchAccessibleMobilizations() =>
      switchLatest(watchValueListenable(_context), (context) {
        if (context == null || !context.hasSelectedOrganization) {
          return _legacyDelegate.watchAccessibleMobilizations();
        }
        if (context.membership == null && context.isLegacy) {
          return _legacyDelegate.watchAccessibleMobilizations();
        }
        if (!context.hasActiveMembership ||
            !context.hasRole(OrganizationRole.coordinator)) {
          return Stream<List<Mobilization>>.value(const []);
        }
        return switchLatest(_accessRepository.watchForUser(context.uid), (
          grants,
        ) {
          final actionIds = grants
              .where(
                (grant) =>
                    grant.organizationId == context.organization?.id &&
                    grant.roles.contains(OrganizationRole.coordinator) &&
                    grant.canRead(context),
              )
              .map((grant) => grant.operationId)
              .toSet();
          if (actionIds.isEmpty) return Stream.value(const <Mobilization>[]);
          return _organizationRepository.watchMobilizations().map(
            (mobilizations) => List<Mobilization>.unmodifiable(
              mobilizations.where(
                (mobilization) =>
                    mobilization.status == MobilizationStatus.active &&
                    actionIds.contains(mobilization.operationId),
              ),
            ),
          );
        });
      });
}
