import 'operational_map_feature.dart';

typedef OperationalMapSelectionChanged =
    void Function(OperationalMapFeature? feature);

abstract interface class OperationalMapRenderer {
  List<OperationalMapFeature> get features;
  OperationalMapFilter get filter;
  String? get selectedFeatureId;

  Future<void> setFeatures(List<OperationalMapFeature> features);
  Future<void> applyFilter(OperationalMapFilter filter);
  Future<void> selectCenter(String featureId);
  Future<void> deselectCenter();
  Future<void> focusCenter(String featureId);
  Future<void> recenterCamera();
}
