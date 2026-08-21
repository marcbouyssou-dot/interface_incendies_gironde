import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/operational_scope.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/models/territory.dart';
import 'package:interface_incendies_gironde/platform_admin/platform_admin_history_view_data.dart';
import 'package:interface_incendies_gironde/platform_admin/platform_admin_statistics_view_data.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/operation_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_admin_history_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_read_repository.dart';
import 'package:interface_incendies_gironde/screens/platform_admin_history_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/platform_admin_bottom_navigation.dart';

void main() {
  group('PlatformAdminHistoryViewData', () {
    test('exclut les actives et trie les bilans les plus récents', () {
      final history = _history();

      expect(history.operations.map((entry) => entry.operation.id), [
        'operation-archived',
        'operation-completed',
        'operation-old',
      ]);
      expect(
        history.operations.map((entry) => entry.operation.id),
        isNot(contains('operation-active')),
      );
      expect(history.operations.first.mobilizationCount, 1);
      expect(history.operations.first.missionCount, 1);
      expect(history.operations.first.mobilizedProfessionalCount, 1);
      expect(history.operations.first.coverage, .5);
    });

    test('recherche par nom, territoire et type', () {
      final history = _history();
      final now = DateTime(2026, 8, 21);

      expect(
        history
            .filtered(
              const PlatformAdminHistoryFilter(search: 'tempête'),
              now: now,
            )
            .single
            .operation
            .id,
        'operation-archived',
      );
      expect(
        history
            .filtered(
              const PlatformAdminHistoryFilter(search: 'landes'),
              now: now,
            )
            .single
            .operation
            .id,
        'operation-completed',
      );
      expect(
        history
            .filtered(
              const PlatformAdminHistoryFilter(search: 'exercice'),
              now: now,
            )
            .single
            .operation
            .id,
        'operation-old',
      );
    });

    test('filtre période, territoire, type et statut final', () {
      final history = _history();
      final now = DateTime(2026, 8, 21);

      expect(
        history.filtered(
          const PlatformAdminHistoryFilter(
            period: PlatformHistoryPeriod.last30Days,
          ),
          now: now,
        ),
        hasLength(2),
      );
      expect(
        history
            .filtered(
              const PlatformAdminHistoryFilter(territoryId: 'landes'),
              now: now,
            )
            .single
            .operation
            .id,
        'operation-completed',
      );
      expect(
        history
            .filtered(
              const PlatformAdminHistoryFilter(type: OperationType.exercise),
              now: now,
            )
            .single
            .operation
            .id,
        'operation-old',
      );
      expect(
        history
            .filtered(
              const PlatformAdminHistoryFilter(
                status: OperationStatus.archived,
              ),
              now: now,
            )
            .single
            .operation
            .id,
        'operation-archived',
      );
    });

    test(
      'charge toutes les mobilisations historiques en un flux borné',
      () async {
        final operations = _OperationRepository(_operations());
        final platform = _PlatformRepository(_mobilizations(), _territories());
        final missions = _MissionRepository(_missions());
        final source = RepositoryPlatformAdminHistoryDataSource(
          platformRepository: platform,
          operationRepository: operations,
          missionRepository: missions,
        );

        final history = await source.watchHistory().first;

        expect(history.operations, hasLength(3));
        expect(operations.watchAllCalls, 1);
        expect(platform.watchMobilizationsCalls, 1);
        expect(platform.watchTerritoriesCalls, 1);
        expect(missions.scopedCalls, 1);
        expect(missions.requestedMobilizationIds.single, {
          'mobilization-archived',
          'mobilization-completed',
          'mobilization-old',
        });
        expect(
          missions.requestedMobilizationIds.single,
          isNot(contains('mobilization-active')),
        );
        expect(missions.allActiveCalls, 0);
      },
    );
  });

  testWidgets('affiche, trie et recherche les opérations historiques', (
    tester,
  ) async {
    await _pumpHistory(tester);

    final archived = find.byKey(
      const Key('platform-history-operation-operation-archived'),
    );
    final completed = find.byKey(
      const Key('platform-history-operation-operation-completed'),
    );
    expect(archived, findsOneWidget);
    expect(
      find.byKey(const Key('platform-history-operation-operation-active')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const Key('platform-history-search')),
      'Landes',
    );
    await tester.pump();
    expect(completed, findsOneWidget);
    expect(archived, findsNothing);
    expect(find.text('1 opération'), findsOneWidget);
  });

  testWidgets('applique un filtre de période depuis la bottom sheet', (
    tester,
  ) async {
    await _pumpHistory(tester);

    await tester.tap(find.byKey(const Key('platform-history-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 derniers jours'));
    await tester.pump();

    final apply = find.byKey(const Key('platform-history-apply-filters'));
    expect(apply.hitTestable(), findsOneWidget);
    await tester.tap(apply);
    await tester.pumpAndSettle();

    expect(find.text('Filtres (1)'), findsOneWidget);
    expect(find.text('2 opérations'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-history-operation-operation-archived')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('platform-history-operation-operation-old')),
      findsNothing,
    );
  });

  testWidgets(
    'ouvre une fiche historique complète sans chronologie artificielle',
    (tester) async {
      await _pumpHistory(tester);

      await tester.tap(
        find.byKey(const Key('platform-history-operation-operation-archived')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlatformAdminHistoryDetailScreen), findsOneWidget);
      expect(find.text('Bilan d’opération'), findsOneWidget);
      expect(find.text('Tempête Gironde'), findsOneWidget);
      await _scrollTo(
        tester,
        find.byKey(const Key('platform-history-detail-coordinator')),
      );
      final coordinatorText = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('platform-history-detail-coordinator')),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
          .join(' ');
      expect(coordinatorText, contains('coordinator-archived'));
      await _scrollTo(
        tester,
        find.byKey(const Key('platform-history-final-statistics')),
      );
      expect(
        find.byKey(const Key('platform-history-final-statistics')),
        findsOneWidget,
      );
      await _scrollTo(
        tester,
        find.byKey(const Key('platform-history-mobilizations')),
      );
      expect(find.text('Mobilisation tempête'), findsOneWidget);
      await _scrollTo(
        tester,
        find.byKey(const Key('platform-history-establishments')),
      );
      expect(find.text('Centre Gironde'), findsOneWidget);
      await _scrollTo(
        tester,
        find.byKey(const Key('platform-history-professions')),
      );
      expect(find.text('Masseur-kinésithérapeute'), findsOneWidget);
      expect(find.textContaining('Chronologie'), findsNothing);
    },
  );

  testWidgets(
    'reste lisible à 320 px avec Dynamic Type, dark mode et reduced motion',
    (tester) async {
      await _pumpHistory(
        tester,
        size: const Size(320, 844),
        textScaler: const TextScaler.linear(2),
        themeMode: ThemeMode.dark,
        disableAnimations: true,
      );

      final scrollable = find.byKey(
        const PageStorageKey('platform-admin-history'),
      );
      final search = find.byKey(const Key('platform-history-search'));
      for (var index = 0; index < 3 && search.evaluate().isEmpty; index++) {
        await tester.drag(scrollable, const Offset(0, -240));
        await tester.pump();
      }
      expect(tester.getSize(search).height, greaterThanOrEqualTo(44));
      final card = find.byKey(
        const Key('platform-history-operation-operation-archived'),
      );
      await _scrollTo(tester, card);
      expect(tester.getSize(card).height, greaterThanOrEqualTo(44));
      expect(
        Theme.of(tester.element(find.text('Historique'))).brightness,
        Brightness.dark,
      );
      for (var index = 0; index < 4; index++) {
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('la navigation compacte conserve un accès direct Historique', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: PlatformAdminBottomNavigation(
            selectedIndex: 3,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Stats'), findsWidgets);
    final history = find.bySemanticsLabel('Historique');
    expect(history, findsWidgets);
    expect(tester.getSize(history.first).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder target) => tester
    .scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);

Future<void> _pumpHistory(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  ThemeMode themeMode = ThemeMode.light,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
      home: Scaffold(
        body: SafeArea(
          child: PlatformAdminHistoryScreen(
            dataSource: _HistorySource(_history()),
            referenceTime: DateTime(2026, 8, 21),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PlatformAdminHistoryViewData _history() =>
    PlatformAdminHistoryViewData.fromStatistics(
      PlatformAdminStatisticsViewData.fromData(
        operations: _operations(),
        mobilizations: _mobilizations(),
        missions: _missions(),
        territories: _territories(),
      ),
    );

List<Operation> _operations() => [
  _operation(
    'operation-active',
    'Opération active',
    OperationStatus.active,
    OperationType.emergency,
    'gironde',
    startAt: DateTime(2026, 8, 20),
    updatedAt: DateTime(2026, 8, 21),
  ),
  _operation(
    'operation-archived',
    'Tempête Gironde',
    OperationStatus.archived,
    OperationType.naturalDisaster,
    'gironde',
    startAt: DateTime(2026, 8, 15),
    endAt: DateTime(2026, 8, 18),
    updatedAt: DateTime(2026, 8, 20),
    coordinatorUid: 'coordinator-archived',
  ),
  _operation(
    'operation-completed',
    'Canicule Landes',
    OperationStatus.completed,
    OperationType.healthCrisis,
    'landes',
    startAt: DateTime(2026, 8, 10),
    endAt: DateTime(2026, 8, 19),
    updatedAt: DateTime(2026, 8, 19),
  ),
  _operation(
    'operation-old',
    'Exercice ancien',
    OperationStatus.completed,
    OperationType.exercise,
    'gironde',
    startAt: DateTime(2026, 4, 25),
    endAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
  ),
];

Operation _operation(
  String id,
  String name,
  OperationStatus status,
  OperationType type,
  String territoryId, {
  required DateTime startAt,
  DateTime? endAt,
  required DateTime updatedAt,
  String? coordinatorUid,
}) => Operation(
  id: id,
  name: name,
  type: type,
  status: status,
  startAt: startAt,
  endAt: endAt,
  coordinatorUid: coordinatorUid,
  scopeRefs: [
    OperationalScopeRef(kind: OperationalScopeKind.territory, id: territoryId),
  ],
  createdBy: 'admin',
  createdAt: startAt.subtract(const Duration(days: 1)),
  updatedBy: 'admin',
  updatedAt: updatedAt,
  schemaVersion: 1,
);

List<Mobilization> _mobilizations() => [
  _mobilization(
    'mobilization-active',
    'operation-active',
    'gironde',
    'Mobilisation active',
  ),
  _mobilization(
    'mobilization-archived',
    'operation-archived',
    'gironde',
    'Mobilisation tempête',
  ),
  _mobilization(
    'mobilization-completed',
    'operation-completed',
    'landes',
    'Mobilisation canicule',
  ),
  _mobilization(
    'mobilization-old',
    'operation-old',
    'gironde',
    'Mobilisation exercice',
  ),
];

Mobilization _mobilization(
  String id,
  String operationId,
  String territoryId,
  String name,
) => Mobilization(
  id: id,
  operationId: operationId,
  territoryId: territoryId,
  name: name,
  subtitle: territoryId,
  contextType: MobilizationContextType.other,
  status: operationId == 'operation-active'
      ? MobilizationStatus.active
      : MobilizationStatus.inactive,
  createdBy: 'admin',
  createdAt: DateTime(2026, 4, 1),
  updatedAt: DateTime(2026, 8, 20),
  schemaVersion: 2,
);

List<CoordinationNeed> _missions() => [
  _mission('mission-active', 'mobilization-active', 'Centre actif', 1, 0),
  _mission('mission-archived', 'mobilization-archived', 'Centre Gironde', 2, 1),
  _mission(
    'mission-completed',
    'mobilization-completed',
    'Centre Landes',
    1,
    1,
  ),
  _mission('mission-old', 'mobilization-old', 'Centre ancien', 1, 1),
];

CoordinationNeed _mission(
  String id,
  String mobilizationId,
  String place,
  int required,
  int registered,
) => CoordinationNeed(
  id: id,
  mobilizationId: mobilizationId,
  locationId: 'location-$id',
  place: place,
  group: TerritorialGroup.southGironde,
  date: 'Bilan',
  time: '08:00 — 12:00',
  requiredPhysiotherapists: required,
  registeredPhysiotherapists: registered,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  professionQuotas: ProfessionQuotas.fromMaps(
    requiredByProfession: {'physiotherapist': required},
    registeredByProfession: {'physiotherapist': registered},
  ),
  equipment: const [],
);

List<Territory> _territories() => [
  _territory('gironde', 'Gironde', '33'),
  _territory('landes', 'Landes', '40'),
];

Territory _territory(String id, String name, String code) => Territory(
  id: id,
  name: name,
  code: code,
  active: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _HistorySource implements PlatformAdminHistoryDataSource {
  const _HistorySource(this.data);

  final PlatformAdminHistoryViewData data;

  @override
  Stream<PlatformAdminHistoryViewData> watchHistory() => Stream.value(data);
}

class _OperationRepository implements OperationReadRepository {
  _OperationRepository(this.operations);

  final List<Operation> operations;
  int watchAllCalls = 0;

  @override
  Stream<Operation?> watchOperation(String operationId) => Stream.value(
    operations.where((operation) => operation.id == operationId).firstOrNull,
  );

  @override
  Stream<List<Operation>> watchOperations({Set<OperationStatus>? statuses}) {
    watchAllCalls++;
    return Stream.value(operations);
  }
}

class _PlatformRepository implements PlatformReadRepository {
  _PlatformRepository(this.mobilizations, this.territories);

  final List<Mobilization> mobilizations;
  final List<Territory> territories;
  int watchMobilizationsCalls = 0;
  int watchTerritoriesCalls = 0;

  @override
  Stream<Mobilization?> watchActiveMobilization() =>
      Stream.value(mobilizations.firstOrNull);

  @override
  Stream<List<Mobilization>> watchMobilizations({
    String? territoryId,
    bool includeInactive = false,
  }) {
    watchMobilizationsCalls++;
    return Stream.value(mobilizations);
  }

  @override
  Stream<String?> watchPlatformConfig() => Stream.value(null);

  @override
  Stream<List<Territory>> watchTerritories() {
    watchTerritoriesCalls++;
    return Stream.value(territories);
  }
}

class _MissionRepository
    implements MultiMobilizationCoordinationReadRepository {
  _MissionRepository(this.missions);

  final List<CoordinationNeed> missions;
  final List<Set<String>> requestedMobilizationIds = [];
  int scopedCalls = 0;
  int allActiveCalls = 0;

  @override
  Stream<List<CoordinationNeed>> watchAllActiveMissions() {
    allActiveCalls++;
    return Stream.value(missions);
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForLocations(Set<String> ids) =>
      Stream.value(const []);

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> ids,
  ) {
    scopedCalls++;
    requestedMobilizationIds.add(Set.of(ids));
    return Stream.value(
      missions
          .where((mission) => ids.contains(mission.mobilizationId))
          .toList(growable: false),
    );
  }
}
