import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

void main() {
  testWidgets(
    'responsible publication is visible before the server stream catches up',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final center = places.firstWhere(
        (place) => place.isOperational && place.isEnabled,
      );
      final repository = _DelayedMissionRepository(
        center: center,
        access: ResponsibleAccess(
          uid: 'responsible-publication',
          role: ResponsibleRole.siteManager,
          locationIds: {center.id},
          active: true,
        ),
      );

      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('responsible-create-need')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mission-location')), findsNothing);
      expect(find.byKey(const Key('mission-location-locked')), findsNothing);
      expect(find.text('Lieu · ${center.name}'), findsOneWidget);

      await _chooseDate(tester);
      await _chooseTime(tester, const Key('mission-start-time'));
      await _chooseTime(tester, const Key('mission-end-time'));
      await tester.ensureVisible(find.byKey(const Key('physiotherapist-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('physiotherapist-add')));
      final publishButton = find.byKey(const Key('publish-mission'));
      await _scrollIntoView(tester, publishButton);
      await tester.tap(publishButton);
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(repository.lastDraft?.location.id, center.id);
      expect(find.text('Mission publiée'), findsOneWidget);

      await tester.tap(find.text('Voir la mission'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('responsible-open-need-responsible-created')),
        findsOneWidget,
      );

      await tester.tap(find.text('Besoins'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('responsible-need-responsible-created')),
        findsOneWidget,
      );
    },
  );
}

Future<void> _chooseDate(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('mission-date')));
  await tester.pumpAndSettle();
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  await tester.tap(find.text('${tomorrow.day}').last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
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

class _DelayedMissionRepository extends MockCoordinationRepository {
  _DelayedMissionRepository({
    required ResponsePlace center,
    required ResponsibleAccess access,
  }) : super(
         initialMissions: const [],
         initialLocations: [center],
         initialEngagements: const [],
         responsibleAccess: access,
       );

  int createCalls = 0;
  MissionDraft? lastDraft;

  @override
  Future<String> createMission(MissionDraft draft) async {
    createCalls++;
    lastDraft = draft;
    return 'responsible-created';
  }
}
