import 'package:flutter/material.dart';

import '../models/executive_dashboard_snapshot.dart';
import '../models/mobilization.dart';
import '../models/need.dart';
import '../models/operation.dart';
import '../models/territory.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/operation_read_repository.dart';
import '../repositories/platform_administration_read_repository.dart';
import '../repositories/platform_read_repository.dart';
import '../services/current_mobilization_provider.dart';
import '../services/platform_administration_service.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../utils/operation_presentation.dart';
import '../widgets/executive_kpi.dart';
import '../widgets/professional_page_header.dart';
import '../widgets/v5_form_system.dart';
import 'platform_admin_mobilization_screen.dart';
import 'platform_mobilization_form_dialog.dart';
import 'platform_operation_form_dialog.dart';

class PlatformAdminOperationsScreen extends StatefulWidget {
  const PlatformAdminOperationsScreen({
    super.key,
    required this.operationRepository,
    required this.platformRepository,
    required this.mobilizationProvider,
    required this.administrationRepository,
    required this.administrationService,
    this.missionRepository,
  });

  final OperationReadRepository operationRepository;
  final PlatformReadRepository platformRepository;
  final MobilizationContextProvider mobilizationProvider;
  final PlatformAdministrationReadRepository administrationRepository;
  final PlatformAdministrationService administrationService;
  final MultiMobilizationCoordinationReadRepository? missionRepository;

  @override
  State<PlatformAdminOperationsScreen> createState() =>
      _PlatformAdminOperationsScreenState();
}

