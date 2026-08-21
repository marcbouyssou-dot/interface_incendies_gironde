import '../models/operation.dart';

String operationTypeLabel(OperationType type) => switch (type) {
  OperationType.emergency => 'Urgence',
  OperationType.healthCrisis => 'Crise sanitaire',
  OperationType.naturalDisaster => 'Catastrophe naturelle',
  OperationType.event => 'Événement',
  OperationType.prevention => 'Prévention',
  OperationType.exercise => 'Exercice',
  OperationType.humanitarian => 'Humanitaire',
  OperationType.other => 'Autre',
};

String operationStatusLabel(OperationStatus status) => switch (status) {
  OperationStatus.draft => 'Brouillon',
  OperationStatus.planned => 'Planifiée',
  OperationStatus.active => 'En cours',
  OperationStatus.suspended => 'Suspendue',
  OperationStatus.completed => 'Terminée',
  OperationStatus.archived => 'Archivée',
};

String operationTransitionLabel(OperationStatus target) => switch (target) {
  OperationStatus.planned => 'Planifier',
  OperationStatus.active => 'Activer',
  OperationStatus.suspended => 'Suspendre',
  OperationStatus.completed => 'Clôturer',
  OperationStatus.archived => 'Archiver',
  OperationStatus.draft => 'Revenir au brouillon',
};
