import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/executive_dashboard_snapshot.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/operational_scope.dart';
import 'package:interface_incendies_gironde/models/territory.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/operation_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_administration_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_read_repository.dart';
import 'package:interface_incendies_gironde/screens/platform_admin_operations_screen.dart';
import 'package:interface_incendies_gironde/services/current_mobilization_provider.dart';
import 'package:interface_incendies_gironde/services/platform_administration_service.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';

void main() {
  group('ExecutiveDashboardSnapshot', () {
    test('calcule les six indicateurs et la couverture multi-opérations', () {
      final operations = [
        _operation('incendies', OperationStatus.active),
        _operation('canicule', OperationStatus.active),
        _operation('festival', OperationStatus.planned),
      ];
      final mobilizations = [
        _mobilization('sud', 'incendies'),
        _mobilization('bordeaux', 'incendies'),
        _mobilization('chaleur', 'canicule'),
      ];
      final snapshot = ExecutiveDashboardSnapshot(
        operations: operations,
        mobilizations: mobilizations,
        missions: [
          _mission('m1', 'sud', location: 'langon', required: 2, registered: 0),
          _mission(
            'm2',
            'bordeaux',
            location: 'bordeaux',
            required: 2,
            registered: 1,
          ),
          _mission(
            'm3',
            'chaleur',
            location: 'langon',
            required: 1,
            registered: 1,
          ),
        ],
      );

      expect(snapshot.activeOperationCount, 2);
      expect(snapshot.activeMobilizationCount, 3);
      expect(snapshot.activeMissionCount, 3);
      expect(snapshot.criticalMissionCount, 1);
      expect(snapshot.mobilizedProfessionalCount, 2);
      expect(snapshot.establishmentCount, 2);
      expect(snapshot.coverage, .4);
      expect(snapshot.state, ExecutivePlatformState.watch);
    });

    test('priorise les critiques et limite les actions à trois', () {
      final operations = List.generate(
        4,
        (index) => _operation('op-$index', OperationStatus.active),
      );
      final mobilizations = List.generate(
        4,
        (index) => _mobilization('mob-$index', 'op-$index'),
      );
      final snapshot = ExecutiveDashboardSnapshot(
        operations: operations,
        mobilizations: mobilizations,
        missions: [
          _mission('m0', 'mob-0', required: 1, registered: 1),
          _mission('m1', 'mob-1', required: 1, registered: 0),
          _mission('m2', 'mob-2', required: 2, registered: 1),
          _mission('m3', 'mob-3', required: 1, registered: 1),
        ],
      );

      expect(snapshot.priorityOperations, hasLength(3));
      expect(snapshot.priorityOperations.first.operation.id, 'op-1');
    });

    test('une mission critique interdit un état stable sans opération', () {
      final snapshot = ExecutiveDashboardSnapshot(
        operations: const [],
        mobilizations: const [],
        missions: [
          _mission(
            'legacy-critical',
            'legacy-mobilization',
            required: 1,
            registered: 0,
          ),
        ],
      );

      expect(snapshot.criticalMissionCount, 1);
      expect(snapshot.coverage, 0);
      expect(snapshot.state, ExecutivePlatformState.watch);
      expect(snapshot.state, isNot(ExecutivePlatformState.stable));
    });
  });

  testWidgets('zéro opération reste calme, compact et explicite', (
    tester,
  ) async {
    await _pumpDashboard(tester, const _Scenario.empty());

    expect(find.text('Plateforme stable'), findsOneWidget);
    expect(find.text('Aucune opération active pour le moment'), findsOneWidget);
    expect(find.text('Nouvelle opération'), findsOneWidget);
    await _scrollTo(tester, find.byKey(const Key('executive-kpi-grid')));
    expect(find.byKey(const Key('executive-kpi-grid')), findsOneWidget);
    await _scrollTo(tester, find.text('Aucune action prioritaire.'));
    expect(find.text('Aucune action prioritaire.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Aucune opération'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Aucune opération'), findsOneWidget);
    expect(find.byKey(const Key('legacy-mobilizations')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('une opération couverte produit une situation stable', (
    tester,
  ) async {
    await _pumpDashboard(tester, _Scenario.one());

    expect(find.text('Plateforme stable'), findsOneWidget);
    expect(find.text('Aucune mission critique détectée'), findsOneWidget);
    expect(find.text('Mis à jour il y a 5 min'), findsOneWidget);
    await _scrollTo(tester, find.byKey(const Key('executive-kpi-critical')));
    expect(find.bySemanticsLabel('1, opérations actives'), findsOneWidget);
    expect(find.bySemanticsLabel('0, missions critiques'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Couverture globale 100 pour cent, 1 établissement concerné',
      ),
      findsOneWidget,
    );
    await _scrollTo(
      tester,
      find.byKey(const Key('executive-priority-op-incendies')),
    );
    expect(
      find.byKey(const Key('executive-priority-op-incendies')),
      findsOneWidget,
    );
    expect(find.text('Voir l’opération'), findsOneWidget);
    await tester.tap(find.byKey(const Key('executive-priority-op-incendies')));
    await tester.pumpAndSettle();
    expect(find.text('Situation de l’opération'), findsOneWidget);
  });

  testWidgets('les KPI sont ordonnés par décision et ont une hauteur commune', (
    tester,
  ) async {
    await _pumpDashboard(tester, _Scenario.three());

    await _scrollTo(tester, find.byKey(const Key('executive-kpi-critical')));
    final keys = [
      const Key('executive-kpi-critical'),
      const Key('executive-kpi-coverage'),
      const Key('executive-kpi-missions'),
      const Key('executive-kpi-professionals'),
      const Key('executive-kpi-mobilizations'),
      const Key('executive-kpi-operations'),
    ];
    final rects = [for (final key in keys) tester.getRect(find.byKey(key))];
    expect(rects[0].left, lessThan(rects[1].left));
    expect(rects[2].top, greaterThan(rects[0].top));
    expect(rects[2].left, lessThan(rects[3].left));
    expect(rects[4].top, greaterThan(rects[2].top));
    expect(rects.map((rect) => rect.height).toSet(), hasLength(1));
  });

  testWidgets('trois opérations sont lisibles et enrichies sans surcharge', (
    tester,
  ) async {
    await _pumpDashboard(tester, _Scenario.three());

    expect(find.text('Sous surveillance'), findsOneWidget);
    expect(find.text('1 mission critique à suivre'), findsOneWidget);
    await _scrollTo(tester, find.text('ACTION URGENTE'));
    expect(find.text('ACTION URGENTE'), findsOneWidget);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('all-platform-operations')),
      300,
      scrollable: scrollable,
    );
    expect(find.text('Situation opérationnelle'), findsOneWidget);
    for (final id in const ['op-incendies', 'op-canicule', 'op-festival']) {
      final card = find.byKey(Key('platform-operation-$id'));
      await tester.scrollUntilVisible(card, 250, scrollable: scrollable);
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('missions')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('critiques')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('couverture')),
        findsOneWidget,
      );
    }
  });

  testWidgets('une plateforme critique expose au plus trois actions', (
    tester,
  ) async {
    await _pumpDashboard(tester, _Scenario.critical());

    expect(find.text('Situation critique'), findsOneWidget);
    expect(
      find.text('3 missions critiques nécessitent une action'),
      findsOneWidget,
    );
    await _scrollTo(tester, find.byKey(const Key('executive-kpi-critical')));
    expect(find.bySemanticsLabel('3, missions critiques'), findsOneWidget);
    for (final id in const ['op-1', 'op-2', 'op-3']) {
      final priority = find.byKey(Key('executive-priority-$id'));
      await _scrollTo(tester, priority);
      expect(priority, findsOneWidget);
      expect(find.text('Voir l’opération'), findsWidgets);
    }
    expect(find.byKey(const Key('executive-priority-op-4')), findsNothing);
  });

  testWidgets('une mission legacy critique ne peut jamais afficher stable', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      _Scenario(
        operations: const [],
        mobilizations: const [],
        missions: [
          _mission(
            'legacy-critical',
            'legacy-mobilization',
            required: 1,
            registered: 0,
          ),
        ],
      ),
    );

    expect(find.text('Sous surveillance'), findsOneWidget);
    expect(find.text('1 mission critique à suivre'), findsOneWidget);
    expect(find.text('Plateforme stable'), findsNothing);
  });

  testWidgets(
    '320 px, Dynamic Type, VoiceOver, Dark Mode et Reduce Motion restent sûrs',
    (tester) async {
      await _pumpDashboard(
        tester,
        _Scenario.critical(),
        size: const Size(320, 844),
        textScaler: const TextScaler.linear(2),
        themeMode: ThemeMode.dark,
        disableAnimations: true,
      );

      expect(
        tester
            .getSize(find.byKey(const Key('create-platform-operation')))
            .height,
        greaterThanOrEqualTo(44),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('executive-platform-state')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('executive-platform-state')))
            .label,
        startsWith('Situation critique. 3 missions critiques'),
      );
      expect(
        Theme.of(tester.element(find.text('Centre opérationnel'))).brightness,
        Brightness.dark,
      );
      for (var index = 0; index < 5; index++) {
        await tester.drag(
          find.byKey(const PageStorageKey('platform-admin-operations')),
          const Offset(0, -500),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  final goldenScenarios = <String, _Scenario>{
    'executive_dashboard_zero': const _Scenario.empty(),
    'executive_dashboard_one': _Scenario.one(),
    'executive_dashboard_three': _Scenario.three(),
    'executive_dashboard_critical': _Scenario.critical(),
    'executive_dashboard_empty': _Scenario.operationalEmpty(),
  };

  for (final entry in goldenScenarios.entries) {
    testWidgets('golden ${entry.key}', (tester) async {
      await _pumpDashboard(
        tester,
        entry.value,
        themeMode: entry.key.endsWith('empty')
            ? ThemeMode.dark
            : ThemeMode.light,
      );
      await expectLater(
        find.byKey(const Key('executive-dashboard-golden-root')),
        matchesGoldenFile('../screenshots/${entry.key}.png'),
      );
    });
  }
}

Future<void> _scrollTo(WidgetTester tester, Finder target) => tester
    .scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);

Future<void> _pumpDashboard(
  WidgetTester tester,
  _Scenario scenario, {
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  ThemeMode themeMode = ThemeMode.light,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final platform = _PlatformRepository(scenario.mobilizations);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler,
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const Key('executive-dashboard-golden-root'),
        child: Scaffold(
          body: SafeArea(
            child: PlatformAdminOperationsScreen(
              operationRepository: _OperationRepository(scenario.operations),
              platformRepository: platform,
              mobilizationProvider: CurrentMobilizationProvider(
                repository: platform,
              ),
              administrationRepository:
                  const NoPlatformAdministrationReadRepository(),
              administrationService: _AdministrationService(),
              missionRepository: _MissionRepository(scenario.missions),
              referenceTime: DateTime(2026, 8, 16, 22, 46),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Scenario {
  const _Scenario({
    required this.operations,
    required this.mobilizations,
    required this.missions,
  });

  const _Scenario.empty()
    : operations = const [],
      mobilizations = const [],
      missions = const [];

  factory _Scenario.one() => _Scenario(
    operations: [_operation('op-incendies', OperationStatus.active)],
    mobilizations: [_mobilization('mob-sud', 'op-incendies')],
    missions: [
      _mission(
        'mission-langon',
        'mob-sud',
        location: 'langon',
        required: 1,
        registered: 1,
      ),
    ],
  );

  factory _Scenario.three() => _Scenario(
    operations: [
      _operation('op-incendies', OperationStatus.active),
      _operation('op-canicule', OperationStatus.active),
      _operation('op-festival', OperationStatus.planned),
    ],
    mobilizations: [
      _mobilization('mob-sud', 'op-incendies'),
      _mobilization('mob-canicule', 'op-canicule'),
      _mobilization('mob-festival', 'op-festival'),
    ],
    missions: [
      _mission('mission-1', 'mob-sud', required: 2, registered: 0),
      _mission('mission-2', 'mob-canicule', required: 2, registered: 1),
      _mission('mission-3', 'mob-festival', required: 1, registered: 1),
    ],
  );

  factory _Scenario.critical() => _Scenario(
    operations: List.generate(
      4,
      (index) => _operation('op-${index + 1}', OperationStatus.active),
    ),
    mobilizations: List.generate(
      4,
      (index) => _mobilization('mob-${index + 1}', 'op-${index + 1}'),
    ),
    missions: [
      _mission('mission-1', 'mob-1', required: 2, registered: 0),
      _mission('mission-2', 'mob-2', required: 2, registered: 0),
      _mission('mission-3', 'mob-3', required: 2, registered: 0),
      _mission('mission-4', 'mob-4', required: 1, registered: 1),
    ],
  );

  factory _Scenario.operationalEmpty() => _Scenario(
    operations: [_operation('op-festival', OperationStatus.planned)],
    mobilizations: const [],
    missions: const [],
  );

  final List<Operation> operations;
  final List<Mobilization> mobilizations;
  final List<CoordinationNeed> missions;
}

Operation _operation(String id, OperationStatus status) => Operation(
  id: id,
  name: switch (id) {
    'op-incendies' => 'Incendies Gironde',
    'op-canicule' => 'Canicule Nouvelle-Aquitaine',
    'op-festival' => 'Festival',
    _ => 'Opération ${id.substring(3)}',
  },
  type: status == OperationStatus.planned
      ? OperationType.event
      : OperationType.emergency,
  status: status,
  startAt: DateTime(2026, 8, 16),
  scopeRefs: const [
    OperationalScopeRef(kind: OperationalScopeKind.territory, id: 'gironde'),
  ],
  createdBy: 'admin-recipe',
  createdAt: DateTime(2026, 8, 16, 20),
  updatedBy: 'admin-recipe',
  updatedAt: DateTime(2026, 8, 16, 22, 41),
  schemaVersion: 1,
);

Mobilization _mobilization(String id, String operationId) => Mobilization(
  id: id,
  territoryId: 'gironde',
  name: 'Mobilisation $id',
  subtitle: 'Recette',
  contextType: MobilizationContextType.other,
  status: MobilizationStatus.active,
  createdBy: 'admin-recipe',
  createdAt: DateTime(2026, 8, 16, 20),
  updatedAt: DateTime(2026, 8, 16, 22, 41),
  schemaVersion: 2,
  operationId: operationId,
);

CoordinationNeed _mission(
  String id,
  String mobilizationId, {
  String location = 'langon',
  required int required,
  required int registered,
}) => CoordinationNeed(
  id: id,
  mobilizationId: mobilizationId,
  locationId: location,
  place: location == 'langon' ? 'Centre de Langon' : 'Centre de Bordeaux',
  group: TerritorialGroup.southGironde,
  date: '17 août',
  time: '12:00 — 16:00',
  requiredPhysiotherapists: required,
  registeredPhysiotherapists: registered,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  equipment: const [],
  updatedAt: DateTime(2026, 8, 16, 22, 41),
);

class _OperationRepository implements OperationReadRepository {
  const _OperationRepository(this.operations);

  final List<Operation> operations;

  @override
  Stream<Operation?> watchOperation(String operationId) => Stream.value(
    operations.where((operation) => operation.id == operationId).firstOrNull,
  );

  @override
  Stream<List<Operation>> watchOperations({Set<OperationStatus>? statuses}) =>
      Stream.value(
        statuses == null
            ? operations
            : operations
                  .where((operation) => statuses.contains(operation.status))
                  .toList(growable: false),
      );
}

class _PlatformRepository implements PlatformReadRepository {
  const _PlatformRepository(this.mobilizations);

  final List<Mobilization> mobilizations;

  @override
  Stream<Mobilization?> watchActiveMobilization() => Stream.value(
    mobilizations
        .where(
          (mobilization) => mobilization.status == MobilizationStatus.active,
        )
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
  Stream<List<Territory>> watchTerritories() => Stream.value([
    Territory(
      id: 'gironde',
      name: 'Gironde',
      code: '33',
      active: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ]);
}

class _MissionRepository
    implements MultiMobilizationCoordinationReadRepository {
  const _MissionRepository(this.missions);

  final List<CoordinationNeed> missions;

  @override
  Stream<List<CoordinationNeed>> watchAllActiveMissions() =>
      Stream.value(missions);

  @override
  Stream<List<CoordinationNeed>> watchMissionsForLocations(Set<String> ids) =>
      Stream.value(
        missions
            .where((mission) => ids.contains(mission.locationId))
            .toList(growable: false),
      );

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> ids,
  ) => Stream.value(
    missions
        .where((mission) => ids.contains(mission.mobilizationId))
        .toList(growable: false),
  );
}

class _AdministrationService extends NoPlatformAdministrationService {
  @override
  bool get isAvailable => true;
}
