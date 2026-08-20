import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/coordinator/cockpit_view_data.dart';
import 'package:interface_incendies_gironde/coordinator/territory_view_data.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/operational_map/operational_map_feature.dart';
import 'package:interface_incendies_gironde/operational_map/operational_map_geojson.dart';
import 'package:interface_incendies_gironde/operational_map/operational_map_visual_style.dart';
import 'package:interface_incendies_gironde/widgets/cockpit_operational_map_adapter.dart';

void main() {
  test('CockpitMapPoint adapter preserves operational map data', () {
    final location = places.first;
    final point = CockpitMapPoint(
      location: location,
      latitude: 44.84,
      longitude: -0.58,
      status: TerritoryOperationalStatus.critical,
      missionCount: 3,
      primaryMission: null,
      coveragePercent: 42,
      tensionCount: 2,
      criticalMissionCount: 1,
      nextDeadlineLabel: null,
      nextDeadlineHorizon: null,
      mostNeededProfession: null,
    );

    final feature = operationalMapFeatureFromCockpitPoint(
      point,
      selected: true,
    );

    expect(feature.id, location.id);
    expect(feature.latitude, 44.84);
    expect(feature.longitude, -0.58);
    expect(feature.operationalStatus, OperationalMapStatus.critical);
    expect(feature.activeMissionCount, 3);
    expect(feature.criticalMissionCount, 1);
    expect(feature.coverage, 42);
    expect(feature.selected, isTrue);
  });

  test('adapter maps a point without a mission to noMission', () {
    final point = CockpitMapPoint(
      location: places.first,
      latitude: 44.84,
      longitude: -0.58,
      status: TerritoryOperationalStatus.stable,
      missionCount: 0,
      primaryMission: null,
      coveragePercent: 0,
      tensionCount: 0,
      criticalMissionCount: 0,
      nextDeadlineLabel: null,
      nextDeadlineHorizon: null,
      mostNeededProfession: null,
    );

    expect(
      operationalMapFeatureFromCockpitPoint(point).operationalStatus,
      OperationalMapStatus.noMission,
    );
  });

  test('GeoJSON exposes stable coordinates and renderer properties', () {
    const feature = OperationalMapFeature(
      id: 'center-1',
      latitude: 44.84,
      longitude: -0.58,
      operationalStatus: OperationalMapStatus.watch,
      activeMissionCount: 2,
      criticalMissionCount: 0,
      coverage: 75,
      selected: false,
    );

    final collection = OperationalMapGeoJson.featureCollection([feature]);
    final features = collection['features']! as List<Map<String, Object>>;
    final encoded = features.single;
    final geometry = encoded['geometry']! as Map<String, Object>;
    final properties = encoded['properties']! as Map<String, Object>;

    expect(collection['type'], 'FeatureCollection');
    expect(encoded['id'], 'center-1');
    expect(geometry['coordinates'], <double>[-0.58, 44.84]);
    expect(properties['status'], 'watch');
    expect(properties['severityRank'], 2);
    expect(properties['activeMissionCount'], 2);
    expect(properties['coverage'], 75);
  });

  test('visual hierarchy follows operational severity', () {
    final critical = OperationalMapVisualStyle.forStatus(
      OperationalMapStatus.critical,
    );
    final priority = OperationalMapVisualStyle.forStatus(
      OperationalMapStatus.watch,
    );
    final covered = OperationalMapVisualStyle.forStatus(
      OperationalMapStatus.covered,
    );
    final noMission = OperationalMapVisualStyle.forStatus(
      OperationalMapStatus.noMission,
    );

    expect(<double>[
      critical.overviewRadius,
      priority.overviewRadius,
      covered.overviewRadius,
      noMission.overviewRadius,
    ], orderedEquals(<double>[10, 8, 5, 3.5]));
    expect(critical.opacity, greaterThan(priority.opacity));
    expect(priority.opacity, greaterThan(covered.opacity));
    expect(covered.opacity, greaterThan(noMission.opacity));
    expect(critical.haloOpacity, greaterThan(priority.haloOpacity));
    expect(covered.haloOpacity, 0);
    expect(noMission.haloOpacity, 0);
  });

  test('cluster styling contains every severity up to critical', () {
    final expression = OperationalMapVisualStyle.clusterColorExpression;

    expect(expression, contains(1));
    expect(expression, contains(2));
    expect(expression, contains(3));
    expect(
      expression,
      contains(
        OperationalMapVisualStyle.forStatus(
          OperationalMapStatus.critical,
        ).color,
      ),
    );
  });
}
