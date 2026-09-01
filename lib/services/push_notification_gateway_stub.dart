import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/app_notification.dart';

enum PushPermissionState { unsupported, prompt, granted, denied, misconfigured }

bool applicationServerKeyMatchesVapid({
  required List<int> applicationServerKey,
  required String vapidKey,
}) {
  try {
    final expectedKey = base64Url.decode(base64Url.normalize(vapidKey));
    if (applicationServerKey.length != expectedKey.length) return false;
    for (var index = 0; index < expectedKey.length; index += 1) {
      if (applicationServerKey[index] != expectedKey[index]) return false;
    }
    return true;
  } catch (_) {
    return false;
  }
}

abstract final class LocalSubscriptionTraceState {
  static const vapidConfigPresent = 'LOCAL_VAPID_CONFIG_PRESENT';
  static const vapidConfigAbsent = 'LOCAL_VAPID_CONFIG_ABSENT';
  static const permissionGranted = 'LOCAL_PERMISSION_GRANTED';
  static const permissionFailed = 'LOCAL_PERMISSION_FAILED';
  static const serviceWorkerApiAvailable = 'LOCAL_SW_API_AVAILABLE';
  static const serviceWorkerApiFailed = 'LOCAL_SW_API_FAILED';
  static const registrationsOk = 'LOCAL_REGISTRATIONS_OK';
  static const registrationsFailed = 'LOCAL_REGISTRATIONS_FAILED';
  static const registrationTypeOk = 'LOCAL_REGISTRATION_TYPE_OK';
  static const registrationTypeFailed = 'LOCAL_REGISTRATION_TYPE_FAILED';
  static const workerActive = 'LOCAL_WORKER_ACTIVE';
  static const workerActiveFailed = 'LOCAL_WORKER_FAILED';
  static const workerScriptOk = 'LOCAL_WORKER_SCRIPT_OK';
  static const workerScriptFailed = 'LOCAL_WORKER_SCRIPT_FAILED';
  static const workerScopeOk = 'LOCAL_WORKER_SCOPE_OK';
  static const workerScopeFailed = 'LOCAL_WORKER_SCOPE_FAILED';
  static const messagingWorkerCount0 = 'LOCAL_MESSAGING_WORKER_COUNT_0';
  static const messagingWorkerCount1 = 'LOCAL_MESSAGING_WORKER_COUNT_1';
  static const messagingWorkerCountMultiple =
      'LOCAL_MESSAGING_WORKER_COUNT_MULTIPLE';
  static const pushManagerAvailable = 'LOCAL_PUSH_MANAGER_AVAILABLE';
  static const pushManagerFailed = 'LOCAL_PUSH_MANAGER_FAILED';
  static const getSubscriptionOk = 'LOCAL_GET_SUBSCRIPTION_OK';
  static const getSubscriptionFailed = 'LOCAL_GET_SUBSCRIPTION_FAILED';
  static const subscriptionPresent = 'LOCAL_SUBSCRIPTION_PRESENT';
  static const subscriptionAbsent = 'LOCAL_SUBSCRIPTION_ABSENT';
  static const subscriptionTypeOk = 'LOCAL_SUBSCRIPTION_TYPE_OK';
  static const subscriptionTypeFailed = 'LOCAL_SUBSCRIPTION_TYPE_FAILED';
  static const applicationServerKeyPresent =
      'LOCAL_APPLICATION_SERVER_KEY_PRESENT';
  static const applicationServerKeyAbsent =
      'LOCAL_APPLICATION_SERVER_KEY_ABSENT';
  static const vapidMatch = 'LOCAL_VAPID_MATCH';
  static const vapidMismatch = 'LOCAL_VAPID_MISMATCH';

  static String messagingWorkerCount(int count) => count == 0
      ? messagingWorkerCount0
      : count == 1
      ? messagingWorkerCount1
      : messagingWorkerCountMultiple;

  static String exceptionClass(PushUnsubscribeErrorClass errorClass) =>
      'LOCAL_SUBSCRIPTION_EXCEPTION_CLASS: ${errorClass.label}';
}

void emitLocalSubscriptionTrace(
  void Function(String state) trace,
  String state,
) {
  try {
    trace(state);
  } catch (_) {
    // Diagnostic output must never affect local subscription checks.
  }
}

