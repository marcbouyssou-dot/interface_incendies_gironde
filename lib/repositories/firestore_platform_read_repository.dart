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

class PlatformReadDocument {
  const PlatformReadDocument({required this.id, required this.data});

  final String id;
  final Map<String, Object?> data;
}

class FirestorePlatformReadDataSource implements PlatformReadDataSource {
  const FirestorePlatformReadDataSource(this.firestore);

  final FirebaseFirestore firestore;

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

class FirestorePlatformReadRepository implements PlatformReadRepository {
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
        return mobilization.status == MobilizationStatus.active
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
