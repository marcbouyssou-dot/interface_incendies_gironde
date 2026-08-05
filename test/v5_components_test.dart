import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';
import 'package:interface_incendies_gironde/widgets/decision_header.dart';
import 'package:interface_incendies_gironde/widgets/mission_card.dart';
import 'package:interface_incendies_gironde/widgets/v5_bottom_navigation.dart';

void main() {
  Widget app(Widget child, {ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  testWidgets('DecisionHeader exposes its four visual states', (tester) async {
    for (final state in DecisionHeaderState.values) {
      await tester.pumpWidget(app(DecisionHeader(state: state)));

      if (state == DecisionHeaderState.loading) {
        expect(
          find.byKey(const Key('decision-header-verdict-loading')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('decision-header-secondary-loading')),
          findsOneWidget,
        );
      } else {
        expect(
          find.byKey(const Key('decision-header-verdict')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('decision-header-secondary')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('MissionCard renders every state and keeps details folded', (
    tester,
  ) async {
    for (final state in MissionCardState.values) {
      final card = state == MissionCardState.loading
          ? MissionCard.loading(key: ValueKey(state))
          : MissionCard(
              key: ValueKey(state),
              state: state,
              locationType: 'Centre de soins',
              locationName: 'Mérignac',
              dateLabel: 'Aujourd’hui',
              timeLabel: '14:00 – 18:00',
              need: const Text('2 renforts attendus'),
              professionTitle: 'Professions recherchées',
              professions: const [Text('Médecin'), Text('Infirmier')],
              primaryAction: const FilledButton(
                onPressed: null,
                child: Text('Je me mobilise'),
              ),
              secondaryDetails: const Text('Accès et contact'),
              secondaryDetailsExpanded: false,
              secondaryDetailsToggleKey: const Key('details-toggle'),
            );

      await tester.pumpWidget(app(card, theme: AppTheme.dark));
      expect(tester.takeException(), isNull);

      if (state != MissionCardState.loading) {
        expect(find.text('Accès et contact'), findsNothing);
        await tester.tap(find.byKey(const Key('details-toggle')));
        await tester.pump();
        expect(find.text('Accès et contact'), findsOneWidget);
      }
    }
  });

  testWidgets('V5 bottom navigation contains exactly three destinations', (
    tester,
  ) async {
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          bottomNavigationBar: V5BottomNavigation(
            selectedIndex: 0,
            onDestinationSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    final navigation = tester.widget<NavigationBar>(
      find.byKey(const Key('v5-bottom-navigation')),
    );
    expect(navigation.destinations, hasLength(3));
    expect(find.text('Missions'), findsOneWidget);
    expect(find.text('Engagements'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).brightness,
      Brightness.dark,
    );
    expect(
      Theme.of(
        tester.element(find.byType(NavigationBar)),
      ).extension<V5Colors>(),
      V5Colors.dark,
    );
    final navigationTheme = NavigationBarTheme.of(
      tester.element(find.byType(NavigationBar)),
    );
    expect(navigationTheme.indicatorColor, Colors.transparent);
    expect(
      navigationTheme.iconTheme?.resolve({WidgetState.selected})?.color,
      V5Colors.dark.info,
    );

    await tester.tap(find.text('Engagements'));
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('professional cards keep a calm borderless surface', (
    tester,
  ) async {
    Future<BoxBorder?> borderFor(MissionCardState state) async {
      await tester.pumpWidget(
        app(
          MissionCard(
            state: state,
            professionalPalette: true,
            locationType: 'Centre de soins',
            locationName: 'Mérignac',
            dateLabel: 'Aujourd’hui',
            timeLabel: '14:00 – 18:00',
            need: const Text('2 renforts attendus'),
            professionTitle: 'Professions recherchées',
            professions: const [Text('Médecin')],
            primaryAction: const FilledButton(
              onPressed: null,
              child: Text('Je me mobilise'),
            ),
            secondaryDetails: const SizedBox.shrink(),
          ),
        ),
      );
      final surface = tester.widget<Container>(
        find.byKey(const Key('mission-card-surface')),
      );
      final decoration = surface.decoration! as BoxDecoration;
      return decoration.border;
    }

    expect(await borderFor(MissionCardState.available), isNull);
    expect(await borderFor(MissionCardState.urgent), isNull);
    expect(await borderFor(MissionCardState.complete), isNull);
  });
}
