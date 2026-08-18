import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/professional_page_header.dart';

void main() {
  test('les quatre libellés de navigation restent courts', () {
    expect(MobSanteJourney.values.map((journey) => journey.title), [
      'Professionnel',
      'Responsable',
      'Coordinateur',
      'Administrateur',
    ]);
  });

  testWidgets('the common header exposes every journey identity', (
    tester,
  ) async {
    for (final journey in MobSanteJourney.values) {
      await tester.pumpWidget(_HeaderHarness(journey: journey));

      expect(find.text('MobSanté'), findsOneWidget);
      expect(find.text(MobSanteJourneyHeader.slogan), findsOneWidget);
      expect(find.text(journey.title), findsOneWidget);
      expect(find.text(journey.subtitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the common slogan stays on one line at 390 logical pixels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _HeaderHarness(
        journey: MobSanteJourney.professional,
        size: Size(390, 844),
      ),
    );

    final slogan = find.byKey(const Key('mobsante-product-slogan'));
    final text = tester.widget<Text>(slogan);
    expect(text.data, isNot(contains('\n')));
    expect(text.maxLines, 1);
    expect(find.byKey(const Key('mobsante-slogan-one-line')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header remains responsive with Dynamic Type and dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _HeaderHarness(
        journey: MobSanteJourney.responsible,
        textScaler: TextScaler.linear(2),
        brightness: Brightness.dark,
        disableAnimations: true,
        viewPadding: EdgeInsets.only(top: 24),
        pageTitle: 'Demain dans mon établissement',
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('mobsante-product-slogan')))
          .maxLines,
      isNull,
    );
    expect(find.byKey(const Key('mobsante-slogan-one-line')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('mobsante-journey-header'))).dy,
      greaterThanOrEqualTo(24),
    );
    expect(
      Theme.of(
        tester.element(find.byKey(const Key('mobsante-journey-header'))),
      ).brightness,
      Brightness.dark,
    );
    expect(
      tester
          .widget<AnimatedSize>(find.byKey(const Key('role-page-title')))
          .duration,
      Duration.zero,
    );
  });

  testWidgets('VoiceOver receives the product and heading hierarchy', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const _HeaderHarness(
        journey: MobSanteJourney.coordinator,
        pageTitle: 'Pilotage territorial',
      ),
    );

    final productIdentity = tester.getSemantics(
      find.byKey(const Key('mobsante-product-identity')),
    );
    expect(
      productIdentity.label,
      contains(
        'MobSanté. Le bon professionnel, au bon endroit, au bon moment.',
      ),
    );
    final journeyTitle = tester.getSemantics(
      find.byKey(const Key('mobsante-journey-title-coordinator')),
    );
    expect(journeyTitle.flagsCollection.isHeader, isTrue);
    final pageTitle = tester.getSemantics(
      find.byKey(const Key('role-page-title')),
    );
    expect(pageTitle.flagsCollection.isHeader, isTrue);
    semantics.dispose();
  });
}

class _HeaderHarness extends StatelessWidget {
  const _HeaderHarness({
    required this.journey,
    this.textScaler = TextScaler.noScaling,
    this.brightness = Brightness.light,
    this.disableAnimations = false,
    this.viewPadding = EdgeInsets.zero,
    this.pageTitle,
    this.size = const Size(320, 568),
  });

  final MobSanteJourney journey;
  final TextScaler textScaler;
  final Brightness brightness;
  final bool disableAnimations;
  final EdgeInsets viewPadding;
  final String? pageTitle;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: textScaler,
          platformBrightness: brightness,
          disableAnimations: disableAnimations,
          padding: viewPadding,
        ),
        child: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: MobSanteJourneyHeader(
                journey: journey,
                pageTitle: pageTitle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
