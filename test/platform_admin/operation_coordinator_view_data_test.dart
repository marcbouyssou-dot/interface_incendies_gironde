import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/operational_scope.dart';
import 'package:interface_incendies_gironde/models/platform_administrator_access.dart';
import 'package:interface_incendies_gironde/models/user_display_identity.dart';
import 'package:interface_incendies_gironde/platform_admin/operation_coordinator_view_data.dart';
import 'package:interface_incendies_gironde/repositories/operation_coordinator_read_repository.dart';

void main() {
  group('OperationCoordinatorViewData', () {
    test('indique Non nommé sans affectation', () {
      final viewData = _aggregate(
        mobilizations: [_mobilization('mob-a'), _mobilization('mob-b')],
      );

      expect(viewData.state, OperationCoordinatorState.unnamed);
      expect(viewData.coverages, isEmpty);
      expect(viewData.unassignedMobilizations, hasLength(2));
    });

    test('consolide un Coordinateur unique sur une mobilisation', () {
      final viewData = _aggregate(
        mobilizations: [_mobilization('mob-a')],
        assignments: [_assignment('mob-a', 'coord-1')],
      );

      expect(viewData.state, OperationCoordinatorState.assigned);
      expect(viewData.coordinator?.identity.displayName, 'Camille Martin');
      expect(viewData.coordinator?.usefulIdentifier, 'coord-1');
      expect(viewData.coordinator?.mobilizationCount, 1);
    });

    test('consolide le même Coordinateur sur plusieurs mobilisations', () {
      final viewData = _aggregate(
        mobilizations: [_mobilization('mob-a'), _mobilization('mob-b')],
        assignments: [
          _assignment('mob-a', 'coord-1'),
          _assignment('mob-b', 'coord-1'),
        ],
      );

      expect(viewData.state, OperationCoordinatorState.assigned);
      expect(viewData.coordinator?.mobilizationCount, 2);
      expect(viewData.coordinator?.mobilizations.map((item) => item.id), [
        'mob-a',
        'mob-b',
      ]);
    });

    test('détaille des Coordinateurs différents par mobilisation', () {
      final viewData = _aggregate(
        mobilizations: [_mobilization('mob-a'), _mobilization('mob-b')],
        assignments: [
          _assignment('mob-a', 'coord-1'),
          _assignment('mob-b', 'coord-2'),
        ],
      );

      expect(viewData.state, OperationCoordinatorState.divergent);
      expect(viewData.coverages, hasLength(2));
      expect(
        viewData.coverages
            .map((coverage) => coverage.mobilizations.single.id)
            .toSet(),
        {'mob-a', 'mob-b'},
      );
      expect(viewData.unassignedMobilizations, isEmpty);
    });

    test('ignore une affectation inactive', () {
      final viewData = _aggregate(
        mobilizations: [_mobilization('mob-a')],
        assignments: [_assignment('mob-a', 'coord-1', active: false)],
      );

      expect(viewData.state, OperationCoordinatorState.unnamed);
      expect(viewData.coverages, isEmpty);
    });

    test('signale une mobilisation partiellement non affectée', () {
      final viewData = _aggregate(
        mobilizations: [_mobilization('mob-a'), _mobilization('mob-b')],
        assignments: [_assignment('mob-a', 'coord-1')],
      );

      expect(viewData.state, OperationCoordinatorState.divergent);
      expect(viewData.unassignedMobilizations.single.id, 'mob-b');
    });

    test(
      'le Coordinateur de l’opération est autoritatif sans mobilisation',
      () {
        final viewData = _aggregate(
          mobilizations: const [],
          coordinatorUid: 'coord-1',
        );

        expect(viewData.state, OperationCoordinatorState.assigned);
        expect(viewData.coordinator?.uid, 'coord-1');
        expect(viewData.coordinator?.mobilizationCount, 0);
      },
    );

    test(
      'une projection divergente est signalée face à la source autoritative',
      () {
        final viewData = _aggregate(
          mobilizations: [_mobilization('mob-a')],
          assignments: [_assignment('mob-a', 'coord-2')],
          coordinatorUid: 'coord-1',
        );

        expect(viewData.state, OperationCoordinatorState.divergent);
        expect(viewData.coverages.map((coverage) => coverage.uid).toSet(), {
          'coord-1',
          'coord-2',
        });
      },
    );
  });

  test('la source groupée ouvre un seul flux pour toute l’opération', () async {
    final repository = _RecordingCoordinatorRepository([
      _assignment('mob-a', 'coord-1'),
      _assignment('mob-b', 'coord-1'),
    ]);
    final source = RepositoryOperationCoordinatorViewDataSource(
      repository: repository,
    );

    final viewData = await source.watchForOperation(_operation(), [
      _mobilization('mob-a'),
      _mobilization('mob-b'),
    ]).first;

    expect(repository.watchCalls, 1);
    expect(repository.requestedIds, {'mob-a', 'mob-b'});
    expect(viewData.state, OperationCoordinatorState.assigned);
  });

  group('requêtes bornées des affectations', () {
    test('une opération sans mobilisation ne crée aucune requête', () async {
      var queryCount = 0;

      final assignments = await watchBoundedCoordinatorAssignmentBatches(
        mobilizationIds: const [],
        watchBatch: (_) {
          queryCount += 1;
          return Stream.value(const []);
        },
      ).first;

      expect(assignments, isEmpty);
      expect(queryCount, 0);
    });

    test('une mobilisation crée une seule requête ciblée', () async {
      final requestedBatches = <List<String>>[];

      final assignments = await watchBoundedCoordinatorAssignmentBatches(
        mobilizationIds: const ['mob-a'],
        watchBatch: (ids) {
          requestedBatches.add(ids);
          return Stream.value([_assignment('mob-a', 'coord-1')]);
        },
      ).first;

      expect(requestedBatches, [
        ['mob-a'],
      ]);
      expect(assignments.single.mobilizationId, 'mob-a');
    });

    test('plusieurs lots sont réunis avant une émission unique', () async {
      final ids = List.generate(
        31,
        (index) => 'mob-${index.toString().padLeft(2, '0')}',
      );
      final requestedBatches = <List<String>>[];

      final assignments = await watchBoundedCoordinatorAssignmentBatches(
        mobilizationIds: ids,
        watchBatch: (batch) {
          requestedBatches.add(batch);
          return Stream.value([
            if (batch.contains('mob-00')) _assignment('mob-00', 'coord-1'),
            if (batch.contains('mob-30')) _assignment('mob-30', 'coord-2'),
          ]);
        },
      ).first;

      expect(requestedBatches, hasLength(2));
      expect(requestedBatches.every((batch) => batch.length <= 30), isTrue);
      expect(assignments.map((item) => item.uid).toSet(), {
        'coord-1',
        'coord-2',
      });
    });

    test(
      'les affectations divergentes restent identiques après fusion',
      () async {
        final assignments = await watchBoundedCoordinatorAssignmentBatches(
          mobilizationIds: List.generate(31, (index) => 'mob-$index'),
          watchBatch: (batch) => Stream.value([
            if (batch.contains('mob-0')) _assignment('mob-0', 'coord-1'),
            if (batch.contains('mob-30')) _assignment('mob-30', 'coord-2'),
          ]),
        ).first;

        final viewData = _aggregate(
          mobilizations: [_mobilization('mob-0'), _mobilization('mob-30')],
          assignments: assignments,
        );
        expect(viewData.state, OperationCoordinatorState.divergent);
        expect(viewData.coverages.map((item) => item.uid).toSet(), {
          'coord-1',
          'coord-2',
        });
      },
    );

    test('le flux fusionné ne publie jamais un état partiel', () async {
      final controllers =
          <StreamController<List<MobilizationCoordinatorAssignment>>>[];
      final emissions = <List<MobilizationCoordinatorAssignment>>[];
      final stream = watchBoundedCoordinatorAssignmentBatches(
        mobilizationIds: List.generate(
          31,
          (index) => 'mob-${index.toString().padLeft(2, '0')}',
        ),
        watchBatch: (_) {
          final controller =
              StreamController<
                List<MobilizationCoordinatorAssignment>
              >.broadcast(sync: true);
          controllers.add(controller);
          return controller.stream;
        },
      );
      final subscription = stream.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      controllers.first.add([_assignment('mob-00', 'coord-1')]);
      expect(emissions, isEmpty);
      controllers.last.add([_assignment('mob-30', 'coord-2')]);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, hasLength(1));
      expect(emissions.single.map((item) => item.uid).toSet(), {
        'coord-1',
        'coord-2',
      });

      controllers.first.add(const []);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, hasLength(2));
      expect(emissions.last.map((item) => item.uid), ['coord-2']);

      await subscription.cancel();
      for (final controller in controllers) {
        await controller.close();
      }
    });

    test('performance: 300 mobilisations restent bornées à dix requêtes', () {
      final ids = List.generate(300, (index) => 'mob-$index');
      final batches = boundedMobilizationIdBatches(ids);

      expect(batches, hasLength(10));
      expect(batches.every((batch) => batch.length <= 30), isTrue);
      expect(batches.expand((batch) => batch).toSet(), ids.toSet());
    });
  });
}

