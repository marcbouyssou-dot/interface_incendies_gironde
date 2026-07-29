import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/common.dart';

void main() {
  final mission = CoordinationNeed(
    id: 'generic-public-mission',
    place: 'Mérignac',
    group: TerritorialGroup.bordeauxMetropole,
    date: 'Aujourd’hui',
    time: '08:00 — 12:00',
    requiredPhysiotherapists: 4,
    registeredPhysiotherapists: 3,
    requiredPodiatrists: 2,
    registeredPodiatrists: 1,
    equipment: const ['Tables'],
    professionQuotas: ProfessionQuotas.fromMaps(
      requiredByProfession: const {
        'physiotherapist': 4,
        'podiatrist': 2,
        'physician': 1,
        'nurse': 2,
        'other_health_professional': 3,
      },
      registeredByProfession: const {
        'physiotherapist': 3,
        'podiatrist': 1,
        'physician': 0,
        'nurse': 2,
        'other_health_professional': 1,
      },
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double height = 1200,
  }) async {
    tester.view.physicalSize = Size(390, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepositoryScope(
        repository: MockCoordinationRepository(
          initialMissions: [mission],
          initialLocations: places,
        ),
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectGenericQuotas() {
    expect(find.text('Masseur-kinésithérapeute'), findsOneWidget);
    expect(find.text('Pédicure-podologue'), findsOneWidget);
    expect(find.text('Médecin'), findsOneWidget);
    expect(find.text('Infirmier'), findsOneWidget);
    expect(find.text('Autre professionnel de santé'), findsOneWidget);
    expect(find.text('3 / 4'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
  }

  testWidgets('public mission card displays every required profession', (
    tester,
  ) async {
    await pump(tester, NeedCard(need: mission));

    expectGenericQuotas();
    expect(tester.takeException(), isNull);
  });

  testWidgets('public coverage summary displays generic profession quotas', (
    tester,
  ) async {
    await pump(
      tester,
      Padding(
        padding: const EdgeInsets.all(20),
        child: CoverageBar(need: mission),
      ),
    );

    expectGenericQuotas();
    expect(tester.takeException(), isNull);
  });

  testWidgets('professions with a zero requirement stay hidden', (
    tester,
  ) async {
    final mkOnly = CoordinationNeed(
      id: 'mk-only',
      place: 'Mérignac',
      group: TerritorialGroup.bordeauxMetropole,
      date: 'Aujourd’hui',
      time: '08:00 — 12:00',
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      equipment: const [],
    );

    await pump(tester, CoverageBar(need: mkOnly));

    expect(find.text('Masseur-kinésithérapeute'), findsOneWidget);
    expect(find.text('Pédicure-podologue'), findsNothing);
    expect(find.text('Médecin'), findsNothing);
    expect(find.text('Infirmier'), findsNothing);
    expect(find.text('Autre professionnel de santé'), findsNothing);
  });
}
