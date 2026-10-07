import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/notification_center_screen.dart';
import 'package:interface_incendies_gironde/widgets/responsible_bottom_navigation.dart';
import 'package:interface_incendies_gironde/widgets/v5_bottom_navigation.dart';

void main() {
  for (final size in const [Size(320, 568), Size(390, 844)]) {
    testWidgets('responsible tabs share the MobSanté header at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final center = places.firstWhere(
        (place) => place.isOperational && place.isEnabled,
      );
      await tester.pumpWidget(
        FireCoordinationApp(
          repository: MockCoordinationRepository(
            responsibleAccess: ResponsibleAccess(
              uid: 'header-responsible',
              role: ResponsibleRole.siteManager,
              locationIds: {center.id},
              active: true,
            ),
            initialLocations: [center],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navigation = find.byType(ResponsibleBottomNavigation);
      const tabs = [
        ('Accueil', 'Demain dans mon établissement'),
        ('Besoins', 'Mes besoins'),
        ('Équipe', 'Mon équipe'),
        ('Profil', 'Mon profil responsable'),
      ];

      for (var index = 0; index < tabs.length; index++) {
        final (tab, title) = tabs[index];
        if (index != 0) {
          await tester.tap(
            find.descendant(of: navigation, matching: find.text(tab)),
          );
          await tester.pumpAndSettle();
        }

        expect(
          find.byKey(const Key('mobsante-journey-header')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('brand-logo-slot')), findsOneWidget);
        expect(find.text('MobSanté'), findsOneWidget);
        expect(
          find.text('Le bon professionnel, au bon endroit, au bon moment.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('mobsante-journey-title-responsible')),
          findsOneWidget,
        );
        expect(find.text('Responsable de site'), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(
          find.text('Organisez la couverture de votre établissement.'),
          index == 0 ? findsOneWidget : findsNothing,
        );
        expect(
          tester.getTopLeft(find.byKey(const Key('role-page-title'))).dy,
          greaterThan(
            tester
                .getBottomLeft(
                  find.byKey(const Key('mobsante-journey-title-responsible')),
                )
                .dy,
          ),
        );

        expect(navigation, findsOneWidget);
        expect(
          tester
              .getBottomLeft(find.byKey(const Key('mobsante-journey-header')))
              .dy,
          lessThan(tester.getTopLeft(navigation).dy),
        );
        final bottomBar = tester.widget<V5BottomBar>(
          find.byKey(const Key('responsible-bottom-navigation')),
        );
        expect(bottomBar.selectedIndex, index);
        expect(bottomBar.destinations.map((destination) => destination.label), [
          'Accueil',
          'Besoins',
          'Équipe',
          'Profil',
        ]);
        expect(tester.takeException(), isNull);

        if (index == 3) {
          expect(
            find.byKey(Key('save-site-equipment-${center.id}')),
            findsOneWidget,
          );
          final notifications = find.byKey(
            const Key('responsible-notification-center'),
          );
          await tester.ensureVisible(notifications);
          await tester.pumpAndSettle();
          await tester.tap(notifications);
          await tester.pumpAndSettle();
          expect(find.byType(NotificationCenterScreen), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('Mon profil responsable'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    });
  }
}
