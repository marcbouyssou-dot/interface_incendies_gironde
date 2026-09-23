import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/diffusion_read_model.dart';

class DiffusionReadDocument {
  DiffusionReadDocument({required this.id, required Map<String, Object?> data})
    : data = Map<String, Object?>.unmodifiable(data);

  final String id;
  final Map<String, Object?> data;
}

abstract final class FirestoreDiffusionReadMapper {
  static DiffusionReadModel fromFirestore({
    required DiffusionReadDocument diffusion,
    DiffusionReadDocument? snapshot,
  }) {
    final diffusionId = _requiredIdentifier(
      diffusion.data,
      'id',
      entity: 'Diffusion',
    );
    if (diffusionId != diffusion.id) {
      throw const FormatException('Identifiant Diffusion incohérent.');
    }
    final needId = _requiredIdentifier(
      diffusion.data,
      'needId',
      entity: 'Diffusion',
    );
    final status = _requiredText(diffusion.data, 'status', entity: 'Diffusion');
    final createdAt = _dateTime(
      diffusion.data['createdAt'],
      entity: 'Diffusion',
    );

    if (snapshot == null) {
      return DiffusionReadModel(
        diffusionId: diffusionId,
        needId: needId,
        status: status,
        createdAt: createdAt,
        populationCount: null,
        snapshotAvailable: false,
      );
    }

    final snapshotDiffusionId = _requiredIdentifier(
      snapshot.data,
      'diffusionId',
      entity: 'Snapshot',
    );
    final snapshotNeedId = _requiredIdentifier(
      snapshot.data,
      'needId',
      entity: 'Snapshot',
    );
    if (snapshot.id != diffusionId ||
        snapshotDiffusionId != diffusionId ||
        snapshotNeedId != needId) {
      throw const FormatException('Snapshot de Diffusion incohérent.');
    }
    final populationCount = snapshot.data['populationCount'];
    if (populationCount is! int || populationCount < 0) {
      throw const FormatException('Population du Snapshot invalide.');
    }

    return DiffusionReadModel(
      diffusionId: diffusionId,
      needId: needId,
      status: status,
      createdAt: createdAt,
      populationCount: populationCount,
      snapshotAvailable: true,
    );
  }

  static String _requiredIdentifier(
    Map<String, Object?> data,
    String field, {
    required String entity,
  }) {
    final value = _requiredText(data, field, entity: entity);
    if (value.length > 180 || value.contains('/')) {
      throw FormatException('$entity invalide : $field.');
    }
    return value;
  }

  static String _requiredText(
    Map<String, Object?> data,
    String field, {
    required String entity,
  }) {
    final value = data[field];
    if (value is! String || value.trim().isEmpty || value.trim() != value) {
      throw FormatException('$entity invalide : $field.');
    }
    return value;
  }

  static DateTime _dateTime(Object? value, {required String entity}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    throw FormatException('Date $entity invalide.');
  }
}
