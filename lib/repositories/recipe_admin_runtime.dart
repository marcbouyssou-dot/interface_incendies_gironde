import 'dart:async';

import '../data/mock_data.dart';
import '../models/mobilization.dart';
import '../models/need.dart';
import '../models/operation.dart';
import '../models/operational_scope.dart';
import '../models/platform_administrator_access.dart';
import '../models/territory.dart';
import '../platform_admin/platform_actor_view_data.dart';
import '../services/accessible_mobilizations_provider.dart';
import '../services/current_mobilization_provider.dart';
import '../services/operational_context_provider.dart';
import '../services/platform_administration_service.dart';
import 'coordination_repository.dart';
import 'mock_coordination_repository.dart';
import 'operation_read_repository.dart';
import 'platform_actor_read_repository.dart';
import 'platform_administration_read_repository.dart';
import 'platform_read_repository.dart';
import 'platform_runtime.dart';

/// Local recipe fixtures. This repository never opens a Firebase connection.
class RecipeAdminCoordinationRepository extends MockCoordinationRepository
    implements MultiMobilizationCoordinationReadRepository {
  RecipeAdminCoordinationRepository()
    : super(
        initialMissions: [...needs, _recipeMission],
        initialLocations: places,
      );

  static final instance = RecipeAdminCoordinationRepository();

  @override
  Stream<List<CoordinationNeed>> watchAllActiveMissions() =>
      Stream.value([_recipeMission]);

  @override
  Stream<List<CoordinationNeed>> watchMissionsForLocations(Set<String> ids) =>
      Stream.value(
        ids.contains(_recipeMission.locationId) ? [_recipeMission] : [],
      );

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> ids,
  ) => Stream.value(
    ids.contains(_recipeMobilization.id) ? [_recipeMission] : [],
  );
}

/// In-memory Admin runtime for MOBSANTE_RECIPE_MODE without USE_FIREBASE.
/// Actual Admin access stays null; only the recipe perspective may select it.
class RecipeAdminRuntime
    implements
        PlatformRuntime,
        MultiOperationPlatformRuntime,
        PlatformActorRuntime {
  RecipeAdminRuntime() : _store = _RecipeAdminStore();

  static final instance = RecipeAdminRuntime();

  final _RecipeAdminStore _store;
  late final PlatformReadRepository _platformRead = _RecipePlatformRead(_store);
  late final MobilizationContextProvider _mobilizationProvider =
      CurrentMobilizationProvider(repository: _platformRead);
  late final PlatformAdministrationReadRepository _administrationRead =
      _RecipeAdministrationRead(_store);
  late final PlatformAdministrationService _administrationService =
      _RecipeAdministrationService(_store);
  late final OperationReadRepository _operationsRead = _RecipeOperationsRead(
    _store,
  );
  late final AccessibleMobilizationsProvider _accessibleMobilizations =
      _RecipeAccessibleMobilizations(_store);
  late final OperationalContextProvider _operationalContext =
      _RecipeOperationalContext(_store);

  @override
  PlatformReadRepository get platformReadRepository => _platformRead;

  @override
  MobilizationContextProvider get currentMobilizationProvider =>
      _mobilizationProvider;

  @override
  PlatformAdministrationReadRepository
  get platformAdministrationReadRepository => _administrationRead;

  @override
  PlatformAdministrationService get platformAdministrationService =>
      _administrationService;

  @override
  OperationReadRepository get operationReadRepository => _operationsRead;

  @override
  AccessibleMobilizationsProvider get accessibleMobilizationsProvider =>
      _accessibleMobilizations;

  @override
  OperationalContextProvider get operationalContextProvider =>
      _operationalContext;

  @override
  PlatformActorReadRepository get platformActorReadRepository =>
      const _RecipeActorsRead();
}

class _RecipePlatformRead implements PlatformReadRepository {
  const _RecipePlatformRead(this.store);

  final _RecipeAdminStore store;

  @override
  Stream<String?> watchPlatformConfig() =>
      watchActiveMobilization().map((mobilization) => mobilization?.id);

  @override
  Stream<Mobilization?> watchActiveMobilization() =>
      store.watchMobilizations().map(
        (items) => items
            .where((item) => item.status == MobilizationStatus.active)
            .firstOrNull,
      );

  @override
  Stream<List<Mobilization>> watchMobilizations({
    String? territoryId,
    bool includeInactive = false,
  }) => store.watchMobilizations().map(
    (items) => items
        .where(
          (item) =>
              (territoryId == null || item.territoryId == territoryId) &&
              (includeInactive || item.status == MobilizationStatus.active),
        )
        .toList(growable: false),
  );

  @override
  Stream<List<Territory>> watchTerritories() =>
      Stream.value([_recipeTerritory]);
}

