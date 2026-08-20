import 'dart:async';

import 'package:interface_incendies_gironde/operational_map/operational_map_surface.dart';

import 'support/fake_operational_map_surface.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  OperationalMapSurfaceRegistry.debugBuilder = buildFakeOperationalMapSurface;
  await testMain();
}
