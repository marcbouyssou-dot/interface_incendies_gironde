import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/utils/app_page_route.dart';
import 'package:interface_incendies_gironde/widgets/decision_header.dart';
import 'package:interface_incendies_gironde/widgets/mission_card.dart';
import 'package:interface_incendies_gironde/widgets/native_interactions.dart';

void main() {
  testWidgets('bottom sheet uses the shared native timing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('open-sheet'),
            onPressed: () => showNativeBottomSheet<void>(
              context: context,
              builder: (_) =>
                  const SizedBox(key: Key('native-sheet'), height: 240),
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-sheet')));
    await tester.pump();

    final route = ModalRoute.of(
      tester.element(find.byKey(const Key('native-sheet'))),
    )!;
    expect(route.transitionDuration, NativeMotion.bottomSheet.duration);
    expect(
      route.reverseTransitionDuration,
      NativeMotion.bottomSheet.reverseDuration,
    );
  });

  testWidgets('tab transition is discreet and preserves tab state', (
    tester,
  ) async {
    var selectedIndex = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: NativeTabView(
                index: selectedIndex,
                children: const [
                  _CounterTab(),
                  Center(child: Text('Second onglet')),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('increment-tab')));
    await tester.pump();
    expect(find.text('Compteur 1'), findsOneWidget);

    update(() => selectedIndex = 1);
    await tester.pump();
    expect(
      tester
          .widget<AnimatedOpacity>(find.byKey(const ValueKey('native-tab-0')))
          .opacity,
      0,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(find.byKey(const ValueKey('native-tab-1')))
          .opacity,
      1,
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Second onglet'), findsOneWidget);

    update(() => selectedIndex = 0);
    await tester.pumpAndSettle();
    expect(find.text('Compteur 1'), findsOneWidget);
  });

  testWidgets('mission details expand progressively', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MissionCard(
              key: const Key('animated-mission'),
              state: MissionCardState.available,
              locationType: 'Centre de soins',
              locationName: 'Mérignac',
              dateLabel: 'Aujourd’hui',
              timeLabel: '14:00 – 18:00',
              need: const Text('2 renforts attendus'),
              professionTitle: 'Profession recherchée',
              professions: const [Text('Médecin')],
              primaryAction: const SizedBox(height: 48),
              secondaryDetails: const SizedBox(
                height: 180,
                child: Text('Détails de la mission'),
              ),
              secondaryDetailsExpanded: false,
              secondaryDetailsToggleKey: const Key('details-toggle'),
            ),
          ),
        ),
      ),
    );

    final card = find.byKey(const Key('animated-mission'));
    final collapsedHeight = tester.getSize(card).height;
    await tester.tap(find.byKey(const Key('details-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final intermediateHeight = tester.getSize(card).height;
    await tester.pumpAndSettle();
    final expandedHeight = tester.getSize(card).height;

    expect(intermediateHeight, greaterThan(collapsedHeight));
    expect(expandedHeight, greaterThan(intermediateHeight));
    expect(find.text('Détails de la mission'), findsOneWidget);
  });

  testWidgets('hero content cross-fades when its state changes', (
    tester,
  ) async {
    var state = DecisionHeaderState.noUpdates;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(body: DecisionHeader(state: state));
          },
        ),
      ),
    );

    update(() => state = DecisionHeaderState.urgentMission);
    await tester.pump();
    expect(find.text('Rien de nouveau pour l’instant'), findsOneWidget);
    expect(find.text('Une mission urgente a besoin de vous'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Rien de nouveau pour l’instant'), findsNothing);
    expect(find.text('Une mission urgente a besoin de vous'), findsOneWidget);
  });

  testWidgets('back transition keeps pages opaque', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            key: const Key('first-page'),
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                AppPageRoute<void>(
                  builder: (_) => const Scaffold(key: Key('second-page')),
                ),
              ),
              child: const Text('Continuer'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    final route = ModalRoute.of(
      tester.element(find.byKey(const Key('second-page'))),
    )!;
    expect(route.transitionDuration, const Duration(milliseconds: 220));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 200));
    expect(
      find.ancestor(
        of: find.byKey(const Key('second-page')),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );

    Navigator.of(tester.element(find.byKey(const Key('second-page')))).pop();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('first-page')), findsOneWidget);
    expect(find.byKey(const Key('second-page')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('second-page')), findsNothing);
  });
}

class _CounterTab extends StatefulWidget {
  const _CounterTab();

  @override
  State<_CounterTab> createState() => _CounterTabState();
}

class _CounterTabState extends State<_CounterTab> {
  var _count = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        key: const Key('increment-tab'),
        onPressed: () => setState(() => _count++),
        child: Text('Compteur $_count'),
      ),
    );
  }
}
