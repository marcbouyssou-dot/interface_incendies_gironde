import 'dart:async';

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
import 'operation_access_read_repository.dart';

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
    OperationAccessReadRepository accessRepository =
        const EmptyOperationAccessReadRepository(),
    required ValueListenable<OrganizationContext?> context,
    LegacyOrganizationResolver resolver = const LegacyOrganizationResolver(),
    OperationVisibilityResolver visibilityResolver =
        const OperationVisibilityResolver(),
  }) : _delegate = delegate,
       _accessRepository = accessRepository,
       _context = context,
       _resolver = resolver,
       _visibilityResolver = visibilityResolver;

  final OperationReadRepository _delegate;
  final OperationAccessReadRepository _accessRepository;
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
        final delegate = _delegate;
        final isManager =
            context?.hasRole(OrganizationRole.coordinator) == true ||
            context?.hasRole(OrganizationRole.siteManager) == true;
        if (isManager &&
            context?.hasActiveMembership == true &&
            context?.isPlatformAdministrator != true) {
          return switchLatest(
            _accessRepository.watchForUser(context!.uid),
            (grants) => _watchGrantedOperations(
              grants
                  .where(
                    (grant) =>
                        grant.organizationId == organizationId &&
                        grant.canRead(context),
                  )
                  .map((grant) => grant.operationId)
                  .toSet(),
              organizationId: organizationId,
              statuses: statuses,
            ),
          );
        }
        final source =
            context?.isPlatformAdministrator != true &&
                isManager &&
                delegate is OrganizationOperationReadRepository
            ? (delegate as OrganizationOperationReadRepository)
                  .watchOperationsForOrganization(
                    organizationId,
                    statuses:
                        statuses ??
                        const {
                          OperationStatus.draft,
                          OperationStatus.planned,
                          OperationStatus.active,
                          OperationStatus.suspended,
                        },
                  )
            : delegate.watchOperations(
                statuses:
                    statuses ??
                    (context?.isPlatformAdministrator == true ||
                            delegate is! OrganizationOperationReadRepository
                        ? null
                        : const {
                            OperationStatus.planned,
                            OperationStatus.active,
                          }),
              );
        return source.map(
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
        final isManager =
            context!.hasRole(OrganizationRole.coordinator) ||
            context.hasRole(OrganizationRole.siteManager);
        if (isManager && context.hasActiveMembership) {
          return switchLatest(_accessRepository.watchForUser(context.uid), (
            grants,
          ) {
            if (!grants.any(
              (grant) =>
                  grant.operationId == operationId &&
                  grant.organizationId == organizationId &&
                  grant.canRead(context),
            )) {
              return Stream<Operation?>.value(null);
            }
            return _delegate
                .watchOperation(operationId)
                .map(
                  (operation) =>
                      operation != null &&
                          _resolver.resolveOperationOrganizationId(operation) ==
                              organizationId
                      ? operation
                      : null,
                );
          });
        }
        return _delegate.watchOperation(operationId).map((operation) {
          if (operation == null) return null;
          return _canReadOperation(
                operation: operation,
                context: context,
                organizationId: organizationId,
              )
              ? operation
              : null;
        });
      });

  Stream<List<Operation>> _watchGrantedOperations(
    Set<String> ids, {
    required String organizationId,
    Set<OperationStatus>? statuses,
  }) {
    if (ids.isEmpty) return Stream.value(const []);
    late final StreamController<List<Operation>> controller;
    final subscriptions = <StreamSubscription<Operation?>>[];
    final values = <String, Operation?>{};

    void emit() {
      if (values.length != ids.length || controller.isClosed) return;
      final operations =
          values.values
              .whereType<Operation>()
              .where(
                (operation) =>
                    _resolver.resolveOperationOrganizationId(operation) ==
                        organizationId &&
                    (statuses == null || statuses.contains(operation.status)),
              )
              .toList(growable: false)
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
      controller.add(List.unmodifiable(operations));
    }

    controller = StreamController<List<Operation>>(
      onListen: () {
        for (final id in ids) {
          subscriptions.add(
            _delegate.watchOperation(id).listen((operation) {
              values[id] = operation;
              emit();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

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
