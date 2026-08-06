import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/location_detail_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';

void main() {
  const structuredLocation = ResponsePlace(
    id: 'site-a',
    name: 'Centre Test',
    type: ResponsePlaceType.sdisStation,
    group: TerritorialGroup.medoc,
    activeNeeds: 2,
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
  const historicalLocation = ResponsePlace(
    id: 'site-b',
    name: 'Site historique',
    type: ResponsePlaceType.otherPartnerSite,
    group: TerritorialGroup.partnerSites,
    activeNeeds: 0,
    address: '5 avenue Historique, 33000 Bordeaux',
  );
  const unknownLocation = ResponsePlace(
    id: 'site-c',
    name: 'Site sans adresse',
    type: ResponsePlaceType.otherPartnerSite,
    group: TerritorialGroup.partnerSites,
    activeNeeds: 0,
  );
  const coordinatesOnlyLocation = ResponsePlace(
    id: 'site-d',
    name: 'Site géolocalisé',
    type: ResponsePlaceType.otherPartnerSite,
    group: TerritorialGroup.partnerSites,
    activeNeeds: 0,
    structuredAddress: LocationAddress(
      latitude: 44.84,
      longitude: -0.58,
      status: AddressStatus.needsConfirmation,
    ),
  );

  CoordinationNeed mission({
    required String id,
    bool active = true,
    bool generic = false,
    DateTime? startAt,
  }) => CoordinationNeed(
    id: id,
    locationId: structuredLocation.id,
    place: structuredLocation.name,
    group: structuredLocation.group,
    date: 'Demain',
    time: '08:00 — 12:00',
    startAt: startAt ?? DateTime.now().add(const Duration(days: 1)),
    endAt: DateTime.now().add(const Duration(days: 2)),
    requiredPhysiotherapists: 2,
    registeredPhysiotherapists: 1,
    requiredPodiatrists: generic ? 1 : 0,
    registeredPodiatrists: 0,
    professionQuotas: generic
        ? ProfessionQuotas.fromMaps(
            requiredByProfession: const {
              'physiotherapist': 2,
              'physician': 1,
              'nurse': 1,
            },
            registeredByProfession: const {'physiotherapist': 1},
          )
        : null,
    equipment: const ['Tables', 'Tensiomètre'],
    isActive: active,
  );

  Future<void> pumpDetail(
    WidgetTester tester, {
    required ResponsePlace location,
    required List<CoordinationNeed> missions,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockCoordinationRepository(
      initialMissions: missions,
      initialLocations: [location],
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
            home: LocationDetailScreen(
              location: location,
              missions: Stream.value(missions),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('location detail shows contact and active ordered needs only', (
    tester,
  ) async {
    final later = mission(
      id: 'later',
      generic: true,
      startAt: DateTime.now().add(const Duration(days: 2)),
    );
    final earlier = mission(id: 'earlier');
    final inactive = mission(id: 'inactive', active: false);
    await pumpDetail(
      tester,
      location: structuredLocation,
      missions: [later, inactive, earlier],
    );

    expect(find.text('Centre Test'), findsWidgets);
    expect(find.text('Caserne SDIS'), findsWidgets);
    expect(find.text('10 rue du Test, 33000 Bordeaux, France'), findsWidgets);
    expect(find.text('Référent : Camille Martin'), findsWidgets);
    expect(find.text('Appeler le référent'), findsOneWidget);
    expect(find.text('Itinéraire'), findsWidgets);
    expect(find.byKey(const ValueKey('earlier')), findsOneWidget);
    expect(find.byKey(const ValueKey('inactive')), findsNothing);
    await tester.drag(
      find.byKey(const Key('location-detail-screen')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('later')), findsOneWidget);
    expect(find.text('Médecin'), findsOneWidget);
    expect(find.text('Infirmier'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('location detail has an immediate empty state without a stream', (
    tester,
  ) async {
    await pumpDetail(tester, location: unknownLocation, missions: const []);

    expect(find.text('Aucun besoin en cours pour ce lieu.'), findsOneWidget);
    expect(find.text('Itinéraire'), findsNothing);
    expect(find.text('Appeler le référent'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('location detail supports coordinates without an address', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      location: coordinatesOnlyLocation,
      missions: const [],
    );

    expect(find.text('Itinéraire'), findsOneWidget);
    expect(find.byKey(const Key('location-address-line')), findsNothing);
    expect(find.text('Adresse à renseigner'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Places displays address fallbacks and opens a location card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _CountingRepository(
      initialMissions: [mission(id: 'active')],
      initialLocations: const [
        structuredLocation,
        historicalLocation,
        unknownLocation,
      ],
    );
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: repository,
        useLegacyCoordinatorShellForTesting: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus').last);
    await tester.pumpAndSettle();

    expect(find.text('10 rue du Test, 33000 Bordeaux, France'), findsOneWidget);
    expect(find.text('5 avenue Historique, 33000 Bordeaux'), findsOneWidget);
    expect(find.text('Adresse à renseigner'), findsNothing);
    expect(find.text('Voir le lieu'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const Key('place-card-site-a')),
      300,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place-card-site-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-detail-screen')), findsOneWidget);
    expect(repository.missionFactories, 1);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('10 rue du Test, 33000 Bordeaux, France'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _CountingRepository extends MockCoordinationRepository {
  _CountingRepository({
    required super.initialMissions,
    required super.initialLocations,
  });

  int missionFactories = 0;

  @override
  Stream<List<CoordinationNeed>> watchMissions() {
    missionFactories++;
    return super.watchMissions();
  }
}
