import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

void main() {
  testWidgets(
    'coordinator publication uses the selected location and is immediately visible',
    (tester) async {
      final location = places.firstWhere(
        (candidate) => candidate.isOperational && candidate.isEnabled,
      );
      final repository = _CoordinatorPublicationRepository(
        locations: [location],
      );

      await _pumpCoordinator(tester, repository);
      await _openAndCompleteForm(tester, location);
      await tester.tap(find.byKey(const Key('publish-mission')));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(repository.lastDraft?.location.id, location.id);
      expect(find.text('Mission publiée'), findsOneWidget);

      await tester.tap(find.text('Voir la mission'));
      await tester.pumpAndSettle();

      final sector = find.byKey(Key('sector-status-${location.group.name}'));
      expect(sector, findsOneWidget);
      expect(
        find.descendant(of: sector, matching: find.text('Besoins actifs')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sector, matching: find.text('1')),
        findsWidgets,
      );

      await tester.tap(find.text('Vue d’ensemble'));
      await tester.pumpAndSettle();
      final summary = find.byKey(const Key('coordinator-operational-summary'));
      expect(
        find.descendant(of: summary, matching: find.text('1')),
        findsWidgets,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();

      final reloadedSummary = find.byKey(
        const Key('coordinator-operational-summary'),
      );
      expect(
        find.descendant(of: reloadedSummary, matching: find.text('1')),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'a failed coordinator write never updates the coordinator views',
    (tester) async {
      final location = places.firstWhere(
        (candidate) => candidate.isOperational && candidate.isEnabled,
      );
      final repository = _CoordinatorPublicationRepository(
        locations: [location],
        failWrite: true,
      );

      await _pumpCoordinator(tester, repository);
      await _openAndCompleteForm(tester, location);
      await tester.tap(find.byKey(const Key('publish-mission')));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(find.text('Mission publiée'), findsNothing);
      expect(
        find.text('La mission n’a pas pu être publiée. Réessayez.'),
        findsOneWidget,
      );
    },
  );
}

Future<void> _pumpCoordinator(
  WidgetTester tester,
  _CoordinatorPublicationRepository repository,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FireCoordinationApp(repository: repository));
  await tester.pumpAndSettle();
}

Future<void> _openAndCompleteForm(
  WidgetTester tester,
  ResponsePlace location,
) async {
  final createButton = find.byKey(const Key('administration-create-need'));
  await tester.ensureVisible(createButton);
  await tester.pumpAndSettle();
  await tester.tap(createButton);
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('mission-location')), findsOneWidget);
  expect(find.byKey(const Key('mission-location-locked')), findsNothing);
  await tester.tap(find.byKey(const Key('mission-location')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(location.name).last);
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('mission-date')));
  await tester.pumpAndSettle();
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  await tester.tap(find.text('${tomorrow.day}').last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();

  await _chooseTime(tester, const Key('mission-start-time'));
  await _chooseTime(tester, const Key('mission-end-time'));
  await tester.ensureVisible(find.byKey(const Key('physiotherapist-add')));
  await tester.tap(find.byKey(const Key('physiotherapist-add')));
  await _scrollIntoView(tester, find.byKey(const Key('publish-mission')));
}

Future<void> _chooseTime(WidgetTester tester, Key fieldKey) async {
  await tester.tap(find.byKey(fieldKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _scrollIntoView(WidgetTester tester, Finder target) async {
  final form = find.byKey(const PageStorageKey('create'));
  for (var attempt = 0; attempt < 10; attempt++) {
    if (tester.getCenter(target).dy < 800) return;
    await tester.drag(form, const Offset(0, -500));
    await tester.pumpAndSettle();
  }
}

class _CoordinatorPublicationRepository extends MockCoordinationRepository {
  _CoordinatorPublicationRepository({
    required List<ResponsePlace> locations,
    this.failWrite = false,
  }) : super(
         initialMissions: const [],
         initialLocations: locations,
         initialEngagements: const [],
         responsibleAccess: const ResponsibleAccess(
           uid: 'coordinator-publication',
           role: ResponsibleRole.coordinator,
           locationIds: {'*'},
           active: true,
         ),
       );

  final bool failWrite;
  int createCalls = 0;
  MissionDraft? lastDraft;
  CoordinationNeed? _persistedMission;

  @override
  Stream<List<CoordinationNeed>> watchMissions() =>
      Stream.value([if (_persistedMission != null) _persistedMission!]);

  @override
  Future<String> createMission(MissionDraft draft) async {
    createCalls++;
    lastDraft = draft;
    if (failWrite) {
      throw const RepositoryException('Écriture Firestore refusée.');
    }
    _persistedMission = CoordinationNeed(
      id: 'coordinator-created',
      locationId: draft.location.id,
      place: draft.location.name,
      group: draft.location.group,
      date: '',
      time: '',
      startAt: draft.startAt,
      endAt: draft.endAt,
      requiredPhysiotherapists: draft.requiredPhysiotherapists,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: draft.requiredPodiatrists,
      registeredPodiatrists: 0,
      professionQuotas: draft.professionQuotas,
      equipment: draft.equipment,
      details: draft.details,
      createdBy: 'coordinator-publication',
    );
    // Simulates the authenticated write succeeding before the public mission
    // listener receives its next server snapshot.
    return 'coordinator-created';
  }
}
