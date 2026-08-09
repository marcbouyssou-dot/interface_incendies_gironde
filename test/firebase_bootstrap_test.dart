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
}
