import '../models/executive_dashboard_snapshot.dart';
import '../models/mobilization.dart';
import '../models/operation.dart';
import 'platform_actor_view_data.dart';

enum PlatformAdminCommandActionKind {
  criticalNeeds,
  missingResponsible,
  insufficientCoverage,
  missingCoordinator,
  incompleteMobilization,
  unfinishedDraft,
}

enum PlatformAdminCommandActionLevel { critical, attention, preparation }

class PlatformAdminCommandAction {
  const PlatformAdminCommandAction({
    required this.kind,
    required this.level,
    required this.priority,
    required this.operation,
    required this.title,
    required this.detail,
  });

  final PlatformAdminCommandActionKind kind;
  final PlatformAdminCommandActionLevel level;
  final int priority;
  final Operation operation;
  final String title;
  final String detail;

  String get id => '${kind.name}-${operation.id}';
}

class PlatformAdminCommandContext {
  const PlatformAdminCommandContext({
    required this.snapshot,
    required this.actorDirectory,
  });

  final OperationExecutiveSnapshot snapshot;
  final PlatformActorDirectoryViewData? actorDirectory;
}

abstract interface class PlatformAdminCommandRule {
  const PlatformAdminCommandRule();

  PlatformAdminCommandAction? evaluate(PlatformAdminCommandContext context);
}

class PlatformAdminCommandEngine {
  const PlatformAdminCommandEngine({
    this.rules = const [
      CriticalNeedsCommandRule(),
      MissingResponsibleCommandRule(),
      InsufficientCoverageCommandRule(),
      MissingCoordinatorCommandRule(),
      IncompleteMobilizationCommandRule(),
      UnfinishedDraftCommandRule(),
    ],
  });

  final List<PlatformAdminCommandRule> rules;

  List<PlatformAdminCommandAction> evaluate(
    ExecutiveDashboardSnapshot dashboard, {
    PlatformActorDirectoryViewData? actorDirectory,
  }) {
    final actions = <PlatformAdminCommandAction>[];
    for (final snapshot in dashboard.operationSnapshots) {
      final context = PlatformAdminCommandContext(
        snapshot: snapshot,
        actorDirectory: actorDirectory,
      );
      for (final rule in rules) {
        final action = rule.evaluate(context);
        if (action != null) actions.add(action);
      }
    }
    actions.sort(_compareActions);
    return List.unmodifiable(actions);
  }

  static int _compareActions(
    PlatformAdminCommandAction left,
    PlatformAdminCommandAction right,
  ) {
    final byPriority = right.priority.compareTo(left.priority);
    if (byPriority != 0) return byPriority;
    final byStatus = _statusPriority(
      right.operation.status,
    ).compareTo(_statusPriority(left.operation.status));
    if (byStatus != 0) return byStatus;
    final byStart = left.operation.startAt.compareTo(right.operation.startAt);
    if (byStart != 0) return byStart;
    return left.operation.name.compareTo(right.operation.name);
  }

  static int _statusPriority(OperationStatus status) => switch (status) {
    OperationStatus.active => 4,
    OperationStatus.suspended => 3,
    OperationStatus.planned => 2,
    OperationStatus.draft => 1,
    OperationStatus.completed || OperationStatus.archived => 0,
  };
}

class CriticalNeedsCommandRule implements PlatformAdminCommandRule {
  const CriticalNeedsCommandRule();

  @override
  PlatformAdminCommandAction? evaluate(PlatformAdminCommandContext context) {
    final snapshot = context.snapshot;
    final count = snapshot.criticalMissionCount;
    if (!_isOperational(snapshot.operation.status) || count == 0) return null;
    return PlatformAdminCommandAction(
      kind: PlatformAdminCommandActionKind.criticalNeeds,
      level: PlatformAdminCommandActionLevel.critical,
      priority: 600,
      operation: snapshot.operation,
      title: 'Traiter les besoins critiques',
      detail:
          '$count mission${count > 1 ? 's' : ''} critique${count > 1 ? 's' : ''} nécessite${count > 1 ? 'nt' : ''} une décision.',
    );
  }
}

class MissingResponsibleCommandRule implements PlatformAdminCommandRule {
  const MissingResponsibleCommandRule();

