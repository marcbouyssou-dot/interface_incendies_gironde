import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/repositories/public_mobilization_read_repository.dart';

void main() {
  group('PublicMobilizationReadRepository', () {
    test(
      'agrège uniquement les mobilisations des opérations platform',
      () async {
        final source = _FakePublicMobilizationReadDataSource(
          operationIds: const ['operation-b', 'operation-a'],
          mobilizationIdsByOperation: const {
            'operation-a': ['mobilization-a'],
            'operation-b': ['mobilization-b'],
          },
          legacyMobilizationId: 'mobilization-legacy',
        );

        final result = await PublicMobilizationReadRepository(
          dataSource: source,
        ).watchActiveMobilizationIds().first;

        expect(result, const [
          'mobilization-a',
          'mobilization-b',
          'mobilization-legacy',
        ]);
        expect(source.requestedOperationBatches, const [
          ['operation-a', 'operation-b'],
        ]);
      },
    );

    test('découpe plus de 30 opérations en requêtes bornées', () async {
      final operationIds = List.generate(
        65,
        (index) => 'operation-${index.toString().padLeft(2, '0')}',
      );
      final source = _FakePublicMobilizationReadDataSource(
        operationIds: operationIds,
        mobilizationIdsByOperation: {
          for (final operationId in operationIds)
            operationId: ['mobilization-$operationId'],
        },
      );

      final result = await PublicMobilizationReadRepository(
        dataSource: source,
      ).watchActiveMobilizationIds().first;

      expect(result, hasLength(65));
      expect(source.requestedOperationBatches.map((batch) => batch.length), [
        30,
        30,
        5,
      ]);
      expect(
        source.requestedOperationBatches.every((batch) => batch.length <= 30),
        isTrue,
      );
    });

    test(
      'ne lit aucune mobilisation par opération si aucune n’est platform',
      () async {
        final source = _FakePublicMobilizationReadDataSource(
          operationIds: const [],
        );

        final result = await PublicMobilizationReadRepository(
          dataSource: source,
        ).watchActiveMobilizationIds().first;

        expect(result, isEmpty);
        expect(source.requestedOperationBatches, isEmpty);
      },
    );

    test('déduplique la mobilisation legacy d’une réponse bornée', () async {
      final source = _FakePublicMobilizationReadDataSource(
        operationIds: const ['operation-a'],
        mobilizationIdsByOperation: const {
          'operation-a': ['mobilization-a'],
        },
        legacyMobilizationId: 'mobilization-a',
      );

      final result = await PublicMobilizationReadRepository(
        dataSource: source,
      ).watchActiveMobilizationIds().first;

      expect(result, const ['mobilization-a']);
    });

    test('refuse un identifiant d’opération non canonique', () async {
      final source = _FakePublicMobilizationReadDataSource(
        operationIds: const ['operation/a'],
      );

      await expectLater(
        PublicMobilizationReadRepository(
          dataSource: source,
        ).watchActiveMobilizationIds(),
        emitsError(isA<FormatException>()),
      );
      expect(source.requestedOperationBatches, isEmpty);
    });
  });
}

class _FakePublicMobilizationReadDataSource
    implements PublicMobilizationReadDataSource {
  _FakePublicMobilizationReadDataSource({
    required this.operationIds,
    this.mobilizationIdsByOperation = const {},
    this.legacyMobilizationId,
  });

  final List<String> operationIds;
  final Map<String, List<String>> mobilizationIdsByOperation;
  final String? legacyMobilizationId;
  final List<List<String>> requestedOperationBatches = [];

  @override
  Stream<List<String>> watchPublishedPlatformOperationIds() =>
      _persistentValue(operationIds);

  @override
  Stream<List<String>> watchActiveMobilizationIdsForOperations(
    List<String> operationIds,
  ) {
    requestedOperationBatches.add(List.unmodifiable(operationIds));
    return _persistentValue([
      for (final operationId in operationIds)
        ...mobilizationIdsByOperation[operationId] ?? const <String>[],
    ]);
  }

  @override
  Stream<String?> watchLegacyActiveMobilizationId() =>
      _persistentValue(legacyMobilizationId);

  Stream<T> _persistentValue<T>(T value) {
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () => controller.add(value),
      onCancel: () => controller.close(),
    );
    return controller.stream;
  }
}
