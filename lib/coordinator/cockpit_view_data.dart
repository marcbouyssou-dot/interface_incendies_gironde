import '../models/health_profession.dart';
import '../models/need.dart';
import '../models/profession_quotas.dart';
import 'territory_view_data.dart';

class CockpitMapPoint {
  const CockpitMapPoint({
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.missionCount,
    required this.primaryMission,
    required this.coveragePercent,
    required this.tensionCount,
    required this.criticalMissionCount,
    required this.nextDeadlineLabel,
    required this.mostNeededProfession,
  });

  final ResponsePlace location;
  final double latitude;
  final double longitude;
  final TerritoryOperationalStatus status;
  final int missionCount;
  final CoordinationNeed? primaryMission;
  final int coveragePercent;
  final int tensionCount;
  final int criticalMissionCount;
  final String? nextDeadlineLabel;
  final String? mostNeededProfession;

  bool get hasMission => missionCount > 0;

  String get accessibilityLabel {
    final centerName = location.name.toLowerCase().startsWith('centre ')
        ? location.name
        : 'Centre de ${location.name}';
    if (!hasMission) return '$centerName, aucune mission active.';
    final missionsLabel = missionCount == 1
        ? '1 mission active'
        : '$missionCount missions actives';
    final tensionLabel = criticalMissionCount > 0
        ? criticalMissionCount == 1
              ? '1 tension critique'
              : '$criticalMissionCount tensions critiques'
        : tensionCount > 0
        ? tensionCount == 1
              ? '1 tension à surveiller'
              : '$tensionCount tensions à surveiller'
        : 'couvert';
    return '$centerName, $missionsLabel, $tensionLabel.';
  }
}

class CockpitPriority {
  const CockpitPriority({
    required this.mission,
    required this.location,
    required this.professionLabel,
    required this.missingProfessionals,
    required this.timingLabel,
  });

  final CoordinationNeed mission;
  final ResponsePlace? location;
  final String professionLabel;
  final int missingProfessionals;
  final String timingLabel;

  String get locationLabel => location?.name ?? mission.place;

  String get needLabel => missingProfessionals == 1
      ? '$professionLabel manquant'
      : '$professionLabel · $missingProfessionals manquants';
}

class CoordinatorCockpitViewData {
  const CoordinatorCockpitViewData({
    required this.territoryName,
    required this.globalStatus,
    required this.globalStateLabel,
    required this.mapPoints,
    required this.priorities,
    required this.locationCount,
    required this.missionCount,
    required this.tensionCount,
    required this.globalCoverage,
    required this.criticalMissions,
    required this.mostNeededProfession,
    required this.refreshedAt,
  });

  factory CoordinatorCockpitViewData.from({
    required List<CoordinationNeed> missions,
    required List<ResponsePlace> locations,
    DateTime? now,
    String territoryName = 'Gironde',
  }) {
    final reference = now ?? DateTime.now();
    final activeMissions = missions
        .where((mission) => _isOperationallyActive(mission, reference))
        .toList(growable: false);
    final enabledLocations = locations
        .where((location) => location.isEnabled)
        .toList(growable: false);
    final tensions =
        activeMissions
            .where((mission) => mission.status != NeedStatus.complete)
            .toList(growable: false)
          ..sort(_compareTensions);
    final criticalCount = activeMissions
        .where((mission) => mission.status == NeedStatus.critical)
        .length;
    final status = criticalCount > 0
        ? TerritoryOperationalStatus.critical
        : tensions.isNotEmpty
        ? TerritoryOperationalStatus.watch
        : TerritoryOperationalStatus.stable;
    final totalQuotas = ProfessionQuotas.aggregate(
      activeMissions.map((mission) => mission.professionQuotas),
    );
    final missingQuotas =
        ProfessionQuotas.aggregate(
            tensions.map((mission) => mission.professionQuotas),
          ).values.where((quota) => quota.missing > 0).toList(growable: false)
          ..sort((left, right) {
            final missing = right.missing.compareTo(left.missing);
            if (missing != 0) return missing;
            return left.professionId.compareTo(right.professionId);
          });

    final priorities = <CockpitPriority>[
      for (final mission in tensions.take(3))
        _priorityFor(
          mission: mission,
          location: responsePlaceForNeed(mission, enabledLocations),
          now: reference,
        ),
    ];
    final mapPoints = <CockpitMapPoint>[
      for (final location in enabledLocations)
        if (location.structuredAddress?.latitude != null &&
            location.structuredAddress?.longitude != null)
          _mapPointFor(
            location: location,
            missions: activeMissions,
            locations: enabledLocations,
            now: reference,
          ),
    ];

    return CoordinatorCockpitViewData(
      territoryName: territoryName,
      globalStatus: status,
      globalStateLabel: switch (status) {
        TerritoryOperationalStatus.stable => 'Situation maîtrisée',
        TerritoryOperationalStatus.watch => 'Situation sous surveillance',
        TerritoryOperationalStatus.critical => 'Situation critique',
      },
      mapPoints: mapPoints,
      priorities: priorities,
      locationCount: enabledLocations.length,
      missionCount: activeMissions.length,
      tensionCount: tensions.length,
      globalCoverage: totalQuotas.coverage,
      criticalMissions: criticalCount,
      mostNeededProfession: missingQuotas.isEmpty
          ? 'Aucune tension'
          : HealthProfessionRegistry.byId(
                  missingQuotas.first.professionId,
                )?.shortLabel ??
                missingQuotas.first.professionId,
      refreshedAt: reference,
    );
  }

