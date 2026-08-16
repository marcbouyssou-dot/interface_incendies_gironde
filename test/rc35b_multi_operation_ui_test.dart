import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/operational_scope.dart';
import 'package:interface_incendies_gironde/models/territory.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/operation_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_administration_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_read_repository.dart';
import 'package:interface_incendies_gironde/screens/coordinator_cockpit_screen.dart';
import 'package:interface_incendies_gironde/screens/coordinator_published_needs.dart';
import 'package:interface_incendies_gironde/screens/platform_admin_operations_screen.dart';
import 'package:interface_incendies_gironde/services/accessible_mobilizations_provider.dart';
import 'package:interface_incendies_gironde/services/current_mobilization_provider.dart';
import 'package:interface_incendies_gironde/services/operational_context_provider.dart';
import 'package:interface_incendies_gironde/services/platform_administration_service.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/operation_context_badge.dart';
import 'package:interface_incendies_gironde/widgets/v5_form_system.dart';

void main() {
  testWidgets('Administrateur classe les opérations et isole le legacy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final platform = _PlatformRepository([
      _mobilization('mob-active', operationId: 'op-active'),
      _mobilization('mob-planned', operationId: 'op-planned'),
      _mobilization('mob-legacy'),
    ]);
    await tester.pumpWidget(
      _app(
        PlatformAdminOperationsScreen(
          operationRepository: _OperationRepository([
            _operation('op-active', OperationStatus.active),
            _operation('op-planned', OperationStatus.planned),
            _operation('op-completed', OperationStatus.completed),
            _operation('op-archived', OperationStatus.archived),
          ]),
          platformRepository: platform,
          mobilizationProvider: CurrentMobilizationProvider(
            repository: platform,
          ),
          administrationRepository:
              const NoPlatformAdministrationReadRepository(),
          administrationService: _AdministrationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Centre opérationnel'), findsOneWidget);
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('À venir'), findsOneWidget);
    expect(find.text('Terminées'), findsOneWidget);
    expect(find.text('Archivées'), findsOneWidget);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('legacy-mobilizations')),
      500,
      scrollable: scrollable,
    );
    expect(find.text('Mobilisations historiques'), findsOneWidget);
    expect(find.text('1 mobilisation sans opération'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('platform-operation-op-active')),
      -500,
      scrollable: scrollable,
    );
    expect(
      find.byKey(const Key('platform-operation-op-active')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('platform-operation-op-active')));
    await tester.pumpAndSettle();
    expect(find.text('Situation de l’opération'), findsOneWidget);
    expect(
      find.byKey(const Key('transition-operation-suspended')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('transition-operation-completed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('transition-operation-archived')),
      findsNothing,
    );
  });

  testWidgets('Coordinateur sélectionne uniquement ses mobilisations', (
    tester,
  ) async {
    final location = places.first;
    final first = _mobilization('mob-a', operationId: 'op-active');
    final second = _mobilization('mob-b', operationId: 'op-planned');
    final unassigned = _mobilization('mob-hidden');
    final missionA = _mission('mission-a', first.id, location);
    final missionB = _mission('mission-b', second.id, location);
    final repository = MockCoordinationRepository(
      initialMissions: const [],
      initialLocations: [location],
    );
    final liveData = LiveCoordinationData(repository);
    addTearDown(liveData.dispose);
    final multi = _MultiReadRepository({
      first.id: [missionA],
      second.id: [missionB],
      unassigned.id: [_mission('mission-hidden', unassigned.id, location)],
    });
    final published = CoordinatorPublishedNeeds();
    addTearDown(published.dispose);
    String? selected;

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: LiveCoordinationDataScope(
            data: liveData,
            child: CoordinatorCockpitScreen(
              publishedNeeds: published,
              onViewMission: (_) {},
              onViewLocation: (_) {},
              onCreateNeed: () {},
              accessibleMobilizationsProvider: _AccessibleMobilizations([
                first,
                second,
              ]),
              multiMobilizationRepository: multi,
              operationRepository: _OperationRepository([
                _operation('op-active', OperationStatus.active),
                _operation('op-planned', OperationStatus.planned),
              ]),
              onMobilizationSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('coordinator-mobilization-selector')),
      findsOneWidget,
    );
    expect(find.text('mob-hidden'), findsNothing);
    expect(selected, first.id);
    expect(multi.requested.any((ids) => setEquals(ids, {first.id})), isTrue);
    expect(
      tester.getSemantics(find.byKey(const Key('cockpit-map-counters'))).label,
      contains('1 mission'),
    );

    final selector = tester.widget<V5SelectField<String>>(
      find.byKey(const Key('coordinator-mobilization-selector')),
    );
    selector.onChanged!(second.id);
    await tester.pumpAndSettle();
    expect(selected, second.id);
    expect(multi.requested.any((ids) => setEquals(ids, {second.id})), isTrue);
    expect(
      find.byKey(const Key('coordinator-operation-context')),
      findsOneWidget,
    );
  });

  testWidgets(
    'état vide Opérations reste compact en Dark Mode et Dynamic Type',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final platform = _PlatformRepository(const []);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: SafeArea(
              child: PlatformAdminOperationsScreen(
                operationRepository: _OperationRepository(const []),
                platformRepository: platform,
                mobilizationProvider: CurrentMobilizationProvider(
                  repository: platform,
                ),
                administrationRepository:
                    const NoPlatformAdministrationReadRepository(),
                administrationService: _AdministrationService(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .getSize(find.byKey(const Key('create-platform-operation')))
            .height,
        greaterThanOrEqualTo(44),
      );
      expect(
        Theme.of(tester.element(find.text('Centre opérationnel'))).brightness,
        Brightness.dark,
      );
      await tester.scrollUntilVisible(
        find.textContaining('Aucune opération'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Aucune opération'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Coordinateur avec une affectation ne voit aucun sélecteur', (
    tester,
  ) async {
    final location = places.first;
    final mobilization = _mobilization('mob-only', operationId: 'op-active');
    final repository = MockCoordinationRepository(
      initialMissions: const [],
      initialLocations: [location],
    );
    final liveData = LiveCoordinationData(repository);
    addTearDown(liveData.dispose);
    final published = CoordinatorPublishedNeeds();
    addTearDown(published.dispose);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: LiveCoordinationDataScope(
            data: liveData,
            child: CoordinatorCockpitScreen(
              publishedNeeds: published,
              onViewMission: (_) {},
              onViewLocation: (_) {},
              onCreateNeed: () {},
              accessibleMobilizationsProvider: _AccessibleMobilizations([
                mobilization,
              ]),
              multiMobilizationRepository: _MultiReadRepository({
                mobilization.id: [
                  _mission('mission-only', mobilization.id, location),
                ],
              }),
              operationRepository: _OperationRepository([
                _operation('op-active', OperationStatus.active),
              ]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('coordinator-mobilization-selector')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('coordinator-operation-context')),
      findsOneWidget,
    );
  });

  test(
    'les flux Professionnel et Responsable restent unifiés sans sélecteur',
    () async {
      final location = places.first;
      final missions = [
        _mission('mission-a', 'mob-a', location),
        _mission('mission-b', 'mob-b', location),
      ];
      final professional = _MultiMockRepository(
        all: missions,
        initialLocations: [location],
        access: null,
      );
      final professionalData = LiveCoordinationData(professional);
      expect(await professionalData.watchMissions().first, missions);
      expect(professional.allCalls, 1);
      await professionalData.dispose();

      final responsible = _MultiMockRepository(
        all: missions,
        byLocations: missions,
        initialLocations: [location],
        access: ResponsibleAccess(
          uid: 'manager',
          role: ResponsibleRole.siteManager,
          locationIds: {location.id},
          active: true,
        ),
      );
      final responsibleData = LiveCoordinationData(responsible);
      expect(await responsibleData.watchMissions().first, missions);
      expect(
        responsible.locationRequests.any(
          (ids) => setEquals(ids, {location.id}),
        ),
        isTrue,
      );
      await responsibleData.dispose();
    },
  );

  testWidgets('le contexte d’opération est discret et accessible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        OperationalContextScope(
          provider: _ContextProvider(),
          child: const Scaffold(
            body: MissionOperationContextBadge(mobilizationId: 'mob-a'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Opération op-active · Urgence'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Contexte : Opération op-active, Urgence'),
      findsOneWidget,
    );
  });
}

Widget _app(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

Operation _operation(String id, OperationStatus status) => Operation(
  id: id,
  name: 'Opération $id',
  type: OperationType.emergency,
  status: status,
  startAt: DateTime(2026, 8, 1),
  scopeRefs: const [
    OperationalScopeRef(kind: OperationalScopeKind.territory, id: 'gironde'),
  ],
  createdBy: 'admin',
  createdAt: DateTime(2026, 8, 1),
  updatedBy: 'admin',
  updatedAt: DateTime(2026, 8, 1),
  schemaVersion: 1,
);

Mobilization _mobilization(String id, {String? operationId}) => Mobilization(
  id: id,
  territoryId: 'gironde',
  name: id,
  subtitle: 'Recette',
  contextType: MobilizationContextType.other,
  status: MobilizationStatus.active,
  createdBy: 'admin',
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
  schemaVersion: 2,
  operationId: operationId,
);

CoordinationNeed _mission(
  String id,
  String mobilizationId,
  ResponsePlace location,
) => CoordinationNeed(
  id: id,
  mobilizationId: mobilizationId,
  locationId: location.id,
  place: location.name,
  group: location.group,
  date: 'demain',
  time: '12:00 — 16:00',
  requiredPhysiotherapists: 1,
  registeredPhysiotherapists: 0,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  equipment: const [],
);

class _OperationRepository implements OperationReadRepository {
  _OperationRepository(this.operations);
  final List<Operation> operations;

  @override
  Stream<Operation?> watchOperation(String operationId) => Stream.value(
    operations.where((item) => item.id == operationId).firstOrNull,
  );

  @override
  Stream<List<Operation>> watchOperations({Set<OperationStatus>? statuses}) =>
      Stream.value(
        statuses == null
            ? operations
            : operations
                  .where((item) => statuses.contains(item.status))
                  .toList(growable: false),
      );
}

class _PlatformRepository implements PlatformReadRepository {
  _PlatformRepository(this.mobilizations);
  final List<Mobilization> mobilizations;
  final territory = Territory(
    id: 'gironde',
    name: 'Gironde',
    code: '33',
    active: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  @override
  Stream<Mobilization?> watchActiveMobilization() => Stream.value(
    mobilizations
        .where((item) => item.status == MobilizationStatus.active)
        .firstOrNull,
  );

  @override
  Stream<List<Mobilization>> watchMobilizations({
    String? territoryId,
    bool includeInactive = false,
  }) => Stream.value(mobilizations);

  @override
  Stream<String?> watchPlatformConfig() => Stream.value(null);

  @override
  Stream<List<Territory>> watchTerritories() => Stream.value([territory]);
}

class _AccessibleMobilizations implements AccessibleMobilizationsProvider {
  const _AccessibleMobilizations(this.values);
  final List<Mobilization> values;
  @override
  Stream<List<Mobilization>> watchAccessibleMobilizations() =>
      Stream.value(values);
}

class _MultiReadRepository
    implements MultiMobilizationCoordinationReadRepository {
  _MultiReadRepository(this.byMobilization);
  final Map<String, List<CoordinationNeed>> byMobilization;
  final List<Set<String>> requested = [];

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> ids,
  ) {
    requested.add(Set.of(ids));
    return Stream.value([
      for (final id in ids) ...byMobilization[id] ?? const [],
    ]);
  }

  @override
  Stream<List<CoordinationNeed>> watchAllActiveMissions() =>
      Stream.value(byMobilization.values.expand((items) => items).toList());

  @override
  Stream<List<CoordinationNeed>> watchMissionsForLocations(Set<String> ids) =>
      watchAllActiveMissions();
}

class _MultiMockRepository extends MockCoordinationRepository
    implements MultiMobilizationCoordinationReadRepository {
  _MultiMockRepository({
    required this.all,
    this.byLocations = const [],
    super.initialLocations,
    ResponsibleAccess? access,
  }) : _access = access,
       super(initialMissions: const [], responsibleAccess: access);

  final List<CoordinationNeed> all;
  final List<CoordinationNeed> byLocations;
  final ResponsibleAccess? _access;
  int allCalls = 0;
  final List<Set<String>> locationRequests = [];

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() =>
      Stream.multi((controller) => controller.add(_access));

  @override
  Stream<List<CoordinationNeed>> watchAllActiveMissions() {
    allCalls++;
    return Stream.value(all);
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForLocations(Set<String> ids) {
    locationRequests.add(Set.of(ids));
    return Stream.value(byLocations);
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> ids,
  ) => Stream.value(
    all.where((item) => ids.contains(item.mobilizationId)).toList(),
  );
}

class _ContextProvider implements OperationalContextProvider {
  @override
  Stream<OperationalMissionContext?> watchForMobilization(String id) =>
      Stream.value(
        OperationalMissionContext(
          mobilizationId: id,
          mobilizationName: id,
          operationId: 'op-active',
          operationName: 'Opération op-active',
          operationType: OperationType.emergency,
        ),
      );
}

class _AdministrationService extends NoPlatformAdministrationService {
  @override
  bool get isAvailable => true;
}
