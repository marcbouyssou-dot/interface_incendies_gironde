import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/repositories/diffusion_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/firestore_diffusion_read_mapper.dart';

void main() {
  group('FirestoreDiffusionReadMapper', () {
    test('maps Diffusion and Snapshot without recalculating population', () {
      final createdAt = DateTime.utc(2026, 8, 24, 12, 30);

      final model = FirestoreDiffusionReadMapper.fromFirestore(
        diffusion: _diffusionDocument(createdAt: Timestamp.fromDate(createdAt)),
        snapshot: _snapshotDocument(populationCount: 17),
      );

      expect(model.diffusionId, 'diffusion-a');
      expect(model.needId, 'need-a');
      expect(model.status, 'READY');
      expect(model.createdAt.toUtc(), createdAt);
      expect(model.populationCount, 17);
      expect(model.snapshotAvailable, isTrue);
    });

    test('maps legacy DateTime and reports an absent Snapshot explicitly', () {
      final createdAt = DateTime.utc(2026, 8, 23, 9);
      final document = _diffusionDocument(createdAt: createdAt);
      final legacyData = Map<String, Object?>.of(document.data)
        ..['futureAdditiveField'] = true;

      final model = FirestoreDiffusionReadMapper.fromFirestore(
        diffusion: DiffusionReadDocument(id: document.id, data: legacyData),
      );

      expect(model.createdAt, createdAt);
      expect(model.populationCount, isNull);
      expect(model.snapshotAvailable, isFalse);
    });

    test('rejects a Snapshot associated with another need', () {
      expect(
        () => FirestoreDiffusionReadMapper.fromFirestore(
          diffusion: _diffusionDocument(),
          snapshot: _snapshotDocument(needId: 'another-need'),
        ),
        throwsFormatException,
      );
    });
  });

  group('FirestoreDiffusionReadRepository', () {
    test('performs exactly two document reads when Snapshot exists', () async {
      final source = _FakeDiffusionReadDataSource(
        diffusion: _diffusionDocument(),
        snapshot: _snapshotDocument(populationCount: 0),
      );
      final repository = FirestoreDiffusionReadRepository(source);

      final model = await repository.readDiffusion('diffusion-a');

      expect(model?.populationCount, 0);
      expect(model?.snapshotAvailable, isTrue);
      expect(source.reads, [
        (collection: 'diffusions', documentId: 'diffusion-a'),
        (collection: 'diffusionSnapshots', documentId: 'diffusion-a'),
      ]);
    });

    test('does not read a Snapshot when Diffusion is absent', () async {
      final source = _FakeDiffusionReadDataSource();
      final repository = FirestoreDiffusionReadRepository(source);

      expect(await repository.readDiffusion('missing'), isNull);
      expect(source.reads, [(collection: 'diffusions', documentId: 'missing')]);
    });

    test(
      'keeps an authorized Diffusion when its optional Snapshot is absent',
      () async {
        final source = _FakeDiffusionReadDataSource(
          diffusion: _diffusionDocument(),
          snapshotError: FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );
        final repository = FirestoreDiffusionReadRepository(source);

        final model = await repository.readDiffusion('diffusion-a');

        expect(model?.status, 'READY');
        expect(model?.populationCount, isNull);
        expect(model?.snapshotAvailable, isFalse);
        expect(source.reads, [
          (collection: 'diffusions', documentId: 'diffusion-a'),
          (collection: 'diffusionSnapshots', documentId: 'diffusion-a'),
          (collection: 'diffusions', documentId: 'diffusion-a'),
        ]);
      },
    );

    test('does not hide a genuine Snapshot read error', () async {
      final source = _FakeDiffusionReadDataSource(
        diffusion: _diffusionDocument(),
        snapshotError: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );
      final repository = FirestoreDiffusionReadRepository(source);

      await expectLater(
        repository.readDiffusion('diffusion-a'),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'unavailable',
          ),
        ),
      );
    });

    test('does not hide a lost Diffusion authorization', () async {
      final source = _FakeDiffusionReadDataSource(
        diffusion: _diffusionDocument(),
        snapshotError: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
        diffusionErrorAfterFirstRead: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );
      final repository = FirestoreDiffusionReadRepository(source);

      await expectLater(
        repository.readDiffusion('diffusion-a'),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });

    test('rejects an invalid id before any Firestore read', () async {
      final source = _FakeDiffusionReadDataSource();
      final repository = FirestoreDiffusionReadRepository(source);

      await expectLater(
        repository.readDiffusion('invalid/id'),
        throwsFormatException,
      );
      expect(source.reads, isEmpty);
    });
  });
}

class _FakeDiffusionReadDataSource implements DiffusionReadDataSource {
  _FakeDiffusionReadDataSource({
    this.diffusion,
    this.snapshot,
    this.snapshotError,
    this.diffusionErrorAfterFirstRead,
  });

  final DiffusionReadDocument? diffusion;
  final DiffusionReadDocument? snapshot;
  final FirebaseException? snapshotError;
  final FirebaseException? diffusionErrorAfterFirstRead;
  final reads = <({String collection, String documentId})>[];
  var _diffusionReadCount = 0;

  @override
  Future<DiffusionReadDocument?> getDiffusion(String diffusionId) async {
    reads.add((collection: 'diffusions', documentId: diffusionId));
    _diffusionReadCount++;
    if (_diffusionReadCount > 1) {
      final error = diffusionErrorAfterFirstRead;
      if (error != null) throw error;
    }
    return diffusion;
  }

  @override
  Future<DiffusionReadDocument?> getSnapshot(String diffusionId) async {
    reads.add((collection: 'diffusionSnapshots', documentId: diffusionId));
    if (snapshotError case final error?) throw error;
    return snapshot;
  }
}

DiffusionReadDocument _diffusionDocument({Object? createdAt}) =>
    DiffusionReadDocument(
      id: 'diffusion-a',
      data: {
        'id': 'diffusion-a',
        'needId': 'need-a',
        'status': 'READY',
        'createdAt': createdAt ?? Timestamp.fromDate(DateTime.utc(2026, 8, 24)),
      },
    );

DiffusionReadDocument _snapshotDocument({
  String needId = 'need-a',
  int populationCount = 3,
}) => DiffusionReadDocument(
  id: 'diffusion-a',
  data: {
    'diffusionId': 'diffusion-a',
    'needId': needId,
    'populationCount': populationCount,
  },
);
