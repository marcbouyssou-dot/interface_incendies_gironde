import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mobilization.dart';
import '../models/operation.dart';
import '../utils/switch_latest.dart';

abstract interface class PublicMobilizationReadDataSource {
  Stream<List<String>> watchPublishedPlatformOperationIds();

  Stream<List<String>> watchActiveMobilizationIdsForOperations(
    List<String> operationIds,
  );

  Stream<String?> watchLegacyActiveMobilizationId();
}

/// Produit l'unique flux public de mobilisations, borné en amont par les
/// opérations explicitement publiées au niveau plateforme.
///
/// Le document de configuration legacy est lu séparément : aucune requête de
/// collection ne tente de retrouver les mobilisations sans `operationId`.
class PublicMobilizationReadRepository {
  const PublicMobilizationReadRepository({
    required PublicMobilizationReadDataSource dataSource,
    this.batchSize = 30,
  }) : _dataSource = dataSource,
       assert(batchSize > 0 && batchSize <= 30);

  final PublicMobilizationReadDataSource _dataSource;
  final int batchSize;

  Stream<List<String>> watchActiveMobilizationIds() => switchLatest(
    _dataSource.watchPublishedPlatformOperationIds(),
    (rawOperationIds) {
      try {
        final operationIds = _validatedIds(rawOperationIds, 'opération');
        final streams = <Stream<List<String>>>[
          for (final batch in _batchesOf(operationIds, batchSize))
            _dataSource.watchActiveMobilizationIdsForOperations(batch),
          _dataSource.watchLegacyActiveMobilizationId().map(
            (id) => id == null ? const <String>[] : [id],
          ),
        ];
        return _combineIdStreams(streams);
      } on Object catch (error, stackTrace) {
        return Stream<List<String>>.error(error, stackTrace);
      }
    },
  );

  List<String> _validatedIds(Iterable<String> values, String label) {
    final result = values.toSet().toList(growable: false)..sort();
    if (result.any(
      (value) => value.isEmpty || value.trim() != value || value.contains('/'),
    )) {
      throw FormatException('Identifiant $label public invalide.');
    }
    return result;
  }

  Iterable<List<String>> _batchesOf(List<String> values, int size) sync* {
    for (var start = 0; start < values.length; start += size) {
      final end = start + size < values.length ? start + size : values.length;
      yield values.sublist(start, end);
    }
  }

  Stream<List<String>> _combineIdStreams(List<Stream<List<String>>> streams) {
    late final StreamController<List<String>> controller;
    final subscriptions = <StreamSubscription<List<String>>>[];
    final values = <int, List<String>>{};

    void emit() {
      if (values.length != streams.length || controller.isClosed) return;
      final ids = values.values.expand((items) => items).toSet().toList()
        ..sort();
      controller.add(List<String>.unmodifiable(ids));
    }

    controller = StreamController<List<String>>(
      onListen: () {
        for (var index = 0; index < streams.length; index += 1) {
          subscriptions.add(
            streams[index].listen((ids) {
              values[index] = _validatedIds(ids, 'mobilisation');
              emit();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }
}

class FirestorePublicMobilizationReadDataSource
    implements PublicMobilizationReadDataSource {
  const FirestorePublicMobilizationReadDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<String>> watchPublishedPlatformOperationIds() => _firestore
      .collection('operations')
      .where('visibility', isEqualTo: 'platform')
      .where(
        'status',
        whereIn: [
          OperationStatus.planned.serializedValue,
          OperationStatus.active.serializedValue,
          OperationStatus.suspended.serializedValue,
          OperationStatus.completed.serializedValue,
        ],
      )
      .snapshots()
      .map((snapshot) {
        final ids = snapshot.docs.map((document) => document.id).toList();
        ids.sort();
        return ids;
      });

  @override
  Stream<List<String>> watchActiveMobilizationIdsForOperations(
    List<String> operationIds,
  ) {
    if (operationIds.isEmpty || operationIds.length > 30) {
      return Stream<List<String>>.error(
        const FormatException('Lot d\'opérations publiques invalide.'),
      );
    }
    return _firestore
        .collection('mobilizations')
        .where('operationId', whereIn: operationIds)
        .where('status', isEqualTo: MobilizationStatus.active.serializedValue)
        .snapshots()
        .map((snapshot) {
          final ids = snapshot.docs.map((document) => document.id).toList();
          ids.sort();
          return ids;
        });
  }

  @override
  Stream<String?> watchLegacyActiveMobilizationId() => switchLatest(
    _firestore.collection('platform').doc('config').snapshots(),
    (snapshot) {
      final value = snapshot.data()?['activeMobilizationId'];
      if (value == null) return Stream<String?>.value(null);
      if (value is! String ||
          value.isEmpty ||
          value.trim() != value ||
          value.contains('/')) {
        return Stream<String?>.error(
          const FormatException('Mobilisation active legacy invalide.'),
        );
      }
      return _firestore.collection('mobilizations').doc(value).snapshots().map((
        mobilization,
      ) {
        final data = mobilization.data();
        if (!mobilization.exists || data == null) return null;
        if (data['id'] != value) {
          throw const FormatException('Mobilisation legacy incohérente.');
        }
        if (data.containsKey('operationId') ||
            data['status'] != MobilizationStatus.active.serializedValue) {
          return null;
        }
        return value;
      });
    },
  );
}