class _RecipeOperationsRead implements OperationReadRepository {
  const _RecipeOperationsRead(this.store);

  final _RecipeAdminStore store;

  @override
  Stream<Operation?> watchOperation(String operationId) =>
      store.watchOperations().map(
        (items) => items.where((item) => item.id == operationId).firstOrNull,
      );

  @override
  Stream<List<Operation>> watchOperations({Set<OperationStatus>? statuses}) =>
      store.watchOperations().map(
        (items) => items
            .where((item) => statuses == null || statuses.contains(item.status))
            .toList(growable: false),
      );
}

class _RecipeAdministrationRead
    implements PlatformAdministrationReadRepository {
  const _RecipeAdministrationRead(this.store);

  final _RecipeAdminStore store;

  @override
  Stream<PlatformAdministratorAccess?> watchCurrentAdministrator() =>
      Stream.value(null);

  @override
  Stream<List<ActivePlatformCoordinator>> watchActiveCoordinators() =>
      Stream.value(const [
        ActivePlatformCoordinator(uid: 'recipe-coordinator'),
      ]);

  @override
  Stream<List<MobilizationCoordinatorAssignment>> watchMobilizationCoordinators(
    String mobilizationId,
  ) => store.watchAssignments().map(
    (items) => items
        .where((item) => item.mobilizationId == mobilizationId)
        .toList(growable: false),
  );
}

/// New on each browser load. No persistence or network-backed dependencies.
class _RecipeAdminStore {
  final operations = <String, Operation>{_recipeOperation.id: _recipeOperation};
  final mobilizations = <String, Mobilization>{
    _recipeMobilization.id: _recipeMobilization,
  };
  final assignments = <String, MobilizationCoordinatorAssignment>{};
  final _operationUpdates = StreamController<List<Operation>>.broadcast();
  final _mobilizationUpdates = StreamController<List<Mobilization>>.broadcast();
  final _assignmentUpdates =
      StreamController<List<MobilizationCoordinatorAssignment>>.broadcast();

  Stream<List<Operation>> watchOperations() async* {
    yield List.unmodifiable(operations.values);
    yield* _operationUpdates.stream;
  }

  Stream<List<Mobilization>> watchMobilizations() async* {
    yield List.unmodifiable(mobilizations.values);
    yield* _mobilizationUpdates.stream;
  }

  Stream<List<MobilizationCoordinatorAssignment>> watchAssignments() async* {
    yield List.unmodifiable(assignments.values);
    yield* _assignmentUpdates.stream;
  }

  void putOperation(Operation operation) {
    operations[operation.id] = operation;
    _operationUpdates.add(List.unmodifiable(operations.values));
  }

  void putMobilization(Mobilization mobilization) {
    mobilizations[mobilization.id] = mobilization;
    _mobilizationUpdates.add(List.unmodifiable(mobilizations.values));
  }

  void notifyAssignments() =>
      _assignmentUpdates.add(List.unmodifiable(assignments.values));
}

class _RecipeAdministrationService implements PlatformAdministrationService {
  const _RecipeAdministrationService(this.store);

  final _RecipeAdminStore store;

  @override
  bool get isAvailable => true;

  @override
  String? get currentUserEmail => 'admin-recette@example.invalid';

  Operation _operation(String id) =>
      store.operations[id] ??
      (throw const PlatformAdministrationException(
        'Opération de recette introuvable.',
      ));

  Mobilization _mobilization(String id) =>
      store.mobilizations[id] ??
      (throw const PlatformAdministrationException(
        'Mobilisation de recette introuvable.',
      ));

  @override
  Future<void> createOperation(OperationAdministrationDraft draft) async {
    if (store.operations.containsKey(draft.operationId)) {
      throw const PlatformAdministrationException(
        'Cette opération existe déjà.',
      );
    }
    final now = DateTime.now();
    store.putOperation(
      Operation(
        id: draft.operationId,
        name: draft.name,
        type: draft.type,
        context: draft.context,
        purpose: draft.purpose,
        themeKey: draft.themeKey,
        organizerDisplayName: draft.organizerDisplayName,
        demoSafetyLabel: draft.demoSafetyLabel,
        status: OperationStatus.draft,
        startAt: draft.startAt,
        endAt: draft.endAt,
        scopeRefs: List.unmodifiable(draft.scopeRefs),
        createdBy: 'recipe-admin',
        createdAt: now,
        updatedBy: 'recipe-admin',
        updatedAt: now,
        schemaVersion: 1,
      ),
    );
  }

