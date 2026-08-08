import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/common.dart';
import 'package:interface_incendies_gironde/widgets/v5_bottom_navigation.dart';

void main() {
  const location = ResponsePlace(
    id: 'site',
    name: 'Site partenaire',
    type: ResponsePlaceType.otherPartnerSite,
    group: TerritorialGroup.partnerSites,
    activeNeeds: 1,
    contactName: 'Camille Martin',
    contactPhone: '06 12 34 56 78',
    structuredAddress: LocationAddress(
      addressLine1: '10 rue du Test',
      postalCode: '33000',
      city: 'Bordeaux',
      latitude: 44.84,
      longitude: -0.58,
      status: AddressStatus.verifiedOfficial,
    ),
  );
  const mission = CoordinationNeed(
    id: 'mission',
    locationId: 'site',
    place: 'Site partenaire',
    group: TerritorialGroup.partnerSites,
    date: 'Aujourd’hui',
    time: '08:00 — 12:00',
    requiredPhysiotherapists: 1,
    registeredPhysiotherapists: 0,
    requiredPodiatrists: 0,
    registeredPodiatrists: 0,
    equipment: ['Table de massage', 'Bottes de pressothérapie'],
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    ResponsePlace? place = location,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockCoordinationRepository(
      initialMissions: const [mission],
      initialLocations: place == null ? const [] : [place],
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
            home: Scaffold(
              body: SingleChildScrollView(
                child: NeedCard(need: mission, location: place),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mission card shows reliable operational location information', (
    tester,
  ) async {
    await pumpCard(tester);

    expect(find.text('Autre site partenaire'), findsOneWidget);
    expect(find.text('10 rue du Test, 33000 Bordeaux, France'), findsOneWidget);
    expect(find.text('Référent : Camille Martin'), findsOneWidget);
    expect(find.text('06 12 34 56 78'), findsOneWidget);
    expect(find.text('Itinéraire'), findsOneWidget);
    expect(find.text('Table de massage'), findsOneWidget);
    expect(find.text('Bottes de pressothérapie'), findsOneWidget);
    expect(find.byIcon(Icons.fire_truck_rounded), findsNothing);
    expect(find.text('Récupération pompiers'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown location does not render misleading empty details', (
    tester,
  ) async {
    await pumpCard(tester, place: null);

    expect(find.byKey(const Key('mission-location-address')), findsNothing);
    expect(find.byKey(const Key('mission-location-contact')), findsNothing);
    expect(find.byKey(const Key('mission-location-phone')), findsNothing);
    expect(find.byKey(const Key('mission-location-directions')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('situation summary reuses the mission location details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      FireCoordinationApp(
        useLegacyCoordinatorShellForTesting: true,
        repository: MockCoordinationRepository(
          initialMissions: const [mission],
          initialLocations: const [location],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final navigation = tester.widget<V5BottomBar>(find.byType(V5BottomBar));
    navigation.onDestinationSelected(2);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('10 rue du Test, 33000 Bordeaux, France'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.text('10 rue du Test, 33000 Bordeaux, France'), findsOneWidget);
    expect(find.text('Référent : Camille Martin'), findsOneWidget);
    expect(find.text('Itinéraire'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
