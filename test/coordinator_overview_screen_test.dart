import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/coordinator_overview_screen.dart';
import 'package:interface_incendies_gironde/screens/coordinator_published_needs.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/common.dart' show SectionTitle;
import 'package:interface_incendies_gironde/widgets/v5_controls.dart' show V5Card;

// coordinator_overview_screen.dart is not currently wired into any real
// navigation route (no CoordinatorOverviewScreen( usage exists anywhere
// else in lib/), so this is a standalone smoke test of the widget itself,
// isolating the V5Card/SectionTitle migration from that fact.
void main() {
  testWidgets(
    'coordinator overview uses V5Card and SectionTitle without regressions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = MockCoordinationRepository();
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
                body: SafeArea(
                  child: CoordinatorOverviewScreen(
                    publishedNeeds: CoordinatorPublishedNeeds(),
                    onOpenTerritory: () {},
                    onCreateNeed: () {},
                    onManageResponsibles: () {},
                    onManageLocations: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SectionTitle, 'Actions rapides'), findsOneWidget);
      expect(find.widgetWithText(SectionTitle, 'À surveiller'), findsOneWidget);
      expect(find.widgetWithText(SectionTitle, 'Sous contrôle'), findsOneWidget);
      expect(
        find.byKey(const Key('coordinator-decision-priorities')),
        findsOneWidget,
      );
      expect(
        tester.widget(find.byKey(const Key('coordinator-decision-priorities'))),
        isA<V5Card>(),
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('administration-create-need')),
          matching: find.byType(V5Card),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
