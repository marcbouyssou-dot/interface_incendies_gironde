import 'package:flutter/widgets.dart';

import 'operational_map_feature.dart';
import 'operational_map_renderer.dart';

class OperationalMapSurfaceRequest {
  const OperationalMapSurfaceRequest({
    required this.features,
    required this.accessibilityFeatures,
    required this.mapKey,
    required this.onSelectionChanged,
    required this.onRendererChanged,
  });

  final List<OperationalMapFeature> features;
  final List<OperationalMapAccessibilityFeature> accessibilityFeatures;
  final Key mapKey;
  final OperationalMapSelectionChanged onSelectionChanged;
  final ValueChanged<OperationalMapRenderer?> onRendererChanged;
}

class OperationalMapAccessibilityFeature {
  const OperationalMapAccessibilityFeature({
    required this.id,
    required this.label,
    required this.selected,
    required this.visualDiameter,
    required this.missionCount,
    required this.onTap,
  });

  final String id;
  final String label;
  final bool selected;
  final double visualDiameter;
  final int missionCount;
  final VoidCallback onTap;
}

typedef OperationalMapSurfaceBuilder =
    Widget Function(BuildContext context, OperationalMapSurfaceRequest request);

abstract final class OperationalMapSurfaceRegistry {
  @visibleForTesting
  static OperationalMapSurfaceBuilder? debugBuilder;

  static bool get hasDebugBuilder => debugBuilder != null;

  static Widget build(
    BuildContext context,
    OperationalMapSurfaceRequest request, {
    required OperationalMapSurfaceBuilder productionBuilder,
  }) {
    return (debugBuilder ?? productionBuilder)(context, request);
  }
}
