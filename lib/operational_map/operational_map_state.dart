import 'operational_map_feature.dart';

class OperationalMapState {
  OperationalMapState({
    List<OperationalMapFeature> features = const [],
    OperationalMapFilter filter = OperationalMapFilter.all,
  }) : _features = List.unmodifiable(features),
       _filter = filter;

  List<OperationalMapFeature> _features;
  OperationalMapFilter _filter;
  String? _selectedFeatureId;

  List<OperationalMapFeature> get features => _features;
  OperationalMapFilter get filter => _filter;
  String? get selectedFeatureId => _selectedFeatureId;

  List<OperationalMapFeature> get visibleFeatures =>
      List.unmodifiable(_features.where(_filter.includes));

  OperationalMapFeature? get selectedFeature =>
      _featureById(_selectedFeatureId);

  void replaceFeatures(List<OperationalMapFeature> features) {
    _features = List.unmodifiable(features);
    if (_featureById(_selectedFeatureId) == null) {
      _selectedFeatureId = null;
    }
  }

  void applyFilter(OperationalMapFilter filter) {
    _filter = filter;
    final selected = selectedFeature;
    if (selected != null && !filter.includes(selected)) {
      _selectedFeatureId = null;
    }
  }

  OperationalMapFeature? select(String featureId) {
    final feature = _featureById(featureId);
    if (feature == null || !_filter.includes(feature)) return null;
    _selectedFeatureId = featureId;
    return feature.copyWith(selected: true);
  }

  void clearSelection() => _selectedFeatureId = null;

  OperationalMapFeature? _featureById(String? id) {
    if (id == null) return null;
    for (final feature in _features) {
      if (feature.id == id) return feature;
    }
    return null;
  }
}
