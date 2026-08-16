import '../models/health_profession.dart';
import '../models/need.dart';
import '../models/profession_quotas.dart';
import 'territory_view_data.dart';

enum CockpitFilter { all, critical, watch, covered }

extension CockpitFilterPresentation on CockpitFilter {
  String get label => switch (this) {
    CockpitFilter.all => 'Toutes',
    CockpitFilter.critical => 'Critiques',
    CockpitFilter.watch => 'À surveiller',
    CockpitFilter.covered => 'Couvertes',
  };

  bool includes(CoordinationNeed mission) => switch (this) {
    CockpitFilter.all => true,
    CockpitFilter.critical => mission.status == NeedStatus.critical,
    CockpitFilter.watch => mission.status == NeedStatus.toComplete,
    CockpitFilter.covered => mission.status == NeedStatus.complete,
  };
}

enum CockpitTimeHorizon { immediate, within24Hours, tomorrow, later }

extension CockpitTimeHorizonPresentation on CockpitTimeHorizon {
  String get label => switch (this) {
    CockpitTimeHorizon.immediate => 'Maintenant',
    CockpitTimeHorizon.within24Hours => '< 24 h',
    CockpitTimeHorizon.tomorrow => 'Demain',
    CockpitTimeHorizon.later => 'Plus tard',
  };
}

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
    required this.nextDeadlineHorizon,
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
  final CockpitTimeHorizon? nextDeadlineHorizon;
  final String? mostNeededProfession;

  bool get hasMission => missionCount > 0;
  bool get showsMissionBadge => missionCount > 1;

  int get visualPriority {
    if (!hasMission) return 0;
    return switch (status) {
      TerritoryOperationalStatus.stable => 1,
      TerritoryOperationalStatus.watch => 2,
      TerritoryOperationalStatus.critical => 3,
    };
  }

  double get visualDiameter {
    if (!hasMission) return 10;
    return switch (missionCount) {
      1 => 26,
      2 => 29,
      3 => 32,
      _ => 35,
    };
  }

  String get operationalStateLabel {
    if (!hasMission) return 'Sans mission';
    return switch (status) {
      TerritoryOperationalStatus.stable => 'Couvert',
      TerritoryOperationalStatus.watch => 'À surveiller',
      TerritoryOperationalStatus.critical => 'Critique',
    };
  }

  String get accessibilityLabel {
    final centerName = location.name.toLowerCase().startsWith('centre ')
        ? location.name
        : 'Centre de ${location.name}';
    if (!hasMission) {
      return '$centerName, état sans mission, aucune mission active.';
    }
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
    return '$centerName, état ${operationalStateLabel.toLowerCase()}, '
        '$missionsLabel, $tensionLabel.';
  }
}

class CockpitPriority {
  const CockpitPriority({
    required this.mission,
    required this.location,
    required this.professionLabel,
    required this.missingProfessionals,
    required this.coverageLabel,
    required this.timingLabel,
    required this.timeHorizon,
  });

  final CoordinationNeed mission;
  final ResponsePlace? location;
  final String professionLabel;
  final int missingProfessionals;
  final String coverageLabel;
  final String timingLabel;
  final CockpitTimeHorizon timeHorizon;

  String get locationLabel => location?.name ?? mission.place;

  String get needLabel => missingProfessionals == 1
      ? '$professionLabel manquant'
      : '$professionLabel · $missingProfessionals manquants';

  String get operationalDetailLabel =>
      '$professionLabel · $coverageLabel · ${_lowercaseInitial(timingLabel)}';
}

enum CockpitAlertLevel { urgent, watch, information }

enum CockpitAlertKind { cancelled, critical, incompleteSoon }

class CockpitAlert {
  const CockpitAlert({
    required this.kind,
    required this.level,
    required this.mission,
    required this.location,
    required this.title,
    required this.detail,
    required this.sortAt,
  });

  final CockpitAlertKind kind;
  final CockpitAlertLevel level;
  final CoordinationNeed mission;
  final ResponsePlace? location;
  final String title;
  final String detail;
  final DateTime sortAt;

  String get locationLabel => location?.name ?? mission.place;

  String get accessibilityLabel => '$title. $locationLabel. $detail.';
}

enum CockpitActivityKind { published, updated, cancelled }

class CockpitActivity {
  const CockpitActivity({
    required this.kind,
    required this.mission,
    required this.location,
    required this.occurredAt,
    required this.timeLabel,
  });

  final CockpitActivityKind kind;
  final CoordinationNeed mission;
  final ResponsePlace? location;
  final DateTime occurredAt;
  final String timeLabel;

  String get title => switch (kind) {
    CockpitActivityKind.published => 'Mission publiée',
    CockpitActivityKind.updated => 'Mission actualisée',
    CockpitActivityKind.cancelled => 'Mission annulée',
  };

  String get locationLabel => location?.name ?? mission.place;

  String get accessibilityLabel => '$title. $locationLabel. $timeLabel.';
}

