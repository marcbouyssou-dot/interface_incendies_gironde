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
    await tester.pump();
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
    expect(find.text('Aucune notification'), findsOneWidget);
    await tester.tap(find.byKey(const Key('activate-notifications')));
    await tester.pump();

    expect(gateway.activationCalls, 1);
    expect(repository.pushSubscriptions.keys, contains('device-test'));
    expect(find.text('Notifications activées'), findsOneWidget);
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
    expect(find.textContaining('ne permet pas encore'), findsOneWidget);
    final button = tester.widget<CupertinoButton>(
      find.descendant(
        of: find.byKey(const Key('activate-notifications')),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(gateway.activationCalls, 0);
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

class _FakePushGateway implements PushNotificationGateway {
  _FakePushGateway({
    this.permission = PushPermissionState.prompt,
    this.activationState = PushPermissionState.granted,
  });

  PushPermissionState permission;
  final PushPermissionState activationState;
  int activationCalls = 0;
  int lastBadge = 0;

  @override
  Stream<PushSubscriptionRegistration> get registrationUpdates =>
      const Stream.empty();

  @override
  Future<PushActivationResult> activate() async {
    activationCalls += 1;
    permission = activationState;
    return PushActivationResult(
      activationState,
      registration: activationState == PushPermissionState.granted
          ? const PushSubscriptionRegistration(
              installationId: 'device-test',
              token: 'token-test',
              platform: 'web',
            )
          : null,
    );
  }

  @override
  Future<PushPermissionState> permissionState() async => permission;

  @override
  Future<void> updateBadge(int count) async => lastBadge = count;
}
