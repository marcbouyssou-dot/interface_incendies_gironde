import '../models/operation.dart';

abstract interface class OperationReadRepository {
  Stream<List<Operation>> watchOperations({Set<OperationStatus>? statuses});

  Stream<Operation?> watchOperation(String operationId);
}
