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
  static const unsubscribePrecheckOk = 'UNSUBSCRIBE_PRECHECK_OK';
  static const unsubscribePrecheckFailed = 'UNSUBSCRIBE_PRECHECK_FAILED';
  static const unsubscribeCallStarted = 'UNSUBSCRIBE_CALL_STARTED';
  static const unsubscribeResultTrue = 'UNSUBSCRIBE_RESULT_TRUE';
  static const unsubscribeResultFalse = 'UNSUBSCRIBE_RESULT_FALSE';
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
    unsubscribePrecheckOk,
    unsubscribePrecheckFailed,
    unsubscribeCallStarted,
    unsubscribeResultTrue,
    unsubscribeResultFalse,
    getTokenStarted,
    getTokenOk,
    getTokenFailed,
    persistStarted,
    persistOk,
    persistFailed,
    recoveryReady,
    recoveryFailed,
  };

  static const _allowedErrorNames = <String>{
    'AbortError',
    'InvalidStateError',
    'NetworkError',
    'NotAllowedError',
    'NotFoundError',
    'NotSupportedError',
    'OperationError',
    'QuotaExceededError',
    'SecurityError',
    'TypeError',
    'UnknownError',
    'Other',
  };

  static String unsubscribeErrorName(String name) {
    final safeName = _allowedErrorNames.contains(name) ? name : 'Other';
    return 'UNSUBSCRIBE_ERROR_NAME: $safeName';
  }

  static String unsubscribeErrorClass(PushUnsubscribeErrorClass errorClass) =>
      'UNSUBSCRIBE_ERROR_CLASS: ${errorClass.label}';

  static String subscriptionAfterFailure(PushSubscriptionAfterFailure state) =>
      'SUBSCRIPTION_AFTER_FAILURE: ${state.label}';
}

enum PushUnsubscribeErrorClass {
  domException('DOMException'),
  error('Error'),
  other('Other');

  const PushUnsubscribeErrorClass(this.label);
  final String label;
}

enum PushSubscriptionAfterFailure {
  present('PRESENT'),
  absent('ABSENT'),
  indeterminate('INDETERMINATE');

  const PushSubscriptionAfterFailure(this.label);
  final String label;
}

class PushUnsubscribeErrorInfo {
  const PushUnsubscribeErrorInfo({
    required this.name,
    required this.errorClass,
  });

  final String name;
  final PushUnsubscribeErrorClass errorClass;
}

void tracePushUnsubscribePrecheck({
  required bool passed,
  required void Function(String state) trace,
  PushSubscriptionAfterFailure failureState =
      PushSubscriptionAfterFailure.indeterminate,
}) {
  _emitPushRecoveryTrace(
    trace,
    passed
        ? PushRecoveryTraceState.unsubscribePrecheckOk
        : PushRecoveryTraceState.unsubscribePrecheckFailed,
  );
  if (!passed) {
    _emitPushRecoveryTrace(
      trace,
      PushRecoveryTraceState.subscriptionAfterFailure(failureState),
    );
  }
}

Future<bool> runTracedPushUnsubscribeCall({
  required Future<bool> Function() unsubscribe,
  required Future<PushSubscriptionAfterFailure> Function()
  inspectSubscriptionAfterFailure,
  required PushUnsubscribeErrorInfo Function(Object error) classifyError,
  required void Function(String state) trace,
}) async {
  _emitPushRecoveryTrace(trace, PushRecoveryTraceState.unsubscribeCallStarted);
  try {
    final result = await unsubscribe();
    _emitPushRecoveryTrace(
      trace,
      result
          ? PushRecoveryTraceState.unsubscribeResultTrue
          : PushRecoveryTraceState.unsubscribeResultFalse,
    );
    if (!result) {
      await _traceSubscriptionAfterFailure(
        inspectSubscriptionAfterFailure,
        trace,
      );
    }
    return result;
  } catch (error, stackTrace) {
    PushUnsubscribeErrorInfo errorInfo;
    try {
      errorInfo = classifyError(error);
    } catch (_) {
      errorInfo = const PushUnsubscribeErrorInfo(
        name: 'Other',
        errorClass: PushUnsubscribeErrorClass.other,
      );
    }
    _emitPushRecoveryTrace(
      trace,
      PushRecoveryTraceState.unsubscribeErrorName(errorInfo.name),
    );
    _emitPushRecoveryTrace(
      trace,
      PushRecoveryTraceState.unsubscribeErrorClass(errorInfo.errorClass),
    );
    await _traceSubscriptionAfterFailure(
      inspectSubscriptionAfterFailure,
      trace,
    );
    Error.throwWithStackTrace(error, stackTrace);
  }
}

Future<void> _traceSubscriptionAfterFailure(
  Future<PushSubscriptionAfterFailure> Function() inspect,
  void Function(String state) trace,
) async {
  var state = PushSubscriptionAfterFailure.indeterminate;
  try {
    state = await inspect();
  } catch (_) {
    // The read-only diagnostic is best-effort.
  }
  _emitPushRecoveryTrace(
    trace,
    PushRecoveryTraceState.subscriptionAfterFailure(state),
  );
}

void _emitPushRecoveryTrace(void Function(String state) trace, String state) {
  try {
    trace(state);
  } catch (_) {
    // Diagnostic output must never affect push recovery.
  }
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
