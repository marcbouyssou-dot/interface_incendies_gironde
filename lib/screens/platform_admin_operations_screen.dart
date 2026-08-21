import 'package:flutter/material.dart';

import '../models/executive_dashboard_snapshot.dart';
import '../models/mobilization.dart';
import '../models/need.dart';
import '../models/operation.dart';
import '../models/operational_scope.dart';
import '../models/platform_administrator_access.dart';
import '../models/territory.dart';
import '../perspective/cross_role_perspective.dart';
import '../platform_admin/operation_coordinator_view_data.dart';
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
import '../widgets/native_interactions.dart';
import '../widgets/professional_page_header.dart';
import '../widgets/perspective_switcher.dart';
import '../widgets/v5_controls.dart';
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
    this.locationStream,
    this.operationCoordinatorDataSource =
        const NoOperationCoordinatorViewDataSource(),
    this.referenceTime,
  });

  final OperationReadRepository operationRepository;
  final PlatformReadRepository platformRepository;
  final MobilizationContextProvider mobilizationProvider;
  final PlatformAdministrationReadRepository administrationRepository;
  final PlatformAdministrationService administrationService;
  final MultiMobilizationCoordinationReadRepository? missionRepository;
  final Stream<List<ResponsePlace>>? locationStream;
  final OperationCoordinatorViewDataSource operationCoordinatorDataSource;
  final DateTime? referenceTime;

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
                        _ExecutiveDashboardHeader(
                          busy: _busy,
                          creationEnabled:
                              widget.administrationService.isAvailable,
                          onCreate: _createOperation,
                        ),
                        if (_busy) ...[
                          const SizedBox(height: V5Spacing.md),
                          const LinearProgressIndicator(),
                        ],
                        const SizedBox(height: V5Spacing.xl),
                        _ExecutiveReveal(
                          child: _ExecutiveStatusHeader(
                            dashboard: dashboard,
                            now: widget.referenceTime ?? DateTime.now(),
                          ),
                        ),
                        const SizedBox(height: V5Spacing.xl),
                        _ExecutiveReveal(
                          child: _ExecutiveKpiGrid(dashboard: dashboard),
                        ),
                        const SizedBox(height: V5Spacing.xxxl),
                        _ExecutiveReveal(
                          child: _ExecutivePriorities(
                            dashboard: dashboard,
                            onOpen: _openOperation,
                          ),
                        ),
                        const SizedBox(height: V5Spacing.xxxl),
                        Text(
                          'Situation opérationnelle',
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
                              OperationStatus.planned,
                            }),
                            dashboard: dashboard,
                            onOpen: _openOperation,
                          ),
                          _OperationSection(
                            title: 'Brouillons',
                            operations: _withStatuses(operations, const {
                              OperationStatus.draft,
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
          mobilizationProvider: widget.mobilizationProvider,
          administrationRepository: widget.administrationRepository,
          administrationService: widget.administrationService,
          missionRepository: widget.missionRepository,
          locationStream: widget.locationStream,
          operationCoordinatorDataSource: widget.operationCoordinatorDataSource,
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
    required this.mobilizationProvider,
    required this.administrationRepository,
    required this.administrationService,
    this.missionRepository,
    this.locationStream,
    this.operationCoordinatorDataSource =
        const NoOperationCoordinatorViewDataSource(),
  });

  final String operationId;
  final OperationReadRepository operationRepository;
  final PlatformReadRepository platformRepository;
  final MobilizationContextProvider mobilizationProvider;
  final PlatformAdministrationReadRepository administrationRepository;
  final PlatformAdministrationService administrationService;
  final MultiMobilizationCoordinationReadRepository? missionRepository;
  final Stream<List<ResponsePlace>>? locationStream;
  final OperationCoordinatorViewDataSource operationCoordinatorDataSource;

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
                return _buildDecisionDetail(
                  operation,
                  mobilizations,
                  mobilizationSnapshot.data!,
                );
              },
            ),
      ),
    ),
  );

  Widget _buildDecisionDetail(
    Operation operation,
    List<Mobilization> mobilizations,
    List<Mobilization> allMobilizations,
  ) {
    final mobilizationIds = mobilizations.map((item) => item.id).toSet();
    final missionStream = widget.missionRepository
        ?.watchMissionsForMobilizations(mobilizationIds);
    return StreamBuilder<List<Territory>>(
      stream: widget.platformRepository.watchTerritories(),
      builder: (context, territorySnapshot) =>
          StreamBuilder<List<CoordinationNeed>>(
            stream:
                missionStream ?? Stream<List<CoordinationNeed>>.value(const []),
            builder: (context, missionSnapshot) =>
                StreamBuilder<OperationCoordinatorViewData>(
                  stream: widget.operationCoordinatorDataSource
                      .watchForOperation(operation, mobilizations),
                  builder: (context, coordinatorSnapshot) {
                    if (territorySnapshot.hasError ||
                        missionSnapshot.hasError) {
                      return const _OperationsMessage(
                        icon: Icons.cloud_off_outlined,
                        text: 'Le détail opérationnel est indisponible.',
                      );
                    }
                    if (!territorySnapshot.hasData ||
                        !missionSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator.adaptive(),
                      );
                    }
                    final snapshot = ExecutiveDashboardSnapshot(
                      operations: [operation],
                      mobilizations: mobilizations,
                      missions: missionSnapshot.data!,
                    ).snapshotFor(operation);
                    return ListView(
                      key: const PageStorageKey('platform-operation-detail'),
                      padding: const EdgeInsets.fromLTRB(
                        V5Spacing.lg,
                        V5Spacing.lg,
                        V5Spacing.lg,
                        V5Spacing.xxxl,
                      ),
                      children: [
                        if (_busy) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: V5Spacing.md),
                        ],
                        _OperationDetailHeader(
                          operation: operation,
                          territories: territorySnapshot.data!,
                        ),
                        const SizedBox(height: V5Spacing.md),
                        _OperationSituationSection(snapshot: snapshot),
                        const SizedBox(height: V5Spacing.md),
                        _OperationActionsSection(
                          operation: operation,
                          busy: _busy,
                          onEdit: () => _edit(operation),
                          onTransition: (target) =>
                              _transition(operation, target),
                        ),
                        const SizedBox(height: V5Spacing.md),
                        _OperationMobilizationsSection(
                          operation: operation,
                          mobilizations: mobilizations,
                          busy: _busy,
                          onAdd: () => _chooseMobilizationAction(
                            operation,
                            allMobilizations,
                          ),
                          onOpen: _openMobilizationManagement,
                        ),
                        const SizedBox(height: V5Spacing.md),
                        _OperationCoordinatorSection(
                          viewData: coordinatorSnapshot.data,
                          hasError: coordinatorSnapshot.hasError,
                          actionEnabled:
                              !_busy &&
                              widget.administrationService.isAvailable &&
                              operation.status != OperationStatus.completed &&
                              operation.status != OperationStatus.archived,
                          onManage: () => _chooseOperationCoordinator(
                            operation,
                            mobilizations,
                            coordinatorSnapshot.data,
                          ),
                        ),
                        const SizedBox(height: V5Spacing.md),
                        _OperationFutureJourneysSection(
                          operation: operation,
                          mobilizations: mobilizations,
                          missions: missionSnapshot.data!,
                          locations: widget.locationStream,
                        ),
                      ],
                    );
                  },
                ),
          ),
    );
  }

  void _openMobilizationManagement(Mobilization mobilization) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Gestion · ${mobilization.name}')),
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

  Future<void> _chooseOperationCoordinator(
    Operation operation,
    List<Mobilization> mobilizations,
    OperationCoordinatorViewData? coordinatorViewData,
  ) async {
    List<ActivePlatformCoordinator> coordinators;
    try {
      coordinators = await widget.administrationRepository
          .watchActiveCoordinators()
          .first;
    } catch (_) {
      if (mounted) _message('Les Coordinateurs ne sont pas disponibles.');
      return;
    }
    if (!mounted) return;
    if (coordinators.isEmpty) {
      _message('Aucun Coordinateur actif n’est disponible.');
      return;
    }
    String? selectedUid =
        coordinators.any(
          (coordinator) => coordinator.uid == operation.coordinatorUid,
        )
        ? operation.coordinatorUid
        : null;
    final selected = await showV5Dialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => V5Dialog(
          title: coordinatorViewData?.state == OperationCoordinatorState.unnamed
              ? 'Nommer le Coordinateur'
              : 'Choisir le Coordinateur principal',
          message: operation.name,
          content: V5SelectField<String>(
            key: const Key('operation-coordinator-select'),
            label: 'Coordinateur actif',
            value: selectedUid,
            options: coordinators
                .map(
                  (coordinator) => V5SelectOption<String>(
                    value: coordinator.uid,
                    label:
                        '${coordinator.displayIdentity.displayName} · '
                        '${coordinator.uid}',
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setDialogState(() => selectedUid = value),
          ),
          actions: [
            V5DialogAction(
              label: 'Annuler',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            V5DialogAction(
              key: const Key('confirm-operation-coordinator-selection'),
              label: 'Continuer',
              style: V5DialogActionStyle.primary,
              onPressed: selectedUid == null
                  ? null
                  : () => Navigator.of(dialogContext).pop(selectedUid),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == operation.coordinatorUid &&
        coordinatorViewData?.state == OperationCoordinatorState.assigned) {
      _message('Ce Coordinateur est déjà affecté à toute l’opération.');
      return;
    }
    final activeCount = mobilizations
        .where((item) => item.status == MobilizationStatus.active)
        .length;
    final hasExistingCoordinator =
        operation.coordinatorUid != null ||
        coordinatorViewData?.state != OperationCoordinatorState.unnamed;
    if (hasExistingCoordinator && activeCount > 0) {
      final confirmed = await showV5Confirmation(
        context: context,
        barrierDismissible: false,
        title: 'Remplacer le Coordinateur principal ?',
        message:
            '$activeCount mobilisation${activeCount > 1 ? 's sont actives' : ' est active'}. '
            'Leurs affectations seront harmonisées immédiatement.',
        confirmLabel: 'Remplacer',
        confirmKey: const Key('confirm-operation-coordinator-replacement'),
      );
      if (confirmed != true || !mounted) return;
    }
    await _run(
      () => widget.administrationService.setOperationCoordinator(
        operationId: operation.id,
        uid: selected,
      ),
      hasExistingCoordinator
          ? 'Coordinateur principal remplacé.'
          : 'Coordinateur principal nommé.',
    );
  }

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

class _ExecutiveDashboardHeader extends StatelessWidget {
  const _ExecutiveDashboardHeader({
    required this.busy,
    required this.creationEnabled,
    required this.onCreate,
  });

  final bool busy;
  final bool creationEnabled;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < 600 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final title = Semantics(
        header: true,
        child: Text(
          'Centre opérationnel',
          key: const Key('executive-dashboard-title'),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      );
      final action = V5Button(
        key: const Key('create-platform-operation'),
        label: 'Nouvelle opération',
        icon: Icons.add_rounded,
        compact: true,
        loading: busy,
        tone: V5ButtonTone.secondary,
        onPressed: busy || !creationEnabled ? null : onCreate,
      );
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: V5Spacing.md),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: title),
          const SizedBox(width: V5Spacing.sm),
          action,
        ],
      );
    },
  );
}

