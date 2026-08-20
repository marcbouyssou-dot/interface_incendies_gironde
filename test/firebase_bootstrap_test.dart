import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/firebase_bootstrap.dart';

void main() {
  test('App Check est initialisé après Firebase et bloque la suite', () async {
    final firebaseReady = Completer<void>();
    final appCheckReady = Completer<void>();
    final events = <String>[];

    final initialization = FirebaseBootstrap.initializeInOrder(
      initializeFirebase: () async {
        events.add('firebase:start');
        await firebaseReady.future;
        events.add('firebase:ready');
      },
      initializeAppCheck: () async {
        events.add('app-check:start');
        await appCheckReady.future;
        events.add('app-check:ready');
      },
    ).then((_) => events.add('services:available'));

    expect(events, ['firebase:start']);
    firebaseReady.complete();
    await Future<void>.delayed(Duration.zero);
    expect(events, ['firebase:start', 'firebase:ready', 'app-check:start']);
    expect(events, isNot(contains('services:available')));

    appCheckReady.complete();
    await initialization;
    expect(events, [
      'firebase:start',
      'firebase:ready',
      'app-check:start',
      'app-check:ready',
      'services:available',
    ]);
  });

  test('la production sélectionne les providers d’attestation', () {
    final providers = FirebaseBootstrap.appCheckProvidersFor(
      isWeb: true,
      isDebugBuild: false,
      webRecaptchaV3SiteKey: 'public-test-site-key',
    );

    expect(providers.web, isA<ReCaptchaV3Provider>());
    expect(providers.android, isA<AndroidPlayIntegrityProvider>());
    expect(
      providers.apple,
      isA<AppleAppAttestWithDeviceCheckFallbackProvider>(),
    );
  });

  test('une build Web de production refuse une site key absente', () {
    expect(
      () => FirebaseBootstrap.appCheckProvidersFor(
        isWeb: true,
        isDebugBuild: false,
        webRecaptchaV3SiteKey: '',
      ),
      throwsStateError,
    );
  });

  test('le provider debug officiel reste limité aux builds debug', () {
    final debugProviders = FirebaseBootstrap.appCheckProvidersFor(
      isWeb: true,
      isDebugBuild: true,
      webRecaptchaV3SiteKey: '',
    );
    expect(debugProviders.web, isA<WebDebugProvider>());
    expect(debugProviders.android, isA<AndroidDebugProvider>());
    expect(debugProviders.apple, isA<AppleDebugProvider>());

    expect(
      () => FirebaseBootstrap.appCheckProvidersFor(
        isWeb: true,
        isDebugBuild: false,
        webRecaptchaV3SiteKey: '',
      ),
      throwsStateError,
    );
  });

  test('App Check est activé séparément pour default et responsible', () async {
    final registry = FirebaseAppCheckActivationRegistry<Object>();
    final defaultApp = Object();
    final responsibleApp = Object();
    final activatedApps = <Object>[];

    Future<void> activate(Object app) async => activatedApps.add(app);

    await registry.activateOnce(defaultApp, activate);
    await registry.activateOnce(responsibleApp, activate);

    expect(activatedApps, [defaultApp, responsibleApp]);
  });

  test('le cache App Check évite une double activation par app', () async {
    final registry = FirebaseAppCheckActivationRegistry<Object>();
    final defaultApp = Object();
    final responsibleApp = Object();
    final activations = <Object, int>{};

    Future<void> activate(Object app) async {
      activations.update(app, (count) => count + 1, ifAbsent: () => 1);
    }

    await Future.wait([
      registry.activateOnce(defaultApp, activate),
      registry.activateOnce(defaultApp, activate),
      registry.activateOnce(responsibleApp, activate),
      registry.activateOnce(responsibleApp, activate),
    ]);

    expect(activations[defaultApp], 1);
    expect(activations[responsibleApp], 1);
  });

  test('une activation App Check échouée peut être retentée', () async {
    final registry = FirebaseAppCheckActivationRegistry<Object>();
    final app = Object();
    var attempts = 0;

    Future<void> activate(Object _) async {
      attempts++;
      if (attempts == 1) throw StateError('App Check indisponible');
    }

    await expectLater(registry.activateOnce(app, activate), throwsStateError);
    await registry.activateOnce(app, activate);

    expect(attempts, 2);
  });
}
