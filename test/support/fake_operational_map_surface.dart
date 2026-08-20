import 'package:flutter/material.dart';
import 'package:interface_incendies_gironde/operational_map/operational_map_feature.dart';
import 'package:interface_incendies_gironde/operational_map/operational_map_renderer.dart';
import 'package:interface_incendies_gironde/operational_map/operational_map_surface.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';

Widget buildFakeOperationalMapSurface(
  BuildContext context,
  OperationalMapSurfaceRequest request,
) {
  return _FakeOperationalMapSurface(request: request);
}

class _FakeOperationalMapSurface extends StatefulWidget {
  const _FakeOperationalMapSurface({required this.request});

  final OperationalMapSurfaceRequest request;

  @override
  State<_FakeOperationalMapSurface> createState() =>
      _FakeOperationalMapSurfaceState();
}

class _FakeOperationalMapSurfaceState
    extends State<_FakeOperationalMapSurface> {
  final TransformationController _transformationController =
      TransformationController();
  late final _FakeOperationalMapRenderer _renderer;

  @override
  void initState() {
    super.initState();
    _renderer = _FakeOperationalMapRenderer(
      transformationController: _transformationController,
      onSelectionChanged: widget.request.onSelectionChanged,
    )..setFeatures(widget.request.features);
    widget.request.onRendererChanged(_renderer);
  }

  @override
  void didUpdateWidget(covariant _FakeOperationalMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _renderer.onSelectionChanged = widget.request.onSelectionChanged;
    _renderer.setFeatures(widget.request.features);
  }

  @override
  void dispose() {
    widget.request.onRendererChanged(null);
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      key: widget.request.mapKey,
      transformationController: _transformationController,
      minScale: 1,
      maxScale: 3,
      boundaryMargin: EdgeInsets.zero,
      constrained: true,
      panEnabled: true,
      scaleEnabled: true,
      trackpadScrollCausesScale: true,
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final accessibilityById =
                <String, OperationalMapAccessibilityFeature>{
                  for (final feature in widget.request.accessibilityFeatures)
                    feature.id: feature,
                };
            final features = [...widget.request.features]
              ..sort(
                (left, right) => left.operationalStatus.severityRank.compareTo(
                  right.operationalStatus.severityRank,
                ),
              );
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FakeTerritoryMapPainter(
                        colors: context.v5Colors,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _transformationController,
                      builder: (context, _) {
                        final mapScale = _transformationController.value
                            .getMaxScaleOnAxis()
                            .clamp(1.0, 3.0);
                        return Stack(
                          children: [
                            for (final feature in features)
                              if (accessibilityById[feature.id]
                                  case final accessibility?)
                                _FakeOperationalMarker(
                                  accessibility: accessibility,
                                  feature: feature,
                                  mapSize: constraints.biggest,
                                  mapScale: mapScale,
                                ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FakeOperationalMarker extends StatelessWidget {
  const _FakeOperationalMarker({
    required this.accessibility,
    required this.feature,
    required this.mapSize,
    required this.mapScale,
  });

  static const _minimumLongitude = -1.35;
  static const _maximumLongitude = 0.15;
  static const _minimumLatitude = 44.2;
  static const _maximumLatitude = 45.65;

  final OperationalMapAccessibilityFeature accessibility;
  final OperationalMapFeature feature;
  final Size mapSize;
  final double mapScale;

  @override
  Widget build(BuildContext context) {
    final markerSize = 44 / mapScale;
    final horizontal =
        ((feature.longitude - _minimumLongitude) /
                (_maximumLongitude - _minimumLongitude))
            .clamp(0.0, 1.0)
            .toDouble();
    final vertical =
        (1 -
                (feature.latitude - _minimumLatitude) /
                    (_maximumLatitude - _minimumLatitude))
            .clamp(0.0, 1.0)
            .toDouble();
    final availableWidth = (mapSize.width - 20)
        .clamp(0.0, double.infinity)
        .toDouble();
    final legendReserve = MediaQuery.textScalerOf(context).scale(1) >= 1.6
        ? 120.0
        : 72.0;
    const controlReserve = 58.0;
    final availableHeight = (mapSize.height - legendReserve - controlReserve)
        .clamp(0.0, double.infinity)
        .toDouble();
    final centerX = 10 + availableWidth * horizontal;
    final centerY = controlReserve + availableHeight * vertical;
    return Positioned(
      left: (centerX - markerSize / 2).clamp(0, mapSize.width - markerSize),
      top: (centerY - markerSize / 2).clamp(0, mapSize.height - markerSize),
      width: markerSize,
      height: markerSize,
      child: Semantics(
        key: Key('cockpit-map-location-${accessibility.id}'),
        button: true,
        selected: accessibility.selected,
        label: accessibility.label,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: accessibility.onTap,
            child: _FakeOperationalMarkerBody(
              accessibility: accessibility,
              feature: feature,
              mapScale: mapScale,
            ),
          ),
        ),
      ),
    );
  }
}

class _FakeOperationalMarkerBody extends StatelessWidget {
  const _FakeOperationalMarkerBody({
    required this.accessibility,
    required this.feature,
    required this.mapScale,
  });

  final OperationalMapAccessibilityFeature accessibility;
  final OperationalMapFeature feature;
  final double mapScale;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final markerColor = switch (feature.operationalStatus) {
      OperationalMapStatus.critical => colors.danger,
      OperationalMapStatus.watch => colors.warning,
      OperationalMapStatus.covered => colors.success,
      OperationalMapStatus.noMission => colors.textSecondary.withValues(
        alpha: 0.62,
      ),
    };
    final visualSize = accessibility.visualDiameter / mapScale;
    final selectedSize =
        (accessibility.visualDiameter + 8).clamp(40, 44) / mapScale;
    final badgeOffset =
        ((44 - accessibility.visualDiameter) / 2 - 5).clamp(0, 44) / mapScale;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 140);
    return SizedBox.square(
      dimension: 44 / mapScale,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: duration,
            width: accessibility.selected ? selectedSize : visualSize,
            height: accessibility.selected ? selectedSize : visualSize,
            decoration: BoxDecoration(
              color: accessibility.selected
                  ? markerColor.withValues(alpha: 0.18)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: accessibility.selected
                  ? Border.all(color: markerColor, width: 2 / mapScale)
                  : null,
            ),
            child: Center(
              child: AnimatedContainer(
                key: Key('cockpit-map-point-${accessibility.id}'),
                duration: duration,
                width: visualSize,
                height: visualSize,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.surfaceElevated,
                    width: 2 / mapScale,
                  ),
                  boxShadow: accessibility.missionCount > 0
                      ? V5Elevation.level1(colors)
                      : null,
                ),
                child: accessibility.missionCount > 0
                    ? Icon(
                        Icons.local_hospital_rounded,
                        color: Colors.white,
                        size: 14 / mapScale,
                      )
                    : null,
              ),
            ),
          ),
          if (accessibility.missionCount > 1)
            Positioned(
              top: badgeOffset,
              right: badgeOffset,
              child: Container(
                key: Key('cockpit-map-badge-${accessibility.id}'),
                width: 17 / mapScale,
                height: 17 / mapScale,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: markerColor, width: 1.5 / mapScale),
                ),
                child: Text(
                  '${accessibility.missionCount}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9 / mapScale,
                    height: 1,
                    color: markerColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FakeTerritoryMapPainter extends CustomPainter {
  const _FakeTerritoryMapPainter({required this.colors});

  final V5Colors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final territory = Path()
      ..moveTo(size.width * 0.28, size.height * 0.05)
      ..lineTo(size.width * 0.55, size.height * 0.08)
      ..lineTo(size.width * 0.76, size.height * 0.21)
      ..lineTo(size.width * 0.84, size.height * 0.43)
      ..lineTo(size.width * 0.72, size.height * 0.68)
      ..lineTo(size.width * 0.52, size.height * 0.83)
      ..lineTo(size.width * 0.30, size.height * 0.76)
      ..lineTo(size.width * 0.17, size.height * 0.55)
      ..lineTo(size.width * 0.20, size.height * 0.27)
      ..close();
    canvas.drawPath(
      territory,
      Paint()
        ..color = colors.surfaceElevated.withValues(alpha: 0.72)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      territory,
      Paint()
        ..color = colors.outline
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    final guide = Paint()
      ..color = colors.outline.withValues(alpha: 0.48)
      ..strokeWidth = 0.8;
    for (final fraction in const [0.33, 0.66]) {
      canvas.drawLine(
        Offset(size.width * fraction, size.height * 0.12),
        Offset(size.width * fraction, size.height * 0.78),
        guide,
      );
    }
    canvas.drawLine(
      Offset(size.width * 0.16, size.height * 0.42),
      Offset(size.width * 0.84, size.height * 0.42),
      guide,
    );
  }

  @override
  bool shouldRepaint(covariant _FakeTerritoryMapPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

class _FakeOperationalMapRenderer implements OperationalMapRenderer {
  _FakeOperationalMapRenderer({
    required this.transformationController,
    required this.onSelectionChanged,
  });

  final TransformationController transformationController;
  OperationalMapSelectionChanged onSelectionChanged;

  List<OperationalMapFeature> _features = const [];
  OperationalMapFilter _filter = OperationalMapFilter.all;
  String? _selectedFeatureId;

  @override
  List<OperationalMapFeature> get features => _features;

  @override
  OperationalMapFilter get filter => _filter;

  @override
  String? get selectedFeatureId => _selectedFeatureId;

  @override
  Future<void> setFeatures(List<OperationalMapFeature> features) async {
    _features = List.unmodifiable(features);
  }

  @override
  Future<void> applyFilter(OperationalMapFilter filter) async {
    _filter = filter;
  }

  @override
  Future<void> selectCenter(String featureId) async {
    _selectedFeatureId = featureId;
  }

  @override
  Future<void> deselectCenter() async {
    _selectedFeatureId = null;
  }

  @override
  Future<void> focusCenter(String featureId) => selectCenter(featureId);

  @override
  Future<void> recenterCamera() async {
    transformationController.value = Matrix4.identity();
  }
}
