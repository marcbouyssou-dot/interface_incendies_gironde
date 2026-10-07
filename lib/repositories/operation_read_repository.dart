import '../models/operation.dart';

abstract interface class OperationReadRepository {
  Stream<List<Operation>> watchOperations({Set<OperationStatus>? statuses});

  Stream<Operation?> watchOperation(String operationId);
}

/// Requête serveur bornée à l'organisation avant lecture des documents.
abstract interface class OrganizationOperationReadRepository {
  Stream<List<Operation>> watchOperationsForOrganization(
    String organizationId, {
    Set<OperationStatus>? statuses,
  });
}
