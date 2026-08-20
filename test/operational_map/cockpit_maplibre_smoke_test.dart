import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/operational_map/maplibre_operational_map.dart';
import 'package:interface_incendies_gironde/operational_map/operational_map_surface.dart';

void main() {
  testWidgets('Cockpit sends its points through the operational map surface', (
    tester,
  ) async {
    OperationalMapSurfaceRequest? capturedRequest;
    final previousBuilder = OperationalMapSurfaceRegistry.debugBuilder;
    OperationalMapSurfaceRegistry.debugBuilder = (context, request) {
      capturedRequest = request;
      return ColoredBox(key: request.mapKey, color: Colors.transparent);
    };
    addTearDown(() {
      OperationalMapSurfaceRegistry.debugBuilder = previousBuilder;
    });

    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();

    expect(capturedRequest, isNotNull);
    expect(capturedRequest!.features, isNotEmpty);
    expect(
      capturedRequest!.features.map((feature) => feature.id).toSet(),
      hasLength(capturedRequest!.features.length),
    );
    expect(
      find.byKey(const Key('cockpit-map-interactive-viewer')),
      findsOneWidget,
    );
  });

  testWidgets('the production operational surface is MapLibre', (tester) async {
    late Widget productionSurface;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            productionSurface = buildMapLibreOperationalMapSurface(
              context,
              OperationalMapSurfaceRequest(
                features: const [],
                accessibilityFeatures: const [],
                mapKey: const Key('maplibre-smoke-surface'),
                onSelectionChanged: (_) {},
                onRendererChanged: (_) {},
              ),
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(productionSurface, isA<MapLibreOperationalMapSurface>());
  });
}
