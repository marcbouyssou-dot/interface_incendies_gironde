import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/coordinator/cockpit_view_data.dart';
import 'package:interface_incendies_gironde/coordinator/territory_view_data.dart';
import 'package:interface_incendies_gironde/models/health_profession.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';

void main() {
  const merignac = ResponsePlace(
    id: 'merignac',
    name: 'Mérignac',
    type: ResponsePlaceType.sdisStation,
    group: TerritorialGroup.bordeauxMetropole,
    activeNeeds: 1,
    structuredAddress: LocationAddress(latitude: 44.81885, longitude: -0.64805),
  );
  const langon = ResponsePlace(
    id: 'langon',
    name: 'Langon',
    type: ResponsePlaceType.sdisStation,
    group: TerritorialGroup.southGironde,
    activeNeeds: 1,
    structuredAddress: LocationAddress(latitude: 44.55, longitude: -0.25),
  );

  CoordinationNeed mission({
    required String id,
    required ResponsePlace location,
    required Map<String, int> required,
    required Map<String, int> registered,
    required DateTime startAt,
    bool isCancelled = false,
  }) => CoordinationNeed(
    id: id,
    locationId: location.id,
    place: location.name,
    group: location.group,
    date: 'samedi 15 août',
    time: '12:00 — 16:00',
    requiredPhysiotherapists: 0,
    registeredPhysiotherapists: 0,
    requiredPodiatrists: 0,
    registeredPodiatrists: 0,
    equipment: const [],
    startAt: startAt,
    endAt: startAt.add(const Duration(hours: 4)),
    isCancelled: isCancelled,
    professionQuotas: ProfessionQuotas.fromMaps(
      requiredByProfession: required,
      registeredByProfession: registered,
    ),
  );

  test(
    'cockpit ranks tensions and derives only the three requested metrics',
    () {
      final now = DateTime(2026, 8, 15, 10);
      final view = CoordinatorCockpitViewData.from(
        now: now,
        locations: const [merignac, langon],
        missions: [
          mission(
            id: 'critical-mk',
            location: merignac,
            required: const {HealthProfessionId.physiotherapist: 3},
            registered: const {HealthProfessionId.physiotherapist: 0},
            startAt: now.add(const Duration(hours: 2)),
          ),
          mission(
            id: 'watch-ide',
            location: langon,
            required: const {HealthProfessionId.nurse: 2},
            registered: const {HealthProfessionId.nurse: 1},
            startAt: now.add(const Duration(hours: 4)),
          ),
          mission(
            id: 'covered',
            location: merignac,
            required: const {HealthProfessionId.physician: 1},
            registered: const {HealthProfessionId.physician: 1},
            startAt: now.add(const Duration(hours: 6)),
          ),
          mission(
            id: 'cancelled',
            location: langon,
            required: const {HealthProfessionId.physician: 4},
            registered: const {HealthProfessionId.physician: 0},
            startAt: now.add(const Duration(hours: 1)),
            isCancelled: true,
          ),
        ],
      );

      expect(view.globalStatus, TerritoryOperationalStatus.critical);
      expect(view.globalStateLabel, 'Situation critique');
      expect(view.priorities.map((priority) => priority.mission.id), [
        'critical-mk',
        'watch-ide',
      ]);
      expect(view.priorities.first.needLabel, 'MK · 3 manquants');
      expect(view.priorities.first.timingLabel, 'Début dans 2 h');
      expect(view.coveragePercent, 33);
      expect(view.criticalMissions, 1);
      expect(view.mostNeededProfession, 'MK');
      expect(view.mapPoints, hasLength(2));
      expect(view.locationCount, 2);
      expect(view.missionCount, 3);
      expect(view.tensionCount, 2);
      expect(view.refreshedAtLabel, '10 h 00');
      expect(
        view.mapPoints.singleWhere((point) => point.location == merignac),
        isA<CockpitMapPoint>()
            .having(
              (point) => point.status,
              'status',
              TerritoryOperationalStatus.critical,
            )
            .having(
              (point) => point.primaryMission?.id,
              'primary mission',
              'critical-mk',
            ),
      );
      expect(
        view.mapPoints.singleWhere((point) => point.location == langon).status,
        TerritoryOperationalStatus.watch,
      );
    },
  );

  test('empty operational territory is stable and fully covered', () {
    final view = CoordinatorCockpitViewData.from(
      locations: const [merignac],
      missions: const [],
    );

    expect(view.globalStatus, TerritoryOperationalStatus.stable);
    expect(view.globalStateLabel, 'Situation maîtrisée');
    expect(view.coveragePercent, 100);
    expect(view.criticalMissions, 0);
    expect(view.mostNeededProfession, 'Aucune tension');
    expect(view.locationCount, 1);
    expect(view.missionCount, 0);
    expect(view.tensionCount, 0);
    expect(view.priorities, isEmpty);
  });

  test('partially covered territory is under surveillance', () {
    final now = DateTime(2026, 8, 15, 10);
    final view = CoordinatorCockpitViewData.from(
      now: now,
      locations: const [langon],
      missions: [
        mission(
          id: 'watch-ide',
          location: langon,
          required: const {HealthProfessionId.nurse: 2},
          registered: const {HealthProfessionId.nurse: 1},
          startAt: now.add(const Duration(hours: 4)),
        ),
      ],
    );

    expect(view.globalStatus, TerritoryOperationalStatus.watch);
    expect(view.globalStateLabel, 'Situation sous surveillance');
  });
}
