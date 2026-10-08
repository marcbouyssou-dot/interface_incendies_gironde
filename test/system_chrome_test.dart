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

  testWidgets('splash and application keep light system chrome', (
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

  test('PWA paints light splash and iPhone safe areas from first frame', () {
    final index = File('web/index.html').readAsStringSync();
    final manifest = File('web/manifest.json').readAsStringSync();

    expect(index, contains('<meta name="theme-color" content="#F6F7F8">'));
    expect(
      index,
      contains('<meta name="apple-mobile-web-app-capable" content="yes">'),
    );
    expect(
      index,
      contains(
        '<meta name="apple-mobile-web-app-status-bar-style" content="default">',
      ),
    );
    expect(
      index,
      contains(
        '<html class="mobsante-splash-active" '
        'style="background-color: #F6F7F8;">',
      ),
    );
    expect(index, contains('<body style="background-color: #F6F7F8;">'));
    expect(index, contains('background: #F6F7F8;'));
    expect(index, isNot(contains('html.mobsante-splash-active body')));
    expect(index, contains('#startup-splash'));
    final nativeSplash = RegExp(
      r'#startup-splash\s*\{([^}]*)\}',
      dotAll: true,
    ).firstMatch(index);
    expect(nativeSplash, isNotNull);
    expect(nativeSplash!.group(1), contains('background: #F6F7F8;'));
    expect(nativeSplash.group(1), isNot(contains('background: #10233E;')));
    final contentRule = RegExp(
      r'\.startup-splash__content\s*\{([^}]*)\}',
      dotAll: true,
    ).firstMatch(index);
    expect(contentRule, isNotNull);
    expect(contentRule!.group(1), isNot(contains('visibility: hidden')));
    expect(
      index,
      isNot(contains('html.mobsante-splash-composed .startup-splash__content')),
    );
    expect(index, contains('<h1 class="startup-splash__title">MobSanté</h1>'));
    expect(
      index,
      contains(
        '<p class="startup-splash__subtitle">'
        '${AppIdentity.productSubtitle}</p>',
      ),
    );
    expect(index, isNot(contains('Incendies Gironde')));
    expect(index, isNot(contains('URPS MK NA')));
    expect(index, isNot(contains('mobilization_flame.png')));
    final imagesRule = RegExp(
      r'\.startup-splash__pictogram\s*\{([^}]*)\}',
      dotAll: true,
    ).firstMatch(index);
    expect(imagesRule, isNotNull);
    expect(imagesRule!.group(1), contains('visibility: hidden'));
    final readyRule = RegExp(
      r'\.startup-splash__image-ready\s*\{([^}]*)\}',
      dotAll: true,
    ).firstMatch(index);
    expect(readyRule, isNotNull);
    expect(readyRule!.group(1), contains('visibility: visible'));
    expect(index, contains('image.naturalWidth > 0'));
    expect(index, contains('images.forEach(revealImage)'));
    expect(index, isNot(contains('Promise.all(images.map')));
    expect(index, contains('mobsante-splash-composed'));
    expect(index, contains('image.decode()'));
    expect(index, contains('mobsante-native-splash-composed'));
    expect(index, contains('padding: var(--startup-splash-safe-block) 28px;'));
    expect(manifest, contains('"theme_color": "#F6F7F8"'));
    expect(manifest, contains('"background_color": "#F6F7F8"'));
    final systemTheme = File(
      'lib/utils/system_theme_web.dart',
    ).readAsStringSync();
    expect(systemTheme, isNot(contains("'black-translucent'")));
    expect(systemTheme, isNot(contains("'#0D1622'")));
  });

  test('MapLibre and Flutter bootstrap defer in dependency order', () {
    final index = File('web/index.html').readAsStringSync();
    const mapScript =
        '<script src="https://unpkg.com/maplibre-gl@5.24.0/dist/maplibre-gl.js" defer></script>';
    const bootstrapScript =
        '<script src="flutter_bootstrap.js" defer></script>';

    expect(index, contains(mapScript));
    expect(index, contains(bootstrapScript));
    expect(index.indexOf(mapScript), lessThan(index.indexOf(bootstrapScript)));
    expect(index, isNot(contains('maplibre-gl.js"></script>')));
    expect(index, isNot(contains('flutter_bootstrap.js" async')));
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
      final index = File('web/index.html').readAsStringSync();

      expect(splashScreen, isNot(contains('dismissNativeStartupSplash();')));
      expect(
        appShell,
        contains("markStartupEvent('mobsante-app-shell-ready')"),
      );
      expect(appShell, contains('revealApplication();'));
      expect(systemTheme, contains('if (_applicationRevealed)'));
      expect(systemTheme, contains('_applyPendingApplicationChrome();'));
      expect(index, isNot(contains('splash.remove()')));
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
  expect(
    AppTheme.splashSystemUiOverlayStyle,
    AppTheme.lightSystemUiOverlayStyle,
  );
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
