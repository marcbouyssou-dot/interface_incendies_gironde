import '../models/need.dart';

enum MissionTemporalState { upcoming, current, past }

MissionTemporalState missionTemporalState(
  CoordinationNeed mission, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final endAt = mission.endAt;
  if (endAt != null && !reference.isBefore(endAt)) {
    return MissionTemporalState.past;
  }
  final startAt = mission.startAt;
  if (startAt != null && reference.isBefore(startAt)) {
    return MissionTemporalState.upcoming;
  }
  if (startAt != null || endAt != null) {
    return MissionTemporalState.current;
  }
  return MissionTemporalState.upcoming;
}

bool isMissionPast(CoordinationNeed mission, {DateTime? now}) =>
    missionTemporalState(mission, now: now) == MissionTemporalState.past;

bool isMissionOperational(CoordinationNeed mission, {DateTime? now}) =>
    mission.isActive &&
    !mission.isCancelled &&
    !isMissionPast(mission, now: now);

bool isMissionScheduledForTomorrow(CoordinationNeed mission, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  if (!isMissionOperational(mission, now: reference)) return false;

  final startAt = mission.startAt;
  final endAt = mission.endAt;
  if (startAt == null || endAt == null) return false;

  final tomorrowStart = DateTime(
    reference.year,
    reference.month,
    reference.day + 1,
  );
  final dayAfterTomorrow = DateTime(
    reference.year,
    reference.month,
    reference.day + 2,
  );
  return startAt.isBefore(dayAfterTomorrow) && endAt.isAfter(tomorrowStart);
}
