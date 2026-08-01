import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/responsible_access.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/coordination_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';

void main() {
  CoordinationNeed mission(ResponsePlace location) => CoordinationNeed(
    id: 'mission-action',
    locationId: location.id,
    place: location.name,
    group: location.group,
    date: '03/08/2026',
    time: '08:00 — 12:00',
    startAt: DateTime(2026, 8, 3, 8),
    endAt: DateTime(2026, 8, 3, 12),
    requiredPhysiotherapists: 1,
    registeredPhysiotherapists: 0,
    requiredPodiatrists: 0,
    registeredPodiatrists: 0,
    equipment: const [],
    createdBy: 'another-manager',
  );

  Future<void> pump(
    WidgetTester tester,
    ResponsibleAccess access,
    ResponsePlace location,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockCoordinationRepository(
      initialMissions: [mission(location)],
      initialLocations: [location],
      initialEngagements: const [],
      responsibleAccess: access,
    );
    final liveData = LiveCoordinationData(repository);
    addTearDown(liveData.dispose);
    await tester.pumpWidget(
      RepositoryScope(
        repository: repository,
        child: LiveCoordinationDataScope(
          data: liveData,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: SafeArea(child: CoordinationScreen())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('coordinator can open the pre-filled edit form', (tester) async {
    final location = places.first;
    await pump(
      tester,
      const ResponsibleAccess(
        uid: 'coordinator',
        role: 'coordinator',
        locationIds: {},
        active: true,
      ),
      location,
    );

    final action = find.byKey(const Key('edit-mission-mission-action'));
    await tester.scrollUntilVisible(
      action,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Modifier la mission'), findsOneWidget);
    expect(find.byKey(const Key('update-mission')), findsOneWidget);
  });

  testWidgets('site manager outside the location sees no mission action', (
    tester,
  ) async {
    final location = places.first;
    final other = places
        .where((candidate) => candidate.id != location.id)
        .first;
    await pump(
      tester,
      ResponsibleAccess.v2(
        uid: 'manager',
        roles: const ['site_manager'],
        locationIds: {other.id},
        active: true,
      ),
      location,
    );

    expect(find.byKey(const Key('edit-mission-mission-action')), findsNothing);
  });

  testWidgets('site manager in the location sees the mission edit action', (
    tester,
  ) async {
    final location = places.first;
    await pump(
      tester,
      ResponsibleAccess.v2(
        uid: 'manager',
        roles: const ['site_manager'],
        locationIds: {location.id},
        active: true,
      ),
      location,
    );

    final action = find.byKey(const Key('edit-mission-mission-action'));
    await tester.scrollUntilVisible(
      action,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(action, findsOneWidget);
    expect(find.text('Modifier la mission'), findsOneWidget);
  });
}
