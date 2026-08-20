import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/operational_map/operational_map_gesture_boundary.dart';

void main() {
  testWidgets('touch gestures on the map do not scroll its parent', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 500,
          child: ListView(
            controller: scrollController,
            children: [
              Container(
                key: const Key('outside-map'),
                height: 160,
                color: Colors.transparent,
              ),
              OperationalMapGestureBoundary(
                child: Container(
                  key: const Key('gesture-map'),
                  height: 240,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 900),
            ],
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const Key('gesture-map')),
      const Offset(0, -100),
      kind: PointerDeviceKind.touch,
    );
    await tester.pumpAndSettle();

    expect(scrollController.offset, 0);
  });

  testWidgets('touch gestures outside the map keep scrolling normally', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 500,
          child: ListView(
            controller: scrollController,
            children: [
              Container(
                key: const Key('outside-map'),
                height: 160,
                color: Colors.transparent,
              ),
              OperationalMapGestureBoundary(
                child: Container(
                  key: const Key('gesture-map'),
                  height: 240,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 900),
            ],
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const Key('outside-map')),
      const Offset(0, -100),
      kind: PointerDeviceKind.touch,
    );
    await tester.pumpAndSettle();

    expect(scrollController.offset, greaterThan(0));
  });

  testWidgets('a two-finger map gesture does not move the page', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 500,
          child: ListView(
            controller: scrollController,
            children: [
              const SizedBox(height: 100),
              OperationalMapGestureBoundary(
                child: Container(
                  key: const Key('gesture-map'),
                  height: 260,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 900),
            ],
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byKey(const Key('gesture-map')));
    final first = await tester.startGesture(
      center + const Offset(-24, 0),
      pointer: 1,
      kind: PointerDeviceKind.touch,
    );
    final second = await tester.startGesture(
      center + const Offset(24, 0),
      pointer: 2,
      kind: PointerDeviceKind.touch,
    );
    await first.moveTo(center + const Offset(-70, -40));
    await second.moveTo(center + const Offset(70, -40));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    expect(scrollController.offset, 0);
  });
}
