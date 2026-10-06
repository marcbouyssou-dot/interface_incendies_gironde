import 'package:flutter/cupertino.dart';
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
      await tester.tap(find.text('Accueil').last);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const PageStorageKey('responsible-home-scroll')),
        const Offset(0, -360),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('responsible-create-need')),
      );
      await tester.tap(find.byKey(const Key('responsible-create-need')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mission-location')), findsNothing);
      expect(find.byKey(const Key('mission-location-locked')), findsOneWidget);
      expect(find.text(center.name), findsNWidgets(2));

      await _chooseDate(tester);
      await _chooseTime(tester, const Key('mission-start-time'));
      await _chooseTime(tester, const Key('mission-end-time'));
      await tester.ensureVisible(find.byKey(const Key('physiotherapist-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('physiotherapist-add')));
      await tester.drag(
        find.byKey(const PageStorageKey('create')),
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const PageStorageKey('create')),
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review-mission')));
      await tester.pumpAndSettle();
      final publishButton = find.byKey(const Key('publish-mission'));
      await tester.scrollUntilVisible(
        publishButton,
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('need-review')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(publishButton);
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(repository.lastDraft?.location.id, center.id);
      expect(find.text('Votre besoin est publié.'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Voir le besoin'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voir le besoin'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('responsible-open-need-responsible-created')),
      );
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
  final field = find.byKey(const Key('mission-date'));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  tester
      .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
      .onDateTimeChanged(DateTime.now().add(const Duration(days: 1)));
  await tester.tap(find.text('Valider'));
  await tester.pumpAndSettle();
}

Future<void> _chooseTime(WidgetTester tester, Key fieldKey) async {
  final field = find.byKey(fieldKey);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Valider'));
  await tester.pumpAndSettle();
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