void traceLocalSubscriptionGuard({
  required bool passed,
  required String successState,
  required String failureState,
  required void Function(String state) trace,
}) {
  emitLocalSubscriptionTrace(trace, passed ? successState : failureState);
}

Future<T> runTracedLocalBrowserRead<T>({
  required Future<T> Function() read,
  required String successState,
  required String failureState,
  required void Function(String state) trace,
}) async {
  try {
    final result = await read();
    emitLocalSubscriptionTrace(trace, successState);
    return result;
  } catch (_) {
    emitLocalSubscriptionTrace(trace, failureState);
    rethrow;
  }
}

void traceLocalSubscriptionException({
  required Object error,
  required PushUnsubscribeErrorClass Function(Object error) classifyError,
  required void Function(String state) trace,
}) {
  PushUnsubscribeErrorClass errorClass;
  try {
    errorClass = classifyError(error);
  } catch (_) {
    errorClass = PushUnsubscribeErrorClass.other;
  }
  emitLocalSubscriptionTrace(
    trace,
    LocalSubscriptionTraceState.exceptionClass(errorClass),
  );
}

class LocalMessagingWorkerCandidate<T> {
  const LocalMessagingWorkerCandidate({
    required this.registration,
    required this.active,
    required this.scriptOk,
    required this.scopeOk,
    required this.matches,
  });

  final T registration;
  final bool active;
  final bool scriptOk;
  final bool scopeOk;
  final bool matches;
}

Future<bool> runInstrumentedLocalSubscriptionCheck<
  ServiceWorkerApi,
  Registration,
  PushManager,
  PushSubscription
