import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/professional_engagements_screen.dart';
import 'package:interface_incendies_gironde/screens/slots_screen.dart';
import 'package:interface_incendies_gironde/widgets/brand_mark.dart';

import 'support/verified_professional_profile.dart';

class _UnavailableMissionsRepository extends MockCoordinationRepository {
  _UnavailableMissionsRepository() : super(responsibleAccess: null);

  int missionReads = 0;
  int locationReads = 0;

  @override
  Stream<List<CoordinationNeed>> watchMissions() {
    missionReads++;
    return Stream.error(StateError('Mission data unavailable'));
  }

  @override
  Stream<List<ResponsePlace>> watchLocations() {
    locationReads++;
    return Stream.error(StateError('Location data unavailable'));
  }
}

CoordinationNeed _mission() => CoordinationNeed(
  id: 'professional-discovery-fixture',
  place: 'Site de test',
  group: TerritorialGroup.medoc,
  date: 'Demain',
  time: '08:00 — 12:00',
  startAt: DateTime.now().add(const Duration(days: 1)),
  endAt: DateTime.now().add(const Duration(days: 1, hours: 4)),
  requiredPhysiotherapists: 1,
  registeredPhysiotherapists: 0,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  professionQuotas: ProfessionQuotas.fromMaps(
    requiredByProfession: const {'physiotherapist': 1, 'physician': 1},
    registeredByProfession: const {},
  ),
  equipment: const ['Crèmes / huiles de massage', 'Stéthoscope'],
  equipmentByProfession: const {
    'physiotherapist': ['massage_cream_oil'],
    'physician': ['stethoscope'],
  },
  availableEquipmentOnSite: const ['massage_table'],
);

void _expectIdentity(WidgetTester tester) {
  expect(find.byType(BrandMark), findsOneWidget);
  expect(find.text('MobSanté'), findsOneWidget);
  expect(
    find.text('Le bon professionnel, au bon endroit, au bon moment.'),
    findsOneWidget,
  );
  expect(find.text('Professionnel de santé'), findsOneWidget);
}

void main() {
  testWidgets(
    'unverified Missions and Engagements explain value without data',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _UnavailableMissionsRepository();
      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();

      _expectIdentity(tester);
      expect(
        find.byKey(const Key('professional-missions-discovery')),
        findsOneWidget,
      );
      expect(
        find.text('Des missions ont besoin de professionnels comme vous'),
        findsOneWidget,
      );
      expect(find.text('Comment ça marche'), findsOneWidget);
      expect(find.textContaining('selon votre profession'), findsOneWidget);
      expect(
        find.byKey(const Key('professional-verification-cta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('professional-verification-cta')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(SlotsScreen), findsNothing);
      expect(find.text('Voir les détails'), findsNothing);
      expect(find.text('Site de test'), findsNothing);
      final startupMissionReads = repository.missionReads;
      final startupLocationReads = repository.locationReads;

      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      _expectIdentity(tester);
      expect(
        find.byKey(const Key('professional-engagements-discovery')),
        findsOneWidget,
      );
      expect(find.text('Vos engagements apparaîtront ici'), findsOneWidget);
      expect(
        find.textContaining('retrouver ici toutes les informations'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('professional-verification-cta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('professional-verification-cta')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(ProfessionalEngagementsScreen), findsNothing);
      expect(repository.missionReads, startupMissionReads);
      expect(repository.locationReads, startupLocationReads);

      await tester.tap(find.byKey(const Key('professional-verification-cta')));
      await tester.pumpAndSettle();
      _expectIdentity(tester);
      expect(find.text('Mon profil'), findsOneWidget);
      expect(find.text('Identité professionnelle'), findsOneWidget);
      expect(find.text('Vérification professionnelle'), findsOneWidget);
      expect(
        find.byKey(const Key('edit-professional-profile')),
        findsOneWidget,
      );
    },
  );

  testWidgets('verified screens retain mission, equipment and engagement UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final mission = _mission();
    final repository = MockCoordinationRepository(
      responsibleAccess: null,
      initialMissions: [mission],
      initialLocations: const [],
      initialProfiles: {'mock-volunteer': verifiedMkProfile()},
    );
    repository.engagements[mission.id] = const EngagementInfo(
      missionId: 'professional-discovery-fixture',
      volunteerId: 'mock-volunteer',
      profession: VolunteerProfession.mk,
      status: EngagementStatus.confirmed,
    );
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();

    _expectIdentity(tester);
    expect(find.byType(SlotsScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Voir les détails'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir les détails'));
    await tester.pumpAndSettle();
    expect(find.text('Crèmes / huiles de massage'), findsOneWidget);
    expect(find.text('Stéthoscope'), findsNothing);

    await tester.tap(find.text('Engagements'));
    await tester.pumpAndSettle();
    _expectIdentity(tester);
    expect(find.byType(ProfessionalEngagementsScreen), findsOneWidget);
    await tester.tap(find.text('Informations pratiques'));
    await tester.pumpAndSettle();
    expect(find.text('Table de massage'), findsOneWidget);
    expect(find.text('Crèmes / huiles de massage'), findsOneWidget);
    expect(find.text('Stéthoscope'), findsNothing);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    _expectIdentity(tester);
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Identité professionnelle'), findsOneWidget);
    expect(find.text('Vérification professionnelle'), findsOneWidget);
  });
}