class CoordinatorCockpitViewData {
  const CoordinatorCockpitViewData({
    required this.territoryName,
    required this.globalStatus,
    required this.globalStateLabel,
    required this.mapPoints,
    required this.priorities,
    required this.alerts,
    required this.recentActivity,
    required this.locationCount,
    required this.missionCount,
    required this.tensionCount,
    required this.globalCoverage,
    required this.criticalMissions,
    required this.mostNeededProfession,
    required this.refreshedAt,
    required this.filter,
    required List<CoordinationNeed> sourceMissions,
    required List<ResponsePlace> sourceLocations,
  }) : _sourceMissions = sourceMissions,
       _sourceLocations = sourceLocations;

  factory CoordinatorCockpitViewData.from({
    required List<CoordinationNeed> missions,
    required List<ResponsePlace> locations,
    DateTime? now,
    String territoryName = 'Gironde',
    CockpitFilter filter = CockpitFilter.all,
  }) {
    final reference = now ?? DateTime.now();
    final allActiveMissions = missions
        .where((mission) => _isOperationallyActive(mission, reference))
        .toList(growable: false);
    final activeMissions = allActiveMissions
        .where(filter.includes)
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
    final allMapPoints = <CockpitMapPoint>[
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
    final mapPoints = filter == CockpitFilter.all
        ? allMapPoints
        : allMapPoints.where((point) => point.hasMission).toList();
    final alerts = _alertsFor(
      missions: missions,
      activeMissions: activeMissions,
      locations: enabledLocations,
      now: reference,
    );
    final recentActivity = _recentActivityFor(
      missions: missions,
      locations: enabledLocations,
      now: reference,
    );

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
      alerts: alerts,
      recentActivity: recentActivity,
      locationCount: filter == CockpitFilter.all
          ? enabledLocations.length
          : mapPoints.length,
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
      filter: filter,
      sourceMissions: missions,
      sourceLocations: locations,
    );
  }

  final String territoryName;
  final TerritoryOperationalStatus globalStatus;
  final String globalStateLabel;
  final List<CockpitMapPoint> mapPoints;
  final List<CockpitPriority> priorities;
  final List<CockpitAlert> alerts;
  final List<CockpitActivity> recentActivity;
  final int locationCount;
  final int missionCount;
  final int tensionCount;
  final double globalCoverage;
  final int criticalMissions;
  final String mostNeededProfession;
  final DateTime refreshedAt;
  final CockpitFilter filter;
  final List<CoordinationNeed> _sourceMissions;
  final List<ResponsePlace> _sourceLocations;

  int get coveragePercent => (globalCoverage * 100).round();

  CoordinatorCockpitViewData filteredBy(CockpitFilter nextFilter) {
    if (filter == nextFilter) return this;
    return CoordinatorCockpitViewData.from(
      missions: _sourceMissions,
      locations: _sourceLocations,
      now: refreshedAt,
      territoryName: territoryName,
      filter: nextFilter,
    );
  }

  String get refreshedAtLabel {
    final hour = refreshedAt.hour.toString().padLeft(2, '0');
    final minute = refreshedAt.minute.toString().padLeft(2, '0');
    return '$hour h $minute';
  }
}

const _nearStartWindow = Duration(hours: 6);
const _recentCancellationWindow = Duration(hours: 24);
const _recentActivityWindow = Duration(days: 7);

List<CockpitAlert> _alertsFor({
  required List<CoordinationNeed> missions,
  required List<CoordinationNeed> activeMissions,
  required List<ResponsePlace> locations,
  required DateTime now,
}) {
  final byMission = <String, CockpitAlert>{};
  for (final mission in missions) {
    final cancelledAt = mission.cancelledAt;
    if (mission.isCancelled &&
        cancelledAt != null &&
        _isRecent(cancelledAt, now, _recentCancellationWindow)) {
      byMission[mission.id] = CockpitAlert(
        kind: CockpitAlertKind.cancelled,
        level: CockpitAlertLevel.urgent,
        mission: mission,
        location: responsePlaceForNeed(mission, locations),
        title: 'Mission annulée',
        detail: mission.cancellationReason?.trim().isNotEmpty == true
            ? mission.cancellationReason!.trim()
            : 'Organisation à réévaluer',
        sortAt: cancelledAt,
      );
    }
  }
  for (final mission in activeMissions) {
    if (byMission.containsKey(mission.id)) continue;
    final location = responsePlaceForNeed(mission, locations);
    if (mission.status == NeedStatus.critical) {
      byMission[mission.id] = CockpitAlert(
        kind: CockpitAlertKind.critical,
        level: CockpitAlertLevel.urgent,
        mission: mission,
        location: location,
        title: 'Mission critique',
        detail: _timingLabel(mission, now),
        sortAt: mission.startAt ?? now,
      );
      continue;
    }
    final startAt = mission.startAt;
    if (mission.status == NeedStatus.toComplete &&
        startAt != null &&
        !startAt.difference(now).isNegative &&
        startAt.difference(now) <= _nearStartWindow) {
      byMission[mission.id] = CockpitAlert(
        kind: CockpitAlertKind.incompleteSoon,
        level: CockpitAlertLevel.watch,
        mission: mission,
        location: location,
        title: 'Mission incomplète proche du début',
        detail: _timingLabel(mission, now),
        sortAt: startAt,
      );
    }
  }
  final alerts = byMission.values.toList(growable: false)
    ..sort((left, right) {
      final level = left.level.index.compareTo(right.level.index);
      if (level != 0) return level;
      final kind = left.kind.index.compareTo(right.kind.index);
      if (kind != 0) return kind;
      final timing = left.sortAt.compareTo(right.sortAt);
      if (timing != 0) return timing;
      return left.mission.id.compareTo(right.mission.id);
    });
  return List.unmodifiable(alerts.take(3));
}

