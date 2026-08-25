import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/app_notification.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/notification_center_screen.dart';
import 'package:interface_incendies_gironde/services/push_notification_gateway.dart';
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
    String? initialNotificationId,
    ThemeMode themeMode = ThemeMode.light,
    double textScale = 1,
    bool reduceMotion = false,
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
            initialNotificationId: initialNotificationId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
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

  testWidgets(
    'existing subscription hydrates active state without permission request or token',
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
      expect(gateway.tokenRequests, 0);
    },
  );

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
    expect(gateway.tokenRequests, 0);
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
    expect(gateway.tokenRequests, 0);
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

class _FakePushGateway implements PushNotificationGateway {
  _FakePushGateway({
    this.permission = PushPermissionState.prompt,
    this.activationState = PushPermissionState.granted,
    this.token = 'token-test',
  });

  PushPermissionState permission;
  final PushPermissionState activationState;
  final String token;
  int activationCalls = 0;
  int permissionStateCalls = 0;
  int tokenRequests = 0;
  int lastBadge = 0;

  @override
  String get installationId => 'device-test';

  @override
  Stream<PushSubscriptionRegistration> get registrationUpdates =>
      const Stream.empty();

  @override
  Future<PushActivationResult> activate() async {
    activationCalls += 1;
    permission = activationState;
    if (activationState == PushPermissionState.granted) tokenRequests += 1;
    return PushActivationResult(
      activationState,
      registration: activationState == PushPermissionState.granted
          ? PushSubscriptionRegistration(
              installationId: 'device-test',
              token: token,
              platform: 'web',
            )
          : null,
    );
  }

  @override
  Future<PushPermissionState> permissionState() async {
    permissionStateCalls += 1;
    return permission;
  }

  @override
  Future<void> updateBadge(int count) async => lastBadge = count;
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
