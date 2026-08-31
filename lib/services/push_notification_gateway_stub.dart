import '../models/app_notification.dart';

enum PushPermissionState { unsupported, prompt, granted, denied, misconfigured }

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