List<CockpitActivity> _recentActivityFor({
  required List<CoordinationNeed> missions,
  required List<ResponsePlace> locations,
  required DateTime now,
}) {
  final activity = <CockpitActivity>[];
  for (final mission in missions) {
    final location = responsePlaceForNeed(mission, locations);
    final cancelledAt = mission.cancelledAt;
    if (mission.isCancelled &&
        cancelledAt != null &&
        _isRecent(cancelledAt, now, _recentActivityWindow)) {
      activity.add(
        CockpitActivity(
          kind: CockpitActivityKind.cancelled,
          mission: mission,
          location: location,
          occurredAt: cancelledAt,
          timeLabel: _activityTimeLabel(cancelledAt, now),
        ),
      );
      continue;
    }
    final createdAt = mission.createdAt;
    if (createdAt != null && _isRecent(createdAt, now, _recentActivityWindow)) {
      activity.add(
        CockpitActivity(
          kind: CockpitActivityKind.published,
          mission: mission,
          location: location,
          occurredAt: createdAt,
          timeLabel: _activityTimeLabel(createdAt, now),
        ),
      );
    }
    final updatedAt = mission.updatedAt;
    final isDistinctUpdate =
        updatedAt != null &&
        (createdAt == null ||
            updatedAt.isAfter(createdAt.add(const Duration(seconds: 1))));
    if (updatedAt != null &&
        isDistinctUpdate &&
        _isRecent(updatedAt, now, _recentActivityWindow)) {
      activity.add(
        CockpitActivity(
          kind: CockpitActivityKind.updated,
          mission: mission,
          location: location,
          occurredAt: updatedAt,
          timeLabel: _activityTimeLabel(updatedAt, now),
        ),
      );
    }
  }
  activity.sort((left, right) {
    final timing = right.occurredAt.compareTo(left.occurredAt);
    if (timing != 0) return timing;
    final mission = left.mission.id.compareTo(right.mission.id);
    if (mission != 0) return mission;
    return left.kind.index.compareTo(right.kind.index);
  });
  return List.unmodifiable(activity.take(5));
}

bool _isRecent(DateTime eventAt, DateTime now, Duration window) {
  if (eventAt.isAfter(now.add(const Duration(minutes: 5)))) return false;
  return now.difference(eventAt) <= window;
}

String _activityTimeLabel(DateTime eventAt, DateTime now) {
  final elapsed = now.difference(eventAt);
  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'À l’instant';
  if (elapsed.inMinutes < 60) return 'Il y a ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) return 'Il y a ${elapsed.inHours} h';
  final day = eventAt.day.toString().padLeft(2, '0');
  final month = eventAt.month.toString().padLeft(2, '0');
  final hour = eventAt.hour.toString().padLeft(2, '0');
  final minute = eventAt.minute.toString().padLeft(2, '0');
  return '$day/$month · $hour h $minute';
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
    coverageLabel:
        '${mission.registeredPeople}/${mission.requiredPeople} couverts',
    timingLabel: _timingLabel(mission, now),
    timeHorizon: _timeHorizon(mission.startAt, now),
  );
}

CockpitTimeHorizon _timeHorizon(DateTime? startAt, DateTime now) {
  if (startAt == null) return CockpitTimeHorizon.later;
  final remaining = startAt.difference(now);
  if (remaining.isNegative || remaining < const Duration(hours: 6)) {
    return CockpitTimeHorizon.immediate;
  }
  if (_isSameDay(startAt, now)) return CockpitTimeHorizon.within24Hours;
  if (_isSameDay(startAt, now.add(const Duration(days: 1)))) {
    return CockpitTimeHorizon.tomorrow;
  }
  return CockpitTimeHorizon.later;
}

bool _isSameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _lowercaseInitial(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toLowerCase()}${value.substring(1)}';
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
  final nextMission = chronologicalMissions.firstOrNull;
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
    nextDeadlineLabel: nextMission == null
        ? null
        : _timingLabel(nextMission, now),
    nextDeadlineHorizon: nextMission == null
        ? null
        : _timeHorizon(nextMission.startAt, now),
    mostNeededProfession: missingQuotas.firstOrNull == null
        ? null
        : HealthProfessionRegistry.byId(
                missingQuotas.first.professionId,
              )?.shortLabel ??
              missingQuotas.first.professionId,
  );
}
