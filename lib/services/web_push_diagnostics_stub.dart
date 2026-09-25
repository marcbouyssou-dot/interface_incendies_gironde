String? peekInstallationId() => null;

String notificationPermission() => 'unsupported';

bool isStandaloneDisplayMode() => false;

bool? navigatorStandaloneLegacy() => null;

Map<String, String>? serviceWorkerController() => null;

Future<List<Map<String, String?>>> serviceWorkerRegistrations() =>
    Future.value(const []);

String currentOrigin() => 'unsupported';
