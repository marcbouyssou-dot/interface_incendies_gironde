import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
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
        'veterinarian': 2,
        'other_health_professional': 3,
      },
      registeredByProfession: const {
        'physiotherapist': 3,
        'podiatrist': 1,
        'physician': 0,
        'nurse': 2,
        'veterinarian': 1,
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
    final repository = MockCoordinationRepository(
      initialMissions: [mission],
      initialLocations: places,
    );
    final liveData = LiveCoordinationData(repository);
    addTearDown(liveData.dispose);
    await tester.pumpWidget(
      RepositoryScope(
        repository: repository,
        child: LiveCoordinationDataScope(
          data: liveData,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: SingleChildScrollView(child: child)),
          ),
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
    expect(find.text('Vétérinaire'), findsOneWidget);
    expect(find.text('Autre professionnel de santé'), findsOneWidget);
    expect(find.text('3 / 4'), findsOneWidget);
    expect(find.text('1 / 2'), findsNWidgets(2));
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

  testWidgets(
    'supervision card groups new equipment without changing legacy display',
    (tester) async {
      final grouped = CoordinationNeed(
        id: 'grouped-equipment',
        place: 'Bassens',
        group: TerritorialGroup.bordeauxMetropole,
        date: 'À venir',
        time: '08:00 — 12:00',
        requiredPhysiotherapists: 1,
        registeredPhysiotherapists: 0,
        requiredPodiatrists: 0,
        registeredPodiatrists: 0,
        professionQuotas: ProfessionQuotas.fromMaps(
          requiredByProfession: const {'physiotherapist': 1, 'nurse': 1},
          registeredByProfession: const {},
        ),
        equipment: const ['Table de massage', 'Matériel de pansement'],
        equipmentByProfession: const {
          'physiotherapist': ['massage_table'],
          'nurse': ['dressing_equipment'],
        },
      );
      await pump(tester, NeedCard(need: grouped));
      expect(find.text('MATÉRIEL DEMANDÉ'), findsOneWidget);
      expect(find.text('• Table de massage'), findsOneWidget);
      expect(find.text('• Matériel de pansement'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('professional multi-profession card names the matching quota', (
    tester,
  ) async {
    final multiMission = CoordinationNeed(
      id: 'multi-profession',
      place: 'Bassens',
      group: TerritorialGroup.bordeauxMetropole,
      date: 'Dimanche 4 octobre',
      time: '08:00 — 12:00',
      requiredPhysiotherapists: 3,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 1,
      registeredPodiatrists: 0,
      equipment: const ['Table de massage', 'Matériel de pansement'],
      equipmentByProfession: const {
        'physiotherapist': ['massage_table'],
        'nurse': ['dressing_equipment'],
      },
      professionQuotas: ProfessionQuotas.fromMaps(
        requiredByProfession: const {
          'physiotherapist': 3,
          'podiatrist': 1,
          'physician': 1,
          'nurse': 2,
        },
        registeredByProfession: const {},
      ),
    );
    await pump(
      tester,
      NeedCard(
        need: multiMission,
        professionalHome: true,
        professionalJourney: true,
        preferredProfession: VolunteerProfession.mk,
      ),
      height: 1800,
    );

    expect(find.text('Votre profession recherchée'), findsOneWidget);
    expect(find.text('Masseur-kinésithérapeute · 3 places'), findsOneWidget);
    expect(find.text('Répartition des renforts'), findsOneWidget);
    for (final label in [
      'Masseur-kinésithérapeute',
      'Pédicure-podologue',
      'Médecin',
      'Infirmier',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('0 / 3'), findsOneWidget);
    expect(find.text('0 / 1'), findsNWidgets(2));
    expect(find.text('0 / 2'), findsOneWidget);
    expect(
      find.text('Matériel à prévoir pour votre intervention'),
      findsOneWidget,
    );
    expect(find.text('• Table de massage'), findsOneWidget);
    expect(find.text('Autres matériels demandés'), findsOneWidget);
    expect(find.text('• Matériel de pansement'), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.text('Matériel à prévoir pour votre intervention'))
          .dy,
      lessThan(tester.getTopLeft(find.text('Répartition des renforts')).dy),
    );
    expect(tester.takeException(), isNull);

    await pump(
      tester,
      NeedCard(
        need: multiMission,
        professionalHome: true,
        professionalJourney: true,
        preferredProfession: VolunteerProfession.pp,
      ),
      height: 1800,
    );
    expect(find.text('Votre profession recherchée'), findsOneWidget);
    expect(find.text('Pédicure-podologue · 1 place'), findsOneWidget);

    await pump(
      tester,
      NeedCard(
        need: multiMission,
        professionalHome: true,
        professionalJourney: true,
        preferredProfession: VolunteerProfession.nurse,
      ),
      height: 1800,
    );
    expect(
      find.text('Matériel à prévoir pour votre intervention'),
      findsOneWidget,
    );
    expect(find.text('• Matériel de pansement'), findsOneWidget);
    expect(find.text('• Table de massage'), findsOneWidget);
  });

  testWidgets('mono-profession professional card keeps its existing label', (
    tester,
  ) async {
    final monoMission = CoordinationNeed(
      id: 'mk-only',
      place: 'Bassens',
      group: TerritorialGroup.bordeauxMetropole,
      date: 'Aujourd’hui',
      time: '08:00 — 12:00',
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      equipment: const ['Tables'],
    );
    await pump(
      tester,
      NeedCard(
        need: monoMission,
        professionalHome: true,
        professionalJourney: true,
        preferredProfession: VolunteerProfession.mk,
      ),
    );

    expect(find.text('Profession recherchée'), findsOneWidget);
    expect(find.text('Votre profession recherchée'), findsNothing);
    expect(find.text('Masseur-kinésithérapeute'), findsWidgets);
    expect(find.text('Matériel demandé'), findsOneWidget);
    expect(find.text('Tables'), findsOneWidget);
    expect(find.textContaining('place'), findsNothing);
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
    expect(find.text('Vétérinaire'), findsNothing);
    expect(find.text('Autre professionnel de santé'), findsNothing);
  });
}