  @override
  Future<void> updateOperation(OperationAdministrationDraft draft) async {
    final current = _operation(draft.operationId);
    store.putOperation(
      Operation.fromMap({
        ...current.toMap(),
        'name': draft.name,
        'type': draft.type.serializedValue,
        'context': draft.context,
        'purpose': draft.purpose.name,
        if (draft.themeKey != null) 'themeKey': draft.themeKey,
        if (draft.organizerDisplayName != null)
          'organizerDisplayName': draft.organizerDisplayName,
        if (draft.demoSafetyLabel != null)
          'demoSafetyLabel': draft.demoSafetyLabel,
        'startAt': draft.startAt,
        'endAt': draft.endAt,
        'scopeRefs': draft.scopeRefs
            .map((item) => item.serializedValue)
            .toList(),
        'updatedAt': DateTime.now(),
        'updatedBy': 'recipe-admin',
      }),
    );
  }

  @override
  Future<void> transitionOperation(
    String operationId,
    OperationStatus targetStatus,
  ) async {
    final current = _operation(operationId);
    if (!current.status.canTransitionTo(targetStatus)) {
      throw const PlatformAdministrationException(
        'Transition de recette invalide.',
      );
    }
    store.putOperation(
      Operation.fromMap({
        ...current.toMap(),
        'status': targetStatus.serializedValue,
        'updatedAt': DateTime.now(),
        'updatedBy': 'recipe-admin',
      }),
    );
  }

  @override
  Future<void> setOperationCoordinator({
    required String operationId,
    required String uid,
  }) async {
    if (uid != 'recipe-coordinator') {
      throw const PlatformAdministrationException(
        'Coordinateur de recette inconnu.',
      );
    }
    final current = _operation(operationId);
    store.putOperation(
      Operation.fromMap({
        ...current.toMap(),
        'coordinatorUid': uid,
        'updatedAt': DateTime.now(),
        'updatedBy': 'recipe-admin',
      }),
    );
    for (final mobilization in store.mobilizations.values.where(
      (item) => item.operationId == operationId,
    )) {
      final id = '${mobilization.id}_$uid';
      store.assignments[id] = MobilizationCoordinatorAssignment(
        id: id,
        uid: uid,
        mobilizationId: mobilization.id,
        active: true,
      );
    }
    store.notifyAssignments();
  }

  @override
  Future<void> createMobilization(MobilizationAdministrationDraft draft) async {
    if (store.mobilizations.containsKey(draft.mobilizationId)) {
      throw const PlatformAdministrationException(
        'Cette mobilisation existe déjà.',
      );
    }
    if (draft.operationId != null) _operation(draft.operationId!);
    final now = DateTime.now();
    store.putMobilization(
      Mobilization(
        id: draft.mobilizationId,
        operationId: draft.operationId,
        territoryId: draft.territoryId,
        name: draft.name,
        subtitle: draft.subtitle,
        contextType: draft.contextType,
        status: MobilizationStatus.draft,
        scopeRefs: draft.scopeRefs ?? const [],
        createdBy: 'recipe-admin',
        createdAt: now,
        updatedAt: now,
        schemaVersion: draft.operationId == null ? 1 : 2,
      ),
    );
  }

  @override
  Future<void> updateMobilization(MobilizationAdministrationDraft draft) async {
    final current = _mobilization(draft.mobilizationId);
    store.putMobilization(
      Mobilization.fromMap({
        ...current.toMap(),
        'operationId': draft.operationId,
        'territoryId': draft.territoryId,
        'name': draft.name,
        'subtitle': draft.subtitle,
        'contextType': draft.contextType.serializedValue,
        'scopeRefs': (draft.scopeRefs ?? const [])
            .map((item) => item.serializedValue)
            .toList(),
        'updatedAt': DateTime.now(),
      }),
    );
  }

  Future<void> _transitionMobilization(
    String id,
    MobilizationStatus target,
  ) async {
    final current = _mobilization(id);
    if (!current.status.canTransitionTo(target, allowActiveArchiving: true)) {
      throw const PlatformAdministrationException(
        'Transition de recette invalide.',
      );
    }
    final now = DateTime.now();
    store.putMobilization(
      Mobilization.fromMap({
        ...current.toMap(),
        'status': target.serializedValue,
        'updatedAt': now,
        if (target == MobilizationStatus.active) 'activatedAt': now,
        if (target == MobilizationStatus.active) 'activatedBy': 'recipe-admin',
        if (target == MobilizationStatus.inactive) 'deactivatedAt': now,
        if (target == MobilizationStatus.inactive)
          'deactivatedBy': 'recipe-admin',
        if (target == MobilizationStatus.archived) 'archivedAt': now,
        if (target == MobilizationStatus.archived) 'archivedBy': 'recipe-admin',
      }),
    );
  }

  @override
  Future<void> activateMobilization(String mobilizationId) =>
      _transitionMobilization(mobilizationId, MobilizationStatus.active);

  @override
  Future<void> deactivateMobilization(String mobilizationId) =>
      _transitionMobilization(mobilizationId, MobilizationStatus.inactive);

