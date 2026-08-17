import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/repositories/firestore_platform_read_repository.dart';
import 'package:interface_incendies_gironde/services/accessible_mobilizations_provider.dart';

void main() {
  test('operation supports no end date and the documented lifecycle', () {
    final operation = Operation.fromMap(_operationData('operation-a'));

    expect(operation.endAt, isNull);
    expect(operation.scopeRefs.single.serializedValue, 'territories/gironde');
    expect(
      OperationStatus.draft.canTransitionTo(OperationStatus.planned),
      isTrue,
    );
    expect(
      OperationStatus.active.canTransitionTo(OperationStatus.completed),
      isTrue,
    );
    expect(
      OperationStatus.completed.canTransitionTo(OperationStatus.active),
      isFalse,
    );
    expect(
      OperationStatus.archived.canTransitionTo(OperationStatus.active),
      isFalse,
    );
  });

  test('two operations can reference the same existing territory', () {
    final operationA = Operation.fromMap(_operationData('operation-a'));
    final operationB = Operation.fromMap(
      _operationData('operation-b', type: 'event'),
    );

    expect(
      operationA.scopeRefs.single.serializedValue,
      operationB.scopeRefs.single.serializedValue,
    );
  });

  test('legacy mobilization remains readable without operationId', () {
    final mobilization = Mobilization.fromMap(_mobilizationData('legacy'));

    expect(mobilization.operationId, isNull);
    expect(mobilization.scopeRefs, isEmpty);
    expect(mobilization.toMap(), isNot(contains('operationId')));
  });

  test('mobilization can reference an operation and several scopes', () {
    final mobilization = Mobilization.fromMap(
      _mobilizationData('a1', operationId: 'operation-a'),
    );

    expect(mobilization.operationId, 'operation-a');
    expect(mobilization.scopeRefs.map((ref) => ref.serializedValue), [
      'territories/gironde',
      'locations/langon',
    ]);
  });

  test('coordinator sees only active assigned mobilizations', () async {
    final dataSource = _AccessibleDataSource(
      ids: const ['a1', 'a2', 'b1'],
      documents: {
        'a1': _mobilizationDocument('a1', operationId: 'operation-a'),
        'a2': _mobilizationDocument('a2', operationId: 'operation-a'),
        'b1': _mobilizationDocument(
          'b1',
          operationId: 'operation-b',
          status: 'inactive',
        ),
      },
    );
    final provider = DefaultAccessibleMobilizationsProvider(
      dataSource: dataSource,
    );

    final mobilizations = await provider.watchAccessibleMobilizations().first;

    expect(mobilizations.map((mobilization) => mobilization.id), ['a1', 'a2']);
  });

  test(
    'legacy coordinator falls back to the configured mobilization',
    () async {
      final dataSource = _AccessibleDataSource(
        ids: const [],
        legacyId: 'legacy',
        documents: {'legacy': _legacyMobilizationDocument('legacy')},
      );
      final provider = DefaultAccessibleMobilizationsProvider(
        dataSource: dataSource,
      );

      final mobilizations = await provider.watchAccessibleMobilizations().first;

      expect(mobilizations.map((mobilization) => mobilization.id), ['legacy']);
    },
  );

  test(
    'an explicit assignment immediately replaces the legacy fallback',
    () async {
      final assignments = StreamController<List<String>>();
      addTearDown(assignments.close);
      final dataSource = _AccessibleDataSource(
        ids: const [],
        legacyId: 'legacy',
        assignmentStream: assignments.stream,
        documents: {
          'legacy': _legacyMobilizationDocument('legacy'),
          'assigned': _mobilizationDocument(
            'assigned',
            operationId: 'operation-a',
          ),
        },
      );
      final provider = DefaultAccessibleMobilizationsProvider(
        dataSource: dataSource,
      );
      final expectation = expectLater(
        provider.watchAccessibleMobilizations().map(
          (items) => items.map((item) => item.id).toList(),
        ),
        emitsInOrder([
          ['legacy'],
          ['assigned'],
        ]),
      );

      assignments.add(const []);
      await Future<void>.delayed(Duration.zero);
      assignments.add(const ['assigned']);

      await expectation;
    },
  );
}

Map<String, Object?> _operationData(String id, {String type = 'emergency'}) => {
  'id': id,
  'name': 'Opération $id',
  'type': type,
  'status': 'draft',
  'context': null,
  'startAt': DateTime.utc(2026, 8, 20),
  'endAt': null,
  'scopeRefs': <Object?>['territories/gironde'],
  'createdBy': 'admin',
  'createdAt': DateTime.utc(2026, 8, 1),
  'updatedBy': 'admin',
  'updatedAt': DateTime.utc(2026, 8, 1),
  'schemaVersion': 1,
};

Map<String, Object?> _mobilizationData(
  String id, {
  String? operationId,
  String status = 'active',
}) => {
  'id': id,
  'territoryId': 'gironde',
  'name': id.toUpperCase(),
  'subtitle': 'Recette',
  'contextType': 'fire',
  'status': status,
  'createdBy': 'admin',
  'createdAt': DateTime.utc(2026, 8, 1),
  'updatedAt': DateTime.utc(2026, 8, 1),
  'schemaVersion': operationId == null ? 1 : 2,
  'operationId': ?operationId,
  if (operationId != null)
    'scopeRefs': <Object?>['territories/gironde', 'locations/langon'],
};

PlatformReadDocument _mobilizationDocument(
  String id, {
  required String operationId,
  String status = 'active',
}) => PlatformReadDocument(
  id: id,
  data: _mobilizationData(id, operationId: operationId, status: status),
);

PlatformReadDocument _legacyMobilizationDocument(String id) =>
    PlatformReadDocument(id: id, data: _mobilizationData(id));

class _AccessibleDataSource implements AccessibleMobilizationsDataSource {
  const _AccessibleDataSource({
    required this.ids,
    required this.documents,
    this.legacyId,
    this.assignmentStream,
  });

  final List<String> ids;
  final Map<String, PlatformReadDocument> documents;
  final String? legacyId;
  final Stream<List<String>>? assignmentStream;

  @override
  Stream<String?> watchCurrentUid() => _openValue('coordinator-a');

  @override
  Stream<List<String>> watchAssignedMobilizationIds(String uid) =>
      assignmentStream ?? _openValue(ids);

  @override
  Stream<String?> watchLegacyActiveMobilizationId(String uid) =>
      _openValue(legacyId);

  @override
  Stream<PlatformReadDocument?> watchMobilization(String mobilizationId) =>
      _openValue(documents[mobilizationId]);
}

Stream<T> _openValue<T>(T value) => Stream<T>.multi((controller) {
  controller.add(value);
});
