import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mobilization.dart';
import '../models/territory.dart';
import '../utils/switch_latest.dart';
import 'platform_read_repository.dart';

abstract interface class PlatformReadDataSource {
  Stream<Map<String, Object?>?> watchPlatformConfigDocument();

  Stream<List<PlatformReadDocument>> watchTerritoryDocuments();

  Stream<List<PlatformReadDocument>> watchMobilizationDocuments({
    String? territoryId,
    required bool includeInactive,
  });

  Stream<PlatformReadDocument?> watchMobilizationDocument(String id);
}

abstract interface class OperationMobilizationReadDataSource {
  Stream<List<PlatformReadDocument>>
  watchActiveMobilizationDocumentsForOperation(String operationId);
}

class PlatformReadDocument {
  const PlatformReadDocument({required this.id, required this.data});

  final String id;
  final Map<String, Object?> data;
}

class FirestorePlatformReadDataSource
    implements PlatformReadDataSource, OperationMobilizationReadDataSource {
  const FirestorePlatformReadDataSource(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Stream<List<PlatformReadDocument>>
  watchActiveMobilizationDocumentsForOperation(String operationId) => firestore
      .collection('mobilizations')
      .where('operationId', isEqualTo: operationId)
      .where('status', isEqualTo: MobilizationStatus.active.serializedValue)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (document) =>
                  PlatformReadDocument(id: document.id, data: document.data()),
            )
            .toList(growable: false),
      );

  @override
  Stream<Map<String, Object?>?> watchPlatformConfigDocument() {
    return firestore
        .collection('platform')
        .doc('config')
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  @override
  Stream<List<PlatformReadDocument>> watchTerritoryDocuments() {
    return firestore
        .collection('territories')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => PlatformReadDocument(
                  id: document.id,
                  data: document.data(),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Stream<List<PlatformReadDocument>> watchMobilizationDocuments({
    String? territoryId,
    required bool includeInactive,
  }) {
    Query<Map<String, dynamic>> query = firestore.collection('mobilizations');
    if (territoryId != null) {
      query = query.where('territoryId', isEqualTo: territoryId);
    }
    if (!includeInactive) {
      query = query.where(
        'status',
        isEqualTo: MobilizationStatus.active.serializedValue,
      );
    }
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (document) =>
                PlatformReadDocument(id: document.id, data: document.data()),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<PlatformReadDocument?> watchMobilizationDocument(String id) {
    return firestore.collection('mobilizations').doc(id).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      return !snapshot.exists || data == null
          ? null
          : PlatformReadDocument(id: snapshot.id, data: data);
    });
  }
}

class FirestorePlatformReadRepository
    implements
        PlatformReadRepository,
        MobilizationLookupRepository,
        OperationMobilizationReadRepository {
  const FirestorePlatformReadRepository({
    required PlatformReadDataSource dataSource,
  }) : _dataSource = dataSource;

  factory FirestorePlatformReadRepository.withFirebase({
    required FirebaseFirestore firestore,
  }) {
    return FirestorePlatformReadRepository(
      dataSource: FirestorePlatformReadDataSource(firestore),
    );
  }

  final PlatformReadDataSource _dataSource;

  @override
  Stream<List<Mobilization>> watchActiveMobilizationsForOperations(
    Set<String> operationIds, {
    String? territoryId,
  }) {
    if (operationIds.any(
      (id) => id.isEmpty || id.trim() != id || id.contains('/'),
    )) {
      return Stream<List<Mobilization>>.error(
        const FormatException('Identifiant d’opération invalide.'),
      );
    }
    if (operationIds.isEmpty) {
      return Stream<List<Mobilization>>.value(const []);
    }
    final source = _dataSource;
    if (source is! OperationMobilizationReadDataSource) {
      return Stream<List<Mobilization>>.error(
        StateError('Lecture de mobilisation bornée indisponible.'),
      );
    }
    final scopedSource = source as OperationMobilizationReadDataSource;
    final streams = operationIds
        .map(
          (id) => scopedSource
              .watchActiveMobilizationDocumentsForOperation(id)
              .map(
                (documents) => documents
                    .map(_mobilizationFromDocument)
                    .where(
                      (item) =>
                          territoryId == null ||
                          item.territoryId == territoryId,
                    )
                    .toList(growable: false),
              ),
        )
        .toList(growable: false);
    late final StreamController<List<Mobilization>> controller;
    final subscriptions = <StreamSubscription<List<Mobilization>>>[];
    final values = <int, List<Mobilization>>{};
    void emit() {
      if (values.length != streams.length || controller.isClosed) return;
      final byId = <String, Mobilization>{};
      for (final list in values.values) {
        for (final item in list) {
          byId[item.id] = item;
        }
      }
      final result = byId.values.toList(growable: false)
        ..sort((left, right) => left.name.compareTo(right.name));
      controller.add(List<Mobilization>.unmodifiable(result));
    }

    controller = StreamController<List<Mobilization>>(
      onListen: () {
        for (var index = 0; index < streams.length; index++) {
          subscriptions.add(
            streams[index].listen((items) {
              values[index] = items;
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

  @override
  Stream<String?> watchPlatformConfig() {
    return _dataSource.watchPlatformConfigDocument().map((data) {
      final value = data?['activeMobilizationId'];
      if (value == null) return null;
      if (value is! String || value.trim().isEmpty || value.trim() != value) {
        throw const FormatException('Configuration plateforme invalide.');
      }
      return value;
    });
  }

  @override
  Stream<List<Territory>> watchTerritories() {
    return _dataSource.watchTerritoryDocuments().map((documents) {
      final territories = documents.map(_territoryFromDocument).toList();
      territories.sort((left, right) => left.name.compareTo(right.name));
      return territories;
    });
  }

  @override
  Stream<List<Mobilization>> watchMobilizations({
    String? territoryId,
    bool includeInactive = false,
  }) {
    return _dataSource
        .watchMobilizationDocuments(
          territoryId: territoryId,
          includeInactive: includeInactive,
        )
        .map(
          (documents) =>
              documents.map(_mobilizationFromDocument).toList(growable: false),
        );
  }

  @override
  Stream<Mobilization?> watchMobilization(String mobilizationId) {
    return _dataSource
        .watchMobilizationDocument(mobilizationId)
        .map(
          (document) =>
              document == null ? null : _mobilizationFromDocument(document),
        )
        .transform(
          StreamTransformer<Mobilization?, Mobilization?>.fromHandlers(
            handleError: (error, stackTrace, sink) {
              // Un refus sur un identifiant précis signifie « non lisible » :
              // la mobilisation est exclue, sans faire tomber les autres
              // lectures. Toute autre erreur reste une vraie panne.
              if (error is FirebaseException &&
                  error.code == 'permission-denied') {
                sink.add(null);
                sink.close();
                return;
              }
              sink.addError(error, stackTrace);
            },
          ),
        );
  }

  @override
  Stream<Mobilization?> watchActiveMobilization() {
    return switchLatest(watchPlatformConfig(), (mobilizationId) {
      if (mobilizationId == null) {
        return Stream<Mobilization?>.value(null);
      }
      return _dataSource.watchMobilizationDocument(mobilizationId).map((
        document,
      ) {
        if (document == null) return null;
        final mobilization = _mobilizationFromDocument(document);
        return mobilization.operationId == null &&
                mobilization.status == MobilizationStatus.active
            ? mobilization
            : null;
      });
    });
  }

  Territory _territoryFromDocument(PlatformReadDocument document) {
    final data = _withDates(
      document.data,
      requiredFields: const ['createdAt', 'updatedAt'],
    );
    final territory = Territory.fromMap(data);
    if (territory.id != document.id) {
      throw const FormatException('Territoire incohérent.');
    }
    return territory;
  }

  Mobilization _mobilizationFromDocument(PlatformReadDocument document) {
    final data = _withDates(
      document.data,
      requiredFields: const ['createdAt', 'updatedAt'],
      optionalFields: const ['activatedAt', 'deactivatedAt', 'archivedAt'],
    );
    final mobilization = Mobilization.fromMap(data);
    if (mobilization.id != document.id) {
      throw const FormatException('Mobilisation incohérente.');
    }
    return mobilization;
  }
}

Map<String, Object?> _withDates(
  Map<String, Object?> data, {
  required List<String> requiredFields,
  List<String> optionalFields = const [],
}) {
  final result = Map<String, Object?>.of(data);
  for (final field in requiredFields) {
    result[field] = _dateTime(data[field], field);
  }
  for (final field in optionalFields) {
    final value = data[field];
    if (value != null) result[field] = _dateTime(value, field);
  }
  return result;
}

DateTime _dateTime(Object? value, String field) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  throw FormatException('Date plateforme invalide : $field.');
}
