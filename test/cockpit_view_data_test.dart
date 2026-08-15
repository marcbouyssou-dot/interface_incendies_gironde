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
    bool isActive = true,
    DateTime? cancelledAt,
    String? cancellationReason,
    DateTime? createdAt,
    DateTime? updatedAt,
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
    isActive: isActive,
    isCancelled: isCancelled,
    cancelledAt: cancelledAt,
    cancellationReason: cancellationReason,
    createdAt: createdAt,
    updatedAt: updatedAt,
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
      expect(view.alerts.map((alert) => alert.mission.id), [
        'critical-mk',
        'watch-ide',
      ]);
      expect(view.alerts.first.level, CockpitAlertLevel.urgent);
      expect(view.alerts.first.kind, CockpitAlertKind.critical);
      expect(view.alerts.last.level, CockpitAlertLevel.watch);
      expect(view.alerts.last.kind, CockpitAlertKind.incompleteSoon);
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
            )
            .having((point) => point.missionCount, 'mission count', 2)
            .having((point) => point.coveragePercent, 'coverage', 25)
            .having((point) => point.tensionCount, 'tensions', 1)
            .having(
              (point) => point.criticalMissionCount,
              'critical missions',
              1,
            )
            .having(
              (point) => point.nextDeadlineLabel,
              'next deadline',
              'Début dans 2 h',
            )
            .having(
              (point) => point.mostNeededProfession,
              'profession in tension',
              'MK',
            )
            .having(
              (point) => point.accessibilityLabel,
              'accessibility label',
              'Centre de Mérignac, 2 missions actives, 1 tension critique.',
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
    expect(view.alerts, isEmpty);
    expect(view.recentActivity, isEmpty);
    expect(view.mapPoints.single.hasMission, isFalse);
    expect(view.mapPoints.single.coveragePercent, 100);
    expect(view.mapPoints.single.nextDeadlineLabel, isNull);
    expect(view.mapPoints.single.mostNeededProfession, isNull);
    expect(
      view.mapPoints.single.accessibilityLabel,
      'Centre de Mérignac, aucune mission active.',
    );
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

  test('alerts are deduplicated, ordered and limited to three', () {
    final now = DateTime(2026, 8, 15, 10);
    final view = CoordinatorCockpitViewData.from(
      now: now,
      locations: const [merignac, langon],
      missions: [
        mission(
          id: 'watch',
          location: langon,
          required: const {HealthProfessionId.nurse: 2},
          registered: const {HealthProfessionId.nurse: 1},
          startAt: now.add(const Duration(minutes: 30)),
        ),
        mission(
          id: 'critical-later',
          location: merignac,
          required: const {HealthProfessionId.physiotherapist: 3},
          registered: const {HealthProfessionId.physiotherapist: 0},
          startAt: now.add(const Duration(hours: 3)),
        ),
        mission(
          id: 'critical-soon',
          location: langon,
          required: const {HealthProfessionId.physician: 2},
          registered: const {HealthProfessionId.physician: 0},
          startAt: now.add(const Duration(hours: 1)),
        ),
        mission(
          id: 'cancelled',
          location: merignac,
          required: const {HealthProfessionId.nurse: 1},
          registered: const {HealthProfessionId.nurse: 1},
          startAt: now.add(const Duration(hours: 2)),
          isActive: false,
          isCancelled: true,
          cancelledAt: now.subtract(const Duration(minutes: 8)),
        ),
      ],
    );

    expect(view.alerts, hasLength(3));
    expect(view.alerts.map((alert) => alert.mission.id), [
      'cancelled',
      'critical-soon',
      'critical-later',
    ]);
    expect(
      view.alerts.map((alert) => alert.mission.id).toSet(),
      hasLength(view.alerts.length),
    );
    expect(
      view.alerts.where((alert) => alert.mission.id == 'critical-soon'),
      hasLength(1),
    );
  });

  test('an incomplete mission outside the six-hour window is not an alert', () {
    final now = DateTime(2026, 8, 15, 10);
    final view = CoordinatorCockpitViewData.from(
      now: now,
      locations: const [langon],
      missions: [
        mission(
          id: 'later',
          location: langon,
          required: const {HealthProfessionId.nurse: 2},
          registered: const {HealthProfessionId.nurse: 1},
          startAt: now.add(const Duration(hours: 7)),
        ),
      ],
    );

    expect(view.alerts, isEmpty);
  });

  test(
    'recent activity uses only available timestamps and keeps five items',
    () {
      final now = DateTime(2026, 8, 15, 10);
      final view = CoordinatorCockpitViewData.from(
        now: now,
        locations: const [merignac],
        missions: [
          for (var index = 0; index < 6; index++)
            mission(
              id: 'published-$index',
              location: merignac,
              required: const {HealthProfessionId.physiotherapist: 1},
              registered: const {HealthProfessionId.physiotherapist: 1},
              startAt: now.add(const Duration(days: 1)),
              createdAt: now.subtract(Duration(minutes: index + 1)),
            ),
        ],
      );

      expect(view.recentActivity, hasLength(5));
      expect(view.recentActivity.map((event) => event.mission.id), [
        'published-0',
        'published-1',
        'published-2',
        'published-3',
        'published-4',
      ]);
      expect(
        view.recentActivity.every(
          (event) => event.kind == CockpitActivityKind.published,
        ),
        isTrue,
      );
    },
  );

  test('activity distinguishes publication, update and cancellation', () {
    final now = DateTime(2026, 8, 15, 10);
    final view = CoordinatorCockpitViewData.from(
      now: now,
      locations: const [merignac, langon],
      missions: [
        mission(
          id: 'updated',
          location: merignac,
          required: const {HealthProfessionId.physiotherapist: 1},
          registered: const {HealthProfessionId.physiotherapist: 1},
          startAt: now.add(const Duration(days: 1)),
          createdAt: now.subtract(const Duration(minutes: 30)),
          updatedAt: now.subtract(const Duration(minutes: 10)),
        ),
        mission(
          id: 'cancelled',
          location: langon,
          required: const {HealthProfessionId.nurse: 1},
          registered: const {HealthProfessionId.nurse: 1},
          startAt: now.add(const Duration(days: 1)),
          isActive: false,
          isCancelled: true,
          cancelledAt: now.subtract(const Duration(minutes: 5)),
          createdAt: now.subtract(const Duration(hours: 2)),
          updatedAt: now.subtract(const Duration(minutes: 5)),
        ),
      ],
    );

    expect(view.recentActivity.map((event) => event.kind), [
      CockpitActivityKind.cancelled,
      CockpitActivityKind.updated,
      CockpitActivityKind.published,
    ]);
    expect(view.recentActivity.first.timeLabel, 'Il y a 5 min');
    expect(view.recentActivity.first.title, 'Mission annulée');
    expect(view.recentActivity[1].title, 'Mission actualisée');
  });
}
