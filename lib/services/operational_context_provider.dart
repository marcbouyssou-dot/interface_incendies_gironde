import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import '../models/operation.dart';
import '../utils/switch_latest.dart';

class OperationalMissionContext {
  const OperationalMissionContext({
    required this.mobilizationId,
    required this.mobilizationName,
    this.operationId,
    this.operationName,
    this.operationType,
  });

  final String mobilizationId;
  final String mobilizationName;
  final String? operationId;
  final String? operationName;
  final OperationType? operationType;

  bool get isLegacy => operationId == null;
}

abstract interface class OperationalContextProvider {
  Stream<OperationalMissionContext?> watchForMobilization(
    String mobilizationId,
  );
}

abstract interface class OperationalContextDataSource {
  Stream<Map<String, Object?>?> watchMobilization(String mobilizationId);

  Stream<Map<String, Object?>?> watchOperation(String operationId);
}

class FirestoreOperationalContextDataSource
    implements OperationalContextDataSource {
  const FirestoreOperationalContextDataSource(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Stream<Map<String, Object?>?> watchMobilization(String mobilizationId) =>
      firestore
          .collection('mobilizations')
          .doc(mobilizationId)
          .snapshots()
          .map((snapshot) => snapshot.data());

  @override
  Stream<Map<String, Object?>?> watchOperation(String operationId) => firestore
      .collection('operations')
      .doc(operationId)
      .snapshots()
      .map((snapshot) => snapshot.data());
}

class DefaultOperationalContextProvider implements OperationalContextProvider {
  const DefaultOperationalContextProvider(this.dataSource);

  final OperationalContextDataSource dataSource;

  @override
  Stream<OperationalMissionContext?> watchForMobilization(
    String mobilizationId,
  ) {
    if (mobilizationId.trim().isEmpty || mobilizationId.contains('/')) {
      return Stream<OperationalMissionContext?>.value(null);
    }
    return switchLatest(dataSource.watchMobilization(mobilizationId), (
      mobilization,
    ) {
      if (mobilization == null) {
        return Stream<OperationalMissionContext?>.value(null);
      }
      final name = mobilization['name'];
      if (name is! String || name.trim().isEmpty) {
        return Stream<OperationalMissionContext?>.error(
          const FormatException('Mobilisation invalide.'),
        );
      }
      final operationId = mobilization['operationId'];
      if (operationId == null) {
        return Stream<OperationalMissionContext?>.value(
          OperationalMissionContext(
            mobilizationId: mobilizationId,
            mobilizationName: name,
          ),
        );
      }
      if (operationId is! String ||
          operationId.trim().isEmpty ||
          operationId.contains('/')) {
        return Stream<OperationalMissionContext?>.error(
          const FormatException('Contexte d’opération invalide.'),
        );
      }
      return dataSource.watchOperation(operationId).map((operation) {
        if (operation == null) return null;
        final operationName = operation['name'];
        if (operationName is! String || operationName.trim().isEmpty) {
          throw const FormatException('Opération invalide.');
        }
        return OperationalMissionContext(
          mobilizationId: mobilizationId,
          mobilizationName: name,
          operationId: operationId,
          operationName: operationName,
          operationType: operationTypeFromValue(operation['type']),
        );
      });
    });
  }
}

class OperationalContextScope extends InheritedWidget {
  const OperationalContextScope({
    super.key,
    required this.provider,
    required super.child,
  });

  final OperationalContextProvider provider;

  static OperationalContextProvider? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<OperationalContextScope>()
      ?.provider;

  @override
  bool updateShouldNotify(OperationalContextScope oldWidget) =>
      !identical(provider, oldWidget.provider);
}
