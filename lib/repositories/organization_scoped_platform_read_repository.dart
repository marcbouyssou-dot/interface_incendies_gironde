import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/mobilization.dart';
import '../models/operation.dart';
import '../models/organization_context.dart';
import '../models/organization_role.dart';
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
    implements
        PlatformReadRepository,
        ResponsibleMobilizationReadRepository,
        MobilizationLookupRepository {
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
  Stream<List<Mobilization>> watchResponsibleActiveMobilizations() =>
      switchLatest(watchValueListenable(_context), (context) {
        final organizationId =
            OrganizationContextReadPolicy.readableOrganizationId(context);
        if (organizationId == null) {
          return Stream<List<Mobilization>>.value(const []);
        }
        if (organizationId != LegacyOrganizationResolver.legacyOrganizationId ||
            context?.hasActiveMembership == true) {
          return _watchMobilizationsForContext(
            context: context,
            organizationId: organizationId,
          );
        }
        if (_delegate is MobilizationLookupRepository) {
          return watchActiveMobilization().map(
            (mobilization) => mobilization == null
                ? const <Mobilization>[]
                : List<Mobilization>.unmodifiable([mobilization]),
          );
        }
        return _delegate.watchActiveMobilization().map((mobilization) {
          if (mobilization == null ||
              !_resolver.isMobilizationAccessible(
                mobilization: mobilization,
                organizationId: organizationId,
                accessibleOperationIds: const {},
              )) {
            return const <Mobilization>[];
          }
          return List<Mobilization>.unmodifiable([mobilization]);
        });
      });

  @override
  Stream<Mobilization?> watchMobilization(String mobilizationId) =>
      switchLatest(watchValueListenable(_context), (context) {
        final source = _lookupMobilization(mobilizationId);
        if (OrganizationContextReadPolicy.hasGlobalPlatformAccess(context)) {
          return source;
        }
        final organizationId =
            OrganizationContextReadPolicy.readableOrganizationId(context);
        if (organizationId == null) return Stream<Mobilization?>.value(null);
        if (organizationId == LegacyOrganizationResolver.legacyOrganizationId &&
            context?.isPlatformAdministrator != true &&
            _delegate is MobilizationLookupRepository) {
          return switchLatest(_retainLastMobilization(source), (mobilization) {
            if (mobilization == null) {
              return Stream<Mobilization?>.value(null);
            }
            final operationId = mobilization.operationId;
            if (operationId == null) {
              return Stream<Mobilization?>.value(mobilization);
            }
            return _operationRepository
                .watchOperation(operationId)
                .map((operation) => operation == null ? null : mobilization);
          });
        }
        return _combineLatestOperationsAndMobilizations<Mobilization?>(
          _operationRepository.watchOperations(),
          source,
          (operations, mobilization) =>
              mobilization != null &&
                  _resolver.isMobilizationAccessible(
                    mobilization: mobilization,
                    organizationId: organizationId,
                    accessibleOperationIds: operations
                        .map((operation) => operation.id)
                        .toSet(),
                  )
              ? mobilization
              : null,
        );
      });

  Stream<Mobilization?> _lookupMobilization(String mobilizationId) {
    final delegate = _delegate;
    if (delegate is MobilizationLookupRepository) {
      return (delegate as MobilizationLookupRepository).watchMobilization(
        mobilizationId,
      );
    }
    return delegate
        .watchMobilizations(includeInactive: true)
        .map(
          (mobilizations) => mobilizations
              .where((mobilization) => mobilization.id == mobilizationId)
              .firstOrNull,
        );
  }

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
    return _watchMobilizationsForContext(
      context: context,
      organizationId: organizationId,
      territoryId: territoryId,
      includeInactive: includeInactive,
    );
  });

  Stream<List<Mobilization>> _watchMobilizationsForContext({
    required OrganizationContext? context,
    required String organizationId,
    String? territoryId,
    bool includeInactive = false,
  }) {
    if (OrganizationContextReadPolicy.hasGlobalPlatformAccess(context)) {
      return _delegate.watchMobilizations(
        territoryId: territoryId,
        includeInactive: includeInactive,
      );
    }
    final delegate = _delegate;
    final isManager =
        context?.hasRole(OrganizationRole.coordinator) == true ||
        context?.hasRole(OrganizationRole.siteManager) == true ||
        context?.hasRole(OrganizationRole.organizationAdmin) == true;
    if (context?.isPlatformAdministrator != true &&
        isManager &&
        delegate is OperationMobilizationReadRepository) {
      if (includeInactive) {
        return Stream<List<Mobilization>>.error(
          StateError('Liste des mobilisations inactives non autorisée.'),
        );
      }
      final scopedDelegate = delegate as OperationMobilizationReadRepository;
      return switchLatest(_operationRepository.watchOperations(), (operations) {
        // Les rôles RC3 legacy sans membership n'ont accès qu'à leur
        // mobilisation configurée en lecture documentaire ciblée.
        final source =
            organizationId == LegacyOrganizationResolver.legacyOrganizationId &&
                context?.hasActiveMembership != true
            ? Stream<List<Mobilization>>.value(const [])
            : scopedDelegate.watchActiveMobilizationsForOperations(
                operations.map((operation) => operation.id).toSet(),
                territoryId: territoryId,
              );
        if (organizationId != LegacyOrganizationResolver.legacyOrganizationId) {
          return source.map(
            (mobilizations) => _filterMobilizations(
              organizationId: organizationId,
              operations: operations,
              mobilizations: mobilizations,
            ),
          );
        }
        final scopedSource = source.map(
          (mobilizations) => _filterMobilizations(
            organizationId: organizationId,
            operations: operations,
            mobilizations: mobilizations,
          ),
        );
        final legacy = switchLatest(_delegate.watchPlatformConfig(), (id) {
          if (id == null) return Stream<List<Mobilization>>.value(const []);
          return switchLatest(
            _retainLastMobilization(_lookupMobilization(id)),
            (mobilization) {
              if (mobilization == null) {
                return Stream<List<Mobilization>>.value(const []);
              }
              if (mobilization.operationId == null) {
                return Stream<List<Mobilization>>.value([mobilization]);
              }
              return Stream<List<Mobilization>>.value(const []);
            },
          );
        });
        return _combineLatestMobilizationLists(scopedSource, legacy).map(
          (mobilizations) => mobilizations
              .where(
                (mobilization) =>
                    mobilization.status == MobilizationStatus.active &&
                    (territoryId == null ||
                        mobilization.territoryId == territoryId),
              )
              .toList(growable: false),
        );
      });
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
  }

  @override
  Stream<Mobilization?> watchActiveMobilization() =>
      switchLatest(watchValueListenable(_context), (context) {
        if (OrganizationContextReadPolicy.hasGlobalPlatformAccess(context)) {
          return _delegate.watchActiveMobilization();
        }
        final organizationId =
            OrganizationContextReadPolicy.readableOrganizationId(context);
        if (organizationId != LegacyOrganizationResolver.legacyOrganizationId ||
            context?.hasInactiveMembership == true) {
          return Stream<Mobilization?>.value(null);
        }
        return _delegate.watchActiveMobilization().map((mobilization) {
          if (mobilization == null ||
              mobilization.operationId != null ||
              mobilization.status != MobilizationStatus.active) {
            return null;
          }
          return _resolver.isMobilizationAccessible(
                mobilization: mobilization,
                organizationId: organizationId!,
                accessibleOperationIds: const {},
              )
              ? mobilization
              : null;
        });
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

Stream<List<Mobilization>> _combineLatestMobilizationLists(
  Stream<List<Mobilization>> first,
  Stream<List<Mobilization>> second,
) => Stream<List<Mobilization>>.multi((controller) {
  List<Mobilization>? firstValue;
  List<Mobilization>? secondValue;
  void emit() {
    if (firstValue == null || secondValue == null) return;
    final byId = <String, Mobilization>{};
    for (final item in firstValue!) {
      byId[item.id] = item;
    }
    for (final item in secondValue!) {
      byId[item.id] = item;
    }
    controller.add(List<Mobilization>.unmodifiable(byId.values));
  }

  final subscriptions = <StreamSubscription<List<Mobilization>>>[
    first.listen((value) {
      firstValue = value;
      emit();
    }, onError: controller.addError),
    second.listen((value) {
      secondValue = value;
      emit();
    }, onError: controller.addError),
  ];
  controller.onCancel = () async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  };
});

/// Les refus documentaires sont projetés en `null` par la source, puis son
/// flux se ferme. Conserver cet état laisse le filtre enfant émettre `null`.
Stream<Mobilization?> _retainLastMobilization(Stream<Mobilization?> source) =>
    Stream<Mobilization?>.multi((controller) {
      final subscription = source.listen(
        controller.add,
        onError: controller.addError,
        onDone: () {},
      );
      controller.onCancel = subscription.cancel;
    });
