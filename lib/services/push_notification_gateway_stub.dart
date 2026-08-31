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
