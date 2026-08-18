import 'mobilization.dart';
import 'need.dart';
import 'operation.dart';

enum ExecutivePlatformState { calm, stable, watch, critical }

class ExecutiveDashboardSnapshot {
  ExecutiveDashboardSnapshot({
    required List<Operation> operations,
    required List<Mobilization> mobilizations,
    required List<CoordinationNeed> missions,
  }) : operations = List.unmodifiable(operations),
       mobilizations = List.unmodifiable(mobilizations),
       missions = List.unmodifiable(
         missions.where((mission) => mission.isActive && !mission.isCancelled),
       ) {
    final mobilizationsByOperation = <String, List<Mobilization>>{};
    for (final mobilization in mobilizations) {
      final operationId = mobilization.operationId;
      if (operationId == null) continue;
      mobilizationsByOperation
          .putIfAbsent(operationId, () => [])
          .add(mobilization);
    }
    final missionsByMobilization = <String, List<CoordinationNeed>>{};
    for (final mission in this.missions) {
      final mobilizationId = mission.mobilizationId;
      if (mobilizationId == null) continue;
      missionsByMobilization.putIfAbsent(mobilizationId, () => []).add(mission);
    }
    operationSnapshots = List.unmodifiable(
      operations.map((operation) {
        final scopedMobilizations = List<Mobilization>.unmodifiable(
          mobilizationsByOperation[operation.id] ?? const [],
        );
        return OperationExecutiveSnapshot(
          operation: operation,
          mobilizations: scopedMobilizations,
          missions: List.unmodifiable(
            scopedMobilizations.expand(
              (mobilization) =>
                  missionsByMobilization[mobilization.id] ?? const [],
            ),
          ),
        );
      }),
    );
  }

  final List<Operation> operations;
  final List<Mobilization> mobilizations;
  final List<CoordinationNeed> missions;
  late final List<OperationExecutiveSnapshot> operationSnapshots;

  int get activeOperationCount => operations
      .where((operation) => operation.status == OperationStatus.active)
      .length;

  int get activeMobilizationCount => mobilizations
      .where((mobilization) => mobilization.status == MobilizationStatus.active)
      .length;

  int get activeMissionCount => missions.length;

  int get criticalMissionCount =>
      missions.where((mission) => mission.status == NeedStatus.critical).length;

  int get mobilizedProfessionalCount =>
      missions.fold(0, (total, mission) => total + mission.registeredPeople);

  int get establishmentCount => missions
      .map((mission) => mission.locationId ?? mission.place)
      .where((value) => value.trim().isNotEmpty)
      .toSet()
      .length;

  int get requiredProfessionalCount =>
      missions.fold(0, (total, mission) => total + mission.requiredPeople);

  double? get coverage {
    final required = requiredProfessionalCount;
    if (required == 0) return null;
    return (mobilizedProfessionalCount / required).clamp(0, 1).toDouble();
  }

  ExecutivePlatformState get state {
    if (criticalMissionCount >= 3) return ExecutivePlatformState.critical;
    if (criticalMissionCount > 0) return ExecutivePlatformState.watch;
    if (operations.isEmpty) return ExecutivePlatformState.calm;
    return ExecutivePlatformState.stable;
  }

  DateTime? get lastUpdated {
    final values = <DateTime>[
      ...operations.map((operation) => operation.updatedAt),
      ...mobilizations.map((mobilization) => mobilization.updatedAt),
      ...missions.map((mission) => mission.updatedAt).whereType<DateTime>(),
    ];
    if (values.isEmpty) return null;
    return values.reduce((left, right) => left.isAfter(right) ? left : right);
  }

  List<OperationExecutiveSnapshot> get priorityOperations {
    final result = operationSnapshots
        .where(
          (snapshot) => !{
            OperationStatus.completed,
            OperationStatus.archived,
          }.contains(snapshot.operation.status),
        )
        .toList(growable: false);
    result.sort((left, right) {
      final byScore = right.priorityScore.compareTo(left.priorityScore);
      if (byScore != 0) return byScore;
      return left.operation.startAt.compareTo(right.operation.startAt);
    });
    return result.take(3).toList(growable: false);
  }

  OperationExecutiveSnapshot snapshotFor(Operation operation) =>
      operationSnapshots.firstWhere(
        (snapshot) => snapshot.operation.id == operation.id,
        orElse: () => OperationExecutiveSnapshot(
          operation: operation,
          mobilizations: const [],
          missions: const [],
        ),
      );
}

class OperationExecutiveSnapshot {
  const OperationExecutiveSnapshot({
    required this.operation,
    required this.mobilizations,
    required this.missions,
  });

  final Operation operation;
  final List<Mobilization> mobilizations;
  final List<CoordinationNeed> missions;

  int get missionCount => missions.length;

  int get criticalMissionCount =>
      missions.where((mission) => mission.status == NeedStatus.critical).length;

  int get establishmentCount => missions
      .map((mission) => mission.locationId ?? mission.place)
      .where((value) => value.trim().isNotEmpty)
      .toSet()
      .length;

  int get requiredProfessionalCount =>
      missions.fold(0, (total, mission) => total + mission.requiredPeople);

  int get mobilizedProfessionalCount =>
      missions.fold(0, (total, mission) => total + mission.registeredPeople);

  double? get coverage {
    final required = requiredProfessionalCount;
    if (required == 0) return null;
    return (mobilizedProfessionalCount / required).clamp(0, 1).toDouble();
  }

  int get priorityScore {
    final statusScore = switch (operation.status) {
      OperationStatus.active => 40,
      OperationStatus.suspended => 30,
      OperationStatus.planned => 20,
      OperationStatus.draft => 10,
      OperationStatus.completed || OperationStatus.archived => 0,
    };
    final uncovered = coverage == null ? 0 : ((1 - coverage!) * 100).round();
    return criticalMissionCount * 1000 + uncovered * 10 + statusScore;
  }
}
