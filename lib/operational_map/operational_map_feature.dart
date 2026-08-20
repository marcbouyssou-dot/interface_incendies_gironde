enum OperationalMapStatus { critical, watch, covered, noMission }

extension OperationalMapStatusPresentation on OperationalMapStatus {
  int get severityRank => switch (this) {
    OperationalMapStatus.noMission => 0,
    OperationalMapStatus.covered => 1,
    OperationalMapStatus.watch => 2,
    OperationalMapStatus.critical => 3,
  };

  String get wireValue => switch (this) {
    OperationalMapStatus.critical => 'critical',
    OperationalMapStatus.watch => 'watch',
    OperationalMapStatus.covered => 'covered',
    OperationalMapStatus.noMission => 'noMission',
  };
}

class OperationalMapFeature {
  const OperationalMapFeature({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.operationalStatus,
    required this.activeMissionCount,
    required this.criticalMissionCount,
    required this.coverage,
    required this.selected,
  });

  final String id;
  final double latitude;
  final double longitude;
  final OperationalMapStatus operationalStatus;
  final int activeMissionCount;
  final int criticalMissionCount;
  final int coverage;
  final bool selected;

  OperationalMapFeature copyWith({bool? selected}) {
    return OperationalMapFeature(
      id: id,
      latitude: latitude,
      longitude: longitude,
      operationalStatus: operationalStatus,
      activeMissionCount: activeMissionCount,
      criticalMissionCount: criticalMissionCount,
      coverage: coverage,
      selected: selected ?? this.selected,
    );
  }
}

enum OperationalMapFilter { all, tensions, critical, activeMissions }

extension OperationalMapFilterRules on OperationalMapFilter {
  bool includes(OperationalMapFeature feature) => switch (this) {
    OperationalMapFilter.all => true,
    OperationalMapFilter.tensions =>
      feature.operationalStatus == OperationalMapStatus.critical ||
          feature.operationalStatus == OperationalMapStatus.watch,
    OperationalMapFilter.critical =>
      feature.operationalStatus == OperationalMapStatus.critical,
    OperationalMapFilter.activeMissions => feature.activeMissionCount > 0,
  };
}