  final String territoryName;
  final TerritoryOperationalStatus globalStatus;
  final String globalStateLabel;
  final List<CockpitMapPoint> mapPoints;
  final List<CockpitPriority> priorities;
  final int locationCount;
  final int missionCount;
  final int tensionCount;
  final double globalCoverage;
  final int criticalMissions;
  final String mostNeededProfession;
  final DateTime refreshedAt;

  int get coveragePercent => (globalCoverage * 100).round();

  String get refreshedAtLabel {
    final hour = refreshedAt.hour.toString().padLeft(2, '0');
    final minute = refreshedAt.minute.toString().padLeft(2, '0');
    return '$hour h $minute';
  }
}

bool _isOperationallyActive(CoordinationNeed mission, DateTime now) {
  if (!mission.isActive || mission.isCancelled) return false;
  final endAt = mission.endAt;
  return endAt == null || now.isBefore(endAt);
}

int _compareTensions(CoordinationNeed left, CoordinationNeed right) {
  final status = left.status.index.compareTo(right.status.index);
  if (status != 0) return status;
  final leftStart = left.startAt;
  final rightStart = right.startAt;
  if (leftStart != null || rightStart != null) {
    if (leftStart == null) return 1;
    if (rightStart == null) return -1;
    final start = leftStart.compareTo(rightStart);
    if (start != 0) return start;
  }
  final coverage = left.coverage.compareTo(right.coverage);
  if (coverage != 0) return coverage;
  final missing = right.professionQuotas.values
      .fold(0, (total, quota) => total + quota.missing)
      .compareTo(
        left.professionQuotas.values.fold(
          0,
          (total, quota) => total + quota.missing,
        ),
      );
  if (missing != 0) return missing;
  return left.id.compareTo(right.id);
}

CockpitPriority _priorityFor({
  required CoordinationNeed mission,
  required ResponsePlace? location,
  required DateTime now,
}) {
  final missing =
      mission.professionQuotas.values
          .where((quota) => quota.missing > 0)
          .toList(growable: false)
        ..sort((left, right) => right.missing.compareTo(left.missing));
  final primary = missing.first;
  final profession = HealthProfessionRegistry.byId(primary.professionId);
  return CockpitPriority(
    mission: mission,
    location: location,
    professionLabel: profession?.shortLabel ?? primary.professionId,
    missingProfessionals: primary.missing,
    timingLabel: _timingLabel(mission, now),
  );
}

String _timingLabel(CoordinationNeed mission, DateTime now) {
  final startAt = mission.startAt;
  if (startAt == null) return 'Début ${mission.date}';
  final remaining = startAt.difference(now);
  if (!remaining.isNegative && remaining.inMinutes < 60) {
    final minutes = remaining.inMinutes.clamp(1, 59);
    return 'Début dans $minutes min';
  }
  if (!remaining.isNegative && remaining.inHours < 24) {
    return 'Début dans ${remaining.inHours} h';
  }
  if (remaining.isNegative) return 'En cours';
  return 'Début ${mission.date}';
}

CockpitMapPoint _mapPointFor({
  required ResponsePlace location,
  required List<CoordinationNeed> missions,
  required List<ResponsePlace> locations,
  required DateTime now,
}) {
  final locationMissions = missions
      .where(
        (mission) =>
            responsePlaceForNeed(mission, locations)?.id == location.id,
      )
      .toList(growable: false);
  final orderedMissions = [...locationMissions]..sort(_compareTensions);
  final chronologicalMissions = [...locationMissions]
    ..sort((left, right) {
      final leftStart = left.startAt;
      final rightStart = right.startAt;
      if (leftStart == null) return rightStart == null ? 0 : 1;
      if (rightStart == null) return -1;
      return leftStart.compareTo(rightStart);
    });
  final tensionMissions = locationMissions
      .where((mission) => mission.status != NeedStatus.complete)
      .toList(growable: false);
  final criticalMissionCount = locationMissions
      .where((mission) => mission.status == NeedStatus.critical)
      .length;
  final quotas = ProfessionQuotas.aggregate(
    locationMissions.map((mission) => mission.professionQuotas),
  );
  final missingQuotas =
      ProfessionQuotas.aggregate(
          tensionMissions.map((mission) => mission.professionQuotas),
        ).values.where((quota) => quota.missing > 0).toList(growable: false)
        ..sort((left, right) {
          final missing = right.missing.compareTo(left.missing);
          if (missing != 0) return missing;
          return left.professionId.compareTo(right.professionId);
        });
  final status =
      locationMissions.any((mission) => mission.status == NeedStatus.critical)
      ? TerritoryOperationalStatus.critical
      : locationMissions.any((mission) => mission.status != NeedStatus.complete)
      ? TerritoryOperationalStatus.watch
      : TerritoryOperationalStatus.stable;
  return CockpitMapPoint(
    location: location,
    latitude: location.structuredAddress!.latitude!,
    longitude: location.structuredAddress!.longitude!,
    status: status,
    missionCount: locationMissions.length,
    primaryMission: orderedMissions.firstOrNull,
    coveragePercent: (quotas.coverage * 100).round(),
    tensionCount: tensionMissions.length,
    criticalMissionCount: criticalMissionCount,
    nextDeadlineLabel: chronologicalMissions.firstOrNull == null
        ? null
        : _timingLabel(chronologicalMissions.first, now),
    mostNeededProfession: missingQuotas.firstOrNull == null
        ? null
        : HealthProfessionRegistry.byId(
                missingQuotas.first.professionId,
              )?.shortLabel ??
              missingQuotas.first.professionId,
  );
}
