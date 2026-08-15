import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/app_notification.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/volunteer_profile.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/services/professional_verification_service.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_admin_invitation_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_location_administration_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_responsible_access_administration_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/create_need_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/utils/french_date_time.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';
import 'package:interface_incendies_gironde/widgets/v5_form_system.dart';

void main() {
  Future<void> pumpForm(
    WidgetTester tester,
    _MissionRepository repository, {
    CoordinationNeed? mission,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final liveData = LiveCoordinationData(repository);
    addTearDown(liveData.dispose);
    await tester.pumpWidget(
      RepositoryScope(
        repository: repository,
        child: LiveCoordinationDataScope(
          data: liveData,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SafeArea(child: CreateNeedScreen(mission: mission)),
            ),
          ),
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
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseTime(
    WidgetTester tester,
    Key fieldKey,
    String expected,
  ) async {
    await tester.tap(find.byKey(fieldKey));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text(expected), findsOneWidget);
  }

  Future<void> completeRequiredFields(
    WidgetTester tester, {
    bool selectLocation = true,
    bool addQuota = true,
  }) async {
    if (selectLocation) await chooseLocation(tester);
    await chooseDate(tester);
    await chooseTime(tester, const Key('mission-start-time'), '08:00');
    await chooseTime(tester, const Key('mission-end-time'), '12:00');
    if (addQuota) {
      await tester.tap(
        find.byKey(const Key('physiotherapist-add')),
        warnIfMissed: false,
      );
      await tester.pump();
    }
  }

  Future<void> revealPublishButton(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('publish-mission')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> addQuota(WidgetTester tester, String professionId) async {
    final button = find.byKey(Key('$professionId-add'));
    await tester.scrollUntilVisible(
      button,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('date and both time pickers open and retain their choices', (
    tester,
  ) async {
    await pumpForm(tester, _MissionRepository());
    await chooseDate(tester);
    final today = DateTime.now();
    expect(find.text(FrenchDateTime.date(today)), findsOneWidget);

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

    expect(find.text('Choisissez un lieu d’intervention.'), findsOneWidget);
    expect(repository.calls, 0);
  });

  testWidgets('publication refuses two zero quotas', (tester) async {
    final repository = _MissionRepository();
    await pumpForm(tester, repository);
    await completeRequiredFields(tester, addQuota: false);
    await revealPublishButton(tester);
    await tester.tap(find.byKey(const Key('publish-mission')));
    await tester.pump();

    expect(
      find.text('Indiquez au moins un professionnel nécessaire.'),
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
      final button = tester.widget<V5Button>(
        find.byKey(const Key('publish-mission')),
      );
      expect(button.onPressed, isNull);

      repository.complete();
      await tester.pumpAndSettle();
      expect(find.text('Mission publiée'), findsOneWidget);
      expect(find.text(places.first.name), findsOneWidget);
      expect(find.text('MK 1'), findsOneWidget);
    },
  );

  testWidgets('all profession quotas start at zero and are persisted', (
    tester,
  ) async {
    final repository = _MissionRepository();
    await pumpForm(tester, repository);

    expect(find.text('Professionnels recherchés'), findsOneWidget);
    expect(find.text('Masseur-kinésithérapeute'), findsOneWidget);
    expect(find.text('Pédicure-podologue'), findsOneWidget);
    expect(find.text('Médecin'), findsOneWidget);
    expect(find.text('Infirmier'), findsOneWidget);
    expect(find.text('Vétérinaire'), findsOneWidget);
    expect(find.text('Autre professionnel de santé'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(6));

    await completeRequiredFields(tester, addQuota: false);
    await addQuota(tester, 'physician');
    await addQuota(tester, 'nurse');
    await addQuota(tester, 'nurse');
    await addQuota(tester, 'veterinarian');
    await addQuota(tester, 'other_health_professional');
    await revealPublishButton(tester);
    await tester.tap(find.byKey(const Key('publish-mission')));
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(repository.lastDraft?.requiredByProfession, {
      'physiotherapist': 0,
      'podiatrist': 0,
      'physician': 1,
      'nurse': 2,
      'veterinarian': 1,
      'other_health_professional': 1,
    });
  });

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

  testWidgets('site manager has one prefilled location and no location field', (
    tester,
  ) async {
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
    expect(find.byKey(const Key('mission-location-locked')), findsNothing);
    expect(find.byKey(const Key('mission-location')), findsNothing);
    expect(find.text('Lieu · Mérignac'), findsOneWidget);
    expect(find.text(places.first.name), findsNothing);

    await completeRequiredFields(tester, selectLocation: false);
    await revealPublishButton(tester);
    await tester.tap(find.byKey(const Key('publish-mission')));
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(repository.lastDraft?.location.id, merignac.id);
  });

  testWidgets('coordinator can select any location', (tester) async {
    final repository = _MissionRepository(
      locations: [
        places.singleWhere((place) => place.name == 'Bordeaux Benauge'),
        places.singleWhere((place) => place.name == 'Bordeaux Bastide'),
      ],
    );
    await pumpForm(tester, repository);

    expect(find.byKey(const Key('mission-location')), findsOneWidget);
    expect(find.byKey(const Key('mission-location-locked')), findsNothing);
    await tester.tap(find.byKey(const Key('mission-location')));
    await tester.pumpAndSettle();
    expect(find.text('Bordeaux Bastide'), findsOneWidget);
    expect(find.text('Bordeaux Benauge'), findsNothing);
  });

  testWidgets('invalid V2 access blocks the mission form explicitly', (
    tester,
  ) async {
    final repository = _MissionRepository(
      accessError: const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.invalidLocationIds,
        'invalid V2 scope',
      ),
    );

    await pumpForm(tester, repository);

    expect(find.text('Configuration d’accès invalide'), findsOneWidget);
    expect(find.byKey(const Key('publish-mission')), findsNothing);
    expect(find.byKey(const Key('mission-location')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('cumulative coordinator retains the global location selector', (
    tester,
  ) async {
    final operational = places
        .where((location) => location.isOperational)
        .take(2)
        .toList(growable: false);
    final repository = _MissionRepository(
      access: ResponsibleAccess.v2(
        uid: 'cumulative',
        roles: const ['coordinator', 'site_manager'],
        locationIds: {operational.first.id},
        active: true,
      ),
      locations: operational,
    );
    await pumpForm(tester, repository);

    expect(find.byKey(const Key('mission-location')), findsOneWidget);
    expect(find.byKey(const Key('mission-location-locked')), findsNothing);
    final selector = tester.widget<V5SelectField<String>>(
      find.byKey(const Key('mission-location')),
    );
    expect(selector.options.map((item) => item.value), [
      operational[0].id,
      operational[1].id,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'multi-site manager selector contains only authorized locations',
    (tester) async {
      final operational = places
          .where((location) => location.isOperational)
          .take(3)
          .toList(growable: false);
      final allowed = operational.take(2).toList(growable: false);
      final denied = operational[2];
      final repository = _MissionRepository(
        access: ResponsibleAccess.v2(
          uid: 'multi-manager',
          roles: const ['site_manager'],
          locationIds: allowed.map((location) => location.id).toSet(),
          active: true,
        ),
        locations: [...allowed, denied],
      );
      await pumpForm(tester, repository);

      expect(find.byKey(const Key('mission-location')), findsOneWidget);
      expect(find.byKey(const Key('mission-location-locked')), findsNothing);
      final selector = tester.widget<V5SelectField<String>>(
        find.byKey(const Key('mission-location')),
      );
      expect(selector.options.map((item) => item.value), [
        allowed[0].id,
        allowed[1].id,
      ]);
      expect(selector.options.any((item) => item.value == denied.id), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets('edit mode pre-fills the mission and updates it once', (
    tester,
  ) async {
    final location = places.first;
    final start = DateTime.now().add(const Duration(days: 1));
    final mission = CoordinationNeed(
      id: 'mission-to-edit',
      locationId: location.id,
      place: location.name,
      group: location.group,
      date: '03/08/2026',
      time: '08:00 — 12:00',
      startAt: DateTime(start.year, start.month, start.day, 8),
      endAt: DateTime(start.year, start.month, start.day, 12),
      requiredPhysiotherapists: 2,
      registeredPhysiotherapists: 1,
      requiredPodiatrists: 1,
      registeredPodiatrists: 0,
      equipment: const ['Tables', 'Huiles'],
      details: 'Consigne initiale',
      createdBy: 'another-manager',
    );
    final repository = _MissionRepository(locations: [location]);
    await pumpForm(tester, repository, mission: mission);

    expect(find.text('Modifier la mission'), findsOneWidget);
    expect(find.text('Enregistrer les modifications'), findsOneWidget);
    expect(find.text(location.name), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Consigne initiale'), findsOneWidget);
    expect(find.byKey(const Key('publish-mission')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('update-mission')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('update-mission')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.calls, 0);
    expect(repository.updatedMissionId, mission.id);
    expect(repository.lastDraft?.location.id, location.id);
    expect(repository.lastDraft?.requiredPhysiotherapists, 2);
    expect(find.text('Mission mise à jour.'), findsOneWidget);
  });

  testWidgets('return from edit mode closes the form without writing', (
    tester,
  ) async {
    final location = places.first;
    final start = DateTime.now().add(const Duration(days: 1));
    final mission = CoordinationNeed(
      id: 'mission-cancel-edit',
      locationId: location.id,
      place: location.name,
      group: location.group,
      date: '03/08/2026',
      time: '08:00 — 12:00',
      startAt: DateTime(start.year, start.month, start.day, 8),
      endAt: DateTime(start.year, start.month, start.day, 12),
      requiredPhysiotherapists: 2,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 1,
      registeredPodiatrists: 0,
      equipment: const ['Tables', 'Huiles'],
      details: 'Consigne conservée',
    );
    final repository = _MissionRepository(locations: [location]);
    final liveData = LiveCoordinationData(repository);
    addTearDown(liveData.dispose);
    await tester.pumpWidget(
      RepositoryScope(
        repository: repository,
        child: MaterialApp(
          home: LiveCoordinationDataScope(
            data: liveData,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => openMissionEditor(context, mission),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier la mission'), findsOneWidget);
    expect(find.text(location.name), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('Consigne conservée'), findsOneWidget);
    expect(repository.updateCalls, 0);
    expect(repository.calls, 0);

    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();

    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.text('Modifier la mission'), findsNothing);
    expect(repository.updateCalls, 0);
    expect(repository.calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit mode refuses a quota below registered counters', (
    tester,
  ) async {
    final location = places.first;
    final start = DateTime.now().add(const Duration(days: 1));
    final mission = CoordinationNeed(
      id: 'mission-with-engagements',
      locationId: location.id,
      place: location.name,
      group: location.group,
      date: '03/08/2026',
      time: '08:00 — 12:00',
      startAt: DateTime(start.year, start.month, start.day, 8),
      endAt: DateTime(start.year, start.month, start.day, 12),
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 1,
      requiredPodiatrists: 1,
      registeredPodiatrists: 0,
      equipment: const [],
    );
    final repository = _MissionRepository(locations: [location]);
    await pumpForm(tester, repository, mission: mission);
    await tester.scrollUntilVisible(
      find.byKey(const Key('physiotherapist-remove')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('physiotherapist-remove')));
    await tester.ensureVisible(find.byKey(const Key('update-mission')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('update-mission')));
    await tester.pump();

    expect(
      find.text(
        'Le besoin ne peut pas être inférieur aux engagements confirmés.',
      ),
      findsOneWidget,
    );
    expect(repository.updateCalls, 0);
  });

  testWidgets('edit mode exposes the exact outside-scope error', (
    tester,
  ) async {
    final location = places.first;
    final start = DateTime.now().add(const Duration(days: 1));
    final mission = CoordinationNeed(
      id: 'mission-outside-scope',
      locationId: location.id,
      place: location.name,
      group: location.group,
      date: '03/08/2026',
      time: '08:00 — 12:00',
      startAt: DateTime(start.year, start.month, start.day, 8),
      endAt: DateTime(start.year, start.month, start.day, 12),
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      equipment: const [],
    );
    final repository = _MissionRepository(
      locations: [location],
      updateError: const RepositoryException(
        'Vous ne pouvez modifier que les missions de vos centres.',
      ),
    );
    await pumpForm(tester, repository, mission: mission);
    await tester.ensureVisible(find.byKey(const Key('update-mission')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('update-mission')));
    await tester.pumpAndSettle();

    expect(
      find.text('Vous ne pouvez modifier que les missions de vos centres.'),
      findsOneWidget,
    );
  });
}

class _MissionRepository implements CoordinationRepository {
  _MissionRepository({
    this.pending = false,
    this.error = false,
    this.updateError,
    this.accessError,
    this.access = _coordinatorAccess,
    List<ResponsePlace>? locations,
  }) : locations = locations ?? [places.first];

  final bool pending;
  final bool error;
  final Object? accessError;
  final RepositoryException? updateError;
  final ResponsibleAccess access;
  final List<ResponsePlace> locations;
  final Completer<String> _completer = Completer<String>();

  @override
  Future<CoordinationNeed?> getMission(String missionId) async => null;

  @override
  Stream<List<AppNotification>> watchNotifications() => Stream.value(const []);

  @override
  Future<void> setNotificationRead(
    String notificationId, {
    required bool read,
  }) async {}

  @override
  Stream<NotificationPreferences> watchNotificationPreferences() =>
      Stream.value(const NotificationPreferences());

  @override
  Future<void> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) async {}

  @override
  Future<void> registerPushSubscription(
    PushSubscriptionRegistration registration,
  ) async {}

  @override
  Future<void> disablePushSubscription(String installationId) async {}
  int calls = 0;
  int updateCalls = 0;
  String? updatedMissionId;
  MissionDraft? lastDraft;
  @override
  final adminInvitationRepository = MockAdminInvitationRepository();
  @override
  final locationAdministrationRepository =
      MockLocationAdministrationRepository();
  @override
  final responsibleAccessAdministrationRepository =
      MockResponsibleAccessAdministrationRepository();

  @override
  Stream<EngagementInfo?> watchMyEngagement(String missionId) =>
      Stream.value(null);

  @override
  Stream<List<EngagementInfo>> watchMissionEngagements(String missionId) =>
      Stream.value(const []);

  @override
  Future<void> updateEngagementStatus({
    required String missionId,
    required String volunteerId,
    required EngagementStatus status,
  }) async {}

  @override
  Future<void> cancelEngagement(String missionId) async {}

  @override
  Future<void> cancelMission(String missionId, String? reason) async {}

  @override
  Future<void> updateMission(String missionId, MissionDraft draft) async {
    updateCalls++;
    updatedMissionId = missionId;
    lastDraft = draft;
    if (updateError != null) throw updateError!;
  }

  @override
  Future<VolunteerProfile?> getVolunteerProfile() async => null;

  @override
  Future<void> saveVolunteerProfile(VolunteerProfile profile) async {}

  @override
  Future<VolunteerProfile> confirmProfessionalRpps(
    ProfessionalVerificationResult verification,
  ) => throw UnimplementedError();

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() =>
      accessError == null ? Stream.value(access) : Stream.error(accessError!);

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
  Future<EngagementCreationResult> createEngagement({
    required String missionId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    String? rpps,
    ProfessionalIdType? professionalIdType,
    String? professionalIdValue,
    String? cptsId,
    String? cptsLabel,
    required VolunteerProfession profession,
    List<String> equipment = const [],
    String? otherEquipmentDetails,
  }) async => EngagementCreationResult.created;
}