>({
  required bool Function() hasVapidConfig,
  required bool Function() permissionGranted,
  required ServiceWorkerApi? Function() serviceWorkerApi,
  required Future<Iterable<Object?>> Function(ServiceWorkerApi api)
  getRegistrations,
  required LocalMessagingWorkerCandidate<Registration>? Function(
    Object? candidate,
  )
  inspectRegistration,
  required PushManager? Function(Registration registration) getPushManager,
  required Future<Object?> Function(PushManager manager) getSubscription,
  required PushSubscription? Function(Object? candidate) asPushSubscription,
  required bool Function(PushSubscription subscription)
  applicationServerKeyPresent,
  required bool Function(PushSubscription subscription) vapidMatches,
  required PushUnsubscribeErrorClass Function(Object error) classifyError,
  required void Function(String state) trace,
}) async {
  final vapidConfigured = hasVapidConfig();
  traceLocalSubscriptionGuard(
    passed: vapidConfigured,
    successState: LocalSubscriptionTraceState.vapidConfigPresent,
    failureState: LocalSubscriptionTraceState.vapidConfigAbsent,
    trace: trace,
  );
  if (!vapidConfigured) return false;

  final hasPermission = permissionGranted();
  traceLocalSubscriptionGuard(
    passed: hasPermission,
    successState: LocalSubscriptionTraceState.permissionGranted,
    failureState: LocalSubscriptionTraceState.permissionFailed,
    trace: trace,
  );
  if (!hasPermission) return false;

  final serviceWorkers = serviceWorkerApi();
  traceLocalSubscriptionGuard(
    passed: serviceWorkers != null,
    successState: LocalSubscriptionTraceState.serviceWorkerApiAvailable,
    failureState: LocalSubscriptionTraceState.serviceWorkerApiFailed,
    trace: trace,
  );
  if (serviceWorkers == null) return false;

  try {
    final registrations = await runTracedLocalBrowserRead(
      read: () => getRegistrations(serviceWorkers),
      successState: LocalSubscriptionTraceState.registrationsOk,
      failureState: LocalSubscriptionTraceState.registrationsFailed,
      trace: trace,
    );
    final typedCandidates = <LocalMessagingWorkerCandidate<Registration>>[];
    for (final rawCandidate in registrations) {
      final candidate = inspectRegistration(rawCandidate);
      if (candidate != null) typedCandidates.add(candidate);
    }
    traceLocalSubscriptionGuard(
      passed: typedCandidates.isNotEmpty,
      successState: LocalSubscriptionTraceState.registrationTypeOk,
      failureState: LocalSubscriptionTraceState.registrationTypeFailed,
      trace: trace,
    );

    final activeCandidates = typedCandidates
        .where((candidate) => candidate.active)
        .toList(growable: false);
    traceLocalSubscriptionGuard(
      passed: activeCandidates.isNotEmpty,
      successState: LocalSubscriptionTraceState.workerActive,
      failureState: LocalSubscriptionTraceState.workerActiveFailed,
      trace: trace,
    );

    final scriptCandidates = activeCandidates
        .where((candidate) => candidate.scriptOk)
        .toList(growable: false);
    traceLocalSubscriptionGuard(
      passed: scriptCandidates.isNotEmpty,
      successState: LocalSubscriptionTraceState.workerScriptOk,
      failureState: LocalSubscriptionTraceState.workerScriptFailed,
      trace: trace,
    );

    final scopeCandidates = scriptCandidates
        .where((candidate) => candidate.scopeOk)
        .toList(growable: false);
    traceLocalSubscriptionGuard(
      passed: scopeCandidates.isNotEmpty,
      successState: LocalSubscriptionTraceState.workerScopeOk,
      failureState: LocalSubscriptionTraceState.workerScopeFailed,
      trace: trace,
    );

    final messagingWorkers = typedCandidates
        .where((candidate) => candidate.matches)
        .toList(growable: false);
    emitLocalSubscriptionTrace(
      trace,
      LocalSubscriptionTraceState.messagingWorkerCount(messagingWorkers.length),
    );
    if (messagingWorkers.length != 1) return false;

    final pushManager = getPushManager(messagingWorkers.single.registration);
    traceLocalSubscriptionGuard(
      passed: pushManager != null,
      successState: LocalSubscriptionTraceState.pushManagerAvailable,
      failureState: LocalSubscriptionTraceState.pushManagerFailed,
      trace: trace,
    );
    if (pushManager == null) return false;

    final rawSubscription = await runTracedLocalBrowserRead(
      read: () => getSubscription(pushManager),
      successState: LocalSubscriptionTraceState.getSubscriptionOk,
      failureState: LocalSubscriptionTraceState.getSubscriptionFailed,
      trace: trace,
    );
    traceLocalSubscriptionGuard(
      passed: rawSubscription != null,
      successState: LocalSubscriptionTraceState.subscriptionPresent,
      failureState: LocalSubscriptionTraceState.subscriptionAbsent,
      trace: trace,
    );
    if (rawSubscription == null) return false;

    final subscription = asPushSubscription(rawSubscription);
    traceLocalSubscriptionGuard(
      passed: subscription != null,
      successState: LocalSubscriptionTraceState.subscriptionTypeOk,
      failureState: LocalSubscriptionTraceState.subscriptionTypeFailed,
      trace: trace,
    );
    if (subscription == null) return false;

    final hasApplicationServerKey = applicationServerKeyPresent(subscription);
    traceLocalSubscriptionGuard(
      passed: hasApplicationServerKey,
      successState: LocalSubscriptionTraceState.applicationServerKeyPresent,
      failureState: LocalSubscriptionTraceState.applicationServerKeyAbsent,
      trace: trace,
    );
    if (!hasApplicationServerKey) return false;

    final matchesVapid = vapidMatches(subscription);
    traceLocalSubscriptionGuard(
      passed: matchesVapid,
      successState: LocalSubscriptionTraceState.vapidMatch,
      failureState: LocalSubscriptionTraceState.vapidMismatch,
      trace: trace,
    );
    return matchesVapid;
  } catch (error) {
    traceLocalSubscriptionException(
      error: error,
      classifyError: classifyError,
      trace: trace,
    );
    return false;
  }
}

abstract final class PushActivationTraceState {
  static const activationStarted = 'ACTIVATION_STARTED';
  static const permissionGranted = 'PERMISSION_GRANTED';
  static const permissionDenied = 'PERMISSION_DENIED';
  static const getTokenStarted = 'GET_TOKEN_STARTED';
  static const getTokenOk = 'GET_TOKEN_OK';
  static const getTokenFailed = 'GET_TOKEN_FAILED';
  static const tokenChanged = 'TOKEN_CHANGED';
  static const tokenUnchanged = 'TOKEN_UNCHANGED';
  static const persistStarted = 'PERSIST_STARTED';
  static const persistOk = 'PERSIST_OK';
  static const persistFailed = 'PERSIST_FAILED';
  static const activationReady = 'ACTIVATION_READY';
  static const activationFailed = 'ACTIVATION_FAILED';