class _ExecutiveReveal extends StatelessWidget {
  const _ExecutiveReveal({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: reduceMotion ? Duration.zero : NativeMotion.detailsExpansion,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class _ExecutiveStatusHeader extends StatelessWidget {
  const _ExecutiveStatusHeader({required this.dashboard, required this.now});

  final ExecutiveDashboardSnapshot dashboard;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final (
      icon,
      title,
      subtitle,
      foreground,
      background,
    ) = switch (dashboard.state) {
      ExecutivePlatformState.calm => (
        Icons.check_circle_rounded,
        'Plateforme stable',
        'Aucune opération active pour le moment',
        colors.success,
        colors.successContainer,
      ),
      ExecutivePlatformState.stable => (
        Icons.check_circle_rounded,
        'Plateforme stable',
        'Aucune mission critique détectée',
        colors.success,
        colors.successContainer,
      ),
      ExecutivePlatformState.watch => (
        Icons.visibility_rounded,
        'Sous surveillance',
        '${dashboard.criticalMissionCount} mission${dashboard.criticalMissionCount > 1 ? 's' : ''} critique${dashboard.criticalMissionCount > 1 ? 's' : ''} à suivre',
        colors.warning,
        colors.warningContainer,
      ),
      ExecutivePlatformState.critical => (
        Icons.error_rounded,
        'Situation critique',
        '${dashboard.criticalMissionCount} missions critiques nécessitent une action',
        colors.danger,
        colors.dangerContainer,
      ),
    };
    final updatedAt = dashboard.lastUpdated;
    final freshness = _freshnessLabel(context, updatedAt, now);
    return Semantics(
      key: const Key('executive-platform-state'),
      container: true,
      label: '$title. $subtitle. $freshness.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(V5Spacing.lg),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(V5Radius.large),
            border: Border.all(color: foreground.withValues(alpha: 0.2)),
            boxShadow: V5Elevation.level1(colors),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: foreground, size: 26),
              ),
              const SizedBox(width: V5Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(color: foreground),
                    ),
                    const SizedBox(height: V5Spacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: V5Spacing.xs),
                    Text(
                      freshness,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
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

  String _freshnessLabel(
    BuildContext context,
    DateTime? updatedAt,
    DateTime now,
  ) {
    if (updatedAt == null) return 'Mise à jour indisponible';
    final localUpdatedAt = updatedAt.toLocal();
    final difference = now.toLocal().difference(localUpdatedAt);
    if (difference.isNegative || difference.inMinutes < 1) {
      return 'Mis à jour à l’instant';
    }
    if (difference.inMinutes < 60) {
      return 'Mis à jour il y a ${difference.inMinutes} min';
    }
    if (difference.inHours < 24) {
      return 'Mis à jour il y a ${difference.inHours} h';
    }
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(localUpdatedAt),
      alwaysUse24HourFormat: true,
    );
    return 'Mis à jour à $time';
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
      CriticalKpi(
        key: const Key('executive-kpi-critical'),
        count: dashboard.criticalMissionCount,
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
      ExecutiveKpi(
        key: const Key('executive-kpi-missions'),
        value: '${dashboard.activeMissionCount}',
        label: 'missions actives',
        icon: Icons.assignment_rounded,
      ),
      ProfessionKpi(
        key: const Key('executive-kpi-professionals'),
        count: dashboard.mobilizedProfessionalCount,
      ),
      ExecutiveKpi(
        key: const Key('executive-kpi-mobilizations'),
        value: '${dashboard.activeMobilizationCount}',
        label: 'mobilisations actives',
        icon: Icons.hub_rounded,
      ),
      OperationKpi(
        key: const Key('executive-kpi-operations'),
        count: dashboard.activeOperationCount,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 3 : 2;
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
    final (icon, stateLabel, foreground, background, detail) = critical > 0
        ? (
            Icons.error_rounded,
            'ACTION URGENTE',
            colors.danger,
            colors.dangerContainer,
            '$critical mission${critical > 1 ? 's' : ''} critique${critical > 1 ? 's' : ''}',
          )
        : hasCoverageRisk
        ? (
            Icons.visibility_rounded,
            'À SURVEILLER',
            colors.warning,
            colors.warningContainer,
            '${snapshot.establishmentCount} établissement${snapshot.establishmentCount > 1 ? 's' : ''} à surveiller',
          )
        : isPlanned
        ? (
            Icons.event_available_rounded,
            'À PRÉPARER',
            colors.info,
            colors.infoContainer,
            'Préparation à confirmer',
          )
        : (
            Icons.check_circle_rounded,
            'SOUS CONTRÔLE',
            colors.success,
            colors.successContainer,
            snapshot.missionCount == 0
                ? 'Aucune mission active'
                : 'Situation maîtrisée',
          );
    const action = 'Voir l’opération';
    return Padding(
      padding: const EdgeInsets.only(bottom: V5Spacing.md),
      child: Semantics(
        button: true,
        label: '$stateLabel. ${snapshot.operation.name}. $detail. $action.',
        child: Material(
          color: colors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(V5Radius.card),
            side: BorderSide(color: foreground.withValues(alpha: 0.24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('executive-priority-${snapshot.operation.id}'),
            borderRadius: BorderRadius.circular(V5Radius.card),
            onTap: () => onOpen(snapshot.operation),
            child: Padding(
              padding: const EdgeInsets.all(V5Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: V5Spacing.xs,
                      vertical: V5Spacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(V5Radius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: foreground, size: 17),
                        const SizedBox(width: V5Spacing.xs),
                        Flexible(
                          child: Text(
                            stateLabel,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .45,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: V5Spacing.md),
                  Text(
                    snapshot.operation.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: V5Spacing.xs),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: V5Spacing.md),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          action,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      const SizedBox(width: V5Spacing.xxs),
                      Icon(Icons.arrow_forward_rounded, color: foreground),
                    ],
                  ),
                ],
              ),
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
      padding: const EdgeInsets.only(bottom: V5Spacing.xxl),
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
      padding: const EdgeInsets.only(bottom: V5Spacing.md),
      child: Material(
        color: context.v5Colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V5Radius.card),
          side: BorderSide(color: context.v5Colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('platform-operation-${operation.id}'),
          borderRadius: BorderRadius.circular(V5Radius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(V5Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.v5Colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(V5Radius.control),
                      ),
                      child: Icon(
                        Icons.domain_rounded,
                        size: 21,
                        color: context.v5Colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: V5Spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            operation.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: V5Spacing.xxs),
                          Text(
                            '${operationTypeLabel(operation.type)} · '
                            '${operationStatusLabel(operation.status)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.v5Colors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: V5Spacing.sm),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.v5Colors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: V5Spacing.sm),
                Text(
                  period,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.v5Colors.textSecondary,
                  ),
                ),
                const SizedBox(height: V5Spacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 1 : 3;
                    final width =
                        (constraints.maxWidth - V5Spacing.xs * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: V5Spacing.xs,
                      runSpacing: V5Spacing.xs,
                      children: [
                        SizedBox(
                          width: width,
                          child: _OperationInlineMetric(
                            value: '${snapshot.criticalMissionCount}',
                            label: 'critiques',
                            critical: snapshot.criticalMissionCount > 0,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _OperationInlineMetric(
                            value: coverageLabel,
                            label: 'couverture',
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _OperationInlineMetric(
                            value: '${snapshot.missionCount}',
                            label: 'missions',
                          ),
                        ),
                      ],
                    );
                  },
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(V5Spacing.xs),
    decoration: BoxDecoration(
      color: context.v5Colors.surfaceMuted,
      borderRadius: BorderRadius.circular(V5Radius.compact),
    ),
    child: Semantics(
      label: '$value $label',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: critical ? context.v5Colors.danger : null,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: V5Spacing.xxs),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.v5Colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OperationDetailHeader extends StatelessWidget {
  const _OperationDetailHeader({
    required this.operation,
    required this.territories,
  });

  final Operation operation;
  final List<Territory> territories;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final territoryById = {for (final item in territories) item.id: item};
    final territoryLabels = operation.scopeRefs
        .where((ref) => ref.kind == OperationalScopeKind.territory)
        .map((ref) {
          final territory = territoryById[ref.id];
          return territory == null
              ? ref.id
              : '${territory.name} · ${territory.code}';
        })
        .toList(growable: false);
    return _OperationDetailSection(
      key: const Key('operation-detail-identity'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              operation.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: V5Spacing.sm),
          Wrap(
            spacing: V5Spacing.xs,
            runSpacing: V5Spacing.xs,
            children: [
              _OperationMetadataChip(
                icon: Icons.category_outlined,
                label: operationTypeLabel(operation.type),
              ),
              _OperationMetadataChip(
                icon: Icons.circle_rounded,
                label: operationStatusLabel(operation.status),
              ),
            ],
          ),
          if (operation.context case final contextText?) ...[
            const SizedBox(height: V5Spacing.md),
            Text(contextText, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: V5Spacing.md),
          _OperationInformationRow(
            icon: Icons.calendar_today_outlined,
            label: 'Début',
            value: localizations.formatMediumDate(operation.startAt),
          ),
          const SizedBox(height: V5Spacing.xs),
          _OperationInformationRow(
            icon: Icons.event_available_outlined,
            label: 'Fin',
            value: operation.endAt == null
                ? 'Non définie'
                : localizations.formatMediumDate(operation.endAt!),
          ),
          const SizedBox(height: V5Spacing.xs),
          _OperationInformationRow(
            icon: Icons.public_rounded,
            label: 'Territoires',
            value: territoryLabels.isEmpty
                ? 'Non défini'
                : territoryLabels.join(', '),
          ),
        ],
      ),
    );
  }
}

class _OperationSituationSection extends StatelessWidget {
  const _OperationSituationSection({required this.snapshot});

  final OperationExecutiveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final coverage = snapshot.coverage;
    final tension = snapshot.criticalMissionCount > 0
        ? '${snapshot.criticalMissionCount} critique${snapshot.criticalMissionCount > 1 ? 's' : ''}'
        : coverage != null && coverage < 1
        ? 'Couverture à renforcer'
        : 'Situation couverte';
    return _OperationDetailSection(
      key: const Key('operation-detail-situation'),
      title: 'Situation opérationnelle',
      icon: Icons.monitor_heart_outlined,
      child: Column(
        children: [
          _OperationMetricRow(
            key: const Key('operation-detail-mobilizations'),
            label: 'Mobilisations',
            value: '${snapshot.mobilizations.length}',
          ),
          _OperationMetricRow(
            key: const Key('operation-detail-missions'),
            label: 'Missions actives',
            value: '${snapshot.missionCount}',
          ),
          _OperationMetricRow(
            key: const Key('operation-detail-coverage'),
            label: 'Couverture',
            value: coverage == null ? '—' : '${(coverage * 100).round()} %',
          ),
          _OperationMetricRow(
            key: const Key('operation-detail-tension'),
            label: 'Tensions',
            value: tension,
            critical: snapshot.criticalMissionCount > 0,
          ),
          _OperationMetricRow(
            key: const Key('operation-detail-professionals'),
            label: 'Professionnels mobilisés',
            value: '${snapshot.mobilizedProfessionalCount}',
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _OperationActionsSection extends StatelessWidget {
  const _OperationActionsSection({
    required this.operation,
    required this.busy,
    required this.onEdit,
    required this.onTransition,
  });

  final Operation operation;
  final bool busy;
  final VoidCallback onEdit;
  final ValueChanged<OperationStatus> onTransition;

  @override
  Widget build(BuildContext context) {
    final transitions = _orderedTransitions(
      operation.status,
    ).where(operation.status.canTransitionTo).toList(growable: false);
    if (transitions.isEmpty && operation.status == OperationStatus.archived) {
      return const SizedBox.shrink();
    }
    return _OperationDetailSection(
      key: const Key('operation-detail-actions'),
      title: 'Actions administrateur',
      icon: Icons.admin_panel_settings_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (operation.status != OperationStatus.completed &&
              operation.status != OperationStatus.archived) ...[
            V5Button(
              key: const Key('edit-platform-operation'),
              onPressed: busy ? null : onEdit,
              label: 'Modifier',
              icon: Icons.edit_outlined,
              tone: V5ButtonTone.secondary,
              expanded: true,
            ),
            if (transitions.isNotEmpty) const SizedBox(height: V5Spacing.xs),
          ],
          for (var index = 0; index < transitions.length; index++) ...[
            V5Button(
              key: Key(
                'transition-operation-${transitions[index].serializedValue}',
              ),
              onPressed: busy ? null : () => onTransition(transitions[index]),
              label: operationTransitionLabel(transitions[index]),
              icon: _transitionIcon(transitions[index]),
              tone: _transitionTone(transitions[index]),
              expanded: true,
            ),
            if (index < transitions.length - 1)
              const SizedBox(height: V5Spacing.xs),
          ],
        ],
      ),
    );
  }

  static List<OperationStatus> _orderedTransitions(OperationStatus status) =>
      switch (status) {
        OperationStatus.draft => const [
          OperationStatus.planned,
          OperationStatus.archived,
        ],
        OperationStatus.planned => const [
          OperationStatus.active,
          OperationStatus.archived,
        ],
        OperationStatus.active => const [
          OperationStatus.completed,
          OperationStatus.suspended,
        ],
        OperationStatus.suspended => const [
          OperationStatus.active,
          OperationStatus.completed,
        ],
        OperationStatus.completed => const [OperationStatus.archived],
        OperationStatus.archived => const [],
      };

  static IconData _transitionIcon(OperationStatus target) => switch (target) {
    OperationStatus.planned => Icons.event_available_outlined,
    OperationStatus.active => Icons.play_circle_outline_rounded,
    OperationStatus.suspended => Icons.pause_circle_outline_rounded,
    OperationStatus.completed => Icons.task_alt_rounded,
    OperationStatus.archived => Icons.archive_outlined,
    OperationStatus.draft => Icons.edit_note_outlined,
  };

  static V5ButtonTone _transitionTone(OperationStatus target) =>
      switch (target) {
        OperationStatus.planned ||
        OperationStatus.active ||
        OperationStatus.completed => V5ButtonTone.primary,
        OperationStatus.suspended ||
        OperationStatus.archived ||
        OperationStatus.draft => V5ButtonTone.secondary,
      };
}

class _OperationMobilizationsSection extends StatelessWidget {
  const _OperationMobilizationsSection({
    required this.operation,
    required this.mobilizations,
    required this.busy,
    required this.onAdd,
    required this.onOpen,
  });

  final Operation operation;
  final List<Mobilization> mobilizations;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<Mobilization> onOpen;

  @override
  Widget build(BuildContext context) {
    final canAdd =
        operation.status != OperationStatus.completed &&
        operation.status != OperationStatus.archived;
    return _OperationDetailSection(
      key: const Key('operation-detail-mobilizations-section'),
      title: 'Mobilisations · ${mobilizations.length}',
      icon: Icons.hub_outlined,
      trailing: canAdd
          ? IconButton(
              key: const Key('add-operation-mobilization'),
              tooltip: 'Ajouter une mobilisation',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: busy ? null : onAdd,
              icon: const Icon(Icons.add_rounded),
            )
          : null,
      child: mobilizations.isEmpty
          ? const Text('Aucune mobilisation rattachée.')
          : Column(
              children: [
                for (var index = 0; index < mobilizations.length; index++) ...[
                  _MobilizationTile(
                    mobilization: mobilizations[index],
                    onTap: () => onOpen(mobilizations[index]),
                  ),
                  if (index < mobilizations.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
    );
  }
}

class _MobilizationTile extends StatelessWidget {
  const _MobilizationTile({required this.mobilization, required this.onTap});

  final Mobilization mobilization;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    key: Key('operation-mobilization-${mobilization.id}'),
    contentPadding: EdgeInsets.zero,
    minTileHeight: 52,
    onTap: onTap,
    title: Text(mobilization.name),
    subtitle: Text(
      '${mobilization.subtitle} · ${_mobilizationStatusLabel(mobilization.status)}',
    ),
    trailing: const Icon(Icons.chevron_right_rounded),
  );

  static String _mobilizationStatusLabel(MobilizationStatus status) =>
      switch (status) {
        MobilizationStatus.draft => 'Brouillon',
        MobilizationStatus.active => 'Active',
        MobilizationStatus.inactive => 'Inactive',
        MobilizationStatus.archived => 'Archivée',
      };
}

class _OperationCoordinatorSection extends StatelessWidget {
  const _OperationCoordinatorSection({
    required this.viewData,
    required this.hasError,
    required this.actionEnabled,
    required this.onManage,
  });

  final OperationCoordinatorViewData? viewData;
  final bool hasError;
  final bool actionEnabled;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return _OperationDetailSection(
      key: const Key('operation-coordinator-section'),
      title: 'Coordinateur',
      icon: Icons.supervisor_account_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _content(context),
          if (!hasError && viewData != null) ...[
            const SizedBox(height: V5Spacing.md),
            V5Button(
              key: const Key('manage-operation-coordinator'),
              onPressed: actionEnabled ? onManage : null,
              label: switch (viewData!.state) {
                OperationCoordinatorState.unnamed => 'Nommer',
                OperationCoordinatorState.assigned => 'Remplacer',
                OperationCoordinatorState.divergent => 'Harmoniser',
              },
              icon: Icons.manage_accounts_outlined,
              tone: V5ButtonTone.secondary,
              expanded: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (hasError) {
      return const _CoordinatorStateMessage(
        icon: Icons.cloud_off_outlined,
        label: 'Coordination indisponible',
        description: 'Les affectations ne peuvent pas être chargées.',
        critical: true,
      );
    }
    final data = viewData;
    if (data == null) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
      );
    }
    return switch (data.state) {
      OperationCoordinatorState.unnamed => const _CoordinatorStateMessage(
        icon: Icons.person_off_outlined,
        label: 'Non nommé',
        description:
            'Aucun Coordinateur actif n’est affecté aux mobilisations.',
      ),
      OperationCoordinatorState.assigned => _UniqueCoordinatorContent(
        coverage: data.coordinator!,
      ),
      OperationCoordinatorState.divergent => _DivergentCoordinatorsContent(
        data: data,
      ),
    };
  }
}

class _CoordinatorStateMessage extends StatelessWidget {
  const _CoordinatorStateMessage({
    required this.icon,
    required this.label,
    required this.description,
    this.critical = false,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool critical;

  @override
  Widget build(BuildContext context) {
    final color = critical
        ? context.v5Colors.warning
        : context.v5Colors.textPrimary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: V5Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                key: const Key('operation-coordinator-state'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: V5Spacing.xxs),
              Text(description),
            ],
          ),
        ),
      ],
    );
  }
}

class _UniqueCoordinatorContent extends StatelessWidget {
  const _UniqueCoordinatorContent({required this.coverage});

  final OperationCoordinatorCoverage coverage;

  @override
  Widget build(BuildContext context) {
    final count = coverage.mobilizationCount;
    return Semantics(
      label:
          'Coordinateur unique, ${coverage.identity.displayName}, '
          '$count mobilisation${count > 1 ? 's' : ''} couverte${count > 1 ? 's' : ''}',
      child: ExcludeSemantics(
        child: Column(
          key: const Key('operation-coordinator-unique'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Coordinateur unique',
              key: const Key('operation-coordinator-state'),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: V5Spacing.xxs),
            Text(
              coverage.identity.displayName,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: V5Spacing.xxs),
            Text(
              'Identifiant · ${coverage.usefulIdentifier}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.v5Colors.textSecondary,
              ),
            ),
            const SizedBox(height: V5Spacing.sm),
            Text(
              '$count mobilisation${count > 1 ? 's' : ''} '
              'couverte${count > 1 ? 's' : ''}',
            ),
          ],
        ),
      ),
    );
  }
}

class _DivergentCoordinatorsContent extends StatelessWidget {
  const _DivergentCoordinatorsContent({required this.data});

  final OperationCoordinatorViewData data;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('operation-coordinator-divergent'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _CoordinatorStateMessage(
        icon: Icons.warning_amber_rounded,
        label: 'Affectations divergentes',
        description:
            'Plusieurs situations de coordination coexistent. '
            'Une harmonisation sera nécessaire.',
        critical: true,
      ),
      const SizedBox(height: V5Spacing.md),
      for (var index = 0; index < data.coverages.length; index++) ...[
        _CoordinatorCoverageLine(coverage: data.coverages[index]),
        if (index < data.coverages.length - 1 ||
            data.unassignedMobilizations.isNotEmpty)
          const Divider(height: V5Spacing.lg),
      ],
      if (data.unassignedMobilizations.isNotEmpty)
        _UnassignedMobilizationsLine(
          mobilizations: data.unassignedMobilizations,
        ),
    ],
  );
}

class _CoordinatorCoverageLine extends StatelessWidget {
  const _CoordinatorCoverageLine({required this.coverage});

  final OperationCoordinatorCoverage coverage;

  @override
  Widget build(BuildContext context) => Column(
    key: Key('operation-coordinator-${coverage.uid}'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        coverage.identity.displayName,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: V5Spacing.xxs),
      Text(
        'Identifiant · ${coverage.usefulIdentifier}',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.v5Colors.textSecondary),
      ),
      const SizedBox(height: V5Spacing.xxs),
      Text(coverage.mobilizations.map((item) => item.name).join(' · ')),
    ],
  );
}

class _UnassignedMobilizationsLine extends StatelessWidget {
  const _UnassignedMobilizationsLine({required this.mobilizations});

  final List<Mobilization> mobilizations;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('operation-coordinator-unassigned'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Sans Coordinateur',
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: V5Spacing.xxs),
      Text(
        mobilizations.map((item) => item.name).join(' · '),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.v5Colors.textSecondary),
      ),
    ],
  );
}

class _OperationFutureJourneysSection extends StatelessWidget {
  const _OperationFutureJourneysSection({
    required this.operation,
    required this.mobilizations,
    required this.missions,
    required this.locations,
  });

  final Operation operation;
  final List<Mobilization> mobilizations;
  final List<CoordinationNeed> missions;
  final Stream<List<ResponsePlace>>? locations;

  CrossRoleOperationContext get _previewContext => CrossRoleOperationContext(
    operationId: operation.id,
    operationName: operation.name,
    mobilizationIds: mobilizations.map((item) => item.id).toSet(),
    locationIds: missions
        .map((item) => item.locationId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet(),
  );

  @override
  Widget build(BuildContext context) => _OperationDetailSection(
    key: const Key('operation-future-journeys'),
    title: 'Voir cette opération comme',
    icon: Icons.visibility_outlined,
    child: StreamBuilder<List<ResponsePlace>>(
      stream: locations ?? Stream.value(const []),
      builder: (context, locationSnapshot) => Column(
        children: [
          _OperationJourneyTile(
            key: const Key('future-view-as-coordinator'),
            icon: Icons.dashboard_outlined,
            label: 'Coordinateur',
            onTap: () {
              CrossRolePerspectiveScope.of(
                context,
              ).showCoordinatorForOperation(_previewContext);
              _closeOperationDetail(context);
            },
          ),
          const Divider(height: 1),
          _OperationJourneyTile(
            key: const Key('future-view-as-responsible'),
            icon: Icons.apartment_outlined,
            label: 'Responsable',
            onTap: () =>
                _openResponsible(context, locationSnapshot.data ?? const []),
          ),
          const Divider(height: 1),
          _OperationJourneyTile(
            key: const Key('future-view-as-professional'),
            icon: Icons.medical_services_outlined,
            label: 'Professionnel',
            onTap: () {
              CrossRolePerspectiveScope.of(
                context,
              ).showProfessionalForOperation(_previewContext);
              _closeOperationDetail(context);
            },
          ),
        ],
      ),
    ),
  );

  Future<void> _openResponsible(
    BuildContext context,
    List<ResponsePlace> locations,
  ) async {
    final previewContext = _previewContext;
    if (previewContext.locationIds.isEmpty) {
      _showUnavailableCenterMessage(context);
      return;
    }
    final available = locations
        .where((location) => previewContext.locationIds.contains(location.id))
        .toList(growable: false);
    if (available.isEmpty) {
      _showUnavailableCenterMessage(context);
      return;
    }
    ResponsePlace? selected;
    if (available.length == 1) {
      selected = available.single;
    } else {
      selected = await showResponsibleCenterPicker(
        context,
        access: const ResponsibleAccess(
          uid: 'platform-administrator-preview',
          role: ResponsibleRole.coordinator,
          locationIds: {},
          active: true,
        ),
        locations: available,
        accentColor: context.v5Colors.accent,
      );
    }
    if (selected == null || !context.mounted) return;
    CrossRolePerspectiveScope.of(
      context,
    ).showResponsibleForOperation(selected.id, previewContext);
    _closeOperationDetail(context);
  }

  void _showUnavailableCenterMessage(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun établissement de cette opération ne peut être prévisualisé.',
          ),
        ),
      );

  void _closeOperationDetail(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);
}

class _OperationJourneyTile extends StatelessWidget {
  const _OperationJourneyTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Voir cette opération comme $label',
    child: ExcludeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(
              children: [
                Icon(icon, color: context.v5Colors.textSecondary),
                const SizedBox(width: V5Spacing.sm),
                Expanded(child: Text(label)),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.v5Colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _OperationDetailSection extends StatelessWidget {
  const _OperationDetailSection({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(V5Spacing.md),
    decoration: BoxDecoration(
      color: context.v5Colors.surfaceElevated,
      borderRadius: BorderRadius.circular(V5Radius.card),
      border: Border.all(color: context.v5Colors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 21, color: context.v5Colors.textSecondary),
                const SizedBox(width: V5Spacing.xs),
              ],
              Expanded(
                child: Text(
                  title!,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: V5Spacing.md),
        ],
        child,
      ],
    ),
  );
}

class _OperationMetadataChip extends StatelessWidget {
  const _OperationMetadataChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: V5Spacing.sm,
      vertical: V5Spacing.xs,
    ),
    decoration: BoxDecoration(
      color: context.v5Colors.surfaceMuted,
      borderRadius: BorderRadius.circular(V5Radius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.v5Colors.textSecondary),
        const SizedBox(width: V5Spacing.xs),
        Flexible(child: Text(label)),
      ],
    ),
  );
}

class _OperationInformationRow extends StatelessWidget {
  const _OperationInformationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 19, color: context.v5Colors.textSecondary),
      const SizedBox(width: V5Spacing.sm),
      SizedBox(
        width: 74,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.v5Colors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Expanded(child: Text(value)),
    ],
  );
}

class _OperationMetricRow extends StatelessWidget {
  const _OperationMetricRow({
    super.key,
    required this.label,
    required this.value,
    this.critical = false,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool critical;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: V5Spacing.sm),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: critical ? context.v5Colors.danger : null,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
      if (showDivider) const Divider(height: 1),
    ],
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
