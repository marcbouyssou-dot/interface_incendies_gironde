import '../models/app_notification.dart';

enum PushPermissionState { unsupported, prompt, granted, denied, misconfigured }

abstract final class PushRenewalTraceState {
  static const staleRenewalStarted = 'STALE_RENEWAL_STARTED';
  static const deleteTokenStarted = 'DELETE_TOKEN_STARTED';
  static const deleteTokenOk = 'DELETE_TOKEN_OK';
  static const deleteTokenFailed = 'DELETE_TOKEN_FAILED';
  static const getTokenStarted = 'GET_TOKEN_STARTED';
  static const getTokenOk = 'GET_TOKEN_OK';
  static const getTokenFailed = 'GET_TOKEN_FAILED';
  static const persistStarted = 'PERSIST_STARTED';
  static const persistOk = 'PERSIST_OK';
  static const persistFailed = 'PERSIST_FAILED';
  static const staleRenewalReady = 'STALE_RENEWAL_READY';
  static const staleRenewalFailed = 'STALE_RENEWAL_FAILED';

  static const values = <String>{
    staleRenewalStarted,
    deleteTokenStarted,
    deleteTokenOk,
    deleteTokenFailed,
    getTokenStarted,
    getTokenOk,
    getTokenFailed,
    persistStarted,
    persistOk,
    persistFailed,
    staleRenewalReady,
    staleRenewalFailed,
  };
}

abstract final class PushRecoveryTraceState {
  static const recoveryStarted = 'RECOVERY_STARTED';
  static const unsubscribeStarted = 'UNSUBSCRIBE_STARTED';
  static const unsubscribeOk = 'UNSUBSCRIBE_OK';
  static const unsubscribeFailed = 'UNSUBSCRIBE_FAILED';
  static const getTokenStarted = 'GET_TOKEN_STARTED';
  static const getTokenOk = 'GET_TOKEN_OK';
  static const getTokenFailed = 'GET_TOKEN_FAILED';
  static const persistStarted = 'PERSIST_STARTED';
  static const persistOk = 'PERSIST_OK';
  static const persistFailed = 'PERSIST_FAILED';
  static const recoveryReady = 'RECOVERY_READY';
  static const recoveryFailed = 'RECOVERY_FAILED';

  static const values = <String>{
    recoveryStarted,
    unsubscribeStarted,
    unsubscribeOk,
    unsubscribeFailed,
    getTokenStarted,
    getTokenOk,
    getTokenFailed,
    persistStarted,
    persistOk,
    persistFailed,
    recoveryReady,
    recoveryFailed,
  };
}

Future<String?> runTracedStaleTokenRenewal({
  required Future<void> Function() deleteToken,
  required Future<String?> Function() getToken,
  required void Function(String state) trace,
}) async {
  void emit(String state) {
    try {
      trace(state);
    } catch (_) {
      // Diagnostic output must never affect token renewal.
    }
  }

  emit(PushRenewalTraceState.deleteTokenStarted);
  try {
    await deleteToken();
    emit(PushRenewalTraceState.deleteTokenOk);
  } catch (_) {
    emit(PushRenewalTraceState.deleteTokenFailed);
    rethrow;
  }

  emit(PushRenewalTraceState.getTokenStarted);
  try {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      emit(PushRenewalTraceState.getTokenFailed);
      return null;
    }
    emit(PushRenewalTraceState.getTokenOk);
    return token;
  } catch (_) {
    emit(PushRenewalTraceState.getTokenFailed);
    rethrow;
  }
}

Future<String?> runTracedStalePushRecovery({
  required Future<bool> Function() unsubscribe,
  required Future<String?> Function() getToken,
  required void Function(String state) trace,
}) async {
  void emit(String state) {
    try {
      trace(state);
    } catch (_) {
      // Diagnostic output must never affect push recovery.
    }
  }

  emit(PushRecoveryTraceState.unsubscribeStarted);
  try {
    if (!await unsubscribe()) {
      emit(PushRecoveryTraceState.unsubscribeFailed);
      return null;
    }
    emit(PushRecoveryTraceState.unsubscribeOk);
  } catch (_) {
    emit(PushRecoveryTraceState.unsubscribeFailed);
    rethrow;
  }

  emit(PushRecoveryTraceState.getTokenStarted);
  try {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      emit(PushRecoveryTraceState.getTokenFailed);
      return null;
    }
    emit(PushRecoveryTraceState.getTokenOk);
    return token;
  } catch (_) {
    emit(PushRecoveryTraceState.getTokenFailed);
    rethrow;
  }
}

bool isExpectedFirebaseMessagingServiceWorker({
  required String origin,
  required String scope,
  required String scriptUrl,
  required String state,
}) {
  final scopeUri = Uri.tryParse(scope);
  final scriptUri = Uri.tryParse(scriptUrl);
  if (scopeUri == null || scriptUri == null) return false;
  final scopePath = scopeUri.path.endsWith('/')
      ? scopeUri.path.substring(0, scopeUri.path.length - 1)
      : scopeUri.path;
  return scopeUri.origin == origin &&
      scriptUri.origin == origin &&
      scopePath == '/firebase-cloud-messaging-push-scope' &&
      scriptUri.path == '/firebase-messaging-sw.js' &&
      state == 'activated';
}

PushPermissionState resolveWebPushPermissionState({
  required bool isSupported,
  required String vapidKey,
  required PushPermissionState permission,
}) {
  if (!isSupported) return PushPermissionState.unsupported;
  if (vapidKey.trim().isEmpty) return PushPermissionState.misconfigured;
  return permission;
}

class PushActivationResult {
  const PushActivationResult(this.state, {this.registration});
  final PushPermissionState state;
  final PushSubscriptionRegistration? registration;
}

abstract interface class PushNotificationGateway {
  String get installationId;
  Future<PushPermissionState> permissionState();
  Future<PushActivationResult> activate();
  Future<PushSubscriptionRegistration?> reconcileRegistration();
  Future<PushSubscriptionRegistration?> renewRegistration();
  Future<void> updateBadge(int count);
  Stream<PushSubscriptionRegistration> get registrationUpdates;
}

/// Recovery capability intentionally kept separate from normal activation.
///
/// The notification center calls it only after Firestore classifies the
/// current installation as stale because FCM rejected its registration token.
abstract interface class PushStaleRecoveryGateway {
  Future<PushSubscriptionRegistration?> recoverStaleRegistration();
}

PushNotificationGateway createPushNotificationGateway() =>
    const UnsupportedPushNotificationGateway();

class UnsupportedPushNotificationGateway implements PushNotificationGateway {
  const UnsupportedPushNotificationGateway();

  @override
  String get installationId => '';

  @override
  Future<PushActivationResult> activate() async =>
      const PushActivationResult(PushPermissionState.unsupported);

  @override
  Future<PushPermissionState> permissionState() async =>
      PushPermissionState.unsupported;

  @override
  Future<PushSubscriptionRegistration?> reconcileRegistration() async => null;

  @override
  Future<PushSubscriptionRegistration?> renewRegistration() async => null;

  @override
  Future<void> updateBadge(int count) async {}

  @override
  Stream<PushSubscriptionRegistration> get registrationUpdates =>
      const Stream.empty();
}
