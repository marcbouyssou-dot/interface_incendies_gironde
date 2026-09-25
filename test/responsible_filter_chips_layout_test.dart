import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

const _needsFilterKeys = [
  'responsible-needs-filter-attention',
  'responsible-needs-filter-inProgress',
  'responsible-needs-filter-covered',
  'responsible-needs-filter-past',
];

const _teamFilterKeys = [
  'responsible-team-filter-confirmed',
  'responsible-team-filter-pending',
  'responsible-team-filter-standby',
  'responsible-team-filter-cancelled',
];

void main() {
  Future<void> pumpResponsible(WidgetTester tester, Size size) async {
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
            uid: 'layout-responsible',
            role: ResponsibleRole.siteManager,
            locationIds: {center.id},
            active: true,
          ),
          initialLocations: [center],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [
    Size(320, 568), // narrow mobile (iPhone SE 1st gen)
    Size(390, 844), // standard mobile (iPhone 12/13/14)
    Size(1024, 768), // tablet/desktop
  ]) {
    testWidgets(
      'Mes besoins filters stay fully reachable without overflow at '
      '${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await pumpResponsible(tester, size);

        await tester.tap(find.text('Besoins'));
        await tester.pumpAndSettle();

        for (final key in _needsFilterKeys) {
          expect(find.byKey(Key(key)), findsOneWidget);
        }
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('responsible-needs-filter-past')));
        await tester.pumpAndSettle();
        expect(find.text('Passés'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Mon équipe filters stay fully reachable without overflow at '
      '${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await pumpResponsible(tester, size);

        await tester.tap(find.text('Équipe').last);
        await tester.pumpAndSettle();

        for (final key in _teamFilterKeys) {
          expect(find.byKey(Key(key)), findsOneWidget);
        }
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.byKey(const Key('responsible-team-filter-pending')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
