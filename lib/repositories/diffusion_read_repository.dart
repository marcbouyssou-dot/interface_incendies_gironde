import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/diffusion_read_model.dart';
import 'firestore_diffusion_read_mapper.dart';

abstract interface class DiffusionReadRepository {
  Future<DiffusionReadModel?> readDiffusion(String diffusionId);
}

abstract interface class DiffusionReadDataSource {
  Future<DiffusionReadDocument?> getDiffusion(String diffusionId);

  Future<DiffusionReadDocument?> getSnapshot(String diffusionId);
}

class FirestoreDiffusionReadDataSource implements DiffusionReadDataSource {
  const FirestoreDiffusionReadDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<DiffusionReadDocument?> getDiffusion(String diffusionId) =>
      _getDocument(collection: 'diffusions', documentId: diffusionId);

  @override
  Future<DiffusionReadDocument?> getSnapshot(String diffusionId) =>
      _getDocument(collection: 'diffusionSnapshots', documentId: diffusionId);

  Future<DiffusionReadDocument?> _getDocument({
    required String collection,
    required String documentId,
  }) async {
    final snapshot = await _firestore
        .collection(collection)
        .doc(documentId)
        .get();
    final data = snapshot.data();
    return !snapshot.exists || data == null
        ? null
        : DiffusionReadDocument(id: snapshot.id, data: data);
  }
}

class FirestoreDiffusionReadRepository implements DiffusionReadRepository {
  const FirestoreDiffusionReadRepository(this._dataSource);

  factory FirestoreDiffusionReadRepository.withFirestore(
    FirebaseFirestore firestore,
  ) => FirestoreDiffusionReadRepository(
    FirestoreDiffusionReadDataSource(firestore),
  );

  final DiffusionReadDataSource _dataSource;

  @override
  Future<DiffusionReadModel?> readDiffusion(String diffusionId) async {
    _validateIdentifier(diffusionId);
    final diffusion = await _dataSource.getDiffusion(diffusionId);
    if (diffusion == null) return null;
    final snapshot = await _readOptionalSnapshot(
      diffusionId: diffusionId,
      diffusion: diffusion,
    );
    return FirestoreDiffusionReadMapper.fromFirestore(
      diffusion: diffusion,
      snapshot: snapshot,
    );
  }

  Future<DiffusionReadDocument?> _readOptionalSnapshot({
    required String diffusionId,
    required DiffusionReadDocument diffusion,
  }) async {
    try {
      return await _dataSource.getSnapshot(diffusionId);
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;

      // Snapshot reads are authorized from resource.data. Firestore therefore
      // reports permission-denied while this optional document does not exist.
      // Re-reading the Diffusion distinguishes that race from a lost access.
      final confirmedDiffusion = await _dataSource.getDiffusion(diffusionId);
      if (confirmedDiffusion == null ||
          confirmedDiffusion.id != diffusion.id ||
          confirmedDiffusion.data['needId'] != diffusion.data['needId']) {
        rethrow;
      }
      return null;
    }
  }

  void _validateIdentifier(String value) {
    if (value.trim().isEmpty ||
        value.trim() != value ||
        value.length > 180 ||
        value.contains('/')) {
      throw const FormatException('Identifiant Diffusion invalide.');
    }
  }
}
