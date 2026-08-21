import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/operational_scope.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/models/territory.dart';
import 'package:interface_incendies_gironde/platform_admin/platform_admin_statistics_view_data.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/operation_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_admin_statistics_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_read_repository.dart';
import 'package:interface_incendies_gironde/screens/platform_admin_statistics_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/platform_admin_bottom_navigation.dart';

void main() {
  group('PlatformAdminStatisticsViewData', () {
    test('agrège la plateforme, les professions et les territoires', () {
      final data = _viewData();

      expect(data.dashboard.activeOperationCount, 2);
      expect(data.dashboard.activeMobilizationCount, 2);
      expect(data.dashboard.activeMissionCount, 2);
      expect(data.dashboard.criticalMissionCount, 1);
      expect(data.dashboard.mobilizedProfessionalCount, 2);
      expect(data.dashboard.establishmentCount, 2);
      expect(data.dashboard.coverage, .5);
      expect(data.platform.remainingProfessionalCount, 2);
      expect(data.platform.mostTenseProfession?.shortLabel, 'PP');
      expect(
        data.platform.professions.map((profession) => profession.shortLabel),
        containsAll(['MK', 'PP']),
      );
      expect(
        data.platform.territories.map((territory) => territory.label),
        containsAll(['Gironde · 33', 'Landes · 40']),
      );
    });

    test('isole strictement chaque opération', () {
      final data = _viewData();
      final gironde = data.operationById('operation-gironde')!;
      final landes = data.operationById('operation-landes')!;

      expect(gironde.snapshot.missionCount, 1);
      expect(gironde.snapshot.mobilizations.single.id, 'mobilization-gironde');
      expect(gironde.snapshot.mobilizedProfessionalCount, 1);
      expect(gironde.remainingProfessionalCount, 2);
      expect(gironde.breakdown.establishments.single.label, 'Centre Gironde');
      expect(gironde.territoryLabels, ['Gironde · 33']);
      expect(gironde.coordinatorUid, 'coordinator-gironde');

      expect(landes.snapshot.missionCount, 1);
      expect(landes.snapshot.mobilizations.single.id, 'mobilization-landes');
      expect(landes.snapshot.mobilizedProfessionalCount, 1);
      expect(landes.remainingProfessionalCount, 0);
      expect(landes.breakdown.establishments.single.label, 'Centre Landes');
      expect(landes.territoryLabels, ['Landes · 40']);
      expect(
        landes.breakdown.establishments.map((item) => item.label),
        isNot(contains('Centre Gironde')),
      );
    });

    test('combine quatre lectures globales dans un flux UI unique', () async {
      final operations = _OperationRepository(_operations());
      final platform = _PlatformRepository(_mobilizations(), _territories());
      final missions = _MissionRepository(_missions());
      final source = RepositoryPlatformAdminStatisticsDataSource(
        platformRepository: platform,
        operationRepository: operations,
        missionRepository: missions,
      );

      final data = await source.watchStatistics().first;

      expect(data.operations, hasLength(2));
      expect(operations.watchAllCalls, 1);
      expect(platform.watchMobilizationsCalls, 1);
      expect(platform.watchTerritoriesCalls, 1);
      expect(missions.watchAllCalls, 1);
      expect(missions.scopedCalls, 0);
    });
  });

  testWidgets('affiche les statistiques plateforme et filtre une opération', (
    tester,
  ) async {
    await _pumpStatistics(tester);

    expect(find.text('Statistiques'), findsOneWidget);
    expect(find.text('Toutes les opérations'), findsOneWidget);
    expect(
      _metricText(tester, const Key('statistics-platform-operations')),
      contains('2'),
    );
    expect(
      _metricText(tester, const Key('statistics-platform-critical')),
      contains('1'),
    );
    expect(
      _metricText(tester, const Key('statistics-platform-coverage')),
      contains('50 %'),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opération Gironde').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('operation-statistics-operation-gironde')),
      findsOneWidget,
    );
    expect(find.text('Gironde · 33'), findsWidgets);
    expect(find.text('Landes · 40'), findsNothing);
    expect(find.text('Nommé · coordinator-gironde'), findsOneWidget);
    expect(
      _metricText(tester, const Key('statistics-operation-missions')),
      contains('1'),
    );
    expect(
      _metricText(tester, const Key('statistics-operation-remaining')),
      contains('2'),
    );
    await _scrollTo(tester, find.byKey(const Key('statistics-professions')));
    expect(
      find.byKey(const Key('statistics-profession-physiotherapist')),
      findsOneWidget,
    );
    await _scrollTo(tester, find.byKey(const Key('statistics-territories')));
    expect(find.text('Gironde · 33'), findsWidgets);
    expect(find.text('Landes · 40'), findsNothing);
  });

  testWidgets(
    'reste mono-colonne à 320 px avec Dynamic Type, dark mode et reduced motion',
    (tester) async {
      await _pumpStatistics(
        tester,
        size: const Size(320, 844),
        textScaler: const TextScaler.linear(2),
        themeMode: ThemeMode.dark,
        disableAnimations: true,
      );

      final scrollable = find.byKey(
        const PageStorageKey('platform-admin-statistics'),
      );
      final selector = find.byType(DropdownButtonFormField<String>);
      for (var index = 0; index < 3 && selector.evaluate().isEmpty; index++) {
        await tester.drag(scrollable, const Offset(0, -240));
        await tester.pump();
      }
      expect(tester.getSize(selector).height, greaterThanOrEqualTo(44));
      final operations = find.byKey(
        const Key('statistics-platform-operations'),
      );
      final mobilizations = find.byKey(
        const Key('statistics-platform-mobilizations'),
      );
      await _scrollTo(tester, operations);
      final operationLeft = tester.getTopLeft(operations).dx;
      final operationWidth = tester.getSize(operations).width;
      await _scrollTo(tester, mobilizations);
      expect(tester.getTopLeft(mobilizations).dx, operationLeft);
      expect(tester.getSize(mobilizations).width, operationWidth);
      expect(
        Theme.of(tester.element(find.text('Statistiques'))).brightness,
        Brightness.dark,
      );
      for (var index = 0; index < 5; index++) {
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('la navigation Statistiques reste tactile à 320 px', (
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
            selectedIndex: 2,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final statistics = find.bySemanticsLabel('Stats');
    expect(statistics, findsWidgets);
    expect(tester.getSize(statistics.first).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });
}

String _metricText(WidgetTester tester, Key key) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .map((text) => text.data ?? '')
    .join(' ');

Future<void> _scrollTo(WidgetTester tester, Finder target) => tester
    .scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);

Future<void> _pumpStatistics(
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
          child: PlatformAdminStatisticsScreen(
            dataSource: _StatisticsSource(_viewData()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PlatformAdminStatisticsViewData _viewData() =>
    PlatformAdminStatisticsViewData.fromData(
      operations: _operations(),
      mobilizations: _mobilizations(),
      missions: _missions(),
      territories: _territories(),
    );

List<Operation> _operations() => [
  _operation(
    'operation-gironde',
    'Opération Gironde',
    'gironde',
    coordinatorUid: 'coordinator-gironde',
  ),
  _operation('operation-landes', 'Opération Landes', 'landes'),
];

Operation _operation(
  String id,
  String name,
  String territoryId, {
  String? coordinatorUid,
}) => Operation(
  id: id,
  name: name,
  type: OperationType.emergency,
  status: OperationStatus.active,
  startAt: DateTime(2026, 8, 20),
  scopeRefs: [
    OperationalScopeRef(kind: OperationalScopeKind.territory, id: territoryId),
  ],
  coordinatorUid: coordinatorUid,
  createdBy: 'admin',
  createdAt: DateTime(2026, 8, 19),
  updatedBy: 'admin',
  updatedAt: DateTime(2026, 8, 20),
  schemaVersion: 1,
);

List<Mobilization> _mobilizations() => [
  _mobilization('mobilization-gironde', 'operation-gironde', 'gironde'),
  _mobilization('mobilization-landes', 'operation-landes', 'landes'),
];

Mobilization _mobilization(String id, String operationId, String territoryId) =>
    Mobilization(
      id: id,
      operationId: operationId,
      territoryId: territoryId,
      name: id,
      subtitle: territoryId,
      contextType: MobilizationContextType.other,
      status: MobilizationStatus.active,
      createdBy: 'admin',
      createdAt: DateTime(2026, 8, 19),
      updatedAt: DateTime(2026, 8, 20),
      schemaVersion: 2,
    );

List<CoordinationNeed> _missions() => [
  _mission(
    'mission-gironde',
    'mobilization-gironde',
    'location-gironde',
    'Centre Gironde',
    ProfessionQuotas.fromMaps(
      requiredByProfession: const {'physiotherapist': 2, 'podiatrist': 1},
      registeredByProfession: const {'physiotherapist': 1},
    ),
  ),
  _mission(
    'mission-landes',
    'mobilization-landes',
    'location-landes',
    'Centre Landes',
    ProfessionQuotas.fromMaps(
      requiredByProfession: const {'physiotherapist': 1},
      registeredByProfession: const {'physiotherapist': 1},
    ),
  ),
];

CoordinationNeed _mission(
  String id,
  String mobilizationId,
  String locationId,
  String place,
  ProfessionQuotas quotas,
) => CoordinationNeed(
  id: id,
  mobilizationId: mobilizationId,
  locationId: locationId,
  place: place,
  group: TerritorialGroup.southGironde,
  date: '21 août',
  time: '08:00 — 12:00',
  requiredPhysiotherapists: 0,
  registeredPhysiotherapists: 0,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  professionQuotas: quotas,
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

class _StatisticsSource implements PlatformAdminStatisticsDataSource {
  const _StatisticsSource(this.data);

  final PlatformAdminStatisticsViewData data;

  @override
  Stream<PlatformAdminStatisticsViewData> watchStatistics() =>
      Stream.value(data);
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
  int watchAllCalls = 0;
  int scopedCalls = 0;

  @override
  Stream<List<CoordinationNeed>> watchAllActiveMissions() {
    watchAllCalls++;
    return Stream.value(missions);
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForLocations(Set<String> ids) {
    scopedCalls++;
    return Stream.value(const []);
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> ids,
  ) {
    scopedCalls++;
    return Stream.value(const []);
  }
}
