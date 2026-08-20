import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'operational_map_config.dart';
import 'operational_map_feature.dart';
import 'operational_map_geojson.dart';
import 'operational_map_renderer.dart';
import 'operational_map_state.dart';
import 'operational_map_surface.dart';
import 'operational_map_visual_style.dart';

const _centersSourceId = 'mobsante-operational-centers';
const _selectionSourceId = 'mobsante-operational-selection';
const _centersLayerId = 'mobsante-operational-centers-layer';
const _criticalHaloLayerId = 'mobsante-operational-critical-halo-layer';
const _watchHaloLayerId = 'mobsante-operational-watch-halo-layer';
const _clustersLayerId = 'mobsante-operational-clusters-layer';
const _clusterHaloLayerId = 'mobsante-operational-cluster-halo-layer';
const _clusterLabelsLayerId = 'mobsante-operational-cluster-labels-layer';
const _selectionLayerId = 'mobsante-operational-selection-layer';

const _initialCamera = CameraPosition(
  target: LatLng(44.78, -0.58),
  zoom: 7.1,
  tilt: 0,
  bearing: 0,
);

class MapLibreOperationalMapRenderer implements OperationalMapRenderer {
  MapLibreOperationalMapRenderer({required this.onSelectionChanged});

  OperationalMapSelectionChanged onSelectionChanged;

  MapLibreMapController? _controller;
  final OperationalMapState _state = OperationalMapState();
  bool _styleReady = false;
  Map<String, Object>? _pendingGeoJson;

  @override
  List<OperationalMapFeature> get features => _state.features;

  List<OperationalMapFeature> get visibleFeatures => _state.visibleFeatures;

  @override
  OperationalMapFilter get filter => _state.filter;

  @override
  String? get selectedFeatureId => _state.selectedFeatureId;

  void attach(MapLibreMapController controller) {
    detach();
    _controller = controller;
    _styleReady = false;
    controller.onFeatureTapped.add(_handleFeatureTap);
  }

  void detach() {
    final controller = _controller;
    if (controller != null && !controller.isDisposed) {
      controller.onFeatureTapped.remove(_handleFeatureTap);
    }
    _controller = null;
    _styleReady = false;
  }

