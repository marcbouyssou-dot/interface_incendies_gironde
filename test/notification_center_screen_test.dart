import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/app_notification.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/notification_center_screen.dart';
import 'package:interface_incendies_gironde/services/push_notification_gateway.dart';
import 'package:interface_incendies_gironde/services/platform_administration_service.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';

void main() {
  final now = DateTime(2026, 8, 15, 12);

  test('missing VAPID configuration is reported as misconfigured', () {
    expect(
      resolveWebPushPermissionState(
        isSupported: true,
        vapidKey: '  ',
        permission: PushPermissionState.prompt,
      ),
      PushPermissionState.misconfigured,
    );
  });

  test('unsupported environment takes precedence over configuration', () {
    expect(
      resolveWebPushPermissionState(
        isSupported: false,
        vapidKey: '',
        permission: PushPermissionState.prompt,
      ),
      PushPermissionState.unsupported,
    );
  });

  test('supported and configured environment remains activable', () {
    expect(
      resolveWebPushPermissionState(
        isSupported: true,
        vapidKey: 'public-vapid-key',
        permission: PushPermissionState.prompt,
      ),
      PushPermissionState.prompt,
    );
  });

  test('normal activation traces granted permission', () {
    final traces = <String>[];

    emitPushActivationPermission(granted: true, trace: traces.add);

    expect(traces, [PushActivationTraceState.permissionGranted]);
  });

  test('normal activation traces denied permission', () {
    final traces = <String>[];

    emitPushActivationPermission(granted: false, trace: traces.add);

    expect(traces, [PushActivationTraceState.permissionDenied]);
  });

  test(
    'normal activation traces successful getToken without token data',
    () async {
      final traces = <String>[];

      final token = await runTracedPushActivationTokenRequest(
        getToken: () async => 'private-activation-token',
        trace: traces.add,
      );

      expect(token, 'private-activation-token');
      expect(traces, [
        PushActivationTraceState.getTokenStarted,
        PushActivationTraceState.getTokenOk,
      ]);
      expect(traces.where((state) => state.contains('private')), isEmpty);
    },
  );

  test('normal activation traces failed getToken without raw error', () async {
    final traces = <String>[];

    await expectLater(
      runTracedPushActivationTokenRequest(
        getToken: () async => throw StateError('private-activation-error'),
        trace: traces.add,
      ),
      throwsStateError,
    );

    expect(traces, [
      PushActivationTraceState.getTokenStarted,
      PushActivationTraceState.getTokenFailed,
    ]);
    expect(traces.where((state) => state.contains('private')), isEmpty);
  });

  test('normal activation token comparison stays boolean-only', () {
    expect(didPushTokenChange('old-token', 'new-token'), isTrue);
    expect(didPushTokenChange('same-token', 'same-token'), isFalse);
  });

  test('normal activation trace failure has no token-request effect', () async {
    var getTokenCalls = 0;

    emitPushActivationPermission(
      granted: true,
      trace: (_) => throw StateError('unavailable-trace-sink'),
    );
    final token = await runTracedPushActivationTokenRequest(
      getToken: () async {
        getTokenCalls += 1;
        return 'private-activation-token';
      },
      trace: (_) => throw StateError('unavailable-trace-sink'),
    );

    expect(token, 'private-activation-token');
    expect(getTokenCalls, 1);
  });

  test(
    'admin Firestore subscription read traces a successful result',
    () async {
      final traces = <String>[];

      final state = await runTracedAdminSubscriptionRead(
        read: () async => PushSubscriptionState.active,
        trace: traces.add,
      );

      expect(state, PushSubscriptionState.active);
      expect(traces, [
        AdminNotificationHydrationTraceState.firestoreSubscriptionReadStarted,
        AdminNotificationHydrationTraceState.firestoreSubscriptionReadOk,
      ]);
    },
  );

  test(
    'admin Firestore subscription read traces failure without details',
    () async {
      const sensitiveError = 'private-uid/private-installation/private-path';
      final traces = <String>[];

      await expectLater(
        runTracedAdminSubscriptionRead<PushSubscriptionState>(
          read: () async => throw StateError(sensitiveError),
          trace: traces.add,
        ),
        throwsStateError,
      );

      expect(traces, [
        AdminNotificationHydrationTraceState.firestoreSubscriptionReadStarted,
        AdminNotificationHydrationTraceState.firestoreSubscriptionReadFailed,
      ]);
      expect(traces.where((state) => state.contains('private')), isEmpty);
    },
  );

  testWidgets(
    'admin Firestore timeout observes a pending read without changing it',
    (tester) async {
      final traces = <String>[];
      final completer = Completer<PushSubscriptionState>();
      var completed = false;
      final read =
          runTracedAdminSubscriptionRead(
            read: () => completer.future,
            trace: traces.add,
          ).then((state) {
            completed = true;
            return state;
          });

      await tester.pump(const Duration(seconds: 14));
      expect(completed, isFalse);
      expect(
        traces,
        isNot(
          contains(
            AdminNotificationHydrationTraceState
                .firestoreSubscriptionReadTimeout,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(completed, isFalse);
      expect(traces, [
        AdminNotificationHydrationTraceState.firestoreSubscriptionReadStarted,
        AdminNotificationHydrationTraceState.firestoreSubscriptionReadTimeout,
      ]);

      completer.complete(PushSubscriptionState.active);
      await tester.pump();
      expect(await read, PushSubscriptionState.active);
      expect(traces, [
        AdminNotificationHydrationTraceState.firestoreSubscriptionReadStarted,
        AdminNotificationHydrationTraceState.firestoreSubscriptionReadTimeout,
        AdminNotificationHydrationTraceState.firestoreSubscriptionReadOk,
      ]);
    },
  );

  test('admin preflight traces STARTED then OK', () async {
    final traces = <String>[];

    final result = await runTracedAdminPreflight(
      preflight: () async => true,
      trace: traces.add,
    );

    expect(result, isTrue);
    expect(traces, [
      AdminNotificationHydrationTraceState.preflightStarted,
      AdminNotificationHydrationTraceState.preflightOk,
    ]);
  });

  test('admin preflight traces STARTED then FAILED', () async {
    final traces = <String>[];

    final result = await runTracedAdminPreflight(
      preflight: () async => false,
      trace: traces.add,
    );

    expect(result, isFalse);
    expect(traces, [
      AdminNotificationHydrationTraceState.preflightStarted,
      AdminNotificationHydrationTraceState.preflightFailed,
    ]);
  });

  test('admin local subscription check traces OK', () async {
    final traces = <String>[];

    final result = await runTracedAdminLocalSubscriptionCheck(
      check: () async => true,
      trace: traces.add,
    );

    expect(result, isTrue);
    expect(traces, [
      AdminNotificationHydrationTraceState.localSubscriptionCheckStarted,
      AdminNotificationHydrationTraceState.localSubscriptionCheckOk,
    ]);
  });

  test('admin local subscription check traces FAILED', () async {
    final traces = <String>[];

    final result = await runTracedAdminLocalSubscriptionCheck(
      check: () async => false,
      trace: traces.add,
    );

    expect(result, isFalse);
    expect(traces, [
      AdminNotificationHydrationTraceState.localSubscriptionCheckStarted,
      AdminNotificationHydrationTraceState.localSubscriptionCheckFailed,
    ]);
  });

  test(
    'admin local subscription exception stays failed and non-sensitive',
    () async {
      const sensitiveError = 'private-worker-endpoint-vapid-error';
      final traces = <String>[];

      await expectLater(
        runTracedAdminLocalSubscriptionCheck(
          check: () async => throw StateError(sensitiveError),
          trace: traces.add,
        ),
        throwsStateError,
      );

      expect(traces, [
        AdminNotificationHydrationTraceState.localSubscriptionCheckStarted,
        AdminNotificationHydrationTraceState.localSubscriptionCheckFailed,
      ]);
      expect(traces.where((state) => state.contains('private')), isEmpty);
    },
  );

  testWidgets(
    'admin local subscription timeout observes without changing the check',
    (tester) async {
      final traces = <String>[];
      final completer = Completer<bool>();
      var completed = false;
      final check =
          runTracedAdminLocalSubscriptionCheck(
            check: () => completer.future,
            trace: traces.add,
          ).then((result) {
            completed = true;
            return result;
          });

      await tester.pump(const Duration(seconds: 14));
      expect(completed, isFalse);
      expect(
        traces,
        isNot(
          contains(
            AdminNotificationHydrationTraceState.localSubscriptionCheckTimeout,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(completed, isFalse);
      expect(traces, [
        AdminNotificationHydrationTraceState.localSubscriptionCheckStarted,
        AdminNotificationHydrationTraceState.localSubscriptionCheckTimeout,
      ]);

      completer.complete(true);
      await tester.pump();
      expect(await check, isTrue);
      expect(traces, [
        AdminNotificationHydrationTraceState.localSubscriptionCheckStarted,
        AdminNotificationHydrationTraceState.localSubscriptionCheckTimeout,
        AdminNotificationHydrationTraceState.localSubscriptionCheckOk,
      ]);
    },
  );

  test('admin trace sink failures do not affect reads or preflight', () async {
    var readCalls = 0;
    var localCheckCalls = 0;
    var preflightCalls = 0;
    void failingTrace(String _) => throw StateError('trace-sink-unavailable');

    final state = await runTracedAdminSubscriptionRead(
      read: () async {
        readCalls += 1;
        return PushSubscriptionState.active;
      },
      trace: failingTrace,
    );
    final localReady = await runTracedAdminLocalSubscriptionCheck(
      check: () async {
        localCheckCalls += 1;
        return true;
      },
      trace: failingTrace,
    );
    final targetAvailable = await runTracedAdminPreflight(
      preflight: () async {
        preflightCalls += 1;
        return true;
      },
      trace: failingTrace,
    );

    expect(state, PushSubscriptionState.active);
    expect(localReady, isTrue);
    expect(targetAvailable, isTrue);
    expect(readCalls, 1);
    expect(localCheckCalls, 1);
    expect(preflightCalls, 1);
  });

  test(
    'stale token renewal traces delete then get without sensitive data',
    () async {
      final traces = <String>[];

      final token = await runTracedStaleTokenRenewal(
        deleteToken: () async {},
        getToken: () async => 'private-token',
        trace: traces.add,
      );

      expect(token, 'private-token');
      expect(traces, [
        PushRenewalTraceState.deleteTokenStarted,
        PushRenewalTraceState.deleteTokenOk,
        PushRenewalTraceState.getTokenStarted,
        PushRenewalTraceState.getTokenOk,
      ]);
      expect(traces.where((state) => state.contains('private-token')), isEmpty);
    },
  );

  test('stale token renewal stops and traces a delete failure', () async {
    final traces = <String>[];
    var getTokenCalls = 0;

    await expectLater(
      runTracedStaleTokenRenewal(
        deleteToken: () async => throw StateError('private-delete-error'),
        getToken: () async {
          getTokenCalls += 1;
          return 'must-not-be-created';
        },
        trace: traces.add,
      ),
      throwsStateError,
    );

    expect(getTokenCalls, 0);
    expect(traces, [
      PushRenewalTraceState.deleteTokenStarted,
      PushRenewalTraceState.deleteTokenFailed,
    ]);
    expect(traces.where((state) => state.contains('private')), isEmpty);
  });

  test('stale token renewal traces a get failure after deletion', () async {
    final traces = <String>[];

    await expectLater(
      runTracedStaleTokenRenewal(
        deleteToken: () async {},
        getToken: () async => throw StateError('private-get-error'),
        trace: traces.add,
      ),
      throwsStateError,
    );

    expect(traces, [
      PushRenewalTraceState.deleteTokenStarted,
      PushRenewalTraceState.deleteTokenOk,
      PushRenewalTraceState.getTokenStarted,
      PushRenewalTraceState.getTokenFailed,
    ]);
    expect(traces.where((state) => state.contains('private')), isEmpty);
  });

  test('trace failures never affect stale token renewal', () async {
    var deleteTokenCalls = 0;
    var getTokenCalls = 0;

    final token = await runTracedStaleTokenRenewal(
      deleteToken: () async => deleteTokenCalls += 1,
      getToken: () async {
        getTokenCalls += 1;
        return 'private-token';
      },
      trace: (_) => throw StateError('unavailable-trace-sink'),
    );

    expect(token, 'private-token');
    expect(deleteTokenCalls, 1);
    expect(getTokenCalls, 1);
  });

  test(
    'stale push recovery unsubscribes before requesting one token',
    () async {
      final traces = <String>[];
      var unsubscribeCalls = 0;
      var getTokenCalls = 0;

      final token = await runTracedStalePushRecovery(
        unsubscribe: () async {
          unsubscribeCalls += 1;
          return true;
        },
        getToken: () async {
          getTokenCalls += 1;
          return 'private-recovered-token';
        },
        trace: traces.add,
      );

      expect(token, 'private-recovered-token');
      expect(unsubscribeCalls, 1);
      expect(getTokenCalls, 1);
      expect(traces, [
        PushRecoveryTraceState.unsubscribeStarted,
        PushRecoveryTraceState.unsubscribeOk,
        PushRecoveryTraceState.getTokenStarted,
        PushRecoveryTraceState.getTokenOk,
      ]);
      expect(traces.where((state) => state.contains('private')), isEmpty);
    },
  );

  test('stale push recovery stops when unsubscribe fails', () async {
    final traces = <String>[];
    var getTokenCalls = 0;

    final token = await runTracedStalePushRecovery(
      unsubscribe: () async => false,
      getToken: () async {
        getTokenCalls += 1;
        return 'must-not-be-created';
      },
      trace: traces.add,
    );

    expect(token, isNull);
    expect(getTokenCalls, 0);
    expect(traces, [
      PushRecoveryTraceState.unsubscribeStarted,
      PushRecoveryTraceState.unsubscribeFailed,
    ]);
  });

  test('unsubscribe instrumentation reports failed precheck', () {
    final traces = <String>[];

    tracePushUnsubscribePrecheck(passed: false, trace: traces.add);

    expect(traces, [
      PushRecoveryTraceState.unsubscribePrecheckFailed,
      PushRecoveryTraceState.subscriptionAfterFailure(
        PushSubscriptionAfterFailure.indeterminate,
      ),
    ]);
  });

  test('unsubscribe instrumentation reports successful precheck', () {
    final traces = <String>[];

    tracePushUnsubscribePrecheck(passed: true, trace: traces.add);

    expect(traces, [PushRecoveryTraceState.unsubscribePrecheckOk]);
  });

  test('unsubscribe instrumentation reports a true result', () async {
    final traces = <String>[];
    var inspections = 0;

    final result = await runTracedPushUnsubscribeCall(
      unsubscribe: () async => true,
      inspectSubscriptionAfterFailure: () async {
        inspections += 1;
        return PushSubscriptionAfterFailure.present;
      },
      classifyError: _classifyTestUnsubscribeError,
      trace: traces.add,
    );

    expect(result, isTrue);
    expect(inspections, 0);
    expect(traces, [
      PushRecoveryTraceState.unsubscribeCallStarted,
      PushRecoveryTraceState.unsubscribeResultTrue,
    ]);
  });

  test('unsubscribe instrumentation reports false and present', () async {
    final traces = <String>[];

    final result = await runTracedPushUnsubscribeCall(
      unsubscribe: () async => false,
      inspectSubscriptionAfterFailure: () async =>
          PushSubscriptionAfterFailure.present,
      classifyError: _classifyTestUnsubscribeError,
      trace: traces.add,
    );

    expect(result, isFalse);
    expect(traces, [
      PushRecoveryTraceState.unsubscribeCallStarted,
      PushRecoveryTraceState.unsubscribeResultFalse,
      PushRecoveryTraceState.subscriptionAfterFailure(
        PushSubscriptionAfterFailure.present,
      ),
    ]);
  });

  test('unsubscribe instrumentation reports DOMException safely', () async {
    final traces = <String>[];

    await expectLater(
      runTracedPushUnsubscribeCall(
        unsubscribe: () async => throw const _TestDomException(),
        inspectSubscriptionAfterFailure: () async =>
            PushSubscriptionAfterFailure.absent,
        classifyError: _classifyTestUnsubscribeError,
        trace: traces.add,
      ),
      throwsA(isA<_TestDomException>()),
    );

    expect(traces, [
      PushRecoveryTraceState.unsubscribeCallStarted,
      PushRecoveryTraceState.unsubscribeErrorName('AbortError'),
      PushRecoveryTraceState.unsubscribeErrorClass(
        PushUnsubscribeErrorClass.domException,
      ),
      PushRecoveryTraceState.subscriptionAfterFailure(
        PushSubscriptionAfterFailure.absent,
      ),
    ]);
  });

  test('unsubscribe instrumentation reports Error safely', () async {
    final traces = <String>[];

    await expectLater(
      runTracedPushUnsubscribeCall(
        unsubscribe: () async => throw StateError('private-error-message'),
        inspectSubscriptionAfterFailure: () async =>
            PushSubscriptionAfterFailure.present,
        classifyError: _classifyTestUnsubscribeError,
        trace: traces.add,
      ),
      throwsStateError,
    );

    expect(traces, [
      PushRecoveryTraceState.unsubscribeCallStarted,
      PushRecoveryTraceState.unsubscribeErrorName('Other'),
      PushRecoveryTraceState.unsubscribeErrorClass(
        PushUnsubscribeErrorClass.error,
      ),
      PushRecoveryTraceState.subscriptionAfterFailure(
        PushSubscriptionAfterFailure.present,
      ),
    ]);
    expect(traces.where((state) => state.contains('private')), isEmpty);
  });

  test('unsubscribe instrumentation reports Other safely', () async {
    final traces = <String>[];

    await expectLater(
      runTracedPushUnsubscribeCall(
        unsubscribe: () async => throw 'private-other-error',
        inspectSubscriptionAfterFailure: () async =>
            PushSubscriptionAfterFailure.indeterminate,
        classifyError: _classifyTestUnsubscribeError,
        trace: traces.add,
      ),
      throwsA('private-other-error'),
    );

    expect(traces, [
      PushRecoveryTraceState.unsubscribeCallStarted,
      PushRecoveryTraceState.unsubscribeErrorName('Other'),
      PushRecoveryTraceState.unsubscribeErrorClass(
        PushUnsubscribeErrorClass.other,
      ),
      PushRecoveryTraceState.subscriptionAfterFailure(
        PushSubscriptionAfterFailure.indeterminate,
      ),
    ]);
    expect(traces.where((state) => state.contains('private')), isEmpty);
  });

  test('unsubscribe instrumentation preserves original error and stack when '
      'inspection also fails', () async {
    final originalError = StateError('private-original-error');
    StackTrace? originalStack;
    Object? caughtError;
    StackTrace? caughtStack;

    try {
      await runTracedPushUnsubscribeCall(
        unsubscribe: () async {
          try {
            throw originalError;
          } catch (_, stackTrace) {
            originalStack = stackTrace;
            rethrow;
          }
        },
        inspectSubscriptionAfterFailure: () async =>
            throw StateError('private-inspection-error'),
        classifyError: _classifyTestUnsubscribeError,
        trace: (_) {},
      );
    } catch (error, stackTrace) {
      caughtError = error;
      caughtStack = stackTrace;
    }

    expect(identical(caughtError, originalError), isTrue);
    expect(caughtStack.toString(), originalStack.toString());
  });

  test(
    'unsubscribe instrumentation reports indeterminate inspection',
    () async {
      final traces = <String>[];

      final result = await runTracedPushUnsubscribeCall(
        unsubscribe: () async => false,
        inspectSubscriptionAfterFailure: () async =>
            throw StateError('private-inspection-error'),
        classifyError: _classifyTestUnsubscribeError,
        trace: traces.add,
      );

      expect(result, isFalse);
      expect(traces, [
        PushRecoveryTraceState.unsubscribeCallStarted,
        PushRecoveryTraceState.unsubscribeResultFalse,
        PushRecoveryTraceState.subscriptionAfterFailure(
          PushSubscriptionAfterFailure.indeterminate,
        ),
      ]);
      expect(traces.where((state) => state.contains('private')), isEmpty);
    },
  );

  test('unsubscribe instrumentation allowlists error names', () {
    expect(
      PushRecoveryTraceState.unsubscribeErrorName('AbortError'),
      'UNSUBSCRIBE_ERROR_NAME: AbortError',
    );
    expect(
      PushRecoveryTraceState.unsubscribeErrorName('private-error-name'),
      'UNSUBSCRIBE_ERROR_NAME: Other',
    );
  });

  test('unsubscribe trace sink failure has no functional effect', () async {
    var unsubscribeCalls = 0;
    var inspectionCalls = 0;

    tracePushUnsubscribePrecheck(
      passed: true,
      trace: (_) => throw StateError('unavailable-trace-sink'),
    );
    final result = await runTracedPushUnsubscribeCall(
      unsubscribe: () async {
        unsubscribeCalls += 1;
        return false;
      },
      inspectSubscriptionAfterFailure: () async {
        inspectionCalls += 1;
        return PushSubscriptionAfterFailure.present;
      },
      classifyError: _classifyTestUnsubscribeError,
      trace: (_) => throw StateError('unavailable-trace-sink'),
    );

    expect(result, isFalse);
    expect(unsubscribeCalls, 1);
    expect(inspectionCalls, 1);
  });

  test('stale push recovery reports a single getToken failure', () async {
    final traces = <String>[];
    var getTokenCalls = 0;

    await expectLater(
      runTracedStalePushRecovery(
        unsubscribe: () async => true,
        getToken: () async {
          getTokenCalls += 1;
          throw StateError('private-get-error');
        },
        trace: traces.add,
      ),
      throwsStateError,
    );

    expect(getTokenCalls, 1);
    expect(traces, [
      PushRecoveryTraceState.unsubscribeStarted,
      PushRecoveryTraceState.unsubscribeOk,
      PushRecoveryTraceState.getTokenStarted,
      PushRecoveryTraceState.getTokenFailed,
    ]);
    expect(traces.where((state) => state.contains('private')), isEmpty);
  });

  test(
    'Firebase messaging worker matcher accepts only the production shape',
    () {
      expect(
        isExpectedFirebaseMessagingServiceWorker(
          origin: 'https://mobsante.netlify.app',
          scope:
              'https://mobsante.netlify.app/firebase-cloud-messaging-push-scope',
          scriptUrl: 'https://mobsante.netlify.app/firebase-messaging-sw.js',
          state: 'activated',
        ),
        isTrue,
      );
      expect(
        isExpectedFirebaseMessagingServiceWorker(
          origin: 'https://mobsante.netlify.app',
          scope: 'https://mobsante.netlify.app/',
          scriptUrl: 'https://mobsante.netlify.app/flutter_service_worker.js',
          state: 'activated',
        ),
        isFalse,
      );
    },
  );

  test('concurrent stale recovery calls share one browser attempt', () async {
    final gateway = _FakePushGateway(
      permission: PushPermissionState.granted,
      renewedToken: 'renewed-token',
    );

    final first = gateway.recoverStaleRegistration();
    final second = gateway.recoverStaleRegistration();

    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);
    expect(gateway.recoveryCalls, 1);
    expect(gateway.unsubscribeCalls, 1);
    expect(gateway.tokenRequests, 1);
    expect(gateway.deleteTokenCalls, 0);
  });

  test('forced renewal invalidates a pending reconciliation result', () async {
    final completer = Completer<PushSubscriptionRegistration?>();
    final gateway = _FakePushGateway(
      permission: PushPermissionState.granted,
      renewedToken: 'renewed-token',
      reconciliationFuture: completer.future,
    );

    final reconciliation = gateway.reconcileRegistration();
    final renewal = gateway.renewRegistration();
    completer.complete(
      const PushSubscriptionRegistration(
        installationId: 'device-test',
        token: 'invalidated-token',
        platform: 'web',
      ),
    );

    expect(await reconciliation, isNull);
    expect((await renewal)?.token, 'renewed-token');
    expect((await gateway.reconcileRegistration())?.token, 'renewed-token');
    expect(gateway.renewalCalls, 1);
  });

  test('forced renewal supersedes a pending activation token', () async {
    final completer = Completer<PushSubscriptionRegistration?>();
    final gateway = _FakePushGateway(
      permission: PushPermissionState.granted,
      renewedToken: 'renewed-token',
      activationFuture: completer.future,
    );

    final activation = gateway.activate();
    final renewal = gateway.renewRegistration();
    completer.complete(
      const PushSubscriptionRegistration(
        installationId: 'device-test',
        token: 'superseded-activation-token',
        platform: 'web',
      ),
    );

    expect((await activation).registration?.token, 'renewed-token');
    expect((await renewal)?.token, 'renewed-token');
    expect((await gateway.reconcileRegistration())?.token, 'renewed-token');
  });

  AppNotification notification({
    String id = 'notification-a',
    String missionId = 'mission-merignac',
    DateTime? readAt,
  }) => AppNotification(
    id: id,
    eventId: 'event-$id',
    type: AppNotificationType.missionBecameCritical,
    title: 'Une mission devient critique',
    body: 'Mérignac · une action est nécessaire.',
    occurredAt: now,
    missionId: missionId,
    readAt: readAt,
  );

  void seedActiveSubscription(MockCoordinationRepository repository) {
    repository.pushSubscriptions['device-test'] =
        const PushSubscriptionRegistration(
          installationId: 'device-test',
          token: 'persisted-token',
          platform: 'web',
        );
  }

  Future<void> pumpCenter(
    WidgetTester tester, {
    required MockCoordinationRepository repository,
    required _FakePushGateway gateway,
    TargetedPushTestService? targetedPushTestService,
    String? initialNotificationId,
    ThemeMode themeMode = ThemeMode.light,
    double textScale = 1,
    bool reduceMotion = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepositoryScope(
        repository: repository,
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduceMotion,
            ),
            child: child!,
          ),
          home: NotificationCenterScreen(
            pushGateway: gateway,
            targetedPushTestService: targetedPushTestService,
            initialNotificationId: initialNotificationId,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('permission is requested only after explicit activation', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      initialNotifications: const [],
    );
    final gateway = _FakePushGateway();
    await pumpCenter(tester, repository: repository, gateway: gateway);

    expect(gateway.activationCalls, 0);
    expect(gateway.tokenRequests, 0);
    expect(repository.pushSubscriptionReadCalls, 0);
    expect(find.text('Aucune notification'), findsOneWidget);
    await tester.tap(find.byKey(const Key('activate-notifications')));
    await tester.pump();

    expect(gateway.activationCalls, 1);
    expect(gateway.tokenRequests, 1);
    expect(repository.pushSubscriptions.keys, contains('device-test'));
    expect(find.text('Notifications activées'), findsOneWidget);
  });

  testWidgets('non-admin never sees the targeted push test control', (
    tester,
  ) async {
    final repository = MockCoordinationRepository();
    seedActiveSubscription(repository);
    await pumpCenter(
      tester,
      repository: repository,
      gateway: _FakePushGateway(permission: PushPermissionState.granted),
    );

    expect(find.byKey(const Key('send-targeted-push-test')), findsNothing);
    expect(find.text('Diagnostic administrateur'), findsNothing);
  });

  testWidgets(
    'platform admin sees a test control for the current installation',
    (tester) async {
      final repository = MockCoordinationRepository();
      seedActiveSubscription(repository);
      final service = _FakeTargetedPushTestService();
      await pumpCenter(
        tester,
        repository: repository,
        gateway: _FakePushGateway(permission: PushPermissionState.granted),
        targetedPushTestService: service,
      );

      expect(find.text('Diagnostic administrateur'), findsOneWidget);
      expect(find.text('Envoyer une notification test'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('admin hydration traces identity, Firestore, then preflight', (
    tester,
  ) async {
    const sensitiveUid = 'private-admin-uid';
    final traces = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) traces.add(message);
    };
    try {
      final repository = _IdentityAwarePushRepository(
        failuresBeforeSuccess: 0,
        administrativeUid: sensitiveUid,
      );
      seedActiveSubscription(repository);

      await pumpCenter(
        tester,
        repository: repository,
        gateway: _FakePushGateway(permission: PushPermissionState.granted),
        targetedPushTestService: _FakeTargetedPushTestService(),
      );

      expect(traces, [
        AdminNotificationHydrationTraceState.identityReady,
        AdminNotificationHydrationTraceState.firestoreSubscriptionReadStarted,
        AdminNotificationHydrationTraceState.firestoreSubscriptionReadOk,
        AdminNotificationHydrationTraceState.identityRevalidationOk,
        AdminNotificationHydrationTraceState.localSubscriptionCheckStarted,
        AdminNotificationHydrationTraceState.localSubscriptionCheckOk,
        AdminNotificationHydrationTraceState.preflightStarted,
        AdminNotificationHydrationTraceState.preflightOk,
      ]);
      expect(traces.where((state) => state.contains(sensitiveUid)), isEmpty);
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets('admin hydration traces a failed identity revalidation', (
    tester,
  ) async {
    const initialUid = 'private-admin-before';
    const replacementUid = 'private-admin-after';
    final traces = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) traces.add(message);
    };
    try {
      final repository = _IdentityChangingAfterReadPushRepository(
        administrativeUid: initialUid,
        replacementUid: replacementUid,
      );
      seedActiveSubscription(repository);
      final service = _FakeTargetedPushTestService();

      await pumpCenter(
        tester,
        repository: repository,
        gateway: _FakePushGateway(permission: PushPermissionState.granted),
        targetedPushTestService: service,
      );

      expect(traces, [
        AdminNotificationHydrationTraceState.identityReady,
        AdminNotificationHydrationTraceState.firestoreSubscriptionReadStarted,
        AdminNotificationHydrationTraceState.firestoreSubscriptionReadOk,
        AdminNotificationHydrationTraceState.identityRevalidationFailed,
      ]);
      expect(service.availabilityChecks, isEmpty);
      expect(
        traces.where(
          (state) =>
              state.contains(initialUid) || state.contains(replacementUid),
        ),
        isEmpty,
      );
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets('admin can target this device without an identity subscription', (
    tester,
  ) async {
    final repository = MockCoordinationRepository();
    final service = _FakeTargetedPushTestService();
    await pumpCenter(
      tester,
      repository: repository,
      gateway: _FakePushGateway(permission: PushPermissionState.granted),
      targetedPushTestService: service,
    );

    final button = tester.widget<CupertinoButton>(
      find.descendant(
        of: find.byKey(const Key('send-targeted-push-test')),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(button.onPressed, isNotNull);
    expect(
      find.text(
        'Identité courante distincte de l’abonnement de l’installation.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('activate-notifications')), findsNothing);
    expect(repository.pushSubscriptions, isEmpty);
    expect(service.installationIds, isEmpty);
  });

  testWidgets('unresolved backend target disables the admin test control', (
    tester,
  ) async {
    final service = _FakeTargetedPushTestService(available: false);
    await pumpCenter(
      tester,
      repository: MockCoordinationRepository(),
      gateway: _FakePushGateway(permission: PushPermissionState.granted),
      targetedPushTestService: service,
    );

    final button = tester.widget<CupertinoButton>(
      find.descendant(
        of: find.byKey(const Key('send-targeted-push-test')),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('Aucune cible administrateur'), findsOneWidget);
  });

  testWidgets('cancelled confirmation never calls the targeted push service', (
    tester,
  ) async {
    final repository = MockCoordinationRepository();
    seedActiveSubscription(repository);
    final service = _FakeTargetedPushTestService();
    await pumpCenter(
      tester,
      repository: repository,
      gateway: _FakePushGateway(permission: PushPermissionState.granted),
      targetedPushTestService: service,
    );

    await tester.tap(find.byKey(const Key('send-targeted-push-test')));
    await tester.pumpAndSettle();
    expect(find.text('Envoyer une notification test ?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-targeted-push-test')));
    await tester.pumpAndSettle();

    expect(service.installationIds, isEmpty);
  });

  testWidgets('confirmed test calls once and reports success without token', (
    tester,
  ) async {
    const token = 'secret-fcm-token-never-rendered';
    final repository = MockCoordinationRepository();
    repository.pushSubscriptions['device-test'] =
        const PushSubscriptionRegistration(
          installationId: 'device-test',
          token: token,
          platform: 'web',
        );
    final service = _FakeTargetedPushTestService();
    await pumpCenter(
      tester,
      repository: repository,
      gateway: _FakePushGateway(
        permission: PushPermissionState.granted,
        token: token,
      ),
      targetedPushTestService: service,
    );

    await tester.tap(find.byKey(const Key('send-targeted-push-test')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-targeted-push-test')));
    await tester.pump();

    expect(service.installationIds, ['device-test']);
    expect(
      find.text('Notification test envoyée à cette installation.'),
      findsOneWidget,
    );
    expect(find.textContaining(token), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('callable error is presented as controlled feedback', (
    tester,
  ) async {
    final repository = MockCoordinationRepository();
    seedActiveSubscription(repository);
    final service = _FakeTargetedPushTestService(
      error: const PlatformAdministrationException(
        'Une notification test a déjà été envoyée à cette installation.',
      ),
    );
    await pumpCenter(
      tester,
      repository: repository,
      gateway: _FakePushGateway(permission: PushPermissionState.granted),
      targetedPushTestService: service,
    );

    await tester.tap(find.byKey(const Key('send-targeted-push-test')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-targeted-push-test')));
    await tester.pump();

    expect(service.installationIds, ['device-test']);
    expect(
      find.textContaining('déjà été envoyée à cette installation'),
      findsOneWidget,
    );
  });

  testWidgets(
    'active subscription reconciles and persists without forced renewal',
    (tester) async {
      final repository = MockCoordinationRepository();
      seedActiveSubscription(repository);
      final gateway = _FakePushGateway(permission: PushPermissionState.granted);

      await pumpCenter(tester, repository: repository, gateway: gateway);

      expect(find.text('Notifications activées'), findsOneWidget);
      expect(find.text('Activation incomplète'), findsNothing);
      expect(repository.pushSubscriptionReadCalls, 1);
      expect(gateway.permissionStateCalls, 1);
      expect(gateway.activationCalls, 0);
      expect(gateway.reconciliationCalls, 1);
      expect(gateway.recoveryCalls, 0);
      expect(gateway.renewalCalls, 0);
      expect(gateway.tokenRequests, 1);
      expect(repository.pushSubscriptions['device-test']?.token, 'token-test');
    },
  );

  testWidgets('failed active reconciliation remains incomplete', (
    tester,
  ) async {
    final repository = MockCoordinationRepository();
    seedActiveSubscription(repository);
    final gateway = _FakePushGateway(
      permission: PushPermissionState.granted,
      reconciliationSucceeds: false,
    );

    await pumpCenter(tester, repository: repository, gateway: gateway);

    expect(find.text('Activation incomplète'), findsOneWidget);
    expect(gateway.reconciliationCalls, 1);
  });

  testWidgets('active reconciliation exception remains incomplete', (
    tester,
  ) async {
    final repository = MockCoordinationRepository();
    seedActiveSubscription(repository);
    final gateway = _FakePushGateway(
      permission: PushPermissionState.granted,
      reconciliationThrows: true,
    );

    await pumpCenter(tester, repository: repository, gateway: gateway);

    expect(find.text('Activation incomplète'), findsOneWidget);
    expect(gateway.reconciliationCalls, 1);
  });

  testWidgets(
    'admin diagnostic never reconciles or persists the current identity',
    (tester) async {
      final repository = MockCoordinationRepository();
      seedActiveSubscription(repository);
      final gateway = _FakePushGateway(permission: PushPermissionState.granted);
      final service = _FakeTargetedPushTestService(available: false);

      await pumpCenter(
        tester,
        repository: repository,
        gateway: gateway,
        targetedPushTestService: service,
      );

      expect(find.text('Activation incomplète'), findsNothing);
      expect(gateway.reconciliationCalls, 0);
      expect(gateway.renewalCalls, 0);
      expect(gateway.registrationStreamAccesses, 0);
      final button = tester.widget<CupertinoButton>(
        find.descendant(
          of: find.byKey(const Key('send-targeted-push-test')),
          matching: find.byType(CupertinoButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(service.installationIds, isEmpty);
    },
  );

  testWidgets('invalid local subscription disables the admin test', (
    tester,
  ) async {
    final repository = MockCoordinationRepository();
    seedActiveSubscription(repository);
    final gateway = _FakePushGateway(
      permission: PushPermissionState.granted,
      localSubscriptionReady: false,
    );
    final service = _FakeTargetedPushTestService();

    await pumpCenter(
      tester,
      repository: repository,
      gateway: gateway,
      targetedPushTestService: service,
    );

    expect(
      find.textContaining('Aucun abonnement local valide'),
      findsOneWidget,
    );
    expect(service.availabilityChecks, isEmpty);
    final button = tester.widget<CupertinoButton>(
      find.descendant(
        of: find.byKey(const Key('send-targeted-push-test')),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(service.installationIds, isEmpty);
  });

  testWidgets('admin diagnostic never creates a missing installation id', (
    tester,
  ) async {
    final gateway = _FakePushGateway(
      permission: PushPermissionState.granted,
      existingId: null,
    );
    final service = _FakeTargetedPushTestService();

    await pumpCenter(
      tester,
      repository: MockCoordinationRepository(),
      gateway: gateway,
      targetedPushTestService: service,
    );

    expect(gateway.installationIdAccesses, 0);
    expect(service.availabilityChecks, isEmpty);
    expect(
      find.textContaining('Aucun abonnement local valide'),
      findsOneWidget,
    );
  });

  testWidgets('admin test stays disabled until backend target is resolved', (
    tester,
  ) async {
    final repository = MockCoordinationRepository();
    seedActiveSubscription(repository);
    final completer = Completer<bool>();
    final gateway = _FakePushGateway(permission: PushPermissionState.granted);
    final service = _FakeTargetedPushTestService(
      availabilityFuture: completer.future,
    );

    await pumpCenter(
      tester,
      repository: repository,
      gateway: gateway,
      targetedPushTestService: service,
      settle: false,
    );
    await tester.pump();

    var button = tester.widget<CupertinoButton>(
      find.descendant(
        of: find.byKey(const Key('send-targeted-push-test')),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(button.onPressed, isNull);

    completer.complete(true);
    await tester.pumpAndSettle();

    expect(
      repository.pushSubscriptions['device-test']?.token,
      'persisted-token',
    );
    expect(gateway.reconciliationCalls, 0);
    button = tester.widget<CupertinoButton>(
      find.descendant(
        of: find.byKey(const Key('send-targeted-push-test')),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(button.onPressed, isNotNull);
    expect(service.installationIds, isEmpty);
  });

  testWidgets('admin identity change cancels pending target resolution', (
    tester,
  ) async {
    final repository = _IdentityAwarePushRepository(
      failuresBeforeSuccess: 0,
      administrativeUid: 'admin-a',
    );
    seedActiveSubscription(repository);
    final completer = Completer<bool>();
    final service = _FakeTargetedPushTestService(
      availabilityFuture: completer.future,
    );

    await pumpCenter(
      tester,
      repository: repository,
      gateway: _FakePushGateway(permission: PushPermissionState.granted),
      targetedPushTestService: service,
      settle: false,
    );
    await tester.pump();
    repository.administrativeUid = 'admin-b';
    completer.complete(true);
    await tester.pumpAndSettle();

    final button = tester.widget<CupertinoButton>(
      find.descendant(
        of: find.byKey(const Key('send-targeted-push-test')),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(service.installationIds, isEmpty);
  });

  testWidgets('identity change cancels pending reconciliation persistence', (
    tester,
  ) async {
    final repository = _IdentityAwarePushRepository(
      failuresBeforeSuccess: 0,
      administrativeUid: 'owner-a',
    );
    seedActiveSubscription(repository);
    final completer = Completer<PushSubscriptionRegistration?>();
    final gateway = _FakePushGateway(
      permission: PushPermissionState.granted,
      reconciliationFuture: completer.future,
    );

    await pumpCenter(
      tester,
      repository: repository,
      gateway: gateway,
      settle: false,
    );
    await tester.pump();
    repository.administrativeUid = 'owner-b';
    completer.complete(
      const PushSubscriptionRegistration(
        installationId: 'device-test',
        token: 'must-not-cross-account',
        platform: 'web',
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.registrationCalls, 0);
    expect(
      repository.pushSubscriptions['device-test']?.token,
      'persisted-token',
    );
    expect(find.text('Activation incomplète'), findsOneWidget);
    final retryButton = tester.widget<CupertinoButton>(
      find.descendant(
        of: find.byKey(const Key('activate-notifications')),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(retryButton.onPressed, isNotNull);
  });

  testWidgets('unmount cancels pending reconciliation persistence', (
    tester,
  ) async {
    final repository = _FlakyPushRepository(failuresBeforeSuccess: 0);
    seedActiveSubscription(repository);
    final completer = Completer<PushSubscriptionRegistration?>();
    final gateway = _FakePushGateway(
      permission: PushPermissionState.granted,
      reconciliationFuture: completer.future,
    );

    await pumpCenter(
      tester,
      repository: repository,
      gateway: gateway,
      settle: false,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    completer.complete(
      const PushSubscriptionRegistration(
        installationId: 'device-test',
        token: 'must-not-persist-after-unmount',
        platform: 'web',
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.registrationCalls, 0);
  });

  testWidgets(
    'stale subscription recovers without deleteToken or permission request',
    (tester) async {
      final logs = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };
      try {
        final repository = MockCoordinationRepository();
        repository.pushSubscriptions['device-test'] =
            const PushSubscriptionRegistration(
              installationId: 'device-test',
              token: 'stale-token',
              platform: 'web',
            );
        repository.pushSubscriptionStates['device-test'] =
            PushSubscriptionState.stale;
        final gateway = _FakePushGateway(
          permission: PushPermissionState.granted,
          renewedToken: 'renewed-token',
        );

        await pumpCenter(tester, repository: repository, gateway: gateway);

        expect(find.text('Notifications activées'), findsOneWidget);
        expect(find.text('Activation incomplète'), findsNothing);
        expect(repository.pushSubscriptionReadCalls, 1);
        expect(
          repository.pushSubscriptions['device-test']?.token,
          'renewed-token',
        );
        expect(
          repository.pushSubscriptionStates['device-test'],
          PushSubscriptionState.active,
        );
        expect(repository.pushSubscriptions.keys, ['device-test']);
        expect(gateway.permissionStateCalls, 1);
        expect(gateway.activationCalls, 0);
        expect(gateway.tokenRequests, 1);
        expect(gateway.recoveryCalls, 1);
        expect(gateway.unsubscribeCalls, 1);
        expect(gateway.deleteTokenCalls, 0);
        expect(gateway.renewalCalls, 0);
        expect(gateway.reconciliationCalls, 0);
        expect(logs, [
          PushRecoveryTraceState.recoveryStarted,
          PushRecoveryTraceState.unsubscribeStarted,
          PushRecoveryTraceState.unsubscribeOk,
          PushRecoveryTraceState.getTokenStarted,
          PushRecoveryTraceState.getTokenOk,
          PushRecoveryTraceState.persistStarted,
          PushRecoveryTraceState.persistOk,
          PushRecoveryTraceState.recoveryReady,
        ]);
      } finally {
        debugPrint = previousDebugPrint;
      }
    },
  );

  testWidgets('unsubscribe failure stops stale recovery before getToken', (
    tester,
  ) async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      final repository = MockCoordinationRepository();
      repository.pushSubscriptions['device-test'] =
          const PushSubscriptionRegistration(
            installationId: 'device-test',
            token: 'stale-token',
            platform: 'web',
          );
      repository.pushSubscriptionStates['device-test'] =
          PushSubscriptionState.stale;
      final gateway = _FakePushGateway(
        permission: PushPermissionState.granted,
        renewedToken: 'must-not-be-created',
        unsubscribeSucceeds: false,
      );

      await pumpCenter(tester, repository: repository, gateway: gateway);

      expect(find.text('Activation incomplète'), findsOneWidget);
      expect(gateway.unsubscribeCalls, 1);
      expect(gateway.tokenRequests, 0);
      expect(gateway.deleteTokenCalls, 0);
      expect(
        repository.pushSubscriptionStates['device-test'],
        PushSubscriptionState.stale,
      );
      expect(logs, [
        PushRecoveryTraceState.recoveryStarted,
        PushRecoveryTraceState.unsubscribeStarted,
        PushRecoveryTraceState.unsubscribeFailed,
        PushRecoveryTraceState.recoveryFailed,
      ]);
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets('getToken failure leaves recovered subscription stale', (
    tester,
  ) async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      final repository = MockCoordinationRepository();
      repository.pushSubscriptions['device-test'] =
          const PushSubscriptionRegistration(
            installationId: 'device-test',
            token: 'stale-token',
            platform: 'web',
          );
      repository.pushSubscriptionStates['device-test'] =
          PushSubscriptionState.stale;
      final gateway = _FakePushGateway(
        permission: PushPermissionState.granted,
        recoveryGetTokenThrows: true,
      );

      await pumpCenter(tester, repository: repository, gateway: gateway);

      expect(find.text('Activation incomplète'), findsOneWidget);
      expect(gateway.unsubscribeCalls, 1);
      expect(gateway.tokenRequests, 1);
      expect(gateway.deleteTokenCalls, 0);
      expect(
        repository.pushSubscriptionStates['device-test'],
        PushSubscriptionState.stale,
      );
      expect(logs, [
        PushRecoveryTraceState.recoveryStarted,
        PushRecoveryTraceState.unsubscribeStarted,
        PushRecoveryTraceState.unsubscribeOk,
        PushRecoveryTraceState.getTokenStarted,
        PushRecoveryTraceState.getTokenFailed,
        PushRecoveryTraceState.recoveryFailed,
      ]);
      expect(logs.where((message) => message.contains('private')), isEmpty);
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets('failed stale persistence traces failure without leaking data', (
    tester,
  ) async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      final repository = _FlakyPushRepository(failuresBeforeSuccess: 1);
      seedActiveSubscription(repository);
      repository.pushSubscriptionStates['device-test'] =
          PushSubscriptionState.stale;
      final gateway = _FakePushGateway(
        permission: PushPermissionState.granted,
        renewedToken: 'private-renewed-token',
      );

      await pumpCenter(tester, repository: repository, gateway: gateway);

      expect(find.text('Activation incomplète'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(
        repository.pushSubscriptionStates['device-test'],
        PushSubscriptionState.stale,
      );
      expect(repository.registrationCalls, 1);
      expect(gateway.recoveryCalls, 1);
      expect(gateway.unsubscribeCalls, 1);
      expect(gateway.tokenRequests, 1);
      expect(logs, [
        PushRecoveryTraceState.recoveryStarted,
        PushRecoveryTraceState.unsubscribeStarted,
        PushRecoveryTraceState.unsubscribeOk,
        PushRecoveryTraceState.getTokenStarted,
        PushRecoveryTraceState.getTokenOk,
        PushRecoveryTraceState.persistStarted,
        PushRecoveryTraceState.persistFailed,
        PushRecoveryTraceState.recoveryFailed,
      ]);
      expect(
        logs.where((message) => message.contains('private-renewed-token')),
        isEmpty,
      );
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets('failed stale recovery has no automatic retry', (tester) async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      final repository = MockCoordinationRepository();
      repository.pushSubscriptions['device-test'] =
          const PushSubscriptionRegistration(
            installationId: 'device-test',
            token: 'stale-token',
            platform: 'web',
          );
      repository.pushSubscriptionStates['device-test'] =
          PushSubscriptionState.stale;
      final gateway = _FakePushGateway(permission: PushPermissionState.granted);

      await pumpCenter(tester, repository: repository, gateway: gateway);
      expect(find.text('Activation incomplète'), findsOneWidget);
      expect(gateway.activationCalls, 0);
      expect(gateway.recoveryCalls, 1);
      expect(gateway.unsubscribeCalls, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Activation incomplète'), findsOneWidget);
      expect(gateway.activationCalls, 0);
      expect(gateway.recoveryCalls, 1);
      expect(gateway.unsubscribeCalls, 1);
      expect(gateway.tokenRequests, 1);
      expect(gateway.deleteTokenCalls, 0);
      expect(logs, [
        PushRecoveryTraceState.recoveryStarted,
        PushRecoveryTraceState.unsubscribeStarted,
        PushRecoveryTraceState.unsubscribeOk,
        PushRecoveryTraceState.getTokenStarted,
        PushRecoveryTraceState.getTokenFailed,
        PushRecoveryTraceState.recoveryFailed,
      ]);
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets('trace sink failures never change stale hydration', (
    tester,
  ) async {
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      throw StateError('unavailable-trace-sink');
    };
    try {
      final repository = MockCoordinationRepository();
      seedActiveSubscription(repository);
      repository.pushSubscriptionStates['device-test'] =
          PushSubscriptionState.stale;
      final gateway = _FakePushGateway(
        permission: PushPermissionState.granted,
        renewedToken: 'renewed-token',
      );

      await pumpCenter(tester, repository: repository, gateway: gateway);

      expect(find.text('Notifications activées'), findsOneWidget);
      expect(
        repository.pushSubscriptions['device-test']?.token,
        'renewed-token',
      );
      expect(gateway.recoveryCalls, 1);
      expect(gateway.deleteTokenCalls, 0);
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets('normal activation traces changed token through ready', (
    tester,
  ) async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      final repository = _ActivationTracePushRepository(
        existingToken: 'old-private-token',
      );
      final gateway = _FakePushGateway(token: 'new-private-token');
      await pumpCenter(tester, repository: repository, gateway: gateway);

      await tester.tap(find.byKey(const Key('activate-notifications')));
      await tester.pumpAndSettle();

      expect(find.text('Notifications activées'), findsOneWidget);
      expect(logs, [
        PushActivationTraceState.activationStarted,
        PushActivationTraceState.permissionGranted,
        PushActivationTraceState.getTokenStarted,
        PushActivationTraceState.getTokenOk,
        PushActivationTraceState.persistStarted,
        PushActivationTraceState.tokenChanged,
        PushActivationTraceState.persistOk,
        PushActivationTraceState.activationReady,
      ]);
      expect(logs.where((state) => state.contains('private')), isEmpty);
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets('normal activation traces unchanged token', (tester) async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      final repository = _ActivationTracePushRepository(
        existingToken: 'same-private-token',
      );
      final gateway = _FakePushGateway(token: 'same-private-token');
      await pumpCenter(tester, repository: repository, gateway: gateway);

      await tester.tap(find.byKey(const Key('activate-notifications')));
      await tester.pumpAndSettle();

      expect(logs, contains(PushActivationTraceState.tokenUnchanged));
      expect(logs, contains(PushActivationTraceState.activationReady));
      expect(logs.where((state) => state.contains('private')), isEmpty);
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets('normal activation traces denied permission and failure', (
    tester,
  ) async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      final repository = _ActivationTracePushRepository();
      final gateway = _FakePushGateway(
        activationState: PushPermissionState.denied,
      );
      await pumpCenter(tester, repository: repository, gateway: gateway);

      await tester.tap(find.byKey(const Key('activate-notifications')));
      await tester.pumpAndSettle();

      expect(logs, [
        PushActivationTraceState.activationStarted,
        PushActivationTraceState.permissionDenied,
        PushActivationTraceState.activationFailed,
      ]);
      expect(gateway.tokenRequests, 0);
      expect(repository.registrationCalls, 0);
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets('normal activation traces getToken failure before persistence', (
    tester,
  ) async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      final repository = _ActivationTracePushRepository();
      final gateway = _FakePushGateway(activationGetTokenThrows: true);
      await pumpCenter(tester, repository: repository, gateway: gateway);

      await tester.tap(find.byKey(const Key('activate-notifications')));
      await tester.pumpAndSettle();

      expect(logs, [
        PushActivationTraceState.activationStarted,
        PushActivationTraceState.permissionGranted,
        PushActivationTraceState.getTokenStarted,
        PushActivationTraceState.getTokenFailed,
        PushActivationTraceState.activationFailed,
      ]);
      expect(repository.registrationCalls, 0);
      expect(logs.where((state) => state.contains('private')), isEmpty);
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets('normal activation traces persistence failure', (tester) async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      final repository = _ActivationTracePushRepository(failPersistence: true);
      final gateway = _FakePushGateway(token: 'private-activation-token');
      await pumpCenter(tester, repository: repository, gateway: gateway);

      await tester.tap(find.byKey(const Key('activate-notifications')));
      await tester.pumpAndSettle();

      expect(find.text('Activation incomplète'), findsOneWidget);
      expect(logs, [
        PushActivationTraceState.activationStarted,
        PushActivationTraceState.permissionGranted,
        PushActivationTraceState.getTokenStarted,
        PushActivationTraceState.getTokenOk,
        PushActivationTraceState.persistStarted,
        PushActivationTraceState.persistFailed,
        PushActivationTraceState.activationFailed,
      ]);
      expect(repository.registrationCalls, 1);
      expect(logs.where((state) => state.contains('private')), isEmpty);
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets('normal activation trace sink failure has no business effect', (
    tester,
  ) async {
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      throw StateError('unavailable-trace-sink');
    };
    try {
      final repository = _ActivationTracePushRepository(
        existingToken: 'old-token',
      );
      final gateway = _FakePushGateway(token: 'new-token');
      await pumpCenter(tester, repository: repository, gateway: gateway);

      await tester.tap(find.byKey(const Key('activate-notifications')));
      await tester.pumpAndSettle();

      expect(find.text('Notifications activées'), findsOneWidget);
      expect(repository.registrationCalls, 1);
      expect(repository.pushSubscriptions['device-test']?.token, 'new-token');
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets(
    'failed persistence stays incomplete, leaks no token and retry succeeds',
    (tester) async {
      const token = 'secret-fcm-token-must-stay-private';
      final logs = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };
      addTearDown(() => debugPrint = previousDebugPrint);
      final repository = _FlakyPushRepository(failuresBeforeSuccess: 1);
      final gateway = _FakePushGateway(token: token);
      await pumpCenter(tester, repository: repository, gateway: gateway);

      await tester.tap(find.byKey(const Key('activate-notifications')));
      await tester.pumpAndSettle();

      expect(repository.registrationCalls, 1);
      expect(find.text('Activation incomplète'), findsOneWidget);
      expect(find.text('Notifications activées'), findsNothing);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining(token), findsNothing);
      expect(logs.where((message) => message.contains(token)), isEmpty);

      await tester.tap(find.byKey(const Key('activate-notifications')));
      await tester.pumpAndSettle();

      expect(repository.registrationCalls, 2);
      expect(repository.pushSubscriptions.keys, contains('device-test'));
      expect(find.text('Notifications activées'), findsOneWidget);
      expect(find.text('Activation incomplète'), findsNothing);
      expect(find.textContaining(token), findsNothing);
      expect(logs.where((message) => message.contains(token)), isEmpty);
      debugPrint = previousDebugPrint;
    },
  );

  testWidgets('granted permission alone is not a persisted activation', (
    tester,
  ) async {
    final repository = MockCoordinationRepository();
    final gateway = _FakePushGateway(permission: PushPermissionState.granted);
    await pumpCenter(tester, repository: repository, gateway: gateway);

    expect(repository.pushSubscriptions, isEmpty);
    expect(repository.pushSubscriptionReadCalls, 1);
    expect(gateway.activationCalls, 0);
    expect(gateway.tokenRequests, 0);
    expect(find.text('Activation incomplète'), findsOneWidget);
    expect(find.text('Notifications activées'), findsNothing);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('non-granted permission skips subscription read', (tester) async {
    final repository = MockCoordinationRepository();
    seedActiveSubscription(repository);
    final gateway = _FakePushGateway();

    await pumpCenter(tester, repository: repository, gateway: gateway);

    expect(repository.pushSubscriptionReadCalls, 0);
    expect(gateway.permissionStateCalls, 1);
    expect(gateway.activationCalls, 0);
    expect(gateway.tokenRequests, 0);
    expect(find.text('Notifications activées'), findsNothing);
  });

  testWidgets('leaving and reopening the screen preserves active state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockCoordinationRepository();
    seedActiveSubscription(repository);
    final gateway = _FakePushGateway(permission: PushPermissionState.granted);
    await tester.pumpWidget(
      RepositoryScope(
        repository: repository,
        child: MaterialApp(
          theme: AppTheme.light,
          home: _NotificationNavigationHost(gateway: gateway),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-notification-center')));
    await tester.pumpAndSettle();
    expect(find.text('Notifications activées'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-center-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-notification-center')));
    await tester.pumpAndSettle();

    expect(find.text('Notifications activées'), findsOneWidget);
    expect(repository.pushSubscriptionReadCalls, 2);
    expect(gateway.activationCalls, 0);
    expect(gateway.reconciliationCalls, 1);
    expect(gateway.renewalCalls, 0);
    expect(gateway.tokenRequests, 1);
  });

  testWidgets('PWA relaunch hydrates an existing subscription', (tester) async {
    final repository = MockCoordinationRepository();
    seedActiveSubscription(repository);
    final gateway = _FakePushGateway(permission: PushPermissionState.granted);

    await pumpCenter(tester, repository: repository, gateway: gateway);
    expect(find.text('Notifications activées'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpCenter(tester, repository: repository, gateway: gateway);

    expect(find.text('Notifications activées'), findsOneWidget);
    expect(repository.pushSubscriptionReadCalls, 2);
    expect(gateway.activationCalls, 0);
    expect(gateway.reconciliationCalls, 1);
    expect(gateway.renewalCalls, 0);
    expect(gateway.tokenRequests, 1);
  });

  testWidgets('Plus tard dismisses the consent explanation without prompting', (
    tester,
  ) async {
    final gateway = _FakePushGateway();
    await pumpCenter(
      tester,
      repository: MockCoordinationRepository(),
      gateway: gateway,
    );
    await tester.tap(find.byKey(const Key('notifications-later')));
    await tester.pump();
    expect(find.byKey(const Key('notification-consent-card')), findsNothing);
    expect(gateway.activationCalls, 0);
  });

  testWidgets('refused permission never blocks the notification center', (
    tester,
  ) async {
    final repository = MockCoordinationRepository();
    final gateway = _FakePushGateway(
      activationState: PushPermissionState.denied,
    );
    await pumpCenter(tester, repository: repository, gateway: gateway);
    await tester.tap(find.byKey(const Key('activate-notifications')));
    await tester.pump();
    expect(find.textContaining('permission est refusée'), findsOneWidget);
    expect(find.text('Préférences'), findsOneWidget);
    expect(repository.pushSubscriptions, isEmpty);
  });

  testWidgets('unsupported device is detected without requesting permission', (
    tester,
  ) async {
    final gateway = _FakePushGateway(
      permission: PushPermissionState.unsupported,
    );
    await pumpCenter(
      tester,
      repository: MockCoordinationRepository(),
      gateway: gateway,
    );
    expect(find.textContaining('ne prend pas en charge'), findsOneWidget);
    expect(find.textContaining('écran d’accueil'), findsOneWidget);
    final button = tester.widget<CupertinoButton>(
      find.descendant(
        of: find.byKey(const Key('activate-notifications')),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(gateway.activationCalls, 0);
  });

  testWidgets('misconfigured push is distinct and cannot be activated', (
    tester,
  ) async {
    final gateway = _FakePushGateway(
      permission: PushPermissionState.misconfigured,
    );
    await pumpCenter(
      tester,
      repository: MockCoordinationRepository(),
      gateway: gateway,
    );

    expect(
      find.textContaining('configuration Push est incomplète'),
      findsOneWidget,
    );
    expect(find.textContaining('ne prend pas en charge'), findsNothing);
    final button = tester.widget<CupertinoButton>(
      find.descendant(
        of: find.byKey(const Key('activate-notifications')),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(gateway.activationCalls, 0);
    expect(gateway.tokenRequests, 0);
  });

  testWidgets('unread badge and read/unread controls stay synchronized', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      initialNotifications: [notification()],
    );
    final gateway = _FakePushGateway(permission: PushPermissionState.granted);
    await pumpCenter(tester, repository: repository, gateway: gateway);

    expect(find.text('1'), findsOneWidget);
    expect(gateway.lastBadge, 1);
    await tester.tap(find.byKey(const Key('notification-read-notification-a')));
    await tester.pump();
    expect(repository.notifications.single.isRead, true);
    expect(gateway.lastBadge, 0);
    await tester.tap(find.byKey(const Key('notification-read-notification-a')));
    await tester.pump();
    expect(repository.notifications.single.isRead, false);
  });

  testWidgets('notification opens an authorized existing mission', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      initialNotifications: [notification()],
    );
    await pumpCenter(
      tester,
      repository: repository,
      gateway: _FakePushGateway(),
    );
    await tester.tap(find.byKey(const Key('notification-notification-a')));
    await tester.pumpAndSettle();
    expect(find.text('Mission'), findsOneWidget);
    expect(find.textContaining('MÉRIGNAC'), findsWidgets);
    expect(repository.notifications.single.isRead, true);
  });

  testWidgets('stale deep link explains an inaccessible mission', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      initialNotifications: [notification(missionId: 'missing')],
    );
    await pumpCenter(
      tester,
      repository: repository,
      gateway: _FakePushGateway(),
      initialNotificationId: 'notification-a',
    );
    await tester.pumpAndSettle();
    expect(find.text('Mission inaccessible'), findsOneWidget);
  });

  testWidgets('preferences keep prudent defaults and persist opt-in', (
    tester,
  ) async {
    final repository = MockCoordinationRepository();
    await pumpCenter(
      tester,
      repository: repository,
      gateway: _FakePushGateway(),
    );
    final compatiblePreference = find.text('Missions compatibles');
    expect(compatiblePreference, findsOneWidget);
    await tester.tap(compatiblePreference);
    await tester.pump();
    expect(repository.notificationPreferences.compatibleMissions, true);
  });

  testWidgets('center supports Dynamic Type, dark mode and Reduce Motion', (
    tester,
  ) async {
    await pumpCenter(
      tester,
      repository: MockCoordinationRepository(
        initialNotifications: [notification()],
      ),
      gateway: _FakePushGateway(),
      themeMode: ThemeMode.dark,
      textScale: 2,
      reduceMotion: true,
    );
    expect(tester.takeException(), isNull);
    expect(
      Theme.of(tester.element(find.text('Notifications'))).brightness,
      Brightness.dark,
    );
    expect(
      MediaQuery.disableAnimationsOf(
        tester.element(find.text('Notifications')),
      ),
      true,
    );
  });

  testWidgets('notification exposes clear semantics for VoiceOver', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpCenter(
      tester,
      repository: MockCoordinationRepository(
        initialNotifications: [notification()],
      ),
      gateway: _FakePushGateway(),
    );
    expect(
      find.bySemanticsLabel(RegExp('Une mission devient critique')),
      findsOneWidget,
    );
    expect(find.byTooltip('Marquer comme lue'), findsOneWidget);
    handle.dispose();
  });
}

class _TestDomException {
  const _TestDomException();
}

PushUnsubscribeErrorInfo _classifyTestUnsubscribeError(Object error) {
  if (error is _TestDomException) {
    return const PushUnsubscribeErrorInfo(
      name: 'AbortError',
      errorClass: PushUnsubscribeErrorClass.domException,
    );
  }
  if (error is Error) {
    return const PushUnsubscribeErrorInfo(
      name: 'Other',
      errorClass: PushUnsubscribeErrorClass.error,
    );
  }
  return const PushUnsubscribeErrorInfo(
    name: 'private-name-that-must-be-filtered',
    errorClass: PushUnsubscribeErrorClass.other,
  );
}

class _NotificationNavigationHost extends StatelessWidget {
  const _NotificationNavigationHost({required this.gateway});

  final PushNotificationGateway gateway;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const Key('open-notification-center'),
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => NotificationCenterScreen(pushGateway: gateway),
          ),
        ),
        child: const Text('Ouvrir les notifications'),
      ),
    ),
  );
}

class _FakePushGateway
    implements PushNotificationGateway, PushStaleRecoveryGateway {
  _FakePushGateway({
    this.permission = PushPermissionState.prompt,
    this.activationState = PushPermissionState.granted,
    this.token = 'token-test',
    this.renewedToken,
    this.reconciliationSucceeds = true,
    this.reconciliationThrows = false,
    this.reconciliationFuture,
    this.activationFuture,
    this.unsubscribeSucceeds = true,
    this.recoveryGetTokenThrows = false,
    this.activationGetTokenThrows = false,
    this.localSubscriptionReady = true,
    this.existingId = 'device-test',
  });

  PushPermissionState permission;
  final PushPermissionState activationState;
  final String token;
  String? renewedToken;
  final bool reconciliationSucceeds;
  final bool reconciliationThrows;
  final Future<PushSubscriptionRegistration?>? reconciliationFuture;
  final Future<PushSubscriptionRegistration?>? activationFuture;
  final bool unsubscribeSucceeds;
  final bool recoveryGetTokenThrows;
  final bool activationGetTokenThrows;
  final bool localSubscriptionReady;
  final String? existingId;
  int activationCalls = 0;
  int reconciliationCalls = 0;
  int renewalCalls = 0;
  int recoveryCalls = 0;
  int unsubscribeCalls = 0;
  int deleteTokenCalls = 0;
  int permissionStateCalls = 0;
  int registrationStreamAccesses = 0;
  int tokenRequests = 0;
  int lastBadge = 0;
  int installationIdAccesses = 0;
  Future<PushSubscriptionRegistration?>? _sessionReconciliation;
  Future<PushSubscriptionRegistration?>? _forcedRenewal;
  Future<PushSubscriptionRegistration?>? _staleRecovery;
  int _registrationGeneration = 0;

  @override
  String get installationId {
    installationIdAccesses += 1;
    return 'device-test';
  }

  @override
  String? get existingInstallationId => existingId;

  @override
  Stream<PushSubscriptionRegistration> get registrationUpdates {
    registrationStreamAccesses += 1;
    return const Stream.empty();
  }

  @override
  Future<PushActivationResult> activate() async {
    activationCalls += 1;
    permission = activationState;
    emitPushActivationPermission(
      granted: activationState == PushPermissionState.granted,
      trace: debugPrint,
    );
    if (activationState != PushPermissionState.granted) {
      return PushActivationResult(activationState);
    }
    _registrationGeneration += 1;
    final generation = _registrationGeneration;
    final pending = activationFuture;
    final candidate = pending == null
        ? runTracedPushActivationTokenRequest(
            getToken: () async {
              tokenRequests += 1;
              if (activationGetTokenThrows) {
                throw StateError('private-activation-get-token-error');
              }
              return token;
            },
            trace: debugPrint,
          ).then(
            (token) => token == null
                ? null
                : PushSubscriptionRegistration(
                    installationId: 'device-test',
                    token: token,
                    platform: 'web',
                  ),
          )
        : _tracePendingActivation(pending);
    final activation = candidate.then(
      (registration) =>
          generation == _registrationGeneration ? registration : null,
    );
    _sessionReconciliation = activation;
    final registration = await activation;
    if (registration == null && generation != _registrationGeneration) {
      return PushActivationResult(
        activationState,
        registration: await _forcedRenewal,
      );
    }
    if (registration != null) {
      _sessionReconciliation = Future.value(registration);
    }
    return PushActivationResult(activationState, registration: registration);
  }

  Future<PushSubscriptionRegistration?> _tracePendingActivation(
    Future<PushSubscriptionRegistration?> pending,
  ) async {
    final token = await runTracedPushActivationTokenRequest(
      getToken: () async {
        tokenRequests += 1;
        return (await pending)?.token;
      },
      trace: debugPrint,
    );
    if (token == null) return null;
    return PushSubscriptionRegistration(
      installationId: installationId,
      token: token,
      platform: 'web',
    );
  }

  @override
  Future<PushPermissionState> permissionState() async {
    permissionStateCalls += 1;
    return permission;
  }

  @override
  Future<bool> hasUsableLocalSubscription() async => localSubscriptionReady;

  @override
  Future<PushSubscriptionRegistration?> reconcileRegistration() {
    final forcedRenewal = _forcedRenewal;
    if (forcedRenewal != null) return forcedRenewal;
    final generation = _registrationGeneration;
    return _sessionReconciliation ??= _reconcileRegistration().then(
      (registration) =>
          generation == _registrationGeneration ? registration : null,
    );
  }

  Future<PushSubscriptionRegistration?> _reconcileRegistration() async {
    reconciliationCalls += 1;
    tokenRequests += 1;
    if (reconciliationThrows) {
      throw StateError('reconciliation failed');
    }
    final pending = reconciliationFuture;
    if (pending != null) return pending;
    if (!reconciliationSucceeds) return null;
    return PushSubscriptionRegistration(
      installationId: installationId,
      token: token,
      platform: 'web',
    );
  }

  @override
  Future<PushSubscriptionRegistration?> renewRegistration() {
    final forcedRenewal = _forcedRenewal;
    if (forcedRenewal != null) return forcedRenewal;
    final previousOperation = _sessionReconciliation;
    _registrationGeneration += 1;
    _sessionReconciliation = null;
    late final Future<PushSubscriptionRegistration?> guardedRenewal;
    guardedRenewal = _renewRegistration(previousOperation).whenComplete(() {
      if (identical(_forcedRenewal, guardedRenewal)) {
        _forcedRenewal = null;
      }
    });
    _forcedRenewal = guardedRenewal;
    return guardedRenewal;
  }

  Future<PushSubscriptionRegistration?> _renewRegistration(
    Future<PushSubscriptionRegistration?>? previousOperation,
  ) async {
    if (previousOperation != null) {
      try {
        await previousOperation;
      } catch (_) {
        // The forced renewal supersedes any failed prior operation.
      }
    }
    renewalCalls += 1;
    final refreshedToken = await runTracedStaleTokenRenewal(
      deleteToken: () async => deleteTokenCalls += 1,
      getToken: () async {
        tokenRequests += 1;
        return renewedToken;
      },
      trace: debugPrint,
    );
    if (refreshedToken == null) return null;
    final registration = PushSubscriptionRegistration(
      installationId: installationId,
      token: refreshedToken,
      platform: 'web',
    );
    _sessionReconciliation = Future.value(registration);
    return registration;
  }

  @override
  Future<PushSubscriptionRegistration?> recoverStaleRegistration() {
    final staleRecovery = _staleRecovery;
    if (staleRecovery != null) return staleRecovery;
    late final Future<PushSubscriptionRegistration?> guardedRecovery;
    guardedRecovery = _recoverStaleRegistration().whenComplete(() {
      if (identical(_staleRecovery, guardedRecovery)) {
        _staleRecovery = null;
      }
    });
    _staleRecovery = guardedRecovery;
    return guardedRecovery;
  }

  Future<PushSubscriptionRegistration?> _recoverStaleRegistration() async {
    recoveryCalls += 1;
    final recoveredToken = await runTracedStalePushRecovery(
      unsubscribe: () async {
        unsubscribeCalls += 1;
        return unsubscribeSucceeds;
      },
      getToken: () async {
        tokenRequests += 1;
        if (recoveryGetTokenThrows) {
          throw StateError('private-get-error');
        }
        return renewedToken;
      },
      trace: debugPrint,
    );
    if (recoveredToken == null) return null;
    final registration = PushSubscriptionRegistration(
      installationId: installationId,
      token: recoveredToken,
      platform: 'web',
    );
    _sessionReconciliation = Future.value(registration);
    return registration;
  }

  @override
  Future<void> updateBadge(int count) async => lastBadge = count;
}

class _FakeTargetedPushTestService implements TargetedPushTestService {
  _FakeTargetedPushTestService({
    this.error,
    this.available = true,
    this.availabilityFuture,
  });

  final Object? error;
  final bool available;
  final Future<bool>? availabilityFuture;
  final List<String> installationIds = [];
  final List<String> availabilityChecks = [];

  @override
  Future<bool> canSendTargetedPushTest({required String installationId}) async {
    availabilityChecks.add(installationId);
    return availabilityFuture == null ? available : await availabilityFuture!;
  }

  @override
  Future<void> sendTargetedPushTest({required String installationId}) async {
    installationIds.add(installationId);
    if (error case final error?) throw error;
  }
}

class _ActivationTracePushRepository extends MockCoordinationRepository
    implements PushActivationPersistenceRepository {
  _ActivationTracePushRepository({
    this.existingToken,
    this.failPersistence = false,
  });

  final String? existingToken;
  final bool failPersistence;
  int registrationCalls = 0;

  @override
  Future<void> registerPushSubscriptionForActivation(
    PushSubscriptionRegistration registration, {
    required void Function(bool tokenChanged) onTokenCompared,
  }) async {
    registrationCalls += 1;
    if (failPersistence) {
      throw StateError('private-persistence-error');
    }
    await super.registerPushSubscription(registration);
    try {
      onTokenCompared(didPushTokenChange(existingToken, registration.token));
    } catch (_) {
      // Mirrors the production best-effort diagnostic callback.
    }
  }
}

class _FlakyPushRepository extends MockCoordinationRepository {
  _FlakyPushRepository({required this.failuresBeforeSuccess});

  int failuresBeforeSuccess;
  int registrationCalls = 0;

  @override
  Future<void> registerPushSubscription(
    PushSubscriptionRegistration registration,
  ) async {
    registrationCalls += 1;
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess -= 1;
      throw StateError('Écriture refusée pour ${registration.token}');
    }
    await super.registerPushSubscription(registration);
  }
}

class _IdentityAwarePushRepository extends _FlakyPushRepository
    implements AdministrativeIdentityReadRepository {
  _IdentityAwarePushRepository({
    required super.failuresBeforeSuccess,
    required this.administrativeUid,
  });

  String? administrativeUid;

  @override
  Stream<String?> watchAdministrativeUid() => Stream.value(administrativeUid);
}

class _IdentityChangingAfterReadPushRepository
    extends _IdentityAwarePushRepository {
  _IdentityChangingAfterReadPushRepository({
    required String administrativeUid,
    required this.replacementUid,
  }) : super(failuresBeforeSuccess: 0, administrativeUid: administrativeUid);

  final String replacementUid;

  @override
  Future<PushSubscriptionState> readPushSubscriptionState(
    String installationId,
  ) async {
    final state = await super.readPushSubscriptionState(installationId);
    administrativeUid = replacementUid;
    return state;
  }
}
