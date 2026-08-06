import '../models/need.dart';
import '../models/profession_quotas.dart';
import '../utils/french_date_time.dart';

enum TerritoryOperationalStatus { stable, watch, critical }

extension TerritoryOperationalStatusLabel on TerritoryOperationalStatus {
  String get label => switch (this) {
    TerritoryOperationalStatus.stable => 'Stable',
    TerritoryOperationalStatus.watch => 'À surveiller',
    TerritoryOperationalStatus.critical => 'Critique',
  };
}

class TerritorySectorViewData {
  const TerritorySectorViewData({
    required this.group,
    required this.status,
    required this.centerCount,
    required this.activeNeeds,
    required this.uncoveredNeeds,
    required this.nextDeadline,
  });

  final TerritorialGroup group;
  final TerritoryOperationalStatus status;
  final int centerCount;
  final int activeNeeds;
  final int uncoveredNeeds;
  final String nextDeadline;
}

class CoordinatorTerritoryViewData {
  const CoordinatorTerritoryViewData({
    required this.sectors,
    required this.activeNeeds,
    required this.coveredCenters,
    required this.mobilizedProfessionals,
  });

  factory CoordinatorTerritoryViewData.from({
    required List<CoordinationNeed> missions,
    required List<ResponsePlace> locations,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final active = missions
        .where((mission) => _isOperationallyActive(mission, reference))
        .toList(growable: false);
    final enabledLocations = locations
        .where((location) => location.isEnabled)
        .toList(growable: false);
    final representedGroups = <TerritorialGroup>{
      for (final location in enabledLocations) location.group,
      for (final mission in active) mission.group,
    };
    final sectors = <TerritorySectorViewData>[
      for (final group in TerritorialGroup.values)
        if (representedGroups.contains(group))
          _sectorFor(
            group: group,
            activeMissions: active,
            locations: enabledLocations,
            now: reference,
          ),
    ];
    final quotas = ProfessionQuotas.aggregate(
      active.map((mission) => mission.professionQuotas),
    );
    var coveredCenters = 0;
    for (final location in enabledLocations) {
      final locationNeeds = active
          .where(
            (mission) =>
                responsePlaceForNeed(mission, enabledLocations)?.id ==
                location.id,
          )
          .toList(growable: false);
      if (locationNeeds.isNotEmpty &&
          locationNeeds.every(
            (mission) => mission.status == NeedStatus.complete,
          )) {
        coveredCenters++;
      }
    }
    return CoordinatorTerritoryViewData(
      sectors: sectors,
      activeNeeds: active.length,
      coveredCenters: coveredCenters,
      mobilizedProfessionals: quotas.registeredTotal,
    );
  }

  final List<TerritorySectorViewData> sectors;
  final int activeNeeds;
  final int coveredCenters;
  final int mobilizedProfessionals;

  List<TerritorySectorViewData> get sectorsRequiringAttention => sectors
      .where((sector) => sector.status != TerritoryOperationalStatus.stable)
      .toList(growable: false);
}

TerritorySectorViewData _sectorFor({
  required TerritorialGroup group,
  required List<CoordinationNeed> activeMissions,
  required List<ResponsePlace> locations,
  required DateTime now,
}) {
  final missions = activeMissions
      .where((mission) => mission.group == group)
      .toList(growable: false);
  final uncovered = missions
      .where((mission) => mission.status != NeedStatus.complete)
      .toList(growable: false);
  final status =
      missions.any((mission) => mission.status == NeedStatus.critical)
      ? TerritoryOperationalStatus.critical
      : uncovered.isNotEmpty
      ? TerritoryOperationalStatus.watch
      : TerritoryOperationalStatus.stable;
  return TerritorySectorViewData(
    group: group,
    status: status,
    centerCount: locations.where((location) => location.group == group).length,
    activeNeeds: missions.length,
    uncoveredNeeds: uncovered.length,
    nextDeadline: _nextDeadline(missions, now),
  );
}

bool _isOperationallyActive(CoordinationNeed mission, DateTime now) {
  if (!mission.isActive || mission.isCancelled) return false;
  final endAt = mission.endAt;
  return endAt == null || now.isBefore(endAt);
}

String _nextDeadline(List<CoordinationNeed> missions, DateTime now) {
  final dated = <DateTime>[];
  for (final mission in missions) {
    final startAt = mission.startAt;
    final endAt = mission.endAt;
    if (startAt != null && now.isBefore(startAt)) {
      dated.add(startAt);
    } else if (endAt != null && now.isBefore(endAt)) {
      dated.add(endAt);
    }
  }
  if (dated.isNotEmpty) {
    dated.sort();
    final deadline = dated.first;
    return '${FrenchDateTime.relativeDate(deadline, now: now)} · '
        '${FrenchDateTime.time(deadline)}';
  }
  for (final mission in missions) {
    final label = mission.date.trim();
    if (label.isNotEmpty) return label;
  }
  return 'Aucune échéance';
}
