import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/operation.dart';
import 'operation_read_repository.dart';

class FirestoreOperationReadRepository implements OperationReadRepository {
  const FirestoreOperationReadRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Operation>> watchOperations({Set<OperationStatus>? statuses}) {
    Query<Map<String, dynamic>> query = _firestore.collection('operations');
    final serializedStatuses = statuses
        ?.map((status) => status.serializedValue)
        .toList(growable: false);
    if (serializedStatuses != null && serializedStatuses.isNotEmpty) {
      query = serializedStatuses.length == 1
          ? query.where('status', isEqualTo: serializedStatuses.single)
          : query.where('status', whereIn: serializedStatuses);
    }
    return query.snapshots().map((snapshot) {
      final operations = snapshot.docs
          .map((document) => _fromDocument(document.id, document.data()))
          .toList(growable: false);
      operations.sort((left, right) {
        final byDate = left.startAt.compareTo(right.startAt);
        return byDate != 0 ? byDate : left.name.compareTo(right.name);
      });
      return operations;
    });
  }

  @override
  Stream<Operation?> watchOperation(String operationId) {
    if (operationId.trim().isEmpty || operationId.contains('/')) {
      return Stream<Operation?>.error(
        const FormatException('Identifiant d’opération invalide.'),
      );
    }
    return _firestore.collection('operations').doc(operationId).snapshots().map(
      (snapshot) {
        final data = snapshot.data();
        return !snapshot.exists || data == null
            ? null
            : _fromDocument(snapshot.id, data);
      },
    );
  }

  Operation _fromDocument(String id, Map<String, Object?> raw) {
    final data = Map<String, Object?>.of(raw);
    for (final field in ['startAt', 'createdAt', 'updatedAt']) {
      data[field] = _dateTime(data[field], field);
    }
    if (data['endAt'] != null) {
      data['endAt'] = _dateTime(data['endAt'], 'endAt');
    }
    final operation = Operation.fromMap(data);
    if (operation.id != id) {
      throw const FormatException('Opération incohérente.');
    }
    return operation;
  }

  DateTime _dateTime(Object? value, String field) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    throw FormatException('Date d’opération invalide : $field.');
  }
}