  @override
  Future<void> archiveMobilization(String mobilizationId) =>
      _transitionMobilization(mobilizationId, MobilizationStatus.archived);

  @override
  Future<void> assignMobilizationCoordinator({
    required String mobilizationId,
    required String uid,
  }) async {
    _mobilization(mobilizationId);
    if (uid != 'recipe-coordinator') {
      throw const PlatformAdministrationException(
        'Coordinateur de recette inconnu.',
      );
    }
    final id = '${mobilizationId}_$uid';
    store.assignments[id] = MobilizationCoordinatorAssignment(
      id: id,
      uid: uid,
      mobilizationId: mobilizationId,
      active: true,
    );
    store.notifyAssignments();
  }

  @override
  Future<void> removeMobilizationCoordinator({
    required String mobilizationId,
    required String uid,
  }) async {
    _mobilization(mobilizationId);
    store.assignments.remove('${mobilizationId}_$uid');
    store.notifyAssignments();
  }
}

class _RecipeAccessibleMobilizations
    implements AccessibleMobilizationsProvider {
  const _RecipeAccessibleMobilizations(this.store);

  final _RecipeAdminStore store;

  @override
  Stream<List<Mobilization>> watchAccessibleMobilizations() =>
      store.watchMobilizations();
}

class _RecipeOperationalContext implements OperationalContextProvider {
  const _RecipeOperationalContext(this.store);

  final _RecipeAdminStore store;

  @override
  Stream<OperationalMissionContext?> watchForMobilization(
    String mobilizationId,
  ) => store.watchMobilizations().map((items) {
    final mobilization = items
        .where((item) => item.id == mobilizationId)
        .firstOrNull;
    if (mobilization == null) return null;
    final operation = store.operations[mobilization.operationId];
    return OperationalMissionContext(
      mobilizationId: mobilization.id,
      mobilizationName: mobilization.name,
      operationId: operation?.id,
      operationName: operation?.name,
      operationType: operation?.type,
    );
  });
}

class _RecipeActorsRead implements PlatformActorReadRepository {
  const _RecipeActorsRead();

  @override
  Future<PlatformActorDirectoryViewData> loadDirectory() async =>
      const PlatformActorDirectoryViewData(
        professionals: [
          PlatformProfessionalViewData(
            uid: 'recipe-professional',
            displayName: 'Professionnel de recette',
            professionLabel: 'Masseur-kinésithérapeute',
            participations: [],
          ),
        ],
        coordinators: [
          PlatformCoordinatorViewData(
            uid: 'recipe-coordinator',
            displayName: 'Coordinateur de recette',
            active: true,
            operations: [],
            mobilizations: [],
          ),
        ],
        managers: [
          PlatformManagerViewData(
            uid: 'recipe-manager',
            displayName: 'Responsable de recette',
            active: true,
            locations: [],
            operations: [],
            territories: [],
          ),
        ],
      );
}

final _recipeMission = CoordinationNeed(
  id: 'recipe-mission',
  mobilizationId: 'recipe-mobilization',
  locationId: places.first.id,
  place: places.first.name,
  group: places.first.group,
  date: '20 juin 2030',
  time: '09:00 — 12:00',
  requiredPhysiotherapists: 2,
  registeredPhysiotherapists: 1,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  equipment: const [],
  startAt: DateTime.utc(2030, 6, 20, 9),
  endAt: DateTime.utc(2030, 6, 20, 12),
  updatedAt: DateTime.utc(2026, 8, 10),
);

final _recipeTerritory = Territory(
  id: 'gironde',
  name: 'Gironde',
  code: '33',
  active: true,
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 10),
);

final _recipeOperation = Operation(
  id: 'recipe-operation',
  name: 'Exercice de recette',
  type: OperationType.exercise,
  status: OperationStatus.active,
  startAt: DateTime.utc(2026, 8, 1),
  scopeRefs: const [
    OperationalScopeRef(kind: OperationalScopeKind.territory, id: 'gironde'),
  ],
  createdBy: 'recipe-admin',
  createdAt: DateTime.utc(2026, 8, 1),
  updatedBy: 'recipe-admin',
  updatedAt: DateTime.utc(2026, 8, 10),
  schemaVersion: 1,
);

final _recipeMobilization = Mobilization(
  id: 'recipe-mobilization',
  operationId: 'recipe-operation',
  territoryId: 'gironde',
  name: 'Mobilisation de recette',
  subtitle: 'Gironde',
  contextType: MobilizationContextType.other,
  status: MobilizationStatus.active,
  createdBy: 'recipe-admin',
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 10),
  activatedBy: 'recipe-admin',
  activatedAt: DateTime.utc(2026, 8, 10),
  schemaVersion: 2,
);
