import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/config/app_identity.dart';
import 'package:interface_incendies_gironde/firebase_startup_gate.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/coordinator_shell.dart';
import 'package:interface_incendies_gironde/screens/professional_shell.dart';
import 'package:interface_incendies_gironde/screens/responsible_shell.dart';
import 'package:interface_incendies_gironde/screens/splash_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';
import 'package:interface_incendies_gironde/utils/app_page_route.dart';
import 'package:interface_incendies_gironde/widgets/v5_secondary_navigation.dart';

void main() {
  testWidgets('all three root journeys keep light system surfaces', (
    tester,
  ) async {
    await _expectLightRoot(
      tester,
      repository: MockCoordinationRepository(responsibleAccess: null),
      shell: find.byType(ProfessionalShell),
    );
    await _expectLightRoot(
      tester,
      repository: MockCoordinationRepository(
        responsibleAccess: const ResponsibleAccess(
          uid: 'system-bars-responsible',
          role: ResponsibleRole.siteManager,
          locationIds: {'ehpad-merignac'},
          active: true,
        ),
      ),
      shell: find.byType(ResponsibleShell),
    );
    await _expectLightRoot(
      tester,
      repository: MockCoordinationRepository(),
      shell: find.byType(CoordinatorShell),
    );
  });

  testWidgets('secondary navigation and back keep the complete light style', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: AppTheme.systemSurface,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) => const Scaffold(
                      appBar: V5SecondaryNavigationBar(title: 'Secondaire'),
                      body: SizedBox.expand(),
                    ),
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    final secondaryRegion = tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.descendant(
            of: find.byType(V5SecondaryNavigationBar),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          ),
        );
    expect(secondaryRegion.value, AppTheme.lightSystemUiOverlayStyle);

    await tester.tap(find.byType(V5BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);
    _expectOnlyLightApplicationChrome(tester);
  });

  testWidgets('non-admin shell never exposes a runtime perspective selector', (
    tester,
  ) async {
    await tester.pumpWidget(
      FireCoordinationApp(repository: MockCoordinationRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();
    expect(find.byType(CoordinatorShell), findsOneWidget);
    expect(find.byKey(const Key('perspective-professional')), findsNothing);
    _expectOnlyLightApplicationChrome(tester);
  });

  testWidgets('splash exits from navy chrome to the light application chrome', (
    tester,
  ) async {
    final startup = Completer<CoordinationRepository>();
    await tester.pumpWidget(FirebaseStartupGate(startup: () => startup.future));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      _systemStyles(tester),
      contains(AppTheme.splashSystemUiOverlayStyle),
    );

    startup.complete(MockCoordinationRepository());
    await tester.pump(AppIdentity.splashRevealDuration);
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    _expectOnlyLightApplicationChrome(tester);
  });

  test('PWA paints navy before CSS and restores application chrome later', () {
    final index = File('web/index.html').readAsStringSync();
    final manifest = File('web/manifest.json').readAsStringSync();

    expect(index, contains('<meta name="theme-color" content="#10233E">'));
    expect(
      index,
      contains(
        '<html class="mobsante-splash-active" '
        'style="background-color: #10233E;">',
      ),
    );
    expect(index, contains('<body style="background-color: #10233E;">'));
    expect(index, contains('background: #F6F7F8;'));
    expect(index, contains('html.mobsante-splash-active body'));
    expect(index, contains('#startup-splash'));
    expect(index, contains('visibility: hidden'));
    expect(index, contains('mobsante-splash-composed'));
    expect(index, contains('image.decode()'));
    expect(index, contains('mobsante-native-splash-composed'));
    expect(index, contains('padding: var(--startup-splash-safe-block) 28px;'));
    expect(manifest, contains('"theme_color": "#F6F7F8"'));
  });

  test('iPhone safe areas cannot recenter the native splash', () {
    final index = File('web/index.html').readAsStringSync();

    expect(
      index,
      contains(
        '--startup-splash-safe-block: max(\n'
        '        20px,\n'
        '        env(safe-area-inset-top),\n'
        '        env(safe-area-inset-bottom)\n'
        '      );',
      ),
    );
    expect(index, isNot(contains('max(20px, env(safe-area-inset-top)) 28px')));

    const viewportHeight = 844.0;
    const contentHeight = 407.125;
    double centeredTop(double safeBlock) =>
        safeBlock + (viewportHeight - 2 * safeBlock - contentHeight) / 2;
    double asymmetricTop(double safeTop, double safeBottom) =>
        safeTop + (viewportHeight - safeTop - safeBottom - contentHeight) / 2;

    expect(centeredTop(20), centeredTop(47));
    expect(
      asymmetricTop(47, 34) - asymmetricTop(20, 20),
      6.5,
      reason:
          'Le padding vertical asymétrique précédent décalait tout le bloc '
          'de 6,5 px sur un iPhone 390 × 844.',
    );
  });

  test(
    'native splash has one handoff owned by the final application frame',
    () {
      final splashScreen = File(
        'lib/screens/splash_screen.dart',
      ).readAsStringSync();
      final appShell = File('lib/screens/app_shell.dart').readAsStringSync();
      final systemTheme = File(
        'lib/utils/system_theme_web.dart',
      ).readAsStringSync();

      expect(splashScreen, isNot(contains('dismissNativeStartupSplash();')));
      expect(
        appShell,
        contains("markStartupEvent('mobsante-app-shell-ready')"),
      );
      expect(appShell, contains('revealApplication();'));
      expect(systemTheme, contains('if (_applicationRevealed)'));
      expect(systemTheme, contains('_applyPendingApplicationChrome();'));
      expect(
        RegExp(r'dismissNativeStartupSplash\(\);').allMatches(systemTheme),
        hasLength(1),
        reason:
            'Le splash HTML ne doit disparaître que pendant la révélation du '
            'frame applicatif final.',
      );
    },
  );
}

Future<void> _expectLightRoot(
  WidgetTester tester, {
  required CoordinationRepository repository,
  required Finder shell,
}) async {
  await tester.pumpWidget(FireCoordinationApp(repository: repository));
  await tester.pumpAndSettle();
  expect(shell, findsOneWidget);
  _expectOnlyLightApplicationChrome(tester);
  await tester.pumpWidget(const SizedBox.shrink());
}

void _expectOnlyLightApplicationChrome(WidgetTester tester) {
  final styles = _systemStyles(tester);
  expect(styles, contains(AppTheme.lightSystemUiOverlayStyle));
  expect(styles, isNot(contains(AppTheme.darkSystemUiOverlayStyle)));
  expect(styles, isNot(contains(AppTheme.splashSystemUiOverlayStyle)));
  final style = AppTheme.lightSystemUiOverlayStyle;
  expect(style.statusBarColor, Colors.transparent);
  expect(style.systemNavigationBarColor, V5Colors.light.canvas);
  expect(style.systemNavigationBarDividerColor, V5Colors.light.canvas);
}

List<SystemUiOverlayStyle> _systemStyles(WidgetTester tester) => tester
    .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    )
    .map((region) => region.value)
    .toList(growable: false);
