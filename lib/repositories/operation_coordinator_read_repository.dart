import 'dart:async';

import '../models/platform_administrator_access.dart';

const mobilizationAssignmentWhereInLimit = 30;

typedef CoordinatorAssignmentBatchWatcher =
    Stream<List<MobilizationCoordinatorAssignment>> Function(
      List<String> mobilizationIds,
    );

List<List<String>> boundedMobilizationIdBatches(Iterable<String> values) {
  final ids = values.toSet().toList(growable: false)..sort();
  return [
    for (
      var start = 0;
      start < ids.length;
      start += mobilizationAssignmentWhereInLimit
    )
      List<String>.unmodifiable(
        ids.skip(start).take(mobilizationAssignmentWhereInLimit),
      ),
  ];
}

Stream<List<MobilizationCoordinatorAssignment>>
watchBoundedCoordinatorAssignmentBatches({
  required Iterable<String> mobilizationIds,
  required CoordinatorAssignmentBatchWatcher watchBatch,
}) {
  final batches = boundedMobilizationIdBatches(mobilizationIds);
  if (batches.isEmpty) {
    return Stream<List<MobilizationCoordinatorAssignment>>.value(const []);
  }
  if (batches.length == 1) return watchBatch(batches.single);
  return _combineLatestAssignmentBatches(
    batches.map(watchBatch).toList(growable: false),
  );
}

Stream<List<MobilizationCoordinatorAssignment>> _combineLatestAssignmentBatches(
  List<Stream<List<MobilizationCoordinatorAssignment>>> sources,
) {
  late StreamController<List<MobilizationCoordinatorAssignment>> controller;
  final subscriptions =
      <StreamSubscription<List<MobilizationCoordinatorAssignment>>>[];
  final latest = List<List<MobilizationCoordinatorAssignment>?>.filled(
    sources.length,
    null,
  );
  var completed = 0;

  void emitIfComplete() {
    if (latest.any((value) => value == null) || controller.isClosed) return;
    final byId = <String, MobilizationCoordinatorAssignment>{};
    for (final batch in latest) {
      for (final assignment in batch!) {
        byId[assignment.id] = assignment;
      }
    }
    controller.add(List.unmodifiable(byId.values));
  }

  controller = StreamController<List<MobilizationCoordinatorAssignment>>(
    onListen: () {
      for (var index = 0; index < sources.length; index++) {
        subscriptions.add(
          sources[index].listen(
            (value) {
              latest[index] = value;
              emitIfComplete();
            },
            onError: controller.addError,
            onDone: () {
              completed += 1;
              if (completed == sources.length && !controller.isClosed) {
                controller.close();
              }
            },
          ),
        );
      }
    },
    onPause: () {
      for (final subscription in subscriptions) {
        subscription.pause();
      }
    },
    onResume: () {
      for (final subscription in subscriptions) {
        subscription.resume();
      }
    },
    onCancel: () =>
        Future.wait(subscriptions.map((subscription) => subscription.cancel())),
  );
  return controller.stream;
}

abstract interface class OperationCoordinatorReadRepository {
  Stream<List<MobilizationCoordinatorAssignment>>
  watchCoordinatorsForMobilizations(Set<String> mobilizationIds);
}

class NoOperationCoordinatorReadRepository
    implements OperationCoordinatorReadRepository {
  const NoOperationCoordinatorReadRepository();

  @override
  Stream<List<MobilizationCoordinatorAssignment>>
  watchCoordinatorsForMobilizations(Set<String> mobilizationIds) =>
      Stream<List<MobilizationCoordinatorAssignment>>.value(const []);
}
