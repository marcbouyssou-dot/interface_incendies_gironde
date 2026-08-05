import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/admin_invitations_screen.dart';
import 'package:interface_incendies_gironde/screens/coordination_screen.dart';
import 'package:interface_incendies_gironde/screens/location_administration_screen.dart';

void main() {
  const coordinator = ResponsibleAccess(
    uid: 'coordinator',
    role: 'coordinator',
    locationIds: {'*'},
    active: true,
  );

  Future<_DashboardRepository> pumpDashboard(
    WidgetTester tester, {
    ResponsibleAccess? access = coordinator,
    Object? accessError,
    List<CoordinationNeed>? missions,
    List<ResponsePlace>? locations,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _DashboardRepository(
      access: access,
      accessError: accessError,
      missions: missions,
      locations: locations,
    );
    addTearDown(repository.disposeDashboard);
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();
    final siteManagerJourney =
        access?.roles.contains(ResponsibleRole.siteManager) == true &&
        access?.roles.contains(ResponsibleRole.coordinator) != true;
    if (access == null && accessError == null) {
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-responsible-access')));
    } else if (!siteManagerJourney) {
      await tester.tap(find.text('Déclarer').last);
    }
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('signed-out user keeps the responsible login only', (
    tester,
  ) async {
    await pumpDashboard(tester, access: null);

    expect(find.text('Se connecter'), findsWidgets);
    expect(find.byKey(const Key('manager-email')), findsOneWidget);
    expect(find.byKey(const Key('administration-create-need')), findsNothing);
    expect(find.byKey(const Key('administration-statistics')), findsNothing);
    expect(find.byKey(const Key('admin-invitations-entry')), findsNothing);
  });

  testWidgets('single-site manager sees its centre and opens a locked form', (
    tester,
  ) async {
    final bazas = places.singleWhere((location) => location.name == 'Bazas');
    await pumpDashboard(
      tester,
      access: ResponsibleAccess(
        uid: 'manager-bazas',
        role: 'site_manager',
        locationIds: {bazas.id},
        active: true,
      ),
      locations: [bazas, places.first],
    );

    expect(find.text('Mon planning est-il sécurisé ?'), findsOneWidget);
    expect(find.byKey(const Key('admin-invitations-entry')), findsNothing);
    expect(find.byKey(const Key('administration-statistics')), findsNothing);

    await tester.tap(find.text('Besoins'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('responsible-needs-create')));
    await tester.pumpAndSettle();

    expect(find.text('Créer un besoin'), findsOneWidget);
    expect(find.byKey(const Key('mission-location-locked')), findsOneWidget);
    expect(find.byKey(const Key('mission-location')), findsNothing);
    expect(find.text('Bazas'), findsOneWidget);
  });

  testWidgets(
    'historical multi-site manager sees the authorized centre count',
    (tester) async {
      await pumpDashboard(
        tester,
        access: ResponsibleAccess(
          uid: 'multi-manager',
          role: 'site_manager',
          locationIds: {places[0].id, places[1].id},
          active: true,
        ),
      );

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text(places[0].name), findsOneWidget);
      expect(find.text(places[1].name), findsOneWidget);
      expect(find.text('Tous les centres'), findsNothing);
    },
  );

  testWidgets('coordinator opens needs, invitations and statistics', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.text('Coordination départementale'), findsOneWidget);
    expect(find.text('Tous les lieux de Gironde'), findsOneWidget);
    expect(find.byKey(const Key('administration-create-need')), findsOneWidget);
    expect(find.byKey(const Key('admin-invitations-entry')), findsOneWidget);
    expect(find.byKey(const Key('admin-locations-entry')), findsOneWidget);
    expect(find.byKey(const Key('administration-statistics')), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin-invitations-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(AdminInvitationsScreen), findsOneWidget);
    expect(find.text('Invitations et accès aux centres'), findsOneWidget);
  });

  testWidgets('coordinator opens location administration', (tester) async {
    await pumpDashboard(tester);

    await tester.ensureVisible(find.byKey(const Key('admin-locations-entry')));
    await tester.tap(find.byKey(const Key('admin-locations-entry')));
    await tester.pumpAndSettle();

    expect(find.byType(LocationAdministrationScreen), findsOneWidget);
    expect(find.text('Créer un lieu'), findsOneWidget);
  });

  testWidgets('coordinator create form retains access to all locations', (
    tester,
  ) async {
    await pumpDashboard(tester, locations: [places[0], places[1]]);
    await tester.tap(find.byKey(const Key('administration-create-need')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mission-location')), findsOneWidget);
    expect(find.byKey(const Key('mission-location-locked')), findsNothing);
  });

  testWidgets(
    'cumulative coordinator keeps global dashboard and invitations at 390x844',
    (tester) async {
      await pumpDashboard(
        tester,
        access: ResponsibleAccess.v2(
          uid: 'cumulative',
          roles: const ['coordinator', 'site_manager'],
          locationIds: {places.first.id},
          active: true,
        ),
        locations: [places.first, places[1]],
      );

      expect(find.text('Coordination départementale'), findsOneWidget);
      expect(find.text('Tous les lieux de Gironde'), findsOneWidget);
      expect(find.byKey(const Key('admin-invitations-entry')), findsOneWidget);
      expect(
        find.byKey(const Key('administration-create-need')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cumulative coordinator statistics include every mission', (
    tester,
  ) async {
    final firstMission = needs.first;
    final firstLocation = responsePlaceForNeed(firstMission, places)!;
    final secondMission = needs.firstWhere(
      (mission) =>
          responsePlaceForNeed(mission, places)?.id != firstLocation.id,
    );
    final secondLocation = responsePlaceForNeed(secondMission, places)!;
    final access = ResponsibleAccess.v2(
      uid: 'cumulative',
      roles: const ['coordinator', 'site_manager'],
      locationIds: {firstLocation.id},
      active: true,
    );
    expect(
      missionsVisibleToResponsible(
        missions: [firstMission, secondMission],
        locations: [firstLocation, secondLocation],
        access: access,
      ),
      [firstMission, secondMission],
    );
    await pumpDashboard(
      tester,
      access: access,
      missions: [firstMission, secondMission],
      locations: [firstLocation, secondLocation],
    );

    await tester.tap(find.byKey(const Key('administration-statistics')));
    await tester.pumpAndSettle();

    expect(find.text('SITUATION'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('site manager has no statistics and keeps scoped needs', (
    tester,
  ) async {
    final allowedMission = needs.first;
    final allowedLocation = responsePlaceForNeed(allowedMission, places)!;
    final deniedMission = needs.firstWhere(
      (mission) =>
          responsePlaceForNeed(mission, places)?.id != allowedLocation.id,
    );
    final deniedLocation = responsePlaceForNeed(deniedMission, places)!;
    await pumpDashboard(
      tester,
      access: ResponsibleAccess(
        uid: 'scoped-manager',
        role: 'site_manager',
        locationIds: {allowedLocation.id},
        active: true,
      ),
      missions: [allowedMission, deniedMission],
      locations: [allowedLocation, deniedLocation],
    );

    expect(find.text('Statistiques'), findsNothing);
    expect(find.byKey(const Key('administration-statistics')), findsNothing);

    await tester.tap(find.text('Besoins'));
    await tester.pumpAndSettle();

    expect(find.text(allowedMission.place), findsOneWidget);
    expect(find.text(deniedMission.place), findsNothing);
  });

  testWidgets('sign out returns to the professional journey', (tester) async {
    final repository = await pumpDashboard(tester);

    final signOut = find.byKey(const Key('administration-sign-out'));
    await tester.scrollUntilVisible(
      signOut,
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('administration-dashboard')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(signOut);
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();

    expect(repository.signOutCalls, 1);
    expect(find.text('Missions'), findsWidgets);
    expect(find.text('Engagements'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.byKey(const Key('manager-email')), findsNothing);
    expect(find.byKey(const Key('administration-create-need')), findsNothing);
  });

  testWidgets('inactive and unreadable roles never expose privileged actions', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      access: const ResponsibleAccess(
        uid: 'inactive',
        role: 'coordinator',
        locationIds: {'*'},
        active: false,
      ),
    );
    expect(find.text('Votre compte responsable est inactif.'), findsOneWidget);
    expect(find.byKey(const Key('responsible-access-retry')), findsOneWidget);
    expect(
      find.byKey(const Key('responsible-access-sign-out')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('administration-create-need')), findsNothing);

    await pumpDashboard(
      tester,
      access: const ResponsibleAccess(
        uid: 'unknown-role',
        role: 'viewer',
        locationIds: {},
        active: true,
      ),
    );
    expect(
      find.text('Votre compte ne dispose pas d’un rôle autorisé.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('administration-create-need')), findsNothing);

    await pumpDashboard(tester, accessError: true);
    expect(
      find.text('Votre accès responsable ne peut pas être vérifié.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('admin-invitations-entry')), findsNothing);
    await tester.tap(find.byKey(const Key('responsible-access-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Coordination départementale'), findsOneWidget);
    expect(find.byKey(const Key('administration-create-need')), findsOneWidget);
  });

  testWidgets(
    'invalid V2 access exposes a safe explicit administration state',
    (tester) async {
      await pumpDashboard(
        tester,
        accessError: const ResponsibleAccessFormatException(
          ResponsibleAccessFormatError.invalidLocationIds,
          'invalid V2 scope',
        ),
      );

      expect(find.text('Configuration d’accès invalide'), findsOneWidget);
      expect(
        find.text('Aucun accès d’administration n’a été accordé.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('administration-create-need')), findsNothing);
      expect(find.byKey(const Key('admin-invitations-entry')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('Plus contains information and places but no administration', (
    tester,
  ) async {
    await pumpDashboard(tester);
    await tester.tap(find.text('Plus').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('admin-invitations-entry')), findsNothing);
    expect(find.byKey(const Key('about-entry')), findsOneWidget);
    expect(find.byKey(const Key('places-territorial-filter')), findsOneWidget);
  });

  testWidgets(
    'administration cards expose button semantics and touch targets',
    (tester) async {
      await pumpDashboard(tester);
      final semantics = tester.getSemantics(
        find.byKey(const Key('administration-create-need')),
      );

      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.label, contains('Créer un besoin'));
      expect(
        tester
            .getSize(find.byKey(const Key('administration-create-need')))
            .height,
        greaterThanOrEqualTo(48),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Créer un besoin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _DashboardRepository extends MockCoordinationRepository {
  _DashboardRepository({
    required ResponsibleAccess? access,
    required this.accessError,
    List<CoordinationNeed>? missions,
    List<ResponsePlace>? locations,
  }) : _currentAccess = access,
       super(
         responsibleAccess: access,
         initialMissions: missions,
         initialLocations: locations,
       );

  ResponsibleAccess? _currentAccess;
  final Object? accessError;
  final _accessUpdates = StreamController<ResponsibleAccess?>.broadcast();
  int accessFactories = 0;
  int signOutCalls = 0;

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() {
    accessFactories++;
    if (accessError != null && accessFactories == 1) {
      final error = accessError == true
          ? StateError('role unavailable')
          : accessError!;
      return Stream<ResponsibleAccess?>.error(error);
    }
    return Stream<ResponsibleAccess?>.multi((controller) {
      controller.add(_currentAccess);
      final subscription = _accessUpdates.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> signOutResponsible() async {
    signOutCalls++;
    _currentAccess = null;
    _accessUpdates.add(null);
  }

  Future<void> disposeDashboard() => _accessUpdates.close();
}