OperationCoordinatorViewData _aggregate({
  required List<Mobilization> mobilizations,
  List<MobilizationCoordinatorAssignment> assignments = const [],
  String? coordinatorUid,
}) => OperationCoordinatorViewData.fromAssignments(
  mobilizations: mobilizations,
  assignments: assignments,
  coordinatorUid: coordinatorUid,
);

Operation _operation({String? coordinatorUid}) => Operation(
  id: 'operation-1',
  name: 'Opération 1',
  type: OperationType.other,
  status: OperationStatus.active,
  startAt: DateTime(2026),
  coordinatorUid: coordinatorUid,
  scopeRefs: const [
    OperationalScopeRef(kind: OperationalScopeKind.territory, id: 'gironde'),
  ],
  createdBy: 'admin',
  createdAt: DateTime(2026),
  updatedBy: 'admin',
  updatedAt: DateTime(2026),
  schemaVersion: 2,
);

Mobilization _mobilization(String id) => Mobilization(
  id: id,
  territoryId: 'gironde',
  name: 'Mobilisation $id',
  subtitle: 'Recette',
  contextType: MobilizationContextType.other,
  status: MobilizationStatus.active,
  createdBy: 'admin',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  schemaVersion: 2,
  operationId: 'operation-1',
);

MobilizationCoordinatorAssignment _assignment(
  String mobilizationId,
  String uid, {
  bool active = true,
}) => MobilizationCoordinatorAssignment(
  id: '${mobilizationId}_$uid',
  uid: uid,
  mobilizationId: mobilizationId,
  active: active,
  identity: UserDisplayIdentity(
    uid: uid,
    displayName: uid == 'coord-1' ? 'Camille Martin' : 'Noah Bernard',
    professionLabel: 'Coordinateur',
  ),
);

class _RecordingCoordinatorRepository
    implements OperationCoordinatorReadRepository {
  _RecordingCoordinatorRepository(this.assignments);

  final List<MobilizationCoordinatorAssignment> assignments;
  int watchCalls = 0;
  Set<String>? requestedIds;

  @override
  Stream<List<MobilizationCoordinatorAssignment>>
  watchCoordinatorsForMobilizations(Set<String> mobilizationIds) {
    watchCalls++;
    requestedIds = Set.of(mobilizationIds);
    return Stream.value(assignments);
  }
}
