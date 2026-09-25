// Runs only under `flutter test --platform=chrome`: this file imports
// dart:html/dart:js_interop transitively via push_notification_gateway_web.dart,
// which the default VM test runner cannot compile. @TestOn('browser') makes
// the default `flutter test` run skip this file gracefully instead of
// failing to load it (matching the sibling push_notification_gateway_web_test.dart).
//
// No Firebase app is initialized anywhere in this test process, on purpose:
// that reproduces, organically and without mocking, the exact browser
// condition that used to crash the app ("Firebase Messaging's JS bridge
// isn't usable yet") — proving the fail-safe guard added to
// FirebaseWebPushNotificationGateway without needing to fake or inject
// anything.
//
// Kept as a separate file from push_notification_gateway_web_test.dart
// (which covers unrelated error-classification/VAPID-matching logic ported
// from origin/main) to avoid overwriting either set of tests.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/services/push_notification_gateway_web.dart';

void main() {
  final gateway = FirebaseWebPushNotificationGateway.instance;

  test(
    'permissionState resolves to unsupported instead of throwing when '
    'Firebase Messaging is unusable',
    () async {
      final state = await gateway.permissionState();
      expect(state, PushPermissionState.unsupported);
    },
  );

  test(
    'activate resolves to an unsupported result instead of throwing when '
    'Firebase Messaging is unusable',
    () async {
      final result = await gateway.activate();
      expect(result.state, PushPermissionState.unsupported);
      expect(result.registration, isNull);
    },
  );

  test(
    'registrationUpdates never throws while being obtained, even when '
    'Firebase Messaging is unusable',
    () {
      expect(() => gateway.registrationUpdates, returnsNormally);
    },
  );

  test('updateBadge does not throw regardless of Firebase Messaging state', () async {
    await expectLater(gateway.updateBadge(1), completes);
    await expectLater(gateway.updateBadge(0), completes);
  });

  test(
    'reconcileRegistration resolves to null instead of throwing when '
    'Firebase Messaging is unusable',
    () async {
      final registration = await gateway.reconcileRegistration();
      expect(registration, isNull);
    },
  );

  test(
    'renewRegistration resolves to null instead of throwing when '
    'Firebase Messaging is unusable',
    () async {
      final registration = await gateway.renewRegistration();
      expect(registration, isNull);
    },
  );

  test(
    'recoverStaleRegistration resolves to null instead of throwing when '
    'Firebase Messaging is unusable',
    () async {
      final registration = await gateway.recoverStaleRegistration();
      expect(registration, isNull);
    },
  );
}
