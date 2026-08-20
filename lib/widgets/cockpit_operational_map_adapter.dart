import '../coordinator/cockpit_view_data.dart';
import '../coordinator/territory_view_data.dart';
import '../operational_map/operational_map_feature.dart';

OperationalMapFeature operationalMapFeatureFromCockpitPoint(
  CockpitMapPoint point, {
  bool selected = false,
}) {
  final status = !point.hasMission
      ? OperationalMapStatus.noMission
      : switch (point.status) {
          TerritoryOperationalStatus.critical => OperationalMapStatus.critical,
          TerritoryOperationalStatus.watch => OperationalMapStatus.watch,
          TerritoryOperationalStatus.stable => OperationalMapStatus.covered,
        };
  return OperationalMapFeature(
    id: point.location.id,
    latitude: point.latitude,
    longitude: point.longitude,
    operationalStatus: status,
    activeMissionCount: point.missionCount,
    criticalMissionCount: point.criticalMissionCount,
    coverage: point.coveragePercent,
    selected: selected,
  );
}
