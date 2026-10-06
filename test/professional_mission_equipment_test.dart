import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/professional_engagements_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';
import 'package:interface_incendies_gironde/widgets/common.dart';

import 'support/verified_professional_profile.dart';

CoordinationNeed _mission({
  Map<String, List<String>>? requested = const {
    'physiotherapist': ['massage_cream_oil', 'massage_gun'],
    'physician': ['stethoscope'],
    'nurse': ['dressing_equipment'],
  },
  List<String>? site = const ['massage_table'],
  List<String> legacy = const [],
}) => CoordinationNeed(
  id: 'equipment-mission',
  place: 'Site de test',
  group: TerritorialGroup.medoc,
  date: 'Demain',
  time: '08:00 — 12:00',
  startAt: DateTime.now().add(const Duration(days: 1)),
  endAt: DateTime.now().add(const Duration(days: 1, hours: 4)),
  requiredPhysiotherapists: 2,
  registeredPhysiotherapists: 0,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  professionQuotas: ProfessionQuotas.fromMaps(
    requiredByProfession: const {
      'physiotherapist': 2,
      'nurse': 1,
      'physician': 1,
    },
    registeredByProfession: const {},
  ),
  equipment: legacy,
  equipmentByProfession: requested,
  availableEquipmentOnSite: site,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  MockCoordinationRepository repository, {
  bool scroll = true,
  bool settle = true,
  Stream<List<CoordinationNeed>> Function()? missionsOverride,
}) async {
  tester.view.physicalSize = const Size(390, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final liveData = LiveCoordinationData(
    repository,
    missionsOverride: missionsOverride,
  );
  addTearDown(liveData.dispose);
  await tester.pumpWidget(
    RepositoryScope(
      repository: repository,
      child: LiveCoordinationDataScope(
        data: liveData,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: scroll ? SingleChildScrollView(child: child) : child,
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

class _CountingEngagementRepository extends MockCoordinationRepository {
  _CountingEngagementRepository({required super.initialMissions})
    : super(responsibleAccess: null, initialLocations: const []);

  int subscriptions = 0;

  @override
  Stream<EngagementInfo?> watchMyEngagement(String missionId) {
    subscriptions++;
    return super.watchMyEngagement(missionId);
  }
}

Future<void> _pumpMission(
  WidgetTester tester,
  CoordinationNeed mission,
  VolunteerProfession profession,
) async {
  await _pump(
    tester,
    NeedCard(
      need: mission,
      professionalHome: true,
      professionalJourney: true,
      professionalDetailsExpanded: false,
      preferredProfession: profession,
    ),
    MockCoordinationRepository(
      responsibleAccess: null,
      initialMissions: [mission],
      initialLocations: const [],
    ),
  );
  await tester.tap(find.text('Voir les détails'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('verified profile profession reaches the mission detail', (
    tester,
  ) async {
    final mission = _mission();
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(
          responsibleAccess: null,
          initialMissions: [mission],
          initialLocations: const [],
          initialProfiles: {'mock-volunteer': verifiedMkProfile()},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir les détails'));
    await tester.pumpAndSettle();
    expect(find.text('Crèmes / huiles de massage'), findsOneWidget);
    expect(find.text('Stéthoscope'), findsNothing);
  });

  testWidgets('verified MK sees site, team and only MK requested equipment', (
    tester,
  ) async {
    final profile = verifiedMkProfile();
    expect(profile.hasVerifiedProfessionalIdentity, isTrue);
    await _pumpMission(tester, _mission(), profile.profession);

    expect(find.text('Équipe mobilisée'), findsOneWidget);
    expect(find.text('MK · Médecin · IDE'), findsOneWidget);
    expect(find.text('Matériel disponible sur place'), findsOneWidget);
    expect(find.text('Table de massage'), findsOneWidget);
    expect(find.text('À apporter'), findsOneWidget);
    expect(find.text('Crèmes / huiles de massage'), findsOneWidget);
    expect(find.text('Pistolet de massage'), findsOneWidget);
    expect(find.text('Stéthoscope'), findsNothing);
    expect(find.text('Matériel de pansement'), findsNothing);
  });

  testWidgets('nurse sees own equipment and no other profession equipment', (
    tester,
  ) async {
    final nurse = verifiedMkProfile().copyWith(
      profession: VolunteerProfession.nurse,
      verifiedProfessionCode: '60',
      verifiedProfessionLabel: 'Infirmier',
    );
    expect(nurse.hasVerifiedProfessionalIdentity, isTrue);
    await _pumpMission(tester, _mission(), nurse.profession);
    expect(find.text('Matériel de pansement'), findsOneWidget);
    expect(find.text('Crèmes / huiles de massage'), findsNothing);
    expect(find.text('Stéthoscope'), findsNothing);
  });

  testWidgets('empty site and own request show precise empty states', (
    tester,
  ) async {
    await _pumpMission(
      tester,
      _mission(
        requested: const {
          'physician': ['stethoscope'],
        },
        site: const [],
      ),
      VolunteerProfession.mk,
    );
    expect(
      find.text('Matériel disponible sur place non renseigné.'),
      findsOneWidget,
    );
    expect(find.text('Aucun matériel spécifique à apporter.'), findsOneWidget);
    expect(find.text('Stéthoscope'), findsNothing);
  });

  testWidgets('legacy global list is never labelled for one profession', (
    tester,
  ) async {
    await _pumpMission(
      tester,
      _mission(requested: null, site: null, legacy: const ['Ancienne trousse']),
      VolunteerProfession.mk,
    );
    expect(find.text('Matériel demandé pour cette mission'), findsOneWidget);
    expect(find.text('Ancienne trousse'), findsOneWidget);
    expect(find.text('À apporter'), findsNothing);
    expect(
      find.text('Matériel disponible sur place non renseigné.'),
      findsOneWidget,
    );
  });

  testWidgets('mismatched profession never falls back to another list', (
    tester,
  ) async {
    await _pumpMission(
      tester,
      _mission(
        requested: const {
          'physician': ['stethoscope'],
        },
      ),
      VolunteerProfession.pp,
    );
    expect(find.text('Stéthoscope'), findsNothing);
    expect(find.text('Aucun matériel spécifique à apporter.'), findsOneWidget);
  });

  testWidgets('legacy mission without equipment makes no profession claim', (
    tester,
  ) async {
    await _pumpMission(
      tester,
      _mission(requested: null, site: null),
      VolunteerProfession.mk,
    );
    expect(find.text('Matériel demandé pour cette mission'), findsOneWidget);
    expect(find.text('Matériel demandé non renseigné.'), findsOneWidget);
    expect(find.text('À apporter'), findsNothing);
  });

  testWidgets('Mes engagements uses recorded profession and site snapshot', (
    tester,
  ) async {
    final mission = _mission();
    final repository = MockCoordinationRepository(
      responsibleAccess: null,
      initialMissions: [mission],
      initialLocations: const [],
    );
    repository.engagements[mission.id] = const EngagementInfo(
      missionId: 'equipment-mission',
      volunteerId: 'mock-volunteer',
      profession: VolunteerProfession.nurse,
      status: EngagementStatus.confirmed,
    );
    await _pump(
      tester,
      const ProfessionalEngagementsScreen(),
      repository,
      scroll: false,
    );
    await tester.tap(find.text('Informations pratiques'));
    await tester.pumpAndSettle();

    expect(find.text('Matériel disponible sur place'), findsOneWidget);
    expect(find.text('Table de massage'), findsOneWidget);
    expect(find.text('À apporter'), findsOneWidget);
    expect(find.text('Matériel de pansement'), findsOneWidget);
    expect(find.text('Crèmes / huiles de massage'), findsNothing);
    expect(find.text('Stéthoscope'), findsNothing);

    await tester.tap(find.text('Informations pratiques'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Informations pratiques'));
    await tester.pumpAndSettle();
    expect(find.text('Matériel de pansement'), findsOneWidget);
  });

  testWidgets('legacy engagement keeps global equipment semantics', (
    tester,
  ) async {
    final mission = _mission(
      requested: null,
      site: null,
      legacy: const ['Ancienne trousse'],
    );
    final repository = MockCoordinationRepository(
      responsibleAccess: null,
      initialMissions: [mission],
      initialLocations: const [],
    );
    repository.engagements[mission.id] = const EngagementInfo(
      missionId: 'equipment-mission',
      volunteerId: 'mock-volunteer',
      profession: VolunteerProfession.mk,
      status: EngagementStatus.confirmed,
    );
    await _pump(
      tester,
      const ProfessionalEngagementsScreen(),
      repository,
      scroll: false,
    );
    await tester.tap(find.text('Informations pratiques'));
    await tester.pumpAndSettle();
    expect(find.text('Matériel demandé pour cette mission'), findsOneWidget);
    expect(find.text('Ancienne trousse'), findsOneWidget);
    expect(find.text('À apporter'), findsNothing);
  });

  testWidgets('JOB-0029 loading and error presentation stay intact', (
    tester,
  ) async {
    final pending = StreamController<List<CoordinationNeed>>();
    addTearDown(pending.close);
    await _pump(
      tester,
      const ProfessionalEngagementsScreen(),
      MockCoordinationRepository(responsibleAccess: null),
      scroll: false,
      settle: false,
      missionsOverride: () => pending.stream,
    );
    expect(find.byType(V5ActivityIndicator), findsOneWidget);
    expect(find.text('Mes engagements'), findsNothing);

    await _pump(
      tester,
      const ProfessionalEngagementsScreen(),
      MockCoordinationRepository(responsibleAccess: null),
      scroll: false,
      missionsOverride: () => Stream.error(StateError('mission load failed')),
    );
    expect(
      find.text('Vos engagements sont temporairement indisponibles.'),
      findsOneWidget,
    );
  });

  testWidgets('JOB-0029 period filtering keeps one engagement subscription', (
    tester,
  ) async {
    final mission = _mission();
    final repository = _CountingEngagementRepository(
      initialMissions: [mission],
    );
    repository.engagements[mission.id] = const EngagementInfo(
      missionId: 'equipment-mission',
      volunteerId: 'mock-volunteer',
      profession: VolunteerProfession.mk,
      status: EngagementStatus.confirmed,
    );
    await _pump(
      tester,
      const ProfessionalEngagementsScreen(),
      repository,
      scroll: false,
    );
    expect(repository.subscriptions, 1);
    expect(find.text('Site de test'), findsOneWidget);
    await tester.tap(find.text('Aujourd’hui'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun engagement aujourd’hui.'), findsOneWidget);
    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun engagement passé.'), findsOneWidget);
    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();
    expect(find.text('Site de test'), findsOneWidget);
    expect(repository.subscriptions, 1);
  });
}
