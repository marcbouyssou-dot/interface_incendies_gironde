import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/splash_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';
import 'package:interface_incendies_gironde/utils/app_page_route.dart';
import 'package:interface_incendies_gironde/widgets/mission_card.dart';
import 'package:interface_incendies_gironde/widgets/native_interactions.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';
import 'package:interface_incendies_gironde/widgets/v5_form_system.dart';
import 'package:interface_incendies_gironde/widgets/v5_secondary_navigation.dart';

void main() {
  testWidgets('application follows the system dark mode through safe areas', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      FireCoordinationApp(repository: MockCoordinationRepository()),
    );
    await tester.pumpAndSettle();

    final themedContext = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(themedContext).brightness, Brightness.dark);
    expect(themedContext.v5Colors, V5Colors.dark);
    final applicationChrome = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        )
        .map((region) => region.value);
    expect(applicationChrome, contains(AppTheme.darkSystemUiOverlayStyle));

    final canvas = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .map((box) => box.color);
    expect(canvas, contains(V5Colors.dark.canvas));
  });

  testWidgets('secondary navigation uses dark system chrome', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(appBar: V5SecondaryNavigationBar(title: 'Profil')),
      ),
    );

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(V5SecondaryNavigationBar),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    );
    expect(region.value, AppTheme.darkSystemUiOverlayStyle);
  });

  testWidgets('reduced motion removes core interaction transitions', (
    tester,
  ) async {
    var tab = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Column(
                children: [
                  V5Button(
                    label: 'Changer',
                    onPressed: () => setState(() => tab = 1),
                  ),
                  const V5ActivityIndicator(),
                  Expanded(
                    child: NativeTabView(
                      index: tab,
                      children: const [Text('Premier'), Text('Second')],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<CupertinoActivityIndicator>(
            find.byType(CupertinoActivityIndicator),
          )
          .animating,
      isFalse,
    );
    expect(find.byType(AnimatedOpacity), findsNothing);
    expect(find.byType(IndexedStack), findsOneWidget);

    await tester.tap(find.text('Changer'));
    await tester.pump();
    expect(find.text('Second'), findsOneWidget);
    expect(find.byType(AnimatedOpacity), findsNothing);

    final route = AppPageRoute<void>(
      reduceMotion: true,
      builder: (_) => const SizedBox.shrink(),
    );
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
  });

  testWidgets('mission expansion is immediate with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: MissionCard(
              state: MissionCardState.available,
              locationType: 'Centre de soins',
              locationName: 'Bassens',
              dateLabel: 'Demain',
              timeLabel: '7 h – 19 h',
              need: const Text('Deux renforts'),
              professionTitle: 'Profession recherchée',
              professions: const [Text('Infirmier')],
              primaryAction: const SizedBox.shrink(),
              secondaryDetails: const Text('Accès et contact'),
              secondaryDetailsExpanded: false,
              secondaryDetailsToggleKey: const Key('details'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('details')));
    await tester.pump();

    expect(find.text('Accès et contact'), findsOneWidget);
    expect(find.byType(AnimatedSize), findsNothing);
  });

  testWidgets('splash and V5 overlays reveal immediately with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SplashScreen(),
        ),
      ),
    );
    await tester.pump();
    final splashFade = tester.widget<FadeTransition>(
      find.byKey(const Key('splash-animated-identity')),
    );
    expect(splashFade.opacity.value, 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  V5Button(
                    label: 'Dialogue',
                    onPressed: () => showV5Dialog<void>(
                      context: context,
                      builder: (_) => const V5Dialog(
                        title: 'Confirmation',
                        message: 'Continuer ?',
                      ),
                    ),
                  ),
                  V5Button(
                    label: 'Toast',
                    onPressed: () => V5Toast.show(
                      context,
                      message: 'Enregistré',
                      duration: const Duration(hours: 1),
                    ),
                  ),
                  V5SelectField<String>(
                    label: 'Profession',
                    options: const [
                      V5SelectOption(value: 'nurse', label: 'Infirmier'),
                    ],
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Toast'));
    await tester.pump();
    expect(find.text('Enregistré'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(V5Toast),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Dialogue'));
    await tester.pump();
    expect(find.text('Confirmation'), findsOneWidget);
    Navigator.of(tester.element(find.text('Confirmation'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(V5SelectField<String>));
    await tester.pump();
    expect(find.text('Infirmier'), findsOneWidget);
  });
}
