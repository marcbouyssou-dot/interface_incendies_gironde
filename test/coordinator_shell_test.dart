import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/screens/coordinator_actors_screen.dart';
import 'package:interface_incendies_gironde/screens/coordinator_more_screen.dart';
import 'package:interface_incendies_gironde/screens/coordinator_overview_screen.dart';
import 'package:interface_incendies_gironde/screens/coordinator_shell.dart';
import 'package:interface_incendies_gironde/screens/coordinator_territory_screen.dart';
import 'package:interface_incendies_gironde/theme/coordinator_identity.dart';
import 'package:interface_incendies_gironde/widgets/coordinator_bottom_navigation.dart';
import 'package:interface_incendies_gironde/widgets/territory_components.dart';
import 'package:interface_incendies_gironde/widgets/v5_bottom_navigation.dart';

void main() {
  testWidgets('coordinator journey exposes four territorial V5 tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();

    expect(find.byType(CoordinatorShell), findsOneWidget);
    expect(find.byType(CoordinatorOverviewScreen), findsOneWidget);
    expect(find.byType(CoordinatorBottomNavigation), findsOneWidget);
    expect(find.text('Pilotage territorial'), findsOneWidget);
    expect(find.byKey(const Key('territory-verdict')), findsOneWidget);
    expect(find.text('À surveiller'), findsWidgets);
    expect(find.text('Sous contrôle'), findsOneWidget);
    expect(find.text('Actions rapides'), findsOneWidget);
    expect(
      find.byKey(const Key('coordinator-operational-summary')),
      findsOneWidget,
    );
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
    expect(
      find.text(
        'Repérez les secteurs stables, sous surveillance ou critiques.',
      ),
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
    expect(
      find.text(
        'Responsables, professionnels mobilisés et lieux du dispositif.',
      ),
      findsOneWidget,
    );
    expect(find.text('Responsables'), findsOneWidget);
    expect(find.text('Professionnels'), findsOneWidget);
    expect(find.text('Lieux'), findsOneWidget);
    expect(find.text('Responsable Mérignac'), findsOneWidget);
    expect(find.text('16 professionnels mobilisés'), findsOneWidget);

    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();

    expect(find.byType(CoordinatorMoreScreen), findsOneWidget);
    expect(find.text('Coordination'), findsOneWidget);
    expect(find.text('Changer de perspective'), findsOneWidget);
    expect(find.text('Statistiques globales'), findsOneWidget);
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);

    await tester.tap(find.byKey(const Key('coordinator-profile')));
    await tester.pumpAndSettle();

    expect(find.byType(CoordinatorProfileScreen), findsOneWidget);
    expect(find.text('Coordinateur MobSanté'), findsOneWidget);
    expect(find.text('Coordinateur territorial'), findsOneWidget);
    expect(find.text('Périmètre départemental'), findsOneWidget);
    expect(find.text('mock-coordinator'), findsNothing);
  });
}
