import '../models/mobilization.dart';
import '../models/operation.dart';
import '../models/platform_administrator_access.dart';
import '../models/user_display_identity.dart';
import '../repositories/operation_coordinator_read_repository.dart';

enum OperationCoordinatorState { unnamed, assigned, divergent }

class OperationCoordinatorCoverage {
  const OperationCoordinatorCoverage({
    required this.uid,
    required this.identity,
    required this.mobilizations,
  });

  final String uid;
  final UserDisplayIdentity identity;
  final List<Mobilization> mobilizations;

  int get mobilizationCount => mobilizations.length;

  String get usefulIdentifier => uid;
}

class OperationCoordinatorViewData {
  const OperationCoordinatorViewData._({
    required this.state,
    required this.coverages,
    required this.unassignedMobilizations,
  });

  factory OperationCoordinatorViewData.fromAssignments({
    required Iterable<Mobilization> mobilizations,
    required Iterable<MobilizationCoordinatorAssignment> assignments,
    String? coordinatorUid,
  }) {
    final operationMobilizations = mobilizations.toList(growable: false);
    final mobilizationById = {
      for (final mobilization in operationMobilizations)
        mobilization.id: mobilization,
    };
    final activeAssignments = assignments
        .where(
          (assignment) =>
              assignment.active &&
              mobilizationById.containsKey(assignment.mobilizationId),
        )
        .toList(growable: false);
    final activeByMobilization =
        <String, List<MobilizationCoordinatorAssignment>>{};
    for (final assignment in activeAssignments) {
      activeByMobilization
          .putIfAbsent(assignment.mobilizationId, () => [])
          .add(assignment);
    }
    final unassigned = operationMobilizations
        .where(
          (mobilization) =>
              (activeByMobilization[mobilization.id] ?? const []).isEmpty,
        )
        .toList(growable: false);
    if (activeAssignments.isEmpty && coordinatorUid == null) {
      return OperationCoordinatorViewData._(
        state: OperationCoordinatorState.unnamed,
        coverages: const [],
        unassignedMobilizations: unassigned,
      );
    }

    final assignmentsByUid =
        <String, List<MobilizationCoordinatorAssignment>>{};
    for (final assignment in activeAssignments) {
      assignmentsByUid.putIfAbsent(assignment.uid, () => []).add(assignment);
    }
    final coverages =
        assignmentsByUid.entries
            .map((entry) {
              final assignment = entry.value.first;
              final coveredMobilizations =
                  entry.value
                      .map((item) => mobilizationById[item.mobilizationId])
                      .whereType<Mobilization>()
                      .toSet()
                      .toList(growable: false)
                    ..sort((left, right) => left.name.compareTo(right.name));
              return OperationCoordinatorCoverage(
                uid: entry.key,
                identity: assignment.displayIdentity,
                mobilizations: List.unmodifiable(coveredMobilizations),
              );
            })
            .toList(growable: true)
          ..addAll(
            coordinatorUid != null &&
                    !assignmentsByUid.containsKey(coordinatorUid)
                ? [
                    OperationCoordinatorCoverage(
                      uid: coordinatorUid,
                      identity: UserDisplayIdentity.coordinatorFallback(
                        coordinatorUid,
                      ),
                      mobilizations: const [],
                    ),
                  ]
                : const [],
          )
          ..sort(
            (left, right) =>
                left.identity.displayName.compareTo(right.identity.displayName),
          );

    final coherent = coordinatorUid == null
        ? operationMobilizations.isNotEmpty &&
              coverages.length == 1 &&
              unassigned.isEmpty &&
              activeByMobilization.values.every(
                (mobilizationAssignments) =>
                    mobilizationAssignments.length == 1,
              )
        : operationMobilizations.isEmpty ||
              (unassigned.isEmpty &&
                  operationMobilizations.every((mobilization) {
                    final values = activeByMobilization[mobilization.id];
                    return values?.length == 1 &&
                        values!.single.uid == coordinatorUid;
                  }));
    return OperationCoordinatorViewData._(
      state: coherent
          ? OperationCoordinatorState.assigned
          : OperationCoordinatorState.divergent,
      coverages: List.unmodifiable(coverages),
      unassignedMobilizations: List.unmodifiable(unassigned),
    );
  }

  final OperationCoordinatorState state;
  final List<OperationCoordinatorCoverage> coverages;
  final List<Mobilization> unassignedMobilizations;

  OperationCoordinatorCoverage? get coordinator =>
      state == OperationCoordinatorState.assigned ? coverages.single : null;
}

abstract interface class OperationCoordinatorViewDataSource {
  Stream<OperationCoordinatorViewData> watchForOperation(
    Operation operation,
    List<Mobilization> mobilizations,
  );
}

class RepositoryOperationCoordinatorViewDataSource
    implements OperationCoordinatorViewDataSource {
  const RepositoryOperationCoordinatorViewDataSource({
    required OperationCoordinatorReadRepository repository,
  }) : _repository = repository;

  final OperationCoordinatorReadRepository _repository;

  @override
  Stream<OperationCoordinatorViewData> watchForOperation(
    Operation operation,
    List<Mobilization> mobilizations,
  ) {
    final immutableMobilizations = List<Mobilization>.unmodifiable(
      mobilizations,
    );
    final ids = immutableMobilizations.map((item) => item.id).toSet();
    return _repository
        .watchCoordinatorsForMobilizations(ids)
        .map(
          (assignments) => OperationCoordinatorViewData.fromAssignments(
            mobilizations: immutableMobilizations,
            assignments: assignments,
            coordinatorUid: operation.coordinatorUid,
          ),
        );
  }
}

class NoOperationCoordinatorViewDataSource
    implements OperationCoordinatorViewDataSource {
  const NoOperationCoordinatorViewDataSource();

  @override
  Stream<OperationCoordinatorViewData> watchForOperation(
    Operation operation,
    List<Mobilization> mobilizations,
  ) => Stream<OperationCoordinatorViewData>.value(
    OperationCoordinatorViewData.fromAssignments(
      mobilizations: mobilizations,
      assignments: const [],
      coordinatorUid: operation.coordinatorUid,
    ),
  );
}