  static const values = <String>{
    activationStarted,
    permissionGranted,
    permissionDenied,
    getTokenStarted,
    getTokenOk,
    getTokenFailed,
    tokenChanged,
    tokenUnchanged,
    persistStarted,
    persistOk,
    persistFailed,
    activationReady,
    activationFailed,
  };
}

void emitPushActivationTrace(void Function(String state) trace, String state) {
  try {
    trace(state);
  } catch (_) {
    // Diagnostic output must never affect push activation.
  }
}

void emitPushActivationPermission({
  required bool granted,
  required void Function(String state) trace,
}) {
  emitPushActivationTrace(
    trace,
    granted
        ? PushActivationTraceState.permissionGranted
        : PushActivationTraceState.permissionDenied,
  );
}

Future<String?> runTracedPushActivationTokenRequest({
  required Future<String?> Function() getToken,
  required void Function(String state) trace,
}) async {
  emitPushActivationTrace(trace, PushActivationTraceState.getTokenStarted);
  try {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      emitPushActivationTrace(trace, PushActivationTraceState.getTokenFailed);
      return null;
    }
    emitPushActivationTrace(trace, PushActivationTraceState.getTokenOk);
    return token;
  } catch (_) {
    emitPushActivationTrace(trace, PushActivationTraceState.getTokenFailed);
    rethrow;
  }
}

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

bool isExpectedFirebaseMessagingWorkerScope({
  required String origin,
  required String scope,
}) {
  final scopeUri = Uri.tryParse(scope);
  if (scopeUri == null) return false;
  final scopePath = scopeUri.path.endsWith('/')
      ? scopeUri.path.substring(0, scopeUri.path.length - 1)
      : scopeUri.path;
  return scopeUri.origin == origin &&
      scopePath == '/firebase-cloud-messaging-push-scope';
}

bool isExpectedFirebaseMessagingWorkerScript({
  required String origin,
  required String scriptUrl,
}) {
  final scriptUri = Uri.tryParse(scriptUrl);
  return scriptUri != null &&
      scriptUri.origin == origin &&
      scriptUri.path == '/firebase-messaging-sw.js';
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
  String? get existingInstallationId;
  Future<PushPermissionState> permissionState();
  Future<bool> hasUsableLocalSubscription();
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

/// Temporary read-only diagnostic capability for the Web Messaging record.
///
/// It exposes only a one-way fingerprint and stays separate from functional
/// Push operations so diagnostics cannot alter the token lifecycle.
/// The fingerprint represents the registration POST token only when the
/// controlled recipe has independently established a fresh successful POST
/// and no later Messaging DELETE/POST before this read.
abstract interface class LocalMessagingTokenFingerprintReader {
  Future<String?> readLocalMessagingTokenFingerprint();
}

Future<String?> readUniqueMessagingTokenFingerprint({
  required Future<bool> Function() databaseExists,
  required Future<List<Object?>> Function(String mode) readRecords,
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    if (!await databaseExists().timeout(timeout)) {
      return null;
    }
    final records = await readRecords('readonly').timeout(timeout);
    if (records.length != 1) return null;
    final record = records.single;
    if (record is! Map) return null;
    final token = record['token'];
    if (token is! String || token.isEmpty) return null;
    return sha256.convert(utf8.encode(token)).toString();
  } catch (_) {
    return null;
  }
}

PushNotificationGateway createPushNotificationGateway() =>
    const UnsupportedPushNotificationGateway();

class UnsupportedPushNotificationGateway implements PushNotificationGateway {
  const UnsupportedPushNotificationGateway();

  @override
  String get installationId => '';

  @override
  String? get existingInstallationId => null;

  @override
  Future<PushActivationResult> activate() async =>
      const PushActivationResult(PushPermissionState.unsupported);

  @override
  Future<PushPermissionState> permissionState() async =>
      PushPermissionState.unsupported;

  @override
  Future<bool> hasUsableLocalSubscription() async => false;

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
