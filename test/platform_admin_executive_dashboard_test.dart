import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/executive_dashboard_snapshot.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/operational_scope.dart';
import 'package:interface_incendies_gironde/models/platform_administrator_access.dart';
import 'package:interface_incendies_gironde/models/territory.dart';
import 'package:interface_incendies_gironde/models/user_display_identity.dart';
import 'package:interface_incendies_gironde/platform_admin/operation_coordinator_view_data.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/operation_coordinator_read_repository.dart';
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
    expect(find.text('Incendies Gironde'), findsOneWidget);
    expect(find.text('Gironde · 33'), findsOneWidget);

    await _scrollTo(
      tester,
      find.byKey(const Key('operation-detail-situation')),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('operation-detail-mobilizations')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('operation-detail-missions')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.text('100 %'), findsOneWidget);
    expect(find.text('Situation couverte'), findsOneWidget);

    await _scrollTo(
      tester,
      find.byKey(const Key('operation-coordinator-section')),
    );
    expect(find.text('Non nommé'), findsOneWidget);

    await _scrollTo(tester, find.byKey(const Key('operation-future-journeys')));
    expect(find.byKey(const Key('future-view-as-coordinator')), findsOneWidget);
    expect(find.byKey(const Key('future-view-as-responsible')), findsOneWidget);
    expect(
      find.byKey(const Key('future-view-as-professional')),
      findsOneWidget,
    );

    final mobilization = find.byKey(
      const Key('operation-mobilization-mob-sud'),
    );
    await _scrollTo(tester, mobilization);
    expect(tester.getSize(mobilization).height, greaterThanOrEqualTo(44));
    await tester.tap(mobilization);
    await tester.pumpAndSettle();
    expect(find.text('Gestion · Mobilisation mob-sud'), findsOneWidget);
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

  testWidgets('la fiche affiche un Coordinateur unique consolidé', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      _Scenario.one(),
      operationCoordinatorDataSource:
          RepositoryOperationCoordinatorViewDataSource(
            repository: _CoordinatorRepository([
              _coordinatorAssignment('mob-sud', 'coord-1'),
            ]),
          ),
    );

    await _openPriorityOperation(tester, 'op-incendies');
    await _scrollTo(
      tester,
      find.byKey(const Key('operation-coordinator-section')),
    );

    expect(find.text('Coordinateur unique'), findsOneWidget);
    expect(find.text('Camille Martin'), findsOneWidget);
    expect(find.text('Identifiant · coord-1'), findsOneWidget);
    expect(find.text('1 mobilisation couverte'), findsOneWidget);
    expect(find.text('Gérer le coordinateur'), findsNothing);
  });

  testWidgets('la fiche détaille les affectations divergentes', (tester) async {
    final scenario = _Scenario(
      operations: [_operation('op-incendies', OperationStatus.active)],
      mobilizations: [
        _mobilization('mob-sud', 'op-incendies'),
        _mobilization('mob-nord', 'op-incendies'),
        _mobilization('mob-ouest', 'op-incendies'),
      ],
      missions: const [],
    );
    await _pumpDashboard(
      tester,
      scenario,
      operationCoordinatorDataSource:
          RepositoryOperationCoordinatorViewDataSource(
            repository: _CoordinatorRepository([
              _coordinatorAssignment('mob-sud', 'coord-1'),
              _coordinatorAssignment('mob-nord', 'coord-2'),
            ]),
          ),
    );

    await _openPriorityOperation(tester, 'op-incendies');
    await _scrollTo(
      tester,
      find.byKey(const Key('operation-coordinator-section')),
    );

    expect(find.text('Affectations divergentes'), findsOneWidget);
    expect(find.text('Camille Martin'), findsOneWidget);
    expect(find.text('Noah Bernard'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('operation-coordinator-coord-1')),
        matching: find.text('Mobilisation mob-sud'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('operation-coordinator-coord-2')),
        matching: find.text('Mobilisation mob-nord'),
      ),
      findsOneWidget,
    );
    expect(find.text('Sans Coordinateur'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('operation-coordinator-unassigned')),
        matching: find.text('Mobilisation mob-ouest'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('l’Administrateur nomme le Coordinateur principal', (
    tester,
  ) async {
    final service = _RecordingAdministrationService();
    await _pumpDashboard(
      tester,
      _Scenario.one(),
      administrationRepository: _AdministrationRepository([
        _activeCoordinator('coord-1', 'Camille Martin'),
      ]),
      administrationService: service,
    );

    await _openPriorityOperation(tester, 'op-incendies');
    await _selectOperationCoordinator(tester, 'Camille Martin');

    expect(service.operationCoordinatorCalls, [
      (operationId: 'op-incendies', uid: 'coord-1'),
    ]);
    expect(find.text('Coordinateur principal nommé.'), findsOneWidget);
  });

  testWidgets(
    'le remplacement avec une mobilisation active exige confirmation',
    (tester) async {
      final service = _RecordingAdministrationService();
      final scenario = _Scenario(
        operations: [
          _operation(
            'op-incendies',
            OperationStatus.active,
            coordinatorUid: 'coord-1',
          ),
        ],
        mobilizations: [_mobilization('mob-sud', 'op-incendies')],
        missions: const [],
      );
      await _pumpDashboard(
        tester,
        scenario,
        administrationRepository: _AdministrationRepository([
          _activeCoordinator('coord-1', 'Camille Martin'),
          _activeCoordinator('coord-2', 'Noah Bernard'),
        ]),
        administrationService: service,
        operationCoordinatorDataSource:
            RepositoryOperationCoordinatorViewDataSource(
              repository: _CoordinatorRepository([
                _coordinatorAssignment('mob-sud', 'coord-1'),
              ]),
            ),
      );

      await _openPriorityOperation(tester, 'op-incendies');
      await _selectOperationCoordinator(
        tester,
        'Noah Bernard',
        confirmReplacement: false,
      );

      expect(
        find.text('Remplacer le Coordinateur principal ?'),
        findsOneWidget,
      );
      expect(service.operationCoordinatorCalls, isEmpty);
      await tester.tap(
        find.byKey(const Key('confirm-operation-coordinator-replacement')),
      );
      await tester.pumpAndSettle();

      expect(service.operationCoordinatorCalls, [
        (operationId: 'op-incendies', uid: 'coord-2'),
      ]);
      expect(find.text('Coordinateur principal remplacé.'), findsOneWidget);
    },
  );

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

  testWidgets('la fiche reste mono-colonne et tactile à 320 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scenario = _Scenario.one();
    final platform = _PlatformRepository(scenario.mobilizations);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.6),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: PlatformOperationDetailScreen(
          operationId: 'op-incendies',
          operationRepository: _OperationRepository(scenario.operations),
          platformRepository: platform,
          mobilizationProvider: CurrentMobilizationProvider(
            repository: platform,
          ),
          administrationRepository:
              const NoPlatformAdministrationReadRepository(),
          administrationService: _AdministrationService(),
          missionRepository: _MissionRepository(scenario.missions),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(const Key('edit-platform-operation')));
    expect(
      tester.getSize(find.byKey(const Key('edit-platform-operation'))).height,
      greaterThanOrEqualTo(44),
    );

    final mobilizations = find.byKey(
      const Key('operation-detail-mobilizations'),
    );
    final missions = find.byKey(const Key('operation-detail-missions'));
    await _scrollTo(tester, missions);
    expect(tester.getTopLeft(missions).dx, tester.getTopLeft(mobilizations).dx);
    expect(
      tester.getTopLeft(missions).dy,
      greaterThan(tester.getTopLeft(mobilizations).dy),
    );

    await _scrollTo(
      tester,
      find.byKey(const Key('future-view-as-professional')),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('future-view-as-professional')))
          .height,
      greaterThanOrEqualTo(44),
    );
    expect(
      Theme.of(
        tester.element(find.text('Situation de l’opération')),
      ).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

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

Future<void> _openPriorityOperation(
  WidgetTester tester,
  String operationId,
) async {
  final target = find.byKey(Key('executive-priority-$operationId'));
  await _scrollTo(tester, target);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _selectOperationCoordinator(
  WidgetTester tester,
  String displayName, {
  bool confirmReplacement = true,
}) async {
  final action = find.byKey(const Key('manage-operation-coordinator'));
  await _scrollTo(tester, action);
  await tester.tap(action);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('operation-coordinator-select')));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(displayName).last);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const Key('confirm-operation-coordinator-selection')),
  );
  await tester.pumpAndSettle();
  if (confirmReplacement &&
      find
          .byKey(const Key('confirm-operation-coordinator-replacement'))
          .evaluate()
          .isNotEmpty) {
    await tester.tap(
      find.byKey(const Key('confirm-operation-coordinator-replacement')),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  _Scenario scenario, {
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  ThemeMode themeMode = ThemeMode.light,
  bool disableAnimations = false,
  PlatformAdministrationReadRepository administrationRepository =
      const NoPlatformAdministrationReadRepository(),
  PlatformAdministrationService administrationService =
      const _AdministrationService(),
  OperationCoordinatorViewDataSource operationCoordinatorDataSource =
      const NoOperationCoordinatorViewDataSource(),
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
              administrationRepository: administrationRepository,
              administrationService: administrationService,
              missionRepository: _MissionRepository(scenario.missions),
              operationCoordinatorDataSource: operationCoordinatorDataSource,
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

Operation _operation(
  String id,
  OperationStatus status, {
  String? coordinatorUid,
}) => Operation(
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
  coordinatorUid: coordinatorUid,
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
  const _AdministrationService();

  @override
  bool get isAvailable => true;
}

class _RecordingAdministrationService extends NoPlatformAdministrationService {
  final operationCoordinatorCalls = <({String operationId, String uid})>[];

  @override
  bool get isAvailable => true;

  @override
  Future<void> setOperationCoordinator({
    required String operationId,
    required String uid,
  }) async {
    operationCoordinatorCalls.add((operationId: operationId, uid: uid));
  }
}

class _AdministrationRepository extends NoPlatformAdministrationReadRepository {
  const _AdministrationRepository(this.coordinators);

  final List<ActivePlatformCoordinator> coordinators;

  @override
  Stream<List<ActivePlatformCoordinator>> watchActiveCoordinators() =>
      Stream.value(coordinators);
}

ActivePlatformCoordinator _activeCoordinator(String uid, String displayName) =>
    ActivePlatformCoordinator(
      uid: uid,
      identity: UserDisplayIdentity(
        uid: uid,
        displayName: displayName,
        professionLabel: 'Coordinateur',
      ),
    );

MobilizationCoordinatorAssignment _coordinatorAssignment(
  String mobilizationId,
  String uid,
) => MobilizationCoordinatorAssignment(
  id: '${mobilizationId}_$uid',
  uid: uid,
  mobilizationId: mobilizationId,
  active: true,
  identity: UserDisplayIdentity(
    uid: uid,
    displayName: uid == 'coord-1' ? 'Camille Martin' : 'Noah Bernard',
    professionLabel: 'Coordinateur',
  ),
);

class _CoordinatorRepository implements OperationCoordinatorReadRepository {
  const _CoordinatorRepository(this.assignments);

  final List<MobilizationCoordinatorAssignment> assignments;

  @override
  Stream<List<MobilizationCoordinatorAssignment>>
  watchCoordinatorsForMobilizations(Set<String> mobilizationIds) =>
      Stream.value(
        assignments
            .where(
              (assignment) =>
                  mobilizationIds.contains(assignment.mobilizationId),
            )
            .toList(growable: false),
      );
}
