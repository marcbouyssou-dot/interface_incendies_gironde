import 'dart:collection';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'utils/system_theme.dart';

typedef FirebaseBootstrapStep = Future<void> Function();
typedef FirebaseAppCheckActivation<T extends Object> =
    Future<void> Function(T app);

@visibleForTesting
class FirebaseAppCheckActivationRegistry<T extends Object> {
  final Map<T, Future<void>> _activations = HashMap<T, Future<void>>.identity();

  Future<void> activateOnce(
    T app,
    FirebaseAppCheckActivation<T> activate,
  ) async {
    final pendingActivation = _activations[app];
    if (pendingActivation != null) return pendingActivation;

    final activation = activate(app);
    _activations[app] = activation;
    try {
      await activation;
    } catch (_) {
      if (identical(_activations[app], activation)) {
        _activations.remove(app);
      }
      rethrow;
    }
  }
}

class FirebaseAppCheckProviders {
  const FirebaseAppCheckProviders({
    required this.web,
    required this.android,
    required this.apple,
  });

  final WebProvider? web;
  final AndroidAppCheckProvider android;
  final AppleAppCheckProvider apple;
}

abstract final class FirebaseBootstrap {
  static const enabled = bool.fromEnvironment('USE_FIREBASE');
  static const _webRecaptchaV3SiteKey = String.fromEnvironment(
    'FIREBASE_APP_CHECK_RECAPTCHA_V3_SITE_KEY',
  );
  static final FirebaseAppCheckActivationRegistry<FirebaseApp>
  _appCheckActivations = FirebaseAppCheckActivationRegistry<FirebaseApp>();

  static Future<FirebaseApp> initialize() async {
    late FirebaseApp app;
    await initializeInOrder(
      initializeFirebase: () async {
        markStartupEvent('mobsante-firebase-start');
        app = Firebase.apps.isNotEmpty
            ? Firebase.app()
            : await Firebase.initializeApp(
                options: const FirebaseOptions(
                  apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
                  appId: String.fromEnvironment('FIREBASE_APP_ID'),
                  messagingSenderId: String.fromEnvironment(
                    'FIREBASE_MESSAGING_SENDER_ID',
                  ),
                  projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
                  authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
                  storageBucket: String.fromEnvironment(
                    'FIREBASE_STORAGE_BUCKET',
                  ),
                ),
              );
        markStartupEvent('mobsante-firebase-ready');
      },
      initializeAppCheck: () async {
        markStartupEvent('mobsante-app-check-start');
        await activateAppCheck(app);
        markStartupEvent('mobsante-app-check-ready');
      },
    );
    return app;
  }

  @visibleForTesting
  static Future<void> initializeInOrder({
    required FirebaseBootstrapStep initializeFirebase,
    required FirebaseBootstrapStep initializeAppCheck,
  }) async {
    await initializeFirebase();
    await initializeAppCheck();
  }

  @visibleForTesting
  static FirebaseAppCheckProviders appCheckProvidersFor({
    required bool isWeb,
    required bool isDebugBuild,
    required String webRecaptchaV3SiteKey,
  }) {
    if (isDebugBuild) {
      return FirebaseAppCheckProviders(
        web: isWeb ? WebDebugProvider() : null,
        android: const AndroidDebugProvider(),
        apple: const AppleDebugProvider(),
      );
    }
    final siteKey = webRecaptchaV3SiteKey.trim();
    if (isWeb && siteKey.isEmpty) {
      throw StateError(
        'FIREBASE_APP_CHECK_RECAPTCHA_V3_SITE_KEY est requise sur Web.',
      );
    }
    return FirebaseAppCheckProviders(
      web: isWeb ? ReCaptchaV3Provider(siteKey) : null,
      android: const AndroidPlayIntegrityProvider(),
      apple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }

  static Future<void> _activateAppCheck(FirebaseApp app) {
    final providers = appCheckProvidersFor(
      isWeb: kIsWeb,
      isDebugBuild: kDebugMode,
      webRecaptchaV3SiteKey: _webRecaptchaV3SiteKey,
    );
    return FirebaseAppCheck.instanceFor(app: app).activate(
      providerWeb: providers.web,
      providerAndroid: providers.android,
      providerApple: providers.apple,
    );
  }

  static Future<void> activateAppCheck(FirebaseApp app) =>
      _appCheckActivations.activateOnce(app, _activateAppCheck);
}