class _PlatformAdminOperationsScreenState
    extends State<PlatformAdminOperationsScreen> {
  bool _busy = false;
  late Stream<List<CoordinationNeed>> _missionStream;

  @override
  void initState() {
    super.initState();
    _missionStream = _missions();
  }

  @override
  void didUpdateWidget(covariant PlatformAdminOperationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.missionRepository, widget.missionRepository)) {
      _missionStream = _missions();
    }
  }

  Stream<List<CoordinationNeed>> _missions() =>
      widget.missionRepository?.watchAllActiveMissions() ??
      Stream<List<CoordinationNeed>>.value(const []);

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Operation>>(
    stream: widget.operationRepository.watchOperations(),
    builder: (context, operationSnapshot) => StreamBuilder<List<Mobilization>>(
      stream: widget.platformRepository.watchMobilizations(
        includeInactive: true,
      ),
      builder: (context, mobilizationSnapshot) =>
          StreamBuilder<List<CoordinationNeed>>(
            stream: _missionStream,
            builder: (context, missionSnapshot) {
              if (operationSnapshot.hasError ||
                  mobilizationSnapshot.hasError ||
                  missionSnapshot.hasError) {
                return const _OperationsMessage(
                  icon: Icons.cloud_off_outlined,
                  text: 'La situation est momentanément indisponible.',
                );
              }
              if (!operationSnapshot.hasData ||
                  !mobilizationSnapshot.hasData ||
                  !missionSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }
              final operations = operationSnapshot.data!;
              final mobilizations = mobilizationSnapshot.data!;
              final dashboard = ExecutiveDashboardSnapshot(
                operations: operations,
                mobilizations: mobilizations,
                missions: missionSnapshot.data!,
              );
              return CustomScrollView(
                key: const PageStorageKey('platform-admin-operations'),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      V5Spacing.lg,
                      V5Spacing.lg,
                      V5Spacing.lg,
                      V5Spacing.xxxl,
                    ),
                    sliver: SliverList.list(
                      children: [
                        const MobSanteJourneyHeader(
                          journey: MobSanteJourney.administrator,
                        ),
                        const SizedBox(height: V5Spacing.xl),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  'Centre opérationnel',
                                  key: const Key('executive-dashboard-title'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineLarge,
                                ),
                              ),
                            ),
                            const SizedBox(width: V5Spacing.sm),
                            IconButton.filled(
                              key: const Key('create-platform-operation'),
                              tooltip: 'Créer une opération',
                              onPressed:
                                  _busy ||
                                      !widget.administrationService.isAvailable
                                  ? null
                                  : _createOperation,
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ],
                        ),
                        if (_busy) ...[
                          const SizedBox(height: V5Spacing.md),
                          const LinearProgressIndicator(),
                        ],
                        const SizedBox(height: V5Spacing.lg),
                        _ExecutiveStatusHeader(dashboard: dashboard),
                        const SizedBox(height: V5Spacing.lg),
                        _ExecutiveKpiGrid(dashboard: dashboard),
                        const SizedBox(height: V5Spacing.xxl),
                        _ExecutivePriorities(
                          dashboard: dashboard,
                          onOpen: _openOperation,
                        ),
                        const SizedBox(height: V5Spacing.xxl),
                        Text(
                          'Toutes les opérations',
                          key: const Key('all-platform-operations'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: V5Spacing.md),
                        if (operations.isEmpty)
                          const _OperationsEmptyState()
                        else ...[
                          _OperationSection(
                            title: 'En cours',
                            operations: _withStatuses(operations, const {
                              OperationStatus.active,
                              OperationStatus.suspended,
                            }),
                            dashboard: dashboard,
                            onOpen: _openOperation,
                          ),
                          _OperationSection(
                            title: 'À venir',
                            operations: _withStatuses(operations, const {
                              OperationStatus.draft,
                              OperationStatus.planned,
                            }),
                            dashboard: dashboard,
                            onOpen: _openOperation,
                          ),
                          _OperationSection(
                            title: 'Terminées',
                            operations: _withStatuses(operations, const {
                              OperationStatus.completed,
                            }),
                            dashboard: dashboard,
                            onOpen: _openOperation,
                          ),
                          _OperationSection(
                            title: 'Archivées',
                            operations: _withStatuses(operations, const {
                              OperationStatus.archived,
                            }),
                            dashboard: dashboard,
                            onOpen: _openOperation,
                          ),
                        ],
                        _LegacyMobilizations(
                          mobilizations: mobilizations
                              .where((item) => item.operationId == null)
                              .toList(growable: false),
                          onManage: _openMobilizations,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
    ),
  );

  List<Operation> _withStatuses(
    List<Operation> operations,
    Set<OperationStatus> statuses,
  ) => operations
      .where((operation) => statuses.contains(operation.status))
      .toList(growable: false);

  Future<List<Territory>?> _territories() async {
    try {
      return await widget.platformRepository.watchTerritories().first;
    } catch (_) {
      if (mounted) _showMessage('Les territoires ne sont pas disponibles.');
      return null;
    }
  }

  Future<void> _createOperation() async {
    final territories = await _territories();
    if (!mounted || territories == null) return;
    final draft = await showV5Dialog<OperationAdministrationDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PlatformOperationFormDialog(territories: territories),
    );
    if (draft == null || !mounted) return;
    await _run(
      () => widget.administrationService.createOperation(draft),
      'Opération créée.',
    );
  }

  void _openOperation(Operation operation) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => PlatformOperationDetailScreen(
          operationId: operation.id,
          operationRepository: widget.operationRepository,
          platformRepository: widget.platformRepository,
          administrationService: widget.administrationService,
        ),
      ),
    );
  }

  void _openMobilizations() {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: PlatformAdminMobilizationScreen(
              platformRepository: widget.platformRepository,
              mobilizationProvider: widget.mobilizationProvider,
              administrationRepository: widget.administrationRepository,
              administrationService: widget.administrationService,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _showMessage(success);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class PlatformOperationDetailScreen extends StatefulWidget {
  const PlatformOperationDetailScreen({
    super.key,
    required this.operationId,
    required this.operationRepository,
    required this.platformRepository,
    required this.administrationService,
  });

  final String operationId;
  final OperationReadRepository operationRepository;
  final PlatformReadRepository platformRepository;
  final PlatformAdministrationService administrationService;

  @override
  State<PlatformOperationDetailScreen> createState() =>
      _PlatformOperationDetailScreenState();
}

class _PlatformOperationDetailScreenState
    extends State<PlatformOperationDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.v5Colors.canvas,
    appBar: AppBar(title: const Text('Situation de l’opération')),
    body: SafeArea(
      child: StreamBuilder<Operation?>(
        stream: widget.operationRepository.watchOperation(widget.operationId),
        builder: (context, operationSnapshot) =>
            StreamBuilder<List<Mobilization>>(
              stream: widget.platformRepository.watchMobilizations(
                includeInactive: true,
              ),
              builder: (context, mobilizationSnapshot) {
                if (operationSnapshot.hasError ||
                    mobilizationSnapshot.hasError) {
                  return const _OperationsMessage(
                    icon: Icons.cloud_off_outlined,
                    text: 'Cette opération est indisponible.',
                  );
                }
                if (!operationSnapshot.hasData ||
                    !mobilizationSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }
                final operation = operationSnapshot.data;
                if (operation == null) {
                  return const _OperationsMessage(
                    icon: Icons.search_off_rounded,
                    text: 'Opération introuvable.',
                  );
                }
                final mobilizations = mobilizationSnapshot.data!
                    .where((item) => item.operationId == operation.id)
                    .toList(growable: false);
                return ListView(
                  padding: const EdgeInsets.all(V5Spacing.lg),
                  children: [
                    if (_busy) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: V5Spacing.md),
                    ],
                    _OperationDetailHeader(operation: operation),
                    if (operation.context case final contextText?) ...[
                      const SizedBox(height: V5Spacing.md),
                      Text(contextText),
                    ],
                    const SizedBox(height: V5Spacing.lg),
                    Wrap(
                      spacing: V5Spacing.sm,
                      runSpacing: V5Spacing.sm,
                      children: [
                        if (operation.status != OperationStatus.completed &&
                            operation.status != OperationStatus.archived)
                          OutlinedButton.icon(
                            key: const Key('edit-platform-operation'),
                            onPressed: _busy ? null : () => _edit(operation),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Modifier'),
                          ),
                        for (final target in OperationStatus.values)
                          if (operation.status.canTransitionTo(target))
                            FilledButton.tonal(
                              key: Key(
                                'transition-operation-${target.serializedValue}',
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _transition(operation, target),
                              child: Text(operationTransitionLabel(target)),
                            ),
                      ],
                    ),
                    const SizedBox(height: V5Spacing.xxl),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Mobilisations',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (operation.status != OperationStatus.completed &&
                            operation.status != OperationStatus.archived)
                          IconButton(
                            key: const Key('add-operation-mobilization'),
                            tooltip: 'Ajouter une mobilisation',
                            onPressed: _busy
                                ? null
                                : () => _chooseMobilizationAction(
                                    operation,
                                    mobilizationSnapshot.data!,
                                  ),
                            icon: const Icon(Icons.add_rounded),
                          ),
                      ],
                    ),
                    const SizedBox(height: V5Spacing.sm),
                    if (mobilizations.isEmpty)
                      const _CompactEmpty(
                        text: 'Aucune mobilisation rattachée.',
                      )
                    else
                      for (final mobilization in mobilizations)
                        _MobilizationTile(mobilization: mobilization),
                    const SizedBox(height: V5Spacing.md),
                    Text(
                      'Les compteurs de missions ne sont pas exposés à '
                      'l’administration plateforme.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.v5Colors.textSecondary,
                      ),
                    ),
                  ],
                );
              },
            ),
      ),
    ),
  );

  Future<List<Territory>?> _territories() async {
    try {
      return await widget.platformRepository.watchTerritories().first;
    } catch (_) {
      return null;
    }
  }

  Future<void> _edit(Operation operation) async {
    final territories = await _territories();
    if (!mounted || territories == null) return;
    final draft = await showV5Dialog<OperationAdministrationDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PlatformOperationFormDialog(
        territories: territories,
        operation: operation,
      ),
    );
    if (draft == null || !mounted) return;
    await _run(
      () => widget.administrationService.updateOperation(draft),
      'Opération mise à jour.',
    );
  }

  Future<void> _transition(Operation operation, OperationStatus target) async {
    final confirmed = await showV5Confirmation(
      context: context,
      title: '${operationTransitionLabel(target)} l’opération ?',
      message: operation.name,
      confirmLabel: operationTransitionLabel(target),
      destructive: target == OperationStatus.archived,
      barrierDismissible: false,
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => widget.administrationService.transitionOperation(
        operation.id,
        target,
      ),
      'Statut mis à jour.',
    );
  }

  Future<void> _chooseMobilizationAction(
    Operation operation,
    List<Mobilization> allMobilizations,
  ) async {
    final action = await showV5Dialog<String>(
      context: context,
      builder: (dialogContext) => V5Dialog(
        title: 'Ajouter une mobilisation',
        message: operation.name,
        actions: [
          V5DialogAction(
            label: 'Annuler',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          V5DialogAction(
            key: const Key('attach-existing-mobilization'),
            label: 'Rattacher une existante',
            onPressed: () => Navigator.of(dialogContext).pop('attach'),
          ),
          V5DialogAction(
            key: const Key('create-operation-mobilization'),
            label: 'Créer',
            style: V5DialogActionStyle.primary,
            onPressed: () => Navigator.of(dialogContext).pop('create'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'create') {
      await _createMobilization(operation);
    } else {
      await _attachMobilization(operation, allMobilizations);
    }
  }

  Future<void> _createMobilization(Operation operation) async {
    final territories = await _territories();
    if (!mounted || territories == null) return;
    final draft = await showV5Dialog<MobilizationAdministrationDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PlatformMobilizationFormDialog(
        territories: territories,
        operationId: operation.id,
      ),
    );
    if (draft == null || !mounted) return;
    await _run(
      () => widget.administrationService.createMobilization(draft),
      'Mobilisation créée.',
    );
  }

  Future<void> _attachMobilization(
    Operation operation,
    List<Mobilization> allMobilizations,
  ) async {
    final candidates = allMobilizations
        .where(
          (item) =>
              item.operationId == null &&
              item.status != MobilizationStatus.active &&
              item.status != MobilizationStatus.archived,
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      _message('Aucune mobilisation disponible à rattacher.');
      return;
    }
    String? selectedId;
    final selected = await showV5Dialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => V5Dialog(
          title: 'Rattacher une mobilisation',
          content: V5SelectField<String>(
            key: const Key('existing-mobilization-select'),
            label: 'Mobilisation',
            value: selectedId,
            options: candidates
                .map((item) => V5SelectOption(value: item.id, label: item.name))
                .toList(growable: false),
            onChanged: (value) => setDialogState(() => selectedId = value),
          ),
          actions: [
            V5DialogAction(
              label: 'Annuler',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            V5DialogAction(
              label: 'Rattacher',
              style: V5DialogActionStyle.primary,
              onPressed: selectedId == null
                  ? null
                  : () => Navigator.of(dialogContext).pop(selectedId),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    final mobilization = candidates.firstWhere((item) => item.id == selected);
    await _run(
      () => widget.administrationService.updateMobilization(
        MobilizationAdministrationDraft(
          mobilizationId: mobilization.id,
          territoryId: mobilization.territoryId,
          name: mobilization.name,
          subtitle: mobilization.subtitle,
          contextType: mobilization.contextType,
          operationId: operation.id,
          scopeRefs: mobilization.scopeRefs,
        ),
      ),
      'Mobilisation rattachée.',
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _message(success);
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _ExecutiveStatusHeader extends StatelessWidget {
  const _ExecutiveStatusHeader({required this.dashboard});

  final ExecutiveDashboardSnapshot dashboard;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final (icon, label, foreground, background) = switch (dashboard.state) {
      ExecutivePlatformState.calm => (
        Icons.circle_outlined,
        'Plateforme en attente',
        colors.info,
        colors.infoContainer,
      ),
      ExecutivePlatformState.stable => (
        Icons.check_circle_rounded,
        'Plateforme stable',
        colors.success,
        colors.successContainer,
      ),
      ExecutivePlatformState.watch => (
        Icons.error_rounded,
        'Vigilance opérationnelle',
        colors.warning,
        colors.warningContainer,
      ),
      ExecutivePlatformState.critical => (
        Icons.warning_rounded,
        'Plateforme sous tension',
        colors.danger,
        colors.dangerContainer,
      ),
    };
    final updatedAt = dashboard.lastUpdated;
    final time = updatedAt == null
        ? '—'
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(updatedAt.toLocal()),
            alwaysUse24HourFormat: true,
          );
    return Semantics(
      key: const Key('executive-platform-state'),
      container: true,
      label: '$label. Dernière actualisation $time.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(V5Spacing.lg),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(V5Radius.large),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 32),
              const SizedBox(width: V5Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(color: foreground),
                    ),
                    const SizedBox(height: V5Spacing.xxs),
                    Text(
                      'Actualisé à $time',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExecutiveKpiGrid extends StatelessWidget {
  const _ExecutiveKpiGrid({required this.dashboard});

  final ExecutiveDashboardSnapshot dashboard;

  @override
  Widget build(BuildContext context) {
    final coverage = dashboard.coverage;
    final coveragePercent = coverage == null ? null : (coverage * 100).round();
    final coverageTone = coverage == null
        ? ExecutiveKpiTone.neutral
        : coverage >= .8
        ? ExecutiveKpiTone.success
        : coverage >= .5
        ? ExecutiveKpiTone.warning
        : ExecutiveKpiTone.critical;
    final items = <Widget>[
      OperationKpi(
        key: const Key('executive-kpi-operations'),
        count: dashboard.activeOperationCount,
      ),
      ExecutiveKpi(
        key: const Key('executive-kpi-mobilizations'),
        value: '${dashboard.activeMobilizationCount}',
        label: 'mobilisations actives',
      ),
      ExecutiveKpi(
        key: const Key('executive-kpi-missions'),
        value: '${dashboard.activeMissionCount}',
        label: 'missions actives',
      ),
      CriticalKpi(
        key: const Key('executive-kpi-critical'),
        count: dashboard.criticalMissionCount,
      ),
      ProfessionKpi(
        key: const Key('executive-kpi-professionals'),
        count: dashboard.mobilizedProfessionalCount,
      ),
      CoverageKpi(
        key: const Key('executive-kpi-coverage'),
        percent: coveragePercent,
        label: dashboard.establishmentCount == 0
            ? 'couverture globale'
            : 'couverture · ${dashboard.establishmentCount} site${dashboard.establishmentCount > 1 ? 's' : ''}',
        semanticLabel:
            '${coveragePercent == null ? 'Couverture indisponible' : 'Couverture globale $coveragePercent pour cent'}, '
            '${dashboard.establishmentCount} établissement${dashboard.establishmentCount > 1 ? 's' : ''} concerné${dashboard.establishmentCount > 1 ? 's' : ''}',
        tone: coverageTone,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 350 ? 3 : 2;
        final itemWidth =
            (constraints.maxWidth - V5Spacing.sm * (columns - 1)) / columns;
        return Wrap(
          key: const Key('executive-kpi-grid'),
          spacing: V5Spacing.sm,
          runSpacing: V5Spacing.sm,
          children: [
            for (final item in items) SizedBox(width: itemWidth, child: item),
          ],
        );
      },
    );
  }
}

class _ExecutivePriorities extends StatelessWidget {
  const _ExecutivePriorities({required this.dashboard, required this.onOpen});

  final ExecutiveDashboardSnapshot dashboard;
  final ValueChanged<Operation> onOpen;

  @override
  Widget build(BuildContext context) {
    final priorities = dashboard.priorityOperations;
    return Column(
      key: const Key('executive-priorities'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions prioritaires',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: V5Spacing.md),
        if (priorities.isEmpty)
          const _CompactEmpty(text: 'Aucune action prioritaire.')
        else
          for (final priority in priorities)
            _PriorityCard(snapshot: priority, onOpen: onOpen),
      ],
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.snapshot, required this.onOpen});

  final OperationExecutiveSnapshot snapshot;
  final ValueChanged<Operation> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final critical = snapshot.criticalMissionCount;
    final isPlanned = {
      OperationStatus.draft,
      OperationStatus.planned,
    }.contains(snapshot.operation.status);
    final hasCoverageRisk = snapshot.coverage != null && snapshot.coverage! < 1;
    final (icon, foreground, background, detail) = critical > 0
        ? (
            Icons.warning_rounded,
            colors.danger,
            colors.dangerContainer,
            '$critical mission${critical > 1 ? 's' : ''} critique${critical > 1 ? 's' : ''}',
          )
        : hasCoverageRisk
        ? (
            Icons.error_rounded,
            colors.warning,
            colors.warningContainer,
            '${snapshot.establishmentCount} établissement${snapshot.establishmentCount > 1 ? 's' : ''} à surveiller',
          )
        : isPlanned
        ? (
            Icons.event_available_rounded,
            colors.info,
            colors.infoContainer,
            'Préparation à confirmer',
          )
        : (
            Icons.check_circle_rounded,
            colors.success,
            colors.successContainer,
            snapshot.missionCount == 0
                ? 'Aucune mission active'
                : 'Situation maîtrisée',
          );
    final action = isPlanned ? 'Préparer' : 'Traiter';
    return Padding(
      padding: const EdgeInsets.only(bottom: V5Spacing.sm),
      child: Semantics(
        button: true,
        label: '${snapshot.operation.name}. $detail. $action.',
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(V5Radius.card),
          child: InkWell(
            key: Key('executive-priority-${snapshot.operation.id}'),
            borderRadius: BorderRadius.circular(V5Radius.card),
            onTap: () => onOpen(snapshot.operation),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final title = Text(
                  snapshot.operation.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                );
                final actionLabel = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: V5Spacing.xxs),
                    Icon(Icons.chevron_right_rounded, color: foreground),
                  ],
                );
                return Padding(
                  padding: const EdgeInsets.all(V5Spacing.md),
                  child: stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, color: foreground, size: 26),
                                const SizedBox(width: V5Spacing.md),
                                Expanded(child: title),
                              ],
                            ),
                            const SizedBox(height: V5Spacing.sm),
                            Text(detail),
                            const SizedBox(height: V5Spacing.sm),
                            actionLabel,
                          ],
                        )
                      : Row(
                          children: [
                            Icon(icon, color: foreground, size: 26),
                            const SizedBox(width: V5Spacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  title,
                                  const SizedBox(height: V5Spacing.xxs),
                                  Text(detail),
                                ],
                              ),
                            ),
                            const SizedBox(width: V5Spacing.sm),
                            actionLabel,
                          ],
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _OperationSection extends StatelessWidget {
  const _OperationSection({
    required this.title,
    required this.operations,
    required this.dashboard,
    required this.onOpen,
  });
  final String title;
  final List<Operation> operations;
  final ExecutiveDashboardSnapshot dashboard;
  final ValueChanged<Operation> onOpen;

  @override
  Widget build(BuildContext context) {
    if (operations.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: V5Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: V5Spacing.sm),
          for (final operation in operations)
            _OperationCard(
              snapshot: dashboard.snapshotFor(operation),
              onTap: () => onOpen(operation),
            ),
        ],
      ),
    );
  }
}

class _OperationCard extends StatelessWidget {
  const _OperationCard({required this.snapshot, required this.onTap});
  final OperationExecutiveSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final operation = snapshot.operation;
    final localizations = MaterialLocalizations.of(context);
    final period = operation.endAt == null
        ? 'Depuis le ${localizations.formatMediumDate(operation.startAt)}'
        : '${localizations.formatMediumDate(operation.startAt)} – '
              '${localizations.formatMediumDate(operation.endAt!)}';
    final coverage = snapshot.coverage;
    final coverageLabel = coverage == null
        ? '—'
        : '${(coverage * 100).round()} %';
    return Padding(
      padding: const EdgeInsets.only(bottom: V5Spacing.sm),
      child: Material(
        color: context.v5Colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
        child: InkWell(
          key: Key('platform-operation-${operation.id}'),
          borderRadius: BorderRadius.circular(V5Radius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(V5Spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        operation.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: V5Spacing.sm),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.v5Colors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: V5Spacing.xxs),
                Text(
                  '${operationTypeLabel(operation.type)} · '
                  '${operationStatusLabel(operation.status)} · $period',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.v5Colors.textSecondary,
                  ),
                ),
                const SizedBox(height: V5Spacing.md),
                Wrap(
                  spacing: V5Spacing.lg,
                  runSpacing: V5Spacing.xs,
                  children: [
                    _OperationInlineMetric(
                      value: '${snapshot.missionCount}',
                      label: 'missions',
                    ),
                    _OperationInlineMetric(
                      value: '${snapshot.criticalMissionCount}',
                      label: 'critiques',
                      critical: snapshot.criticalMissionCount > 0,
                    ),
                    _OperationInlineMetric(
                      value: coverageLabel,
                      label: 'couverture',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OperationInlineMetric extends StatelessWidget {
  const _OperationInlineMetric({
    required this.value,
    required this.label,
    this.critical = false,
  });

  final String value;
  final String label;
  final bool critical;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $label',
    child: ExcludeSemantics(
      child: Wrap(
        spacing: V5Spacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: critical ? context.v5Colors.danger : null,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.v5Colors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _OperationDetailHeader extends StatelessWidget {
  const _OperationDetailHeader({required this.operation});
  final Operation operation;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(operation.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: V5Spacing.xs),
        Text(
          '${operationTypeLabel(operation.type)} · ${operationStatusLabel(operation.status)}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.v5Colors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _MobilizationTile extends StatelessWidget {
  const _MobilizationTile({required this.mobilization});
  final Mobilization mobilization;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(mobilization.name),
      subtitle: Text(
        '${mobilization.subtitle} · ${mobilization.status.serializedValue}',
      ),
    ),
  );
}

class _LegacyMobilizations extends StatelessWidget {
  const _LegacyMobilizations({
    required this.mobilizations,
    required this.onManage,
  });
  final List<Mobilization> mobilizations;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    if (mobilizations.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('legacy-mobilizations'),
      margin: const EdgeInsets.only(top: V5Spacing.xl),
      decoration: BoxDecoration(
        color: context.v5Colors.surfaceMuted,
        borderRadius: BorderRadius.circular(V5Radius.section),
      ),
      child: Padding(
        padding: const EdgeInsets.all(V5Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mobilisations historiques',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.v5Colors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: V5Spacing.xs),
            Text(
              '${mobilizations.length} mobilisation${mobilizations.length > 1 ? 's' : ''} sans opération',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.v5Colors.textSecondary,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onManage,
                child: const Text('Consulter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationsEmptyState extends StatelessWidget {
  const _OperationsEmptyState();
  @override
  Widget build(BuildContext context) => const _CompactEmpty(
    text:
        'Aucune opération. Créez un cadre avant d’y rattacher des mobilisations.',
  );
}

class _CompactEmpty extends StatelessWidget {
  const _CompactEmpty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(V5Spacing.lg),
    decoration: BoxDecoration(
      color: context.v5Colors.surfaceMuted,
      borderRadius: BorderRadius.circular(V5Radius.card),
    ),
    child: Text(text),
  );
}

class _OperationsMessage extends StatelessWidget {
  const _OperationsMessage({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(V5Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(height: V5Spacing.sm),
          Text(text),
        ],
      ),
    ),
  );
}
