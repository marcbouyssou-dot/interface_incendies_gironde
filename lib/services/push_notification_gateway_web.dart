// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import 'push_installation_id.dart';
import 'push_notification_gateway_stub.dart';

export 'push_notification_gateway_stub.dart'
    show
        PushActivationResult,
        PushNotificationGateway,
        PushPermissionState,
        resolveWebPushPermissionState;

const _vapidKey = String.fromEnvironment('FIREBASE_WEB_PUSH_VAPID_KEY');
const _installationKey = 'mobsante.push.installation.v1';

extension type _BadgeNavigator._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> setAppBadge(JSNumber count);
  external JSPromise<JSAny?> clearAppBadge();
}

@JS('navigator')
external _BadgeNavigator get _badgeNavigator;

PushNotificationGateway createPushNotificationGateway() =>
    FirebaseWebPushNotificationGateway.instance;

class FirebaseWebPushNotificationGateway implements PushNotificationGateway {
  FirebaseWebPushNotificationGateway._();

  static final instance = FirebaseWebPushNotificationGateway._();

  Future<void> _operationTail = Future.value();
  Future<PushSubscriptionRegistration?>? _sessionReconciliation;
  Future<PushSubscriptionRegistration?>? _forcedRenewal;
  int _registrationGeneration = 0;

  @override
  String get installationId => _installationId();

  @override
  Stream<PushSubscriptionRegistration> get registrationUpdates =>
      FirebaseMessaging.instance.onTokenRefresh
          .where((token) => token.isNotEmpty)
          .map(
            (token) => PushSubscriptionRegistration(
              installationId: _installationId(),
              token: token,
              platform: 'web',
            ),
          );

  @override
  Future<PushPermissionState> permissionState() async {
    final isSupported = await FirebaseMessaging.instance.isSupported();
    final availability = resolveWebPushPermissionState(
      isSupported: isSupported,
      vapidKey: _vapidKey,
      permission: PushPermissionState.prompt,
    );
    if (availability != PushPermissionState.prompt) return availability;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return resolveWebPushPermissionState(
      isSupported: isSupported,
      vapidKey: _vapidKey,
      permission: _map(settings.authorizationStatus),
    );
  }

  @override
  Future<PushActivationResult> activate() async {
    if (!await FirebaseMessaging.instance.isSupported()) {
      return const PushActivationResult(PushPermissionState.unsupported);
    }
    if (_vapidKey.trim().isEmpty) {
      return const PushActivationResult(PushPermissionState.misconfigured);
    }
    final settings = await FirebaseMessaging.instance.requestPermission();
    final state = _map(settings.authorizationStatus);
    if (state != PushPermissionState.granted) {
      return PushActivationResult(state);
    }
    final forcedRenewal = _forcedRenewal;
    if (forcedRenewal != null) {
      return PushActivationResult(state, registration: await forcedRenewal);
    }
    _registrationGeneration += 1;
    final generation = _registrationGeneration;
    late final Future<PushSubscriptionRegistration?> activation;
    activation = _enqueueRegistration(() async {
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: _vapidKey,
      );
      if (token == null || token.isEmpty) return null;
      final registration = PushSubscriptionRegistration(
        installationId: _installationId(),
        token: token,
        platform: 'web',
      );
      return generation == _registrationGeneration ? registration : null;
    });
    _sessionReconciliation = activation;
    var registration = await activation;
    if (registration == null && generation != _registrationGeneration) {
      final replacement = _forcedRenewal;
      if (replacement != null) registration = await replacement;
      return PushActivationResult(state, registration: registration);
    }
    if (registration == null) {
      return const PushActivationResult(PushPermissionState.misconfigured);
    }
    _sessionReconciliation = Future.value(registration);
    return PushActivationResult(state, registration: registration);
  }

  @override
  Future<PushSubscriptionRegistration?> reconcileRegistration() {
    final forcedRenewal = _forcedRenewal;
    if (forcedRenewal != null) return forcedRenewal;
    final generation = _registrationGeneration;
    return _sessionReconciliation ??= _enqueueRegistration(() async {
      final registration = await _reconcileRegistration();
      return generation == _registrationGeneration ? registration : null;
    });
  }

  Future<PushSubscriptionRegistration?> _enqueueRegistration(
    Future<PushSubscriptionRegistration?> Function() operation,
  ) {
    final completer = Completer<PushSubscriptionRegistration?>();
    _operationTail = _operationTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<PushSubscriptionRegistration?> _reconcileRegistration() async {
    if (!await FirebaseMessaging.instance.isSupported() ||
        _vapidKey.trim().isEmpty) {
      return null;
    }
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (_map(settings.authorizationStatus) != PushPermissionState.granted) {
      return null;
    }
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: _vapidKey,
    );
    if (token == null || token.isEmpty) return null;
    return PushSubscriptionRegistration(
      installationId: _installationId(),
      token: token,
      platform: 'web',
    );
  }

  @override
  Future<PushSubscriptionRegistration?> renewRegistration() {
    final forcedRenewal = _forcedRenewal;
    if (forcedRenewal != null) return forcedRenewal;
    _registrationGeneration += 1;
    _sessionReconciliation = null;
    late final Future<PushSubscriptionRegistration?> guardedRenewal;
    guardedRenewal = _enqueueRegistration(_renewRegistration).whenComplete(() {
      if (identical(_forcedRenewal, guardedRenewal)) {
        _forcedRenewal = null;
      }
    });
    _forcedRenewal = guardedRenewal;
    return guardedRenewal;
  }

  Future<PushSubscriptionRegistration?> _renewRegistration() async {
    _sessionReconciliation = null;
    if (!await FirebaseMessaging.instance.isSupported() ||
        _vapidKey.trim().isEmpty) {
      return null;
    }
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (_map(settings.authorizationStatus) != PushPermissionState.granted) {
      return null;
    }
    final token = await runTracedStaleTokenRenewal(
      deleteToken: FirebaseMessaging.instance.deleteToken,
      getToken: () => FirebaseMessaging.instance.getToken(vapidKey: _vapidKey),
      trace: debugPrint,
    );
    if (token == null) return null;
    final registration = PushSubscriptionRegistration(
      installationId: _installationId(),
      token: token,
      platform: 'web',
    );
    _sessionReconciliation = Future.value(registration);
    return registration;
  }

  @override
  Future<void> updateBadge(int count) async {
    try {
      if (count <= 0) {
        await _badgeNavigator.clearAppBadge().toDart;
      } else {
        await _badgeNavigator.setAppBadge(count.toJS).toDart;
      }
    } catch (_) {
      // The Badging API is optional. Notifications remain fully usable.
    }
  }

  String _installationId() {
    final existing = html.window.localStorage[_installationKey];
    if (existing != null && existing.isNotEmpty) return existing;
    final value = generatePushInstallationId(Random.secure());
    html.window.localStorage[_installationKey] = value;
    return value;
  }

  PushPermissionState _map(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushPermissionState.granted,
    AuthorizationStatus.denied => PushPermissionState.denied,
    AuthorizationStatus.notDetermined => PushPermissionState.prompt,
  };
}