  Future<void> onStyleLoaded() async {
    final controller = _controller;
    if (controller == null || controller.isDisposed) return;
    try {
      final geoJson = _pendingGeoJson ?? _encodeVisibleFeatures();
      await controller.addSource(
        _centersSourceId,
        GeojsonSourceProperties(
          data: geoJson,
          cluster: true,
          clusterRadius: 52,
          clusterMaxZoom: 12,
          promoteId: 'id',
          clusterProperties: const <String, Object>{
            'maxSeverity': <Object>[
              'max',
              <Object>['get', 'severityRank'],
            ],
          },
        ),
      );
      await controller.addSource(
        _selectionSourceId,
        GeojsonSourceProperties(
          data: OperationalMapGeoJson.emptyFeatureCollection(),
          promoteId: 'id',
        ),
      );
      await _addLayers(controller);
      if (!identical(controller, _controller) || controller.isDisposed) return;
      _styleReady = true;
      _pendingGeoJson = null;
      await _updateSelectionSource();
    } catch (error, stackTrace) {
      debugPrint('MapLibre initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _addLayers(MapLibreMapController controller) async {
    final criticalStyle = OperationalMapVisualStyle.forStatus(
      OperationalMapStatus.critical,
    );
    final watchStyle = OperationalMapVisualStyle.forStatus(
      OperationalMapStatus.watch,
    );
    await controller.addCircleLayer(
      _centersSourceId,
      _criticalHaloLayerId,
      CircleLayerProperties(
        circleRadius: criticalStyle.haloRadius,
        circleColor: criticalStyle.color,
        circleOpacity: criticalStyle.haloOpacity,
        circleBlur: 0.3,
      ),
      filter: const <Object>[
        'all',
        <Object>[
          '!',
          <Object>['has', 'point_count'],
        ],
        <Object>[
          '==',
          <Object>['get', 'status'],
          'critical',
        ],
      ],
      enableInteraction: false,
    );
    await controller.addCircleLayer(
      _centersSourceId,
      _watchHaloLayerId,
      CircleLayerProperties(
        circleRadius: watchStyle.haloRadius,
        circleColor: watchStyle.color,
        circleOpacity: watchStyle.haloOpacity,
        circleBlur: 0.22,
      ),
      filter: const <Object>[
        'all',
        <Object>[
          '!',
          <Object>['has', 'point_count'],
        ],
        <Object>[
          '==',
          <Object>['get', 'status'],
          'watch',
        ],
      ],
      enableInteraction: false,
    );
    await controller.addCircleLayer(
      _centersSourceId,
      _centersLayerId,
      CircleLayerProperties(
        circleRadius: OperationalMapVisualStyle.centerRadiusExpression,
        circleColor: OperationalMapVisualStyle.centerColorExpression,
        circleOpacity: OperationalMapVisualStyle.centerOpacityExpression,
        circleStrokeColor:
            OperationalMapVisualStyle.centerStrokeColorExpression,
        circleStrokeWidth:
            OperationalMapVisualStyle.centerStrokeWidthExpression,
        circleSortKey: const <Object>['get', 'severityRank'],
      ),
      filter: const <Object>[
        '!',
        <Object>['has', 'point_count'],
      ],
    );
    await controller.addCircleLayer(
      _centersSourceId,
      _clusterHaloLayerId,
      CircleLayerProperties(
        circleRadius: const <Object>[
          'interpolate',
          <Object>['linear'],
          <Object>['get', 'point_count'],
          2,
          24,
          50,
          31,
          1000,
          39,
        ],
        circleColor: OperationalMapVisualStyle.clusterColorExpression,
        circleOpacity: const <Object>[
          'step',
          <Object>['get', 'maxSeverity'],
          0.0,
          2,
          0.12,
          3,
          0.22,
        ],
        circleBlur: 0.28,
      ),
      filter: const <Object>['has', 'point_count'],
      enableInteraction: false,
    );
    await controller.addCircleLayer(
      _centersSourceId,
      _clustersLayerId,
      CircleLayerProperties(
        circleRadius: const <Object>[
          'interpolate',
          <Object>['linear'],
          <Object>['get', 'point_count'],
          2,
          18,
          50,
          24,
          1000,
          32,
        ],
        circleColor: OperationalMapVisualStyle.clusterColorExpression,
        circleOpacity: OperationalMapVisualStyle.clusterOpacityExpression,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth:
            OperationalMapVisualStyle.clusterStrokeWidthExpression,
      ),
      filter: const <Object>['has', 'point_count'],
    );
    await controller.addSymbolLayer(
      _centersSourceId,
      _clusterLabelsLayerId,
      const SymbolLayerProperties(
        textField: <Object>['get', 'point_count_abbreviated'],
        textSize: 12,
        textColor: '#FFFFFF',
        textHaloColor: '#10233E',
        textHaloWidth: 0.8,
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
      filter: const <Object>['has', 'point_count'],
      enableInteraction: false,
    );
    await controller.addCircleLayer(
      _selectionSourceId,
      _selectionLayerId,
      const CircleLayerProperties(
        circleRadius: 16,
        circleColor: 'rgba(255,255,255,0.08)',
        circleStrokeColor: '#58A5FF',
        circleStrokeWidth: 4,
      ),
      enableInteraction: false,
    );
  }

  @override
  Future<void> setFeatures(List<OperationalMapFeature> features) async {
    final previousSelection = _state.selectedFeatureId;
    _state.replaceFeatures(features);
    if (previousSelection != null && _state.selectedFeatureId == null) {
      onSelectionChanged(null);
    }
    await _pushVisibleFeatures();
  }

  @override
  Future<void> applyFilter(OperationalMapFilter filter) async {
    final previousSelection = _state.selectedFeatureId;
    _state.applyFilter(filter);
    if (previousSelection != null && _state.selectedFeatureId == null) {
      await _updateSelectionSource();
      onSelectionChanged(null);
    }
    await _pushVisibleFeatures();
  }

  Map<String, Object> _encodeVisibleFeatures() {
    return OperationalMapGeoJson.featureCollection(
      visibleFeatures.map(
        (feature) =>
            feature.copyWith(selected: feature.id == _state.selectedFeatureId),
      ),
    );
  }

  Future<void> _pushVisibleFeatures() async {
    final geoJson = _encodeVisibleFeatures();
    final controller = _controller;
    if (!_styleReady || controller == null || controller.isDisposed) {
      _pendingGeoJson = geoJson;
      return;
    }
    try {
      await controller.setGeoJsonSource(_centersSourceId, geoJson);
    } catch (error, stackTrace) {
      debugPrint('MapLibre GeoJSON update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _handleFeatureTap(
    math.Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) async {
    if (layerId == _clustersLayerId) {
      final controller = _controller;
      if (controller == null || controller.isDisposed) return;
      final currentZoom =
          controller.cameraPosition?.zoom ?? _initialCamera.zoom;
      await _moveCamera(
        controller,
        CameraUpdate.newLatLngZoom(
          coordinates,
          math.min(currentZoom + 2, 13.0),
        ),
      );
      return;
    }
    if (layerId != _centersLayerId) return;
    final feature = _state.select(id);
    if (feature == null) return;
    await _updateSelectionSource();
    onSelectionChanged(feature);
  }

  @override
  Future<void> selectCenter(String featureId) async {
    final feature = _state.select(featureId);
    if (feature == null) return;
    await _updateSelectionSource();
  }

  @override
  Future<void> deselectCenter() async {
    _state.clearSelection();
    await _updateSelectionSource();
    onSelectionChanged(null);
  }

  Future<void> _updateSelectionSource() async {
    final controller = _controller;
    if (!_styleReady || controller == null || controller.isDisposed) return;
    final selected = _state.selectedFeature;
    await controller.setGeoJsonSource(
      _selectionSourceId,
      selected == null
          ? OperationalMapGeoJson.emptyFeatureCollection()
          : OperationalMapGeoJson.featureCollection(<OperationalMapFeature>[
              selected.copyWith(selected: true),
            ]),
    );
  }

  @override
  Future<void> focusCenter(String featureId) async {
    final feature = _state.select(featureId);
    final controller = _controller;
    if (feature == null || controller == null || controller.isDisposed) return;
    await _updateSelectionSource();
    await _moveCamera(
      controller,
      CameraUpdate.newLatLngZoom(
        LatLng(feature.latitude, feature.longitude),
        12.5,
      ),
    );
  }

  @override
  Future<void> recenterCamera() async {
    final controller = _controller;
    if (controller == null || controller.isDisposed) return;
    await _moveCamera(
      controller,
      CameraUpdate.newCameraPosition(_initialCamera),
    );
  }

  Future<void> _moveCamera(
    MapLibreMapController controller,
    CameraUpdate update,
  ) async {
    final reducedMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (reducedMotion) {
      await controller.moveCamera(update);
    } else {
      await controller.animateCamera(
        update,
        duration: const Duration(milliseconds: 180),
      );
    }
  }
}

class MapLibreOperationalMap extends StatefulWidget {
  const MapLibreOperationalMap({
    super.key,
    required this.renderer,
    required this.style,
  });

  final MapLibreOperationalMapRenderer renderer;
  final String style;

  @override
  State<MapLibreOperationalMap> createState() => _MapLibreOperationalMapState();
}

class _MapLibreOperationalMapState extends State<MapLibreOperationalMap> {
  @override
  void didUpdateWidget(covariant MapLibreOperationalMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.renderer, widget.renderer)) {
      oldWidget.renderer.detach();
    }
  }

  @override
  void dispose() {
    widget.renderer.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      key: ValueKey((widget.style, widget.renderer)),
      initialCameraPosition: _initialCamera,
      styleString: widget.style,
      onMapCreated: widget.renderer.attach,
      onStyleLoadedCallback: widget.renderer.onStyleLoaded,
      trackCameraPosition: true,
      compassEnabled: false,
      scaleControlEnabled: true,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      doubleClickZoomEnabled: true,
      dragEnabled: true,
      annotationOrder: const <AnnotationType>[],
      cameraTargetBounds: CameraTargetBounds(
        LatLngBounds(
          southwest: const LatLng(42.9, -2.2),
          northeast: const LatLng(46.5, 1.7),
        ),
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(5, 15),
    );
  }
}

Widget buildMapLibreOperationalMapSurface(
  BuildContext context,
  OperationalMapSurfaceRequest request,
) {
  return MapLibreOperationalMapSurface(request: request);
}

class MapLibreOperationalMapSurface extends StatefulWidget {
  const MapLibreOperationalMapSurface({super.key, required this.request});

  final OperationalMapSurfaceRequest request;

  @override
  State<MapLibreOperationalMapSurface> createState() =>
      _MapLibreOperationalMapSurfaceState();
}

class _MapLibreOperationalMapSurfaceState
    extends State<MapLibreOperationalMapSurface> {
  late final MapLibreOperationalMapRenderer _renderer;

  @override
  void initState() {
    super.initState();
    _renderer = MapLibreOperationalMapRenderer(
      onSelectionChanged: widget.request.onSelectionChanged,
    );
    widget.request.onRendererChanged(_renderer);
    _scheduleFeatureSync();
  }

  @override
  void didUpdateWidget(covariant MapLibreOperationalMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _renderer.onSelectionChanged = widget.request.onSelectionChanged;
    _scheduleFeatureSync();
  }

  void _scheduleFeatureSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_renderer.setFeatures(widget.request.features));
    });
  }

  @override
  void dispose() {
    widget.request.onRendererChanged(null);
    _renderer.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapLibreOperationalMap(
      key: widget.request.mapKey,
      renderer: _renderer,
      style: OperationalMapConfig.styleFor(Theme.of(context).brightness),
    );
  }
}
