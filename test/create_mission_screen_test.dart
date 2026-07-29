import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/create_need_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';

void main() {
  Future<void> pumpForm(
    WidgetTester tester,
    _MissionRepository repository,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepositoryScope(
        repository: repository,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SafeArea(child: CreateNeedScreen())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseLocation(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('mission-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(places.first.name).last);
    await tester.pumpAndSettle();
  }

  Future<void> chooseDate(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('mission-date')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseTime(
    WidgetTester tester,
    Key fieldKey,
    String expected,
  ) async {
    await tester.tap(find.byKey(fieldKey));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text(expected), findsOneWidget);
  }

  Future<void> completeRequiredFields(
    WidgetTester tester, {
    bool selectLocation = true,
  }) async {
    if (selectLocation) await chooseLocation(tester);
    await chooseDate(tester);
    await chooseTime(tester, const Key('mission-start-time'), '08:00');
    await chooseTime(tester, const Key('mission-end-time'), '12:00');
  }

  Future<void> revealPublishButton(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('publish-mission')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('date and both time pickers open and retain their choices', (
    tester,
  ) async {
    await pumpForm(tester, _MissionRepository());
    await chooseDate(tester);
    final today = DateTime.now();
    final dateLabel =
        '${today.day.toString().padLeft(2, '0')}/'
        '${today.month.toString().padLeft(2, '0')}/${today.year}';
    expect(find.text(dateLabel), findsOneWidget);

    await chooseTime(tester, const Key('mission-start-time'), '08:00');
    await chooseTime(tester, const Key('mission-end-time'), '12:00');
    expect(tester.takeException(), isNull);
  });

  testWidgets('publication refuses a missing location', (tester) async {
    final repository = _MissionRepository();
    await pumpForm(tester, repository);
    await revealPublishButton(tester);
    await tester.tap(find.byKey(const Key('publish-mission')));
    await tester.pump();

    expect(find.text('Choisissez un lieu'), findsOneWidget);
    expect(repository.calls, 0);
  });

  testWidgets('publication refuses two zero quotas', (tester) async {
    final repository = _MissionRepository();
    await pumpForm(tester, repository);
    await completeRequiredFields(tester);

    for (var index = 0; index < 4; index++) {
      await tester.tap(find.byKey(const Key('mk-remove')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('pp-remove')));
    await revealPublishButton(tester);
    await tester.tap(find.byKey(const Key('publish-mission')));
    await tester.pump();

    expect(
      find.text('Indiquez au moins un professionnel nécessaire'),
      findsOneWidget,
    );
    expect(repository.calls, 0);
  });

  testWidgets(
    'repository is called once and confirmation waits for the write',
    (tester) async {
      final repository = _MissionRepository(pending: true);
      await pumpForm(tester, repository);
      await completeRequiredFields(tester);
      await revealPublishButton(tester);
      await tester.tap(find.byKey(const Key('publish-mission')));
      await tester.pump();

      expect(repository.calls, 1);
      expect(find.text('Publication…'), findsOneWidget);
      expect(find.text('Mission publiée'), findsNothing);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('publish-mission')),
      );
      expect(button.onPressed, isNull);

      repository.complete();
      await tester.pumpAndSettle();
      expect(find.text('Mission publiée'), findsOneWidget);
      expect(find.text(places.first.name), findsOneWidget);
      expect(find.text('MK 4 • PP 1'), findsOneWidget);
    },
  );

  testWidgets('repository errors remain on the form and are explicit', (
    tester,
  ) async {
    final repository = _MissionRepository(error: true);
    await pumpForm(tester, repository);
    await completeRequiredFields(tester);
    await revealPublishButton(tester);
    await tester.tap(find.byKey(const Key('publish-mission')));
    await tester.pumpAndSettle();

    expect(
      find.text('La mission n’a pas pu être publiée. Réessayez.'),
      findsOneWidget,
    );
    expect(find.text('Mission publiée'), findsNothing);
    expect(repository.calls, 1);
  });

  testWidgets(
    'site manager has one injected location and no location selector',
    (tester) async {
      final merignac = places.singleWhere(
        (location) => location.name == 'Mérignac',
      );
      final repository = _MissionRepository(
        access: ResponsibleAccess(
          uid: 'manager-merignac',
          role: 'site_manager',
          locationIds: {merignac.id},
          active: true,
        ),
        locations: [merignac, places.first],
      );
      await pumpForm(tester, repository);

      expect(find.text('Créer un besoin'), findsOneWidget);
      expect(find.byKey(const Key('mission-location-locked')), findsOneWidget);
      expect(find.byKey(const Key('mission-location')), findsNothing);
      expect(find.text('Mérignac'), findsOneWidget);
      expect(find.text(places.first.name), findsNothing);

      await completeRequiredFields(tester, selectLocation: false);
      await revealPublishButton(tester);
      await tester.tap(find.byKey(const Key('publish-mission')));
      await tester.pumpAndSettle();

      expect(repository.calls, 1);
      expect(repository.lastDraft?.location.id, merignac.id);
    },
  );

  testWidgets('coordinator can select any location', (tester) async {
    final repository = _MissionRepository(locations: places.take(2).toList());
    await pumpForm(tester, repository);

    expect(find.byKey(const Key('mission-location')), findsOneWidget);
    expect(find.byKey(const Key('mission-location-locked')), findsNothing);
    await tester.tap(find.byKey(const Key('mission-location')));
    await tester.pumpAndSettle();
    expect(find.text(places[1].name), findsOneWidget);
  });

  test('an earlier end time crosses midnight and equal times are invalid', () {
    final overnight = MissionSchedule.fromLocal(
      date: DateTime(2026, 7, 30),
      startMinutes: 22 * 60,
      endMinutes: 2 * 60,
    );
    expect(overnight.startAt, DateTime(2026, 7, 30, 22));
    expect(overnight.endAt, DateTime(2026, 7, 31, 2));
    expect(
      () => MissionSchedule.fromLocal(
        date: DateTime(2026, 7, 30),
        startMinutes: 8 * 60,
        endMinutes: 8 * 60,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

class _MissionRepository implements CoordinationRepository {
  _MissionRepository({
    this.pending = false,
    this.error = false,
    this.access = _coordinatorAccess,
    List<ResponsePlace>? locations,
  }) : locations = locations ?? [places.first];

  final bool pending;
  final bool error;
  final ResponsibleAccess access;
  final List<ResponsePlace> locations;
  final Completer<String> _completer = Completer<String>();
  int calls = 0;
  MissionDraft? lastDraft;

  @override
  Stream<EngagementInfo?> watchMyEngagement(String missionId) =>
      Stream.value(null);

  @override
  Future<void> cancelEngagement(String missionId) async {}

  @override
  Future<void> cancelMission(String missionId, String? reason) async {}

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() => Stream.value(access);

  @override
  Future<ResponsibleAccess> signInResponsible({
    required String email,
    required String password,
  }) async => access;

  static const _coordinatorAccess = ResponsibleAccess(
    uid: 'test-manager',
    role: 'coordinator',
    locationIds: {'*'},
    active: true,
  );

  @override
  Future<void> signOutResponsible() async {}

  void complete() {
    if (!_completer.isCompleted) _completer.complete('created-mission');
  }

  @override
  Future<String> createMission(MissionDraft draft) {
    calls++;
    lastDraft = draft;
    if (error) return Future.error(StateError('write failed'));
    if (pending) return _completer.future;
    return Future.value('created-mission');
  }

  @override
  Stream<List<ResponsePlace>> watchLocations() => Stream.value(locations);

  @override
  Stream<List<CoordinationNeed>> watchMissions() =>
      const Stream<List<CoordinationNeed>>.empty();

  @override
  Future<void> createEngagement({
    required String missionId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    required VolunteerProfession profession,
  }) async {}
}