  @override
  PlatformAdminCommandAction? evaluate(PlatformAdminCommandContext context) {
    final snapshot = context.snapshot;
    final directory = context.actorDirectory;
    if (!_isOperational(snapshot.operation.status) || directory == null) {
      return null;
    }
    final locationIds = snapshot.missions
        .map((mission) => mission.locationId)
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    if (locationIds.isEmpty) return null;
    final coveredLocationIds = directory.managers
        .where((manager) => manager.active)
        .expand((manager) => manager.locations)
        .map((location) => location.id)
        .toSet();
    final missingCount = locationIds.difference(coveredLocationIds).length;
    if (missingCount == 0) return null;
    return PlatformAdminCommandAction(
      kind: PlatformAdminCommandActionKind.missingResponsible,
      level: PlatformAdminCommandActionLevel.critical,
      priority: 500,
      operation: snapshot.operation,
      title: 'Nommer un responsable',
      detail:
          '$missingCount établissement${missingCount > 1 ? 's' : ''} actif${missingCount > 1 ? 's' : ''} sans responsable.',
    );
  }
}

class InsufficientCoverageCommandRule implements PlatformAdminCommandRule {
  const InsufficientCoverageCommandRule();

  @override
  PlatformAdminCommandAction? evaluate(PlatformAdminCommandContext context) {
    final snapshot = context.snapshot;
    final coverage = snapshot.coverage;
    if (!_isOperational(snapshot.operation.status) ||
        snapshot.criticalMissionCount > 0 ||
        coverage == null ||
        coverage >= 1) {
      return null;
    }
    final remaining =
        snapshot.requiredProfessionalCount -
        snapshot.mobilizedProfessionalCount;
    return PlatformAdminCommandAction(
      kind: PlatformAdminCommandActionKind.insufficientCoverage,
      level: PlatformAdminCommandActionLevel.attention,
      priority: 400,
      operation: snapshot.operation,
      title: 'Renforcer la couverture',
      detail:
          '${(coverage * 100).round()} % couverts · $remaining renfort${remaining > 1 ? 's' : ''} restant${remaining > 1 ? 's' : ''}.',
    );
  }
}

class MissingCoordinatorCommandRule implements PlatformAdminCommandRule {
  const MissingCoordinatorCommandRule();

  @override
  PlatformAdminCommandAction? evaluate(PlatformAdminCommandContext context) {
    final operation = context.snapshot.operation;
    if (!_isOperational(operation.status) || operation.coordinatorUid != null) {
      return null;
    }
    return PlatformAdminCommandAction(
      kind: PlatformAdminCommandActionKind.missingCoordinator,
      level: PlatformAdminCommandActionLevel.attention,
      priority: 300,
      operation: operation,
      title: 'Nommer le coordinateur',
      detail: 'Aucun coordinateur principal n’est affecté à l’opération.',
    );
  }
}

class IncompleteMobilizationCommandRule implements PlatformAdminCommandRule {
  const IncompleteMobilizationCommandRule();

  @override
  PlatformAdminCommandAction? evaluate(PlatformAdminCommandContext context) {
    final snapshot = context.snapshot;
    final status = snapshot.operation.status;
    if (!_isOperational(status)) return null;
    final mobilizations = snapshot.mobilizations;
    final usableMobilizations = mobilizations
        .where(
          (mobilization) => mobilization.status != MobilizationStatus.archived,
        )
        .toList(growable: false);
    final incompleteCount = status == OperationStatus.active
        ? usableMobilizations
              .where(
                (mobilization) =>
                    mobilization.status != MobilizationStatus.active,
              )
              .length
        : 0;
    if (usableMobilizations.isNotEmpty && incompleteCount == 0) return null;
    final detail = usableMobilizations.isEmpty
        ? 'Aucune mobilisation exploitable n’est rattachée à l’opération.'
        : '$incompleteCount mobilisation${incompleteCount > 1 ? 's' : ''} reste${incompleteCount > 1 ? 'nt' : ''} à activer.';
    return PlatformAdminCommandAction(
      kind: PlatformAdminCommandActionKind.incompleteMobilization,
      level: PlatformAdminCommandActionLevel.preparation,
      priority: 200,
      operation: snapshot.operation,
      title: 'Compléter la mobilisation',
      detail: detail,
    );
  }
}

class UnfinishedDraftCommandRule implements PlatformAdminCommandRule {
  const UnfinishedDraftCommandRule();

  @override
  PlatformAdminCommandAction? evaluate(PlatformAdminCommandContext context) {
    final operation = context.snapshot.operation;
    if (operation.status != OperationStatus.draft) return null;
    return PlatformAdminCommandAction(
      kind: PlatformAdminCommandActionKind.unfinishedDraft,
      level: PlatformAdminCommandActionLevel.preparation,
      priority: 100,
      operation: operation,
      title: 'Finaliser le brouillon',
      detail: 'Le brouillon doit être planifié ou archivé.',
    );
  }
}

bool _isOperational(OperationStatus status) => {
  OperationStatus.active,
  OperationStatus.suspended,
  OperationStatus.planned,
}.contains(status);
