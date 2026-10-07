import 'package:flutter/foundation.dart';

import '../models/need.dart';
import '../models/organization_context.dart';
import '../models/organization_role.dart';
import '../services/legacy_organization_resolver.dart';
import '../services/organization_context_read_policy.dart';
import '../utils/switch_latest.dart';
import '../utils/value_listenable_stream.dart';
import 'location_read_repository.dart';

/// Projection des sites bornée à leur organisation gestionnaire.
///
/// RC4.3A ne modélise aucun partage : un site appartient soit à son
/// organisation explicite, soit à l'organisation legacy lorsque le champ est
/// absent. Une future politique de partage pourra être ajoutée ici sans
/// modifier les consommateurs ni le modèle RC3.
class OrganizationScopedLocationReadRepository
    implements ScopedLocationReadRepository {
  const OrganizationScopedLocationReadRepository({
    required LocationReadRepository delegate,
    required ValueListenable<OrganizationContext?> context,
    LegacyOrganizationResolver resolver = const LegacyOrganizationResolver(),
  }) : _delegate = delegate,
       _context = context,
       _resolver = resolver;

  final LocationReadRepository _delegate;
  final ValueListenable<OrganizationContext?> _context;
  final LegacyOrganizationResolver _resolver;

  @override
  Stream<List<ResponsePlace>> watchLocations() =>
      switchLatest(watchValueListenable(_context), (context) {
        if (OrganizationContextReadPolicy.hasGlobalPlatformAccess(context)) {
          final delegate = _delegate;
          return delegate is OrganizationLocationReadDataSource
              ? delegate.watchAllAdministrativeLocations()
              : delegate.watchLocations();
        }
        final organizationId =
            OrganizationContextReadPolicy.readableOrganizationId(context);
        if (organizationId == null) {
          return Stream<List<ResponsePlace>>.value(const []);
        }
        final delegate = _delegate;
        if (delegate is! OrganizationLocationReadDataSource) {
          return _withinOrganization(delegate.watchLocations(), organizationId);
        }
        if (context?.isPlatformAdministrator == true) {
          return _withinOrganization(
            organizationId == LegacyOrganizationResolver.legacyOrganizationId
                ? delegate.watchAllAdministrativeLocations()
                : delegate.watchLocationsManagedByOrganization(organizationId),
            organizationId,
          );
        }
        if (context?.hasRole(OrganizationRole.coordinator) == true ||
            context?.hasRole(OrganizationRole.organizationAdmin) == true) {
          return _withinOrganization(
            organizationId == LegacyOrganizationResolver.legacyOrganizationId
                ? delegate.watchLegacyAdministrativeLocations()
                : delegate.watchLocationsManagedByOrganization(organizationId),
            organizationId,
          );
        }
        return Stream<List<ResponsePlace>>.error(
          StateError('Le périmètre de sites Responsable est requis.'),
        );
      });

  @override
  Stream<List<ResponsePlace>> watchLocationsForIds(Set<String> locationIds) =>
      switchLatest(watchValueListenable(_context), (context) {
        final organizationId =
            OrganizationContextReadPolicy.readableOrganizationId(context);
        if (organizationId == null || locationIds.isEmpty) {
          return Stream<List<ResponsePlace>>.value(const []);
        }
        final delegate = _delegate;
        final source = delegate is OrganizationLocationReadDataSource
            ? delegate.watchLocationsForIds(locationIds)
            : delegate.watchLocations().map(
                (locations) => locations
                    .where((location) => locationIds.contains(location.id))
                    .toList(growable: false),
              );
        return _withinOrganization(source, organizationId);
      });

  Stream<List<ResponsePlace>> _withinOrganization(
    Stream<List<ResponsePlace>> source,
    String organizationId,
  ) => source.map(
    (locations) => List<ResponsePlace>.unmodifiable(
      locations.where(
        (location) =>
            _resolver.resolveSiteOrganizationId(
              managingOrganizationId: location.managingOrganizationId,
            ) ==
            organizationId,
      ),
    ),
  );
}
