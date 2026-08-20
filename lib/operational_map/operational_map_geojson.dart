import 'operational_map_feature.dart';

abstract final class OperationalMapGeoJson {
  static Map<String, Object> featureCollection(
    Iterable<OperationalMapFeature> features,
  ) {
    return <String, Object>{
      'type': 'FeatureCollection',
      'features': <Map<String, Object>>[
        for (final feature in features) pointFeature(feature),
      ],
    };
  }

  static Map<String, Object> pointFeature(OperationalMapFeature feature) {
    return <String, Object>{
      'type': 'Feature',
      'id': feature.id,
      'properties': <String, Object>{
        'id': feature.id,
        'status': feature.operationalStatus.wireValue,
        'severityRank': feature.operationalStatus.severityRank,
        'activeMissionCount': feature.activeMissionCount,
        'criticalMissionCount': feature.criticalMissionCount,
        'remainingNeedCount': feature.remainingNeedCount,
        'establishmentCount': 1,
        'coverage': feature.coverage,
        'selected': feature.selected,
      },
      'geometry': <String, Object>{
        'type': 'Point',
        'coordinates': <double>[feature.longitude, feature.latitude],
      },
    };
  }

  static Map<String, Object> emptyFeatureCollection() {
    return const <String, Object>{
      'type': 'FeatureCollection',
      'features': <Object>[],
    };
  }
}
