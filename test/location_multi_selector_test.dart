import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/location_multi_selector.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';

void main() {
  Future<Set<String> Function()> pumpSelector(
    WidgetTester tester, {
    List<ResponsePlace>? locations,
    Set<String> initialSelection = const {},
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var selected = Set<String>.of(initialSelection);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (context, setState) => LocationMultiSelector(
                  locations: locations ?? places,
                  selectedIds: selected,
                  onChanged: (value) =>
                      setState(() => selected = Set.of(value)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return () => selected;
  }

  Future<void> search(WidgetTester tester, String value) async {
    await tester.enterText(find.byKey(const Key('location-search')), value);
    await tester.pumpAndSettle();
  }

  testWidgets('empty search exposes the complete operational catalogue', (
    tester,
  ) async {
    await pumpSelector(tester);
    final operationalCount = places
        .where((place) => place.isOperational)
        .length;

    expect(places, hasLength(65));
    expect(
      find.text(
        '$operationalCount centre${operationalCount > 1 ? 's' : ''} '
        'disponible${operationalCount > 1 ? 's' : ''}',
      ),
      findsOneWidget,
    );
    expect(find.text('0 centre sélectionné'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search filters by name, territory, city and address', (
    tester,
  ) async {
    await pumpSelector(tester);
    final bazas = places.singleWhere((place) => place.name == 'Bazas');

    await search(tester, 'Bazas');
    expect(
      find.descendant(
        of: find.byKey(Key('invitation-location-${bazas.id}')),
        matching: find.text('Bazas'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 centre disponible'), findsOneWidget);

    await search(tester, 'medoc');
    expect(find.byKey(const Key('location-group-medoc')), findsOneWidget);

    final city = bazas.structuredAddress?.city;
    if (city != null && city.trim().isNotEmpty) {
      await search(tester, city);
      expect(find.text('Bazas'), findsWidgets);
    }
    final addressToken = bazas.structuredAddress?.addressLine1;
    if (addressToken != null && addressToken.trim().isNotEmpty) {
      await search(tester, addressToken);
      expect(find.text('Bazas'), findsWidgets);
    }
  });

  testWidgets('search without a result is explicit', (tester) async {
    await pumpSelector(tester);
    await search(tester, 'centre totalement inexistant');

    expect(find.byKey(const Key('location-search-empty')), findsOneWidget);
    expect(
      find.text('Aucun centre ne correspond à votre recherche.'),
      findsOneWidget,
    );
  });

  testWidgets('single and multiple selections update French counters', (
    tester,
  ) async {
    final selected = await pumpSelector(tester);
    final first = places.where((place) => place.isOperational).take(2).toList();

    await tester.tap(find.byKey(Key('invitation-location-${first[0].id}')));
    await tester.pump();
    expect(selected(), {first[0].id});
    expect(find.text('1 centre sélectionné'), findsOneWidget);

    await tester.tap(find.byKey(Key('invitation-location-${first[1].id}')));
    await tester.pump();
    expect(selected(), {first[0].id, first[1].id});
    expect(find.text('2 centres sélectionnés'), findsOneWidget);
  });

  testWidgets('selection survives filtering and can be removed from its chip', (
    tester,
  ) async {
    final selected = await pumpSelector(tester);
    final location = places.where((place) => place.isOperational).first;
    await tester.tap(find.byKey(Key('invitation-location-${location.id}')));
    await tester.pump();

    await search(tester, 'aucun résultat pour la sélection');
    expect(find.byKey(Key('selected-location-${location.id}')), findsOneWidget);
    expect(selected(), contains(location.id));

    await tester.tap(
      find.byTooltip('Retirer ${location.name} de la sélection'),
    );
    await tester.pump();
    expect(selected(), isEmpty);
    expect(find.text('0 centre sélectionné'), findsOneWidget);
  });

  testWidgets('territorial groups collapse without losing selection', (
    tester,
  ) async {
    final selected = await pumpSelector(tester);
    final location = places.where((place) => place.isOperational).first;
    final groupKey = Key('location-group-${location.group.name}');
    final locationKey = Key('invitation-location-${location.id}');

    expect(find.byKey(groupKey), findsOneWidget);
    await tester.tap(find.byKey(locationKey));
    await tester.pump();
    await tester.tap(find.byKey(groupKey));
    await tester.pumpAndSettle();
    expect(find.byKey(locationKey), findsNothing);
    expect(selected(), contains(location.id));
    expect(find.byKey(Key('selected-location-${location.id}')), findsOneWidget);

    await tester.tap(find.byKey(groupKey));
    await tester.pumpAndSettle();
    expect(find.byKey(locationKey), findsOneWidget);
    final tile = tester.widget<V5CheckboxTile>(find.byKey(locationKey));
    expect(tile.value, isTrue);
  });

  testWidgets('groups follow the existing territorial order', (tester) async {
    await pumpSelector(tester);
    final expected = TerritorialGroup.values
        .where(
          (group) => places.any(
            (place) => place.isOperational && place.group == group,
          ),
        )
        .toList();
    final innerList = find.byKey(const Key('location-selector-list'));

    for (final group in expected) {
      final key = find.byKey(Key('location-group-${group.name}'));
      await tester.scrollUntilVisible(
        key,
        180,
        scrollable: find.descendant(
          of: innerList,
          matching: find.byType(Scrollable),
        ),
      );
      expect(key, findsOneWidget);
    }
  });

  testWidgets('group and checkbox semantics expose state and labels', (
    tester,
  ) async {
    await pumpSelector(tester);
    final location = places.where((place) => place.isOperational).first;
    final groupNode = tester.getSemantics(
      find.byKey(Key('location-group-${location.group.name}')),
    );
    final checkboxNode = tester.getSemantics(
      find.byKey(Key('invitation-location-${location.id}')),
    );

    expect(groupNode.flagsCollection.isButton, isTrue);
    expect(groupNode.flagsCollection.isExpanded, ui.Tristate.isTrue);
    expect(groupNode.label, contains(location.group.label));
    expect(checkboxNode.label, contains(location.name));
    expect(checkboxNode.flagsCollection.isChecked, isNot(ui.Tristate.none));
    expect(
      tester
          .getSize(find.byKey(Key('invitation-location-${location.id}')))
          .height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('keyboard toggles groups and locations with Enter and Space', (
    tester,
  ) async {
    final selected = await pumpSelector(tester);
    final first = places.where((place) => place.isOperational).first;
    final firstLocation = find.byKey(Key('invitation-location-${first.id}'));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(firstLocation, findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(firstLocation, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(selected(), contains(first.id));
  });

  testWidgets('long labels, many selections and 65 locations never overflow', (
    tester,
  ) async {
    final longLocation = ResponsePlace(
      id: 'very-long-location',
      name:
          'Centre d’intervention sanitaire départemental au nom particulièrement long',
      type: ResponsePlaceType.otherPartnerSite,
      group: TerritorialGroup.partnerSites,
      activeNeeds: 0,
    );
    final operational = places.where((place) => place.isOperational).toList();
    await pumpSelector(
      tester,
      locations: [...operational, longLocation],
      initialSelection: operational.take(12).map((place) => place.id).toSet(),
    );

    await search(tester, 'particulièrement long');
    expect(
      find.textContaining('Centre d’intervention sanitaire'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
