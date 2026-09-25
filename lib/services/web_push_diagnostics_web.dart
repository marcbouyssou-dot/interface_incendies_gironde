// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js_interop';

const _installationKey = 'mobsante.push.installation.v1';

extension type _NotificationApi._(JSObject _) implements JSObject {
  external JSString get permission;
}

extension type _Navigator._(JSObject _) implements JSObject {
  external JSBoolean? get standalone;
  external _ServiceWorkerContainer? get serviceWorker;
}

extension type _ServiceWorkerContainer._(JSObject _) implements JSObject {
  external _ServiceWorker? get controller;
  external JSPromise<JSArray<_ServiceWorkerRegistration>> getRegistrations();
}

extension type _ServiceWorkerRegistration._(JSObject _) implements JSObject {
  external JSString get scope;
  external _ServiceWorker? get active;
  external _ServiceWorker? get waiting;
  external _ServiceWorker? get installing;
}

extension type _ServiceWorker._(JSObject _) implements JSObject {
  external JSString get scriptURL;
}

@JS('Notification')
external _NotificationApi? get _notificationApi;

@JS('navigator')
external _Navigator get _navigator;

String? peekInstallationId() {
  final value = html.window.localStorage[_installationKey];
  return value == null || value.isEmpty ? null : value;
}

String notificationPermission() {
  final notification = _notificationApi;
  return notification == null ? 'unsupported' : notification.permission.toDart;
}

bool isStandaloneDisplayMode() =>
    html.window.matchMedia('(display-mode: standalone)').matches;

bool? navigatorStandaloneLegacy() => _navigator.standalone?.toDart;

Map<String, String>? serviceWorkerController() {
  final controller = _navigator.serviceWorker?.controller;
  if (controller == null) return null;
  return {'present': 'true', 'scriptURL': controller.scriptURL.toDart};
}

Future<List<Map<String, String?>>> serviceWorkerRegistrations() async {
  final serviceWorker = _navigator.serviceWorker;
  if (serviceWorker == null) return const [];
  try {
    final registrations =
        (await serviceWorker.getRegistrations().toDart).toDart;
    return registrations
        .map(
          (registration) => {
            'scope': registration.scope.toDart,
            'active': registration.active?.scriptURL.toDart,
            'waiting': registration.waiting?.scriptURL.toDart,
            'installing': registration.installing?.scriptURL.toDart,
          },
        )
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

String currentOrigin() => html.window.location.origin;
