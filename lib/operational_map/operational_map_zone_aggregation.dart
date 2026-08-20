import 'operational_map_feature.dart';

class OperationalMapZoneSummary {
  const OperationalMapZoneSummary({
    required this.maximumSeverity,
    required this.activeMissionCount,
    required this.remainingNeedCount,
    required this.establishmentCount,
  });

  factory OperationalMapZoneSummary.fromFeatures(
    Iterable<OperationalMapFeature> features,
  ) {
    var maximumSeverity = OperationalMapStatus.noMission.severityRank;
    var activeMissionCount = 0;
    var remainingNeedCount = 0;
    var establishmentCount = 0;
    for (final feature in features) {
      if (feature.operationalStatus.severityRank > maximumSeverity) {
        maximumSeverity = feature.operationalStatus.severityRank;
      }
      activeMissionCount += feature.activeMissionCount;
      remainingNeedCount += feature.remainingNeedCount;
      establishmentCount += 1;
    }
    return OperationalMapZoneSummary(
      maximumSeverity: maximumSeverity,
      activeMissionCount: activeMissionCount,
      remainingNeedCount: remainingNeedCount,
      establishmentCount: establishmentCount,
    );
  }

  final int maximumSeverity;
  final int activeMissionCount;
  final int remainingNeedCount;
  final int establishmentCount;

  bool get isTension =>
      maximumSeverity >= OperationalMapStatus.watch.severityRank;
}

abstract final class OperationalMapZoneAggregation {
  static const clusterRadius = 58.0;
  static const clusterMaxZoom = 11.0;

  static const clusterProperties = <String, Object>{
    'maxSeverity': <Object>[
      'max',
      <Object>['get', 'severityRank'],
    ],
    'activeMissionCount': <Object>[
      '+',
      <Object>['get', 'activeMissionCount'],
    ],
    'remainingNeedCount': <Object>[
      '+',
      <Object>['get', 'remainingNeedCount'],
    ],
    'establishmentCount': <Object>[
      '+',
      <Object>['get', 'establishmentCount'],
    ],
  };
}
