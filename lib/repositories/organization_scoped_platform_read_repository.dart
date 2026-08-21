import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/mobilization.dart';
import '../models/operation.dart';
import '../models/organization_context.dart';
import '../models/territory.dart';
import '../services/legacy_organization_resolver.dart';
import '../services/organization_context_read_policy.dart';
import '../utils/switch_latest.dart';
import '../utils/value_listenable_stream.dart';
import 'operation_read_repository.dart';
import 'platform_read_repository.dart';

/// Projection de [PlatformReadRepository] bornée à l'organisation courante.
///
/// Les territoires restent partagés. Toutes les lectures de mobilisations,
/// y compris la mobilisation active legacy, appliquent la même politique.
class OrganizationScopedPlatformReadRepository
    implements PlatformReadRepository {
  const OrganizationScopedPlatformReadRepository({
    required PlatformReadRepository delegate,
    required OperationReadRepository operationRepository,
    required ValueListenable<OrganizationContext?> context,
    LegacyOrganizationResolver resolver = const LegacyOrganizationResolver(),
  }) : _delegate = delegate,
       _operationRepository = operationRepository,
       _context = context,
       _resolver = resolver;

  final PlatformReadRepository _delegate;
  final OperationReadRepository _operationRepository;
  final ValueListenable<OrganizationContext?> _context;
  final LegacyOrganizationResolver _resolver;

  @override
  Stream<String?> watchPlatformConfig() =>
      watchActiveMobilization().map((mobilization) => mobilization?.id);

  @override
  Stream<List<Territory>> watchTerritories() => _delegate.watchTerritories();

  @override
  Stream<List<Mobilization>> watchMobilizations({
    String? territoryId,
    bool includeInactive = false,
  }) => switchLatest(watchValueListenable(_context), (context) {
    if (OrganizationContextReadPolicy.hasGlobalPlatformAccess(context)) {
      return _delegate.watchMobilizations(
        territoryId: territoryId,
        includeInactive: includeInactive,
      );
    }
    final organizationId = OrganizationContextReadPolicy.readableOrganizationId(
      context,
    );
    if (organizationId == null) {
      return Stream<List<Mobilization>>.value(const []);
    }
    return _combineLatestOperationsAndMobilizations(
      _operationRepository.watchOperations(),
      _delegate.watchMobilizations(
        territoryId: territoryId,
        includeInactive: includeInactive,
      ),
      (operations, mobilizations) => _filterMobilizations(
        organizationId: organizationId,
        operations: operations,
        mobilizations: mobilizations,
      ),
    );
  });

  @override
  Stream<Mobilization?> watchActiveMobilization() =>
      switchLatest(watchValueListenable(_context), (context) {
        if (OrganizationContextReadPolicy.hasGlobalPlatformAccess(context)) {
          return _delegate.watchActiveMobilization();
        }
        final organizationId =
            OrganizationContextReadPolicy.readableOrganizationId(context);
        if (organizationId == null) {
          return Stream<Mobilization?>.value(null);
        }
        return _combineLatestOperationsAndMobilizations<Mobilization?>(
          _operationRepository.watchOperations(),
          _delegate.watchActiveMobilization(),
          (operations, mobilization) {
            if (mobilization == null) return null;
            final accessibleOperationIds = operations
                .map((operation) => operation.id)
                .toSet();
            return _resolver.isMobilizationAccessible(
                  mobilization: mobilization,
                  organizationId: organizationId,
                  accessibleOperationIds: accessibleOperationIds,
                )
                ? mobilization
                : null;
          },
        );
      });

  List<Mobilization> _filterMobilizations({
    required String organizationId,
    required List<Operation> operations,
    required List<Mobilization> mobilizations,
  }) {
    final accessibleOperationIds = operations
        .map((operation) => operation.id)
        .toSet();
    return List<Mobilization>.unmodifiable(
      mobilizations.where(
        (mobilization) => _resolver.isMobilizationAccessible(
          mobilization: mobilization,
          organizationId: organizationId,
          accessibleOperationIds: accessibleOperationIds,
        ),
      ),
    );
  }
}

Stream<R> _combineLatestOperationsAndMobilizations<R>(
  Stream<List<Operation>> operationStream,
  Stream<R> mobilizationStream,
  R Function(List<Operation> operations, R mobilizations) combine,
) => Stream<R>.multi((controller) {
  List<Operation>? operations;
  R? mobilizations;
  var hasMobilizations = false;
  var completedStreams = 0;

  void emitWhenReady() {
    final currentOperations = operations;
    if (currentOperations == null || !hasMobilizations) return;
    controller.add(combine(currentOperations, mobilizations as R));
  }

  void markDone() {
    completedStreams++;
    if (completedStreams == 2) controller.close();
  }

  final subscriptions = <StreamSubscription<dynamic>>[
    operationStream.listen(
      (value) {
        operations = value;
        emitWhenReady();
      },
      onError: controller.addError,
      onDone: markDone,
    ),
    mobilizationStream.listen(
      (value) {
        mobilizations = value;
        hasMobilizations = true;
        emitWhenReady();
      },
      onError: controller.addError,
      onDone: markDone,
    ),
  ];
  controller.onCancel = () async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  };
});
