import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/screens/coordinator_actors_screen.dart';
import 'package:interface_incendies_gironde/screens/coordinator_cockpit_screen.dart';
import 'package:interface_incendies_gironde/screens/coordinator_more_screen.dart';
import 'package:interface_incendies_gironde/screens/coordinator_shell.dart';
import 'package:interface_incendies_gironde/screens/coordinator_territory_screen.dart';
import 'package:interface_incendies_gironde/theme/coordinator_identity.dart';
import 'package:interface_incendies_gironde/widgets/coordinator_bottom_navigation.dart';
import 'package:interface_incendies_gironde/widgets/territory_components.dart';
import 'package:interface_incendies_gironde/widgets/v5_bottom_navigation.dart';
import 'package:interface_incendies_gironde/widgets/v5_secondary_navigation.dart';

void main() {
  void expectBrandedCoordinatorHeader(WidgetTester tester) {
    expect(find.byKey(const Key('brand-logo-slot')), findsOneWidget);
    expect(find.text('MobSanté'), findsOneWidget);
    expect(
      find.text('Le bon professionnel, au bon endroit, au bon moment.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobsante-journey-title-coordinator')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  }

  testWidgets('coordinator journey exposes four territorial V5 tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();

    expect(find.byType(CoordinatorShell), findsOneWidget);
    expectBrandedCoordinatorHeader(tester);
    expect(find.byType(CoordinatorCockpitScreen), findsOneWidget);
    expect(find.byType(CoordinatorBottomNavigation), findsOneWidget);
    expect(find.text('Gironde'), findsOneWidget);
    expect(find.byKey(const Key('cockpit-global-state')), findsOneWidget);
    expect(find.byKey(const Key('cockpit-operational-map')), findsOneWidget);
    expect(find.text('3 actions prioritaires'), findsOneWidget);
    expect(find.byKey(const Key('coordinator-global-dashboard')), findsNothing);
    expect(find.text('Déclarer'), findsNothing);

    final navigation = tester.widget<V5BottomBar>(
      find.byKey(const Key('coordinator-bottom-navigation')),
    );
    expect(navigation.destinations, hasLength(4));
    final identity = CoordinatorIdentity.of(
      tester.element(find.byType(CoordinatorShell)),
    );
    expect(navigation.selectedColor, identity.accent);

    await tester.tap(find.text('Territoire'));
    await tester.pumpAndSettle();

    expect(find.byType(CoordinatorTerritoryScreen), findsOneWidget);
    expectBrandedCoordinatorHeader(tester);
    expect(
      find.text(
        'Situation aujourd’hui et à venir : secteurs stables, sous surveillance ou critiques.',
      ),
      findsNothing,
    );
    expect(
      find.byKey(const Key('coordinator-territory-period')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('coordinator-territory-filter-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('coordinator-territory-filter-watch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('coordinator-territory-filter-critical')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('coordinator-territory-filter-stable')),
      findsOneWidget,
    );
    expect(find.byType(SectorStatusCard), findsWidgets);
    expect(find.text('Carte'), findsNothing);

    await tester.tap(find.text('Acteurs'));
    await tester.pumpAndSettle();

    expect(find.byType(CoordinatorActorsScreen), findsOneWidget);
    expectBrandedCoordinatorHeader(tester);
    expect(
      find.text(
        'Responsables, professionnels mobilisés et lieux du dispositif.',
      ),
      findsNothing,
    );
    expect(find.text('Responsables'), findsOneWidget);
    expect(find.text('Professionnels'), findsOneWidget);
    expect(find.text('Lieux'), findsOneWidget);
    expect(find.text('Responsable Mérignac'), findsOneWidget);
    expect(find.text('16 professionnels mobilisés'), findsOneWidget);

    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();

    expect(find.byType(CoordinatorMoreScreen), findsOneWidget);
    expectBrandedCoordinatorHeader(tester);
    expect(find.text('Coordination'), findsNothing);
    expect(find.text('Changer de perspective'), findsNothing);
    expect(find.byKey(const Key('perspective-professional')), findsNothing);
    expect(find.text('Statistiques globales'), findsOneWidget);
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);

    await tester.tap(find.byKey(const Key('coordinator-profile')));
    await tester.pumpAndSettle();

    expect(find.byType(CoordinatorProfileScreen), findsOneWidget);
    expectBrandedCoordinatorHeader(tester);
    expect(find.text('Coordinateur MobSanté'), findsOneWidget);
    expect(find.text("Coordinateur d'action"), findsNWidgets(2));
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Rôle'), findsOneWidget);
    expect(find.text('Périmètre'), findsOneWidget);
    expect(find.text('Périmètre départemental'), findsOneWidget);
    expect(find.text('coordinateur@example.test'), findsOneWidget);
    expect(find.byKey(const Key('coordinator-profile-back')), findsOneWidget);
    expect(find.text('mock-coordinator'), findsNothing);
    await tester.tap(find.byKey(const Key('coordinator-profile-back')));
    await tester.pumpAndSettle();
    expect(find.byType(CoordinatorMoreScreen), findsOneWidget);
  });

  testWidgets('Coordinator identity stays aligned without desktop overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();

    for (final tab in ['Cockpit', 'Territoire', 'Acteurs', 'Plus']) {
      if (tab != 'Cockpit') {
        await tester.tap(find.text(tab).first);
        await tester.pumpAndSettle();
      }
      expectBrandedCoordinatorHeader(tester);
      expect(find.byType(CoordinatorBottomNavigation), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('brand-logo-slot'))).dx,
        greaterThan(100),
      );
    }
  });

  testWidgets('territory statistics use the shared temporal vocabulary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();
    expect(find.text('Gironde'), findsOneWidget);
    expect(find.text('Besoins actifs'), findsNothing);

    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statistiques globales'));
    await tester.pumpAndSettle();

    expect(find.text('Période observée'), findsOneWidget);
    expect(find.text('Aujourd’hui'), findsWidgets);
    expect(find.text('À venir'), findsOneWidget);
    expect(find.text('Passés'), findsOneWidget);
    expect(find.text('En cours'), findsNothing);
    expect(
      find.byKey(const Key('coordinator-statistics-navigation')),
      findsOneWidget,
    );
    expect(find.byType(V5BackButton), findsOneWidget);

    await tester.tap(find.byType(V5BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(CoordinatorMoreScreen), findsOneWidget);
    expect(find.byKey(const Key('coordinator-statistics-route')), findsNothing);

    await tester.tap(find.text('Statistiques globales'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('coordinator-statistics-route')),
      findsOneWidget,
    );
    await tester.tap(find.byType(V5BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(CoordinatorMoreScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
