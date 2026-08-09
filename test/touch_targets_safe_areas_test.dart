import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/create_need_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/mission_location_details.dart';
import 'package:interface_incendies_gironde/widgets/native_interactions.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';

void main() {
  testWidgets('compact V5 buttons keep a minimum 44 point hitbox', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: V5Button(
            key: const Key('compact-button'),
            compact: true,
            onPressed: () {},
            label: 'Action',
          ),
        ),
      ),
    );

    _expectAtLeast44(tester, find.byKey(const Key('compact-button')));
  });

  testWidgets(
    'professional filter controls and chips expose 44 point targets',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        FireCoordinationApp(
          repository: MockCoordinationRepository(responsibleAccess: null),
        ),
      );
      await tester.pumpAndSettle();

      final filters = find.byKey(const Key('professional-secondary-filters'));
      _expectAtLeast44(tester, filters);
      final details = find.ancestor(
        of: find.text('Voir les détails').first,
        matching: find.byType(TextButton),
      );
      _expectAtLeast44(tester, details);
      await tester.tap(filters);
      await tester.pumpAndSettle();

      final chipHitbox = find.ancestor(
        of: find.text('Prioritaires'),
        matching: find.byType(InkWell),
      );
      expect(chipHitbox, findsOneWidget);
      _expectAtLeast44(tester, chipHitbox);
      final visualChip = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text('Prioritaires'),
              matching: find.byType(Container),
            ),
          )
          .firstWhere((container) => container.constraints?.maxHeight == 32);
      expect(visualChip.constraints?.maxHeight, 32);
    },
  );

  testWidgets('role filter chips retain padded touch targets', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final center = places.firstWhere(
      (place) => place.isOperational && place.isEnabled,
    );
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(
          responsibleAccess: ResponsibleAccess(
            uid: 'chip-responsible',
            role: ResponsibleRole.siteManager,
            locationIds: {center.id},
            active: true,
          ),
          initialLocations: [center],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Besoins'));
    await tester.pumpAndSettle();
    _expectAtLeast44(
      tester,
      find.byKey(const Key('responsible-needs-filter-attention')),
    );

    await tester.pumpWidget(
      FireCoordinationApp(repository: MockCoordinationRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Territoire'));
    await tester.pumpAndSettle();
    _expectAtLeast44(
      tester,
      find.byKey(const Key('coordinator-territory-filter-all')),
    );
  });

  testWidgets('phone and directions actions expose 44 point targets', (
    tester,
  ) async {
    const location = ResponsePlace(
      id: 'touch-location',
      name: 'Centre test',
      type: ResponsePlaceType.otherPartnerSite,
      group: TerritorialGroup.partnerSites,
      activeNeeds: 0,
      address: '1 rue du Test, Bordeaux',
      contactPhone: '05 56 00 00 00',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MissionLocationDetails(location: location)),
      ),
    );

    _expectAtLeast44(tester, find.byKey(const Key('mission-location-phone')));
    _expectAtLeast44(
      tester,
      find.byKey(const Key('mission-location-directions')),
    );
  });

  testWidgets('responsible CreateNeed route respects safe areas and keyboard', (
    tester,
  ) async {
    final center = places.firstWhere(
      (place) => place.isOperational && place.isEnabled,
    );
    await _pumpCreateNeedRoute(
      tester,
      repository: MockCoordinationRepository(
        responsibleAccess: ResponsibleAccess(
          uid: 'touch-responsible',
          role: ResponsibleRole.siteManager,
          locationIds: {center.id},
          active: true,
        ),
        initialLocations: [center],
      ),
      opener: const Key('responsible-create-need'),
    );
  });

  testWidgets('coordinator CreateNeed route respects safe areas and keyboard', (
    tester,
  ) async {
    await _pumpCreateNeedRoute(
      tester,
      repository: MockCoordinationRepository(),
      opener: const Key('administration-create-need'),
    );
  });

  testWidgets('native sheets use SafeArea by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNativeBottomSheet<void>(
              context: context,
              builder: (_) =>
                  const SizedBox(key: Key('safe-native-sheet'), height: 240),
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.byKey(const Key('safe-native-sheet')),
        matching: find.byType(SafeArea),
      ),
      findsWidgets,
    );
  });
}

Future<void> _pumpCreateNeedRoute(
  WidgetTester tester, {
  required CoordinationRepository repository,
  required Key opener,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FireCoordinationApp(repository: repository));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(opener));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(opener));
  await tester.pumpAndSettle();

  final createNeed = find.byType(CreateNeedScreen);
  expect(createNeed, findsOneWidget);
  expect(
    find.ancestor(of: createNeed, matching: find.byType(SafeArea)),
    findsWidgets,
  );
  final routeScaffolds = tester.widgetList<Scaffold>(
    find.ancestor(of: createNeed, matching: find.byType(Scaffold)),
  );
  expect(
    routeScaffolds.any((scaffold) => scaffold.resizeToAvoidBottomInset == true),
    isTrue,
  );
  expect(
    tester.getTopLeft(find.byKey(const PageStorageKey('create'))).dy,
    greaterThanOrEqualTo(47),
  );
  _expectAtLeast44(tester, find.byKey(const Key('create-need-back')));

  tester.view.viewInsets = const FakeViewPadding(bottom: 300);
  addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void _expectAtLeast44(WidgetTester tester, Finder finder) {
  final size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(44));
  expect(size.height, greaterThanOrEqualTo(44));
}
