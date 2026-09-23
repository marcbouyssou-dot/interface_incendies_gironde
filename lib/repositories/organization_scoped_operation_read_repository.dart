import 'package:flutter/foundation.dart';

import '../models/operation.dart';
import '../models/organization_context.dart';
import '../models/organization_role.dart';
import '../services/legacy_organization_resolver.dart';
import '../services/organization_context_read_policy.dart';
import '../services/operation_visibility_resolver.dart';
import '../utils/switch_latest.dart';
import '../utils/value_listenable_stream.dart';
import 'operation_read_repository.dart';

/// Borne toutes les projections d'opérations à l'organisation courante.
///
/// Le delegate reste responsable de la persistance et du parsing. Cette couche
/// garantit que ses consommateurs ne reçoivent jamais une opération d'une autre
/// organisation. Le fallback RC3 est exclusivement délégué à
/// [LegacyOrganizationResolver].
class OrganizationScopedOperationReadRepository
    implements OperationReadRepository {
  const OrganizationScopedOperationReadRepository({
    required OperationReadRepository delegate,
    required ValueListenable<OrganizationContext?> context,
    LegacyOrganizationResolver resolver = const LegacyOrganizationResolver(),
    OperationVisibilityResolver visibilityResolver =
        const OperationVisibilityResolver(),
  }) : _delegate = delegate,
       _context = context,
       _resolver = resolver,
       _visibilityResolver = visibilityResolver;

  final OperationReadRepository _delegate;
  final ValueListenable<OrganizationContext?> _context;
  final LegacyOrganizationResolver _resolver;
  final OperationVisibilityResolver _visibilityResolver;

  @override
  Stream<List<Operation>> watchOperations({Set<OperationStatus>? statuses}) =>
      switchLatest(watchValueListenable(_context), (context) {
        if (OrganizationContextReadPolicy.hasGlobalPlatformAccess(context)) {
          return _delegate.watchOperations(statuses: statuses);
        }
        final organizationId =
            OrganizationContextReadPolicy.readableOrganizationId(context);
        if (organizationId == null) {
          return Stream<List<Operation>>.value(const []);
        }
        return _delegate
            .watchOperations(statuses: statuses)
            .map(
              (operations) => List<Operation>.unmodifiable(
                operations.where(
                  (operation) => _canReadOperation(
                    operation: operation,
                    context: context!,
                    organizationId: organizationId,
                  ),
                ),
              ),
            );
      });

  @override
  Stream<Operation?> watchOperation(String operationId) =>
      switchLatest(watchValueListenable(_context), (context) {
        if (OrganizationContextReadPolicy.hasGlobalPlatformAccess(context)) {
          return _delegate.watchOperation(operationId);
        }
        final organizationId =
            OrganizationContextReadPolicy.readableOrganizationId(context);
        if (organizationId == null) {
          return Stream<Operation?>.value(null);
        }
        return _delegate.watchOperation(operationId).map((operation) {
          if (operation == null) return null;
          return _canReadOperation(
                operation: operation,
                context: context!,
                organizationId: organizationId,
              )
              ? operation
              : null;
        });
      });

  bool _canReadOperation({
    required Operation operation,
    required OrganizationContext context,
    required String organizationId,
  }) {
    final ownerId = _resolver.resolveOperationOrganizationId(operation);
    if (ownerId == organizationId) return true;
    if (!context.hasRole(OrganizationRole.professional)) return false;

    // Une opération externe sans visibilité explicite reste fermée : le défaut
    // de son organisation ne doit jamais être deviné ni élargir implicitement
    // l'accès. Le seul fallback externe autorisé est le legacy centralisé.
    if (operation.visibility == null &&
        ownerId != LegacyOrganizationResolver.legacyOrganizationId) {
      return false;
    }
    return _visibilityResolver.isPlatformDiscoverable(operation: operation);
  }
}
