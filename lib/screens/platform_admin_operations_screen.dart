import 'package:flutter/material.dart';

import '../models/mobilization.dart';
import '../models/operation.dart';
import '../models/territory.dart';
import '../repositories/operation_read_repository.dart';
import '../repositories/platform_administration_read_repository.dart';
import '../repositories/platform_read_repository.dart';
import '../services/current_mobilization_provider.dart';
import '../services/platform_administration_service.dart';
import '../theme/platform_admin_identity.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../utils/operation_presentation.dart';
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
  });

  final OperationReadRepository operationRepository;
  final PlatformReadRepository platformRepository;
  final MobilizationContextProvider mobilizationProvider;
  final PlatformAdministrationReadRepository administrationRepository;
  final PlatformAdministrationService administrationService;

  @override
  State<PlatformAdminOperationsScreen> createState() =>
      _PlatformAdminOperationsScreenState();
}

class _PlatformAdminOperationsScreenState
    extends State<PlatformAdminOperationsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Operation>>(
    stream: widget.operationRepository.watchOperations(),
    builder: (context, operationSnapshot) => StreamBuilder<List<Mobilization>>(
      stream: widget.platformRepository.watchMobilizations(
        includeInactive: true,
      ),
      builder: (context, mobilizationSnapshot) {
        if (operationSnapshot.hasError || mobilizationSnapshot.hasError) {
          return const _OperationsMessage(
            icon: Icons.cloud_off_outlined,
            text: 'Les opérations sont momentanément indisponibles.',
          );
        }
        if (!operationSnapshot.hasData || !mobilizationSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        final operations = operationSnapshot.data!;
        final mobilizations = mobilizationSnapshot.data!;
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
                  const SizedBox(height: V5Spacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Opérations',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: V5Spacing.xxs),
                            Text(
                              'Piloter plusieurs mobilisations en parallèle.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: context.v5Colors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: V5Spacing.sm),
                      IconButton.filled(
                        key: const Key('create-platform-operation'),
                        tooltip: 'Créer une opération',
                        onPressed:
                            _busy || !widget.administrationService.isAvailable
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
                  const SizedBox(height: V5Spacing.xl),
                  _OperationsSummary(
                    operations: operations,
                    mobilizations: mobilizations,
                  ),
                  const SizedBox(height: V5Spacing.xl),
                  if (operations.isEmpty)
                    const _OperationsEmptyState()
                  else ...[
                    _OperationSection(
                      title: 'En cours',
                      operations: _withStatuses(operations, const {
                        OperationStatus.active,
                        OperationStatus.suspended,
                      }),
                      mobilizations: mobilizations,
                      onOpen: _openOperation,
                    ),
                    _OperationSection(
                      title: 'À venir',
                      operations: _withStatuses(operations, const {
                        OperationStatus.draft,
                        OperationStatus.planned,
                      }),
                      mobilizations: mobilizations,
                      onOpen: _openOperation,
                    ),
                    _OperationSection(
                      title: 'Terminées',
                      operations: _withStatuses(operations, const {
                        OperationStatus.completed,
                      }),
                      mobilizations: mobilizations,
                      onOpen: _openOperation,
                    ),
                    _OperationSection(
                      title: 'Archivées',
                      operations: _withStatuses(operations, const {
                        OperationStatus.archived,
                      }),
                      mobilizations: mobilizations,
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

class _OperationsSummary extends StatelessWidget {
  const _OperationsSummary({
    required this.operations,
    required this.mobilizations,
  });

  final List<Operation> operations;
  final List<Mobilization> mobilizations;

  @override
  Widget build(BuildContext context) {
    final activeOperations = operations
        .where((item) => item.status == OperationStatus.active)
        .length;
    final activeMobilizations = mobilizations
        .where((item) => item.status == MobilizationStatus.active)
        .length;
    return Semantics(
      container: true,
      label:
          '$activeOperations opérations en cours, $activeMobilizations mobilisations actives',
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              value: '$activeOperations',
              label: 'opérations en cours',
            ),
          ),
          const SizedBox(width: V5Spacing.sm),
          Expanded(
            child: _Metric(
              value: '$activeMobilizations',
              label: 'mobilisations actives',
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(V5Spacing.md),
    decoration: BoxDecoration(
      color: PlatformAdminIdentity.container(context),
      borderRadius: BorderRadius.circular(V5Radius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _OperationSection extends StatelessWidget {
  const _OperationSection({
    required this.title,
    required this.operations,
    required this.mobilizations,
    required this.onOpen,
  });
  final String title;
  final List<Operation> operations;
  final List<Mobilization> mobilizations;
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
              operation: operation,
              mobilizationCount: mobilizations
                  .where((item) => item.operationId == operation.id)
                  .length,
              onTap: () => onOpen(operation),
            ),
        ],
      ),
    );
  }
}

class _OperationCard extends StatelessWidget {
  const _OperationCard({
    required this.operation,
    required this.mobilizationCount,
    required this.onTap,
  });
  final Operation operation;
  final int mobilizationCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final period = operation.endAt == null
        ? 'Depuis le ${localizations.formatMediumDate(operation.startAt)}'
        : '${localizations.formatMediumDate(operation.startAt)} – '
              '${localizations.formatMediumDate(operation.endAt!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: V5Spacing.sm),
      child: Card(
        child: ListTile(
          key: Key('platform-operation-${operation.id}'),
          minVerticalPadding: V5Spacing.md,
          onTap: onTap,
          title: Text(operation.name),
          subtitle: Text(
            '${operationTypeLabel(operation.type)} · '
            '${operationStatusLabel(operation.status)}\n'
            '$period · $mobilizationCount mobilisation${mobilizationCount > 1 ? 's' : ''}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(V5Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mobilisations historiques',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: V5Spacing.xs),
            Text(
              '${mobilizations.length} mobilisation${mobilizations.length > 1 ? 's' : ''} sans opération. Aucune migration requise.',
            ),
            const SizedBox(height: V5Spacing.sm),
            TextButton(onPressed: onManage, child: const Text('Gérer')),
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
