import 'package:flutter/material.dart';

import '../models/mobilization.dart';
import '../models/mobilization_context.dart';
import '../models/platform_administrator_access.dart';
import '../models/territory.dart';
import '../models/user_display_identity.dart';
import '../repositories/platform_administration_read_repository.dart';
import '../repositories/platform_read_repository.dart';
import '../services/current_mobilization_provider.dart';
import '../services/platform_administration_service.dart';
import '../theme/platform_admin_identity.dart';
import '../theme/v5_foundation.dart';
import '../widgets/v5_controls.dart';
import '../widgets/v5_form_system.dart';
import 'platform_mobilization_form_dialog.dart';

class PlatformAdminMobilizationScreen extends StatefulWidget {
  const PlatformAdminMobilizationScreen({
    super.key,
    required this.platformRepository,
    required this.mobilizationProvider,
    required this.administrationRepository,
    required this.administrationService,
  });

  final PlatformReadRepository platformRepository;
  final MobilizationContextProvider mobilizationProvider;
  final PlatformAdministrationReadRepository administrationRepository;
  final PlatformAdministrationService administrationService;

  @override
  State<PlatformAdminMobilizationScreen> createState() =>
      _PlatformAdminMobilizationScreenState();
}

class _PlatformAdminMobilizationScreenState
    extends State<PlatformAdminMobilizationScreen> {
  bool _mutationInProgress = false;
  bool _dialogOpen = false;

  bool get _actionsEnabled =>
      widget.administrationService.isAvailable &&
      !_mutationInProgress &&
      !_dialogOpen;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey('platform-admin-mobilization'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            V5Spacing.lg,
            V5Spacing.lg,
            V5Spacing.lg,
            V5Spacing.xxl,
          ),
          sliver: SliverList.list(
            children: [
              const _PlatformHeader(),
              if (_mutationInProgress) ...[
                const SizedBox(height: V5Spacing.md),
                const LinearProgressIndicator(
                  key: Key('platform-mutation-loading'),
                ),
              ],
              const SizedBox(height: V5Spacing.lg),
              StreamBuilder<MobilizationContext?>(
                stream: widget.mobilizationProvider.watchContext(),
                builder: (context, contextSnapshot) {
                  final Widget activeContent;
                  if (contextSnapshot.hasError) {
                    activeContent = const _PlatformErrorState();
                  } else if (contextSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !contextSnapshot.hasData) {
                    activeContent = const _PlatformLoadingState();
                  } else {
                    final activeContext = contextSnapshot.data;
                    if (activeContext == null || !activeContext.isActive) {
                      activeContent = _NoActiveMobilization(
                        onCreateMobilization: _actionsEnabled
                            ? _openCreateMobilization
                            : null,
                      );
                    } else {
                      activeContent = _ActiveMobilizationLoader(
                        contextValue: activeContext,
                        platformRepository: widget.platformRepository,
                        administrationRepository:
                            widget.administrationRepository,
                        onCreateMobilization: _actionsEnabled
                            ? _openCreateMobilization
                            : null,
                        onDeactivateMobilization: _actionsEnabled
                            ? _deactivateMobilization
                            : null,
                      );
                    }
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      activeContent,
                      const SizedBox(height: V5Spacing.lg),
                      _ManagedMobilizationsSection(
                        platformRepository: widget.platformRepository,
                        administrationRepository:
                            widget.administrationRepository,
                        actionsEnabled: _actionsEnabled,
                        onEdit: _openEditMobilization,
                        onAssign: _assignCoordinator,
                        onRemove: _removeCoordinator,
                        onActivate: _activateMobilization,
                        onArchive: _archiveMobilization,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<List<Territory>?> _territories() async {
    try {
      return await widget.platformRepository.watchTerritories().first;
    } catch (_) {
      if (mounted) _showError('Les territoires ne sont pas disponibles.');
      return null;
    }
  }

  Future<void> _openCreateMobilization() async {
    if (!_lockDialog()) return;
    final territories = await _territories();
    if (!mounted || territories == null) {
      _unlockDialog();
      return;
    }
    final draft = await showV5Dialog<MobilizationAdministrationDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PlatformMobilizationFormDialog(territories: territories),
    );
    _unlockDialog();
    if (draft == null || !mounted) return;
    await _runMutation(
      () => widget.administrationService.createMobilization(draft),
      successMessage: 'Mobilisation préparée.',
    );
  }

  Future<void> _openEditMobilization(Mobilization mobilization) async {
    if (!_lockDialog()) return;
    final territories = await _territories();
    if (!mounted || territories == null) {
      _unlockDialog();
      return;
    }
    final draft = await showV5Dialog<MobilizationAdministrationDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PlatformMobilizationFormDialog(
        territories: territories,
        mobilization: mobilization,
      ),
    );
    _unlockDialog();
    if (draft == null || !mounted) return;
    await _runMutation(
      () => widget.administrationService.updateMobilization(draft),
      successMessage: 'Mobilisation mise à jour.',
    );
  }

  Future<void> _assignCoordinator(Mobilization mobilization) async {
    if (!_lockDialog()) return;
    List<ActivePlatformCoordinator> coordinators;
    try {
      coordinators = await widget.administrationRepository
          .watchActiveCoordinators()
          .first;
    } catch (_) {
      _unlockDialog();
      if (mounted) _showError('Les Coordinateurs ne sont pas disponibles.');
      return;
    }
    if (!mounted) return;
    if (coordinators.isEmpty) {
      _unlockDialog();
      _showError('Aucun Coordinateur V5 actif n’est disponible.');
      return;
    }
    String? selectedUid;
    final uid = await showV5Dialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => V5Dialog(
          title: 'Affecter un Coordinateur',
          message: mobilization.name,
          content: V5SelectField<String>(
            key: const Key('platform-coordinator-select'),
            label: 'Coordinateur V5 actif',
            value: selectedUid,
            options: coordinators
                .map(
                  (coordinator) => V5SelectOption<String>(
                    value: coordinator.uid,
                    label: _coordinatorOptionLabel(coordinator.displayIdentity),
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
              key: const Key('confirm-platform-coordinator-assignment'),
              label: 'Affecter',
              style: V5DialogActionStyle.primary,
              onPressed: selectedUid == null
                  ? null
                  : () => Navigator.of(dialogContext).pop(selectedUid),
            ),
          ],
        ),
      ),
    );
    _unlockDialog();
    if (uid == null || !mounted) return;
    await _runMutation(
      () => widget.administrationService.assignMobilizationCoordinator(
        mobilizationId: mobilization.id,
        uid: uid,
      ),
      successMessage: 'Coordinateur affecté.',
    );
  }

  Future<void> _removeCoordinator(
    Mobilization mobilization,
    MobilizationCoordinatorAssignment assignment,
  ) async {
    final confirmed = await _confirmation(
      title: 'Retirer ce Coordinateur ?',
      message:
          '${assignment.displayIdentity.displayName} ne coordonnera plus '
          '${mobilization.name}.',
      confirmLabel: 'Retirer',
      destructive: true,
      confirmKey: const Key('confirm-platform-coordinator-removal'),
    );
    if (!confirmed || !mounted) return;
    await _runMutation(
      () => widget.administrationService.removeMobilizationCoordinator(
        mobilizationId: mobilization.id,
        uid: assignment.uid,
      ),
      successMessage: 'Affectation retirée.',
    );
  }

  Future<void> _activateMobilization(
    Mobilization mobilization,
    Territory territory,
    List<MobilizationCoordinatorAssignment> assignments,
  ) async {
    final activeAssignments = assignments
        .where((assignment) => assignment.active)
        .toList(growable: false);
    if (activeAssignments.isEmpty) {
      _showError('Affectez un Coordinateur actif avant l’activation.');
      return;
    }
    final coordinatorLabels = activeAssignments
        .map((assignment) => assignment.displayIdentity.displayName)
        .join(', ');
    final confirmed = await _confirmation(
      title: 'Activer cette mobilisation ?',
      message:
          '${mobilization.name}\n'
          'Territoire : ${territory.name}\n'
          'Coordination : $coordinatorLabels',
      confirmLabel: 'Activer',
      confirmKey: const Key('confirm-platform-activation'),
    );
    if (!confirmed || !mounted) return;
    await _runMutation(
      () => widget.administrationService.activateMobilization(mobilization.id),
      successMessage: 'Mobilisation activée.',
    );
  }

  Future<void> _deactivateMobilization(Mobilization mobilization) async {
    final confirmed = await _confirmation(
      title: 'Désactiver cette mobilisation ?',
      message:
          '${mobilization.name} redeviendra une mobilisation préparée. Aucune archive ne sera créée.',
      confirmLabel: 'Désactiver',
      destructive: true,
      confirmKey: const Key('confirm-platform-deactivation'),
    );
    if (!confirmed || !mounted) return;
    await _runMutation(
      () =>
          widget.administrationService.deactivateMobilization(mobilization.id),
      successMessage: 'Mobilisation désactivée.',
    );
  }

  Future<void> _archiveMobilization(Mobilization mobilization) async {
    final confirmed = await _confirmation(
      title: 'Archiver cette mobilisation ?',
      message:
          '${mobilization.name} sera conservée dans l’historique et ne pourra plus être modifiée.',
      confirmLabel: 'Archiver',
      destructive: true,
      confirmKey: const Key('confirm-platform-archive'),
    );
    if (!confirmed || !mounted) return;
    await _runMutation(
      () => widget.administrationService.archiveMobilization(mobilization.id),
      successMessage: 'Mobilisation archivée.',
    );
  }

  Future<bool> _confirmation({
    required String title,
    required String message,
    required String confirmLabel,
    required Key confirmKey,
    bool destructive = false,
  }) async {
    if (!_lockDialog()) return false;
    final confirmed = await showV5Confirmation(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
      barrierDismissible: false,
      confirmKey: confirmKey,
    );
    _unlockDialog();
    return confirmed == true;
  }

  bool _lockDialog() {
    if (!_actionsEnabled) return false;
    setState(() => _dialogOpen = true);
    return true;
  }

  void _unlockDialog() {
    if (mounted) setState(() => _dialogOpen = false);
  }

  Future<void> _runMutation(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_mutationInProgress) return;
    setState(() => _mutationInProgress = true);
    try {
      await action();
      if (!mounted) return;
      V5Toast.show(context, message: successMessage, tone: V5ToastTone.success);
    } on PlatformAdministrationException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) {
        _showError('Le service est momentanément indisponible.');
      }
    } finally {
      if (mounted) setState(() => _mutationInProgress = false);
    }
  }

  void _showError(String message) {
    V5Toast.show(context, message: message, tone: V5ToastTone.danger);
  }
}

class _PlatformHeader extends StatelessWidget {
  const _PlatformHeader();

  @override
  Widget build(BuildContext context) {
    final accent = PlatformAdminIdentity.accent(context);
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PlatformAdminIdentity.container(context),
                  borderRadius: BorderRadius.circular(V5Radius.control),
                ),
                child: Icon(
                  Icons.account_balance_outlined,
                  color: accent,
                  size: 23,
                ),
              ),
              const SizedBox(width: V5Spacing.sm),
              Expanded(
                child: Text(
                  'Administration plateforme',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveMobilizationLoader extends StatelessWidget {
  const _ActiveMobilizationLoader({
    required this.contextValue,
    required this.platformRepository,
    required this.administrationRepository,
    required this.onCreateMobilization,
    required this.onDeactivateMobilization,
  });

  final MobilizationContext contextValue;
  final PlatformReadRepository platformRepository;
  final PlatformAdministrationReadRepository administrationRepository;
  final VoidCallback? onCreateMobilization;
  final ValueChanged<Mobilization>? onDeactivateMobilization;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Mobilization?>(
      stream: platformRepository.watchActiveMobilization(),
      builder: (context, mobilizationSnapshot) {
        if (mobilizationSnapshot.hasError) {
          return const _PlatformErrorState();
        }
        if (!mobilizationSnapshot.hasData) {
          return mobilizationSnapshot.connectionState == ConnectionState.waiting
              ? const _PlatformLoadingState()
              : const _PlatformErrorState();
        }
        final mobilization = mobilizationSnapshot.data;
        if (mobilization == null ||
            mobilization.id != contextValue.mobilizationId ||
            mobilization.territoryId != contextValue.territoryId ||
            mobilization.status != MobilizationStatus.active) {
          return const _PlatformErrorState();
        }
        return StreamBuilder<List<Territory>>(
          stream: platformRepository.watchTerritories(),
          builder: (context, territoriesSnapshot) {
            if (territoriesSnapshot.hasError) {
              return const _PlatformErrorState();
            }
            if (!territoriesSnapshot.hasData) {
              return const _PlatformLoadingState();
            }
            Territory? territory;
            for (final candidate in territoriesSnapshot.data!) {
              if (candidate.id == mobilization.territoryId) {
                territory = candidate;
                break;
              }
            }
            if (territory == null) return const _PlatformErrorState();
            return StreamBuilder<List<MobilizationCoordinatorAssignment>>(
              stream: administrationRepository.watchMobilizationCoordinators(
                mobilization.id,
              ),
              builder: (context, assignmentsSnapshot) {
                if (assignmentsSnapshot.hasError) {
                  return const _PlatformErrorState();
                }
                if (!assignmentsSnapshot.hasData) {
                  return const _PlatformLoadingState();
                }
                return _ActiveMobilizationContent(
                  mobilization: mobilization,
                  territory: territory!,
                  assignments: assignmentsSnapshot.data!,
                  onCreateMobilization: onCreateMobilization,
                  onDeactivateMobilization: onDeactivateMobilization,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ActiveMobilizationContent extends StatelessWidget {
  const _ActiveMobilizationContent({
    required this.mobilization,
    required this.territory,
    required this.assignments,
    required this.onCreateMobilization,
    required this.onDeactivateMobilization,
  });

  final Mobilization mobilization;
  final Territory territory;
  final List<MobilizationCoordinatorAssignment> assignments;
  final VoidCallback? onCreateMobilization;
  final ValueChanged<Mobilization>? onDeactivateMobilization;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final accent = PlatformAdminIdentity.accent(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdminSectionCard(
          key: const Key('active-mobilization-card'),
          title: 'Mobilisation active',
          icon: Icons.campaign_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mobilization.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (mobilization.subtitle.isNotEmpty &&
                  mobilization.subtitle != mobilization.name) ...[
                const SizedBox(height: V5Spacing.xxs),
                Text(
                  mobilization.subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
                ),
              ],
              const SizedBox(height: V5Spacing.md),
              Wrap(
                spacing: V5Spacing.xs,
                runSpacing: V5Spacing.xs,
                children: [
                  _MetadataChip(
                    icon: _contextIcon(mobilization.contextType),
                    label: _contextLabel(mobilization.contextType),
                  ),
                ],
              ),
              const SizedBox(height: V5Spacing.md),
              _DataLine(
                label: 'État de préparation',
                valueKey: const Key('platform-preparation-state'),
                value: assignments.isEmpty ? 'À compléter' : 'Complet',
              ),
            ],
          ),
        ),
        const SizedBox(height: V5Spacing.md),
        _AdminSectionCard(
          key: const Key('platform-coordination-card'),
          title: 'Coordination',
          icon: Icons.supervisor_account_rounded,
          child: assignments.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coordination à compléter',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: V5Spacing.xxs),
                    Text(
                      'Affectez un Coordinateur pour assurer le suivi de '
                      'cette mobilisation.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                )
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < assignments.length;
                      index++
                    ) ...[
                      if (index > 0)
                        Divider(height: V5Spacing.xl, color: colors.outline),
                      _CoordinatorLine(assignment: assignments[index]),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: V5Spacing.md),
        _AdminSectionCard(
          key: const Key('platform-territory-card'),
          title: 'Territoire',
          icon: Icons.public_rounded,
          child: Column(
            children: [
              _DataLine(
                label: 'Périmètre',
                value: '${territory.name} · ${territory.code}',
              ),
              const SizedBox(height: V5Spacing.sm),
              _DataLine(
                label: 'Activée le',
                valueKey: const Key('platform-activation-date'),
                value: mobilization.activatedAt == null
                    ? 'Date non renseignée'
                    : MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(mobilization.activatedAt!.toLocal()),
              ),
            ],
          ),
        ),
        const SizedBox(height: V5Spacing.lg),
        Text(
          'Actions',
          key: const Key('platform-primary-actions'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: accent),
        ),
        const SizedBox(height: V5Spacing.sm),
        Wrap(
          spacing: V5Spacing.xs,
          runSpacing: V5Spacing.xs,
          children: [
            V5Button(
              key: const Key('platform-create-mobilization'),
              onPressed: onCreateMobilization,
              label: 'Nouvelle mobilisation',
              icon: Icons.add_rounded,
              tone: V5ButtonTone.tonal,
              backgroundColor: PlatformAdminIdentity.container(context),
              foregroundColor: accent,
            ),
            V5Button(
              key: const Key('platform-deactivate-mobilization'),
              onPressed: onDeactivateMobilization == null
                  ? null
                  : () => onDeactivateMobilization!(mobilization),
              label: 'Désactiver',
              icon: Icons.pause_circle_outline_rounded,
              tone: V5ButtonTone.secondary,
            ),
          ],
        ),
      ],
    );
  }
}

typedef _MobilizationAssignmentAction =
    void Function(
      Mobilization mobilization,
      MobilizationCoordinatorAssignment assignment,
    );
typedef _MobilizationActivationAction =
    void Function(
      Mobilization mobilization,
      Territory territory,
      List<MobilizationCoordinatorAssignment> assignments,
    );

class _ManagedMobilizationsSection extends StatelessWidget {
  const _ManagedMobilizationsSection({
    required this.platformRepository,
    required this.administrationRepository,
    required this.actionsEnabled,
    required this.onEdit,
    required this.onAssign,
    required this.onRemove,
    required this.onActivate,
    required this.onArchive,
  });

  final PlatformReadRepository platformRepository;
  final PlatformAdministrationReadRepository administrationRepository;
  final bool actionsEnabled;
  final ValueChanged<Mobilization> onEdit;
  final ValueChanged<Mobilization> onAssign;
  final _MobilizationAssignmentAction onRemove;
  final _MobilizationActivationAction onActivate;
  final ValueChanged<Mobilization> onArchive;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Mobilization>>(
      stream: platformRepository.watchMobilizations(includeInactive: true),
      builder: (context, mobilizationsSnapshot) {
        if (mobilizationsSnapshot.hasError) {
          return const _PortfolioError();
        }
        if (!mobilizationsSnapshot.hasData) {
          return const _PortfolioLoading();
        }
        return StreamBuilder<List<Territory>>(
          stream: platformRepository.watchTerritories(),
          builder: (context, territoriesSnapshot) {
            if (territoriesSnapshot.hasError) {
              return const _PortfolioError();
            }
            if (!territoriesSnapshot.hasData) {
              return const _PortfolioLoading();
            }
            final territories = {
              for (final territory in territoriesSnapshot.data!)
                territory.id: territory,
            };
            final manageable =
                mobilizationsSnapshot.data!
                    .where(
                      (mobilization) =>
                          mobilization.status == MobilizationStatus.draft ||
                          mobilization.status == MobilizationStatus.inactive,
                    )
                    .toList(growable: false)
                  ..sort((left, right) => left.name.compareTo(right.name));
            return Column(
              key: const Key('platform-managed-mobilizations'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Mobilisations à préparer',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: V5Spacing.sm),
                if (manageable.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(V5Spacing.lg),
                    decoration: BoxDecoration(
                      color: context.v5Colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(V5Radius.section),
                      border: Border.all(color: context.v5Colors.outline),
                    ),
                    child: Text(
                      'Aucune mobilisation préparée.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  for (final mobilization in manageable) ...[
                    _ManagedMobilizationLoader(
                      mobilization: mobilization,
                      territory: territories[mobilization.territoryId],
                      administrationRepository: administrationRepository,
                      actionsEnabled: actionsEnabled,
                      onEdit: onEdit,
                      onAssign: onAssign,
                      onRemove: onRemove,
                      onActivate: onActivate,
                      onArchive: onArchive,
                    ),
                    const SizedBox(height: V5Spacing.sm),
                  ],
              ],
            );
          },
        );
      },
    );
  }
}

class _ManagedMobilizationLoader extends StatelessWidget {
  const _ManagedMobilizationLoader({
    required this.mobilization,
    required this.territory,
    required this.administrationRepository,
    required this.actionsEnabled,
    required this.onEdit,
    required this.onAssign,
    required this.onRemove,
    required this.onActivate,
    required this.onArchive,
  });

  final Mobilization mobilization;
  final Territory? territory;
  final PlatformAdministrationReadRepository administrationRepository;
  final bool actionsEnabled;
  final ValueChanged<Mobilization> onEdit;
  final ValueChanged<Mobilization> onAssign;
  final _MobilizationAssignmentAction onRemove;
  final _MobilizationActivationAction onActivate;
  final ValueChanged<Mobilization> onArchive;

  @override
  Widget build(BuildContext context) {
    if (territory == null) {
      return const _PortfolioError();
    }
    return StreamBuilder<List<MobilizationCoordinatorAssignment>>(
      stream: administrationRepository.watchMobilizationCoordinators(
        mobilization.id,
      ),
      builder: (context, assignmentsSnapshot) {
        if (assignmentsSnapshot.hasError) return const _PortfolioError();
        if (!assignmentsSnapshot.hasData) return const _PortfolioLoading();
        return _ManagedMobilizationCard(
          mobilization: mobilization,
          territory: territory!,
          assignments: assignmentsSnapshot.data!,
          actionsEnabled: actionsEnabled,
          onEdit: onEdit,
          onAssign: onAssign,
          onRemove: onRemove,
          onActivate: onActivate,
          onArchive: onArchive,
        );
      },
    );
  }
}

class _ManagedMobilizationCard extends StatelessWidget {
  const _ManagedMobilizationCard({
    required this.mobilization,
    required this.territory,
    required this.assignments,
    required this.actionsEnabled,
    required this.onEdit,
    required this.onAssign,
    required this.onRemove,
    required this.onActivate,
    required this.onArchive,
  });

  final Mobilization mobilization;
  final Territory territory;
  final List<MobilizationCoordinatorAssignment> assignments;
  final bool actionsEnabled;
  final ValueChanged<Mobilization> onEdit;
  final ValueChanged<Mobilization> onAssign;
  final _MobilizationAssignmentAction onRemove;
  final _MobilizationActivationAction onActivate;
  final ValueChanged<Mobilization> onArchive;

  @override
  Widget build(BuildContext context) {
    final activeAssignments = assignments
        .where((assignment) => assignment.active)
        .toList(growable: false);
    return _AdminSectionCard(
      key: Key('managed-mobilization-${mobilization.id}'),
      title: mobilization.name,
      icon: _contextIcon(mobilization.contextType),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: V5Spacing.xs,
            runSpacing: V5Spacing.xs,
            children: [
              _MetadataChip(
                icon: Icons.public_rounded,
                label: '${territory.name} · ${territory.code}',
              ),
              _MetadataChip(
                icon: Icons.circle_outlined,
                label: _statusLabel(mobilization.status),
              ),
            ],
          ),
          const SizedBox(height: V5Spacing.sm),
          if (activeAssignments.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coordination à compléter',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: V5Spacing.xxs),
                Text(
                  'Cette mobilisation n’est pas prête à être activée.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            )
          else
            for (final assignment in activeAssignments)
              Padding(
                padding: const EdgeInsets.only(bottom: V5Spacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Coordination · '
                        '${assignment.displayIdentity.displayName}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    V5Button(
                      key: Key(
                        'remove-coordinator-${mobilization.id}-${assignment.uid}',
                      ),
                      onPressed: actionsEnabled
                          ? () => onRemove(mobilization, assignment)
                          : null,
                      label: 'Retirer',
                      compact: true,
                      tone: V5ButtonTone.secondary,
                    ),
                  ],
                ),
              ),
          const SizedBox(height: V5Spacing.sm),
          Wrap(
            spacing: V5Spacing.xs,
            runSpacing: V5Spacing.xs,
            children: [
              V5Button(
                key: Key('edit-mobilization-${mobilization.id}'),
                onPressed: actionsEnabled ? () => onEdit(mobilization) : null,
                label: 'Modifier',
                icon: Icons.edit_outlined,
                compact: true,
                tone: V5ButtonTone.secondary,
              ),
              V5Button(
                key: Key('assign-coordinator-${mobilization.id}'),
                onPressed: actionsEnabled ? () => onAssign(mobilization) : null,
                label: 'Affecter',
                icon: Icons.person_add_alt_rounded,
                compact: true,
                tone: V5ButtonTone.secondary,
              ),
              V5Button(
                key: Key('activate-mobilization-${mobilization.id}'),
                onPressed: actionsEnabled
                    ? () => onActivate(mobilization, territory, assignments)
                    : null,
                label: 'Activer',
                icon: Icons.play_circle_outline_rounded,
                compact: true,
                tone: V5ButtonTone.tonal,
              ),
              V5Button(
                key: Key('archive-mobilization-${mobilization.id}'),
                onPressed: actionsEnabled
                    ? () => onArchive(mobilization)
                    : null,
                label: 'Archiver',
                icon: Icons.archive_outlined,
                compact: true,
                tone: V5ButtonTone.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PortfolioLoading extends StatelessWidget {
  const _PortfolioLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(V5Spacing.lg),
      child: V5ActivityIndicator(),
    ),
  );
}

class _PortfolioError extends StatelessWidget {
  const _PortfolioError();

  @override
  Widget build(BuildContext context) => Text(
    'Les mobilisations à préparer ne sont pas disponibles.',
    style: Theme.of(context).textTheme.bodyMedium,
  );
}

class _AdminSectionCard extends StatelessWidget {
  const _AdminSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final accent = PlatformAdminIdentity.accent(context);
    return Container(
      padding: const EdgeInsets.all(V5Spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
        border: Border.all(color: colors.outline),
        boxShadow: V5Elevation.level1(colors),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: V5Spacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: V5Spacing.md),
          child,
        ],
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final foreground = accent
        ? PlatformAdminIdentity.accent(context)
        : colors.textSecondary;
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(
        horizontal: V5Spacing.sm,
        vertical: V5Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: accent
            ? PlatformAdminIdentity.container(context)
            : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(V5Radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 16),
          const SizedBox(width: V5Spacing.xs),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataLine extends StatelessWidget {
  const _DataLine({required this.label, required this.value, this.valueKey});

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
      const SizedBox(width: V5Spacing.sm),
      Flexible(
        child: Text(
          value,
          key: valueKey,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.v5Colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _CoordinatorLine extends StatelessWidget {
  const _CoordinatorLine({required this.assignment});

  final MobilizationCoordinatorAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final identity = assignment.displayIdentity;
    final statusColor = assignment.active
        ? PlatformAdminIdentity.accent(context)
        : colors.textSecondary;
    return Semantics(
      key: const Key('platform-coordinator-semantics'),
      label:
          '${identity.displayName}, ${_coordinatorSupportingLabel(identity)}, '
          '${assignment.active ? 'actif' : 'inactif'}',
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(V5Radius.control),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: V5Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  identity.displayName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  _coordinatorSupportingLabel(identity),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: V5Spacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: assignment.active
                  ? PlatformAdminIdentity.container(context)
                  : colors.surfaceMuted,
              borderRadius: BorderRadius.circular(V5Radius.pill),
            ),
            child: Text(
              assignment.active ? 'Actif' : 'Inactif',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoActiveMobilization extends StatelessWidget {
  const _NoActiveMobilization({required this.onCreateMobilization});

  final VoidCallback? onCreateMobilization;

  @override
  Widget build(BuildContext context) => _StateCard(
    key: const Key('platform-no-active-mobilization'),
    icon: Icons.pause_circle_outline_rounded,
    title: 'Aucune mobilisation active',
    message: 'La plateforme ne pointe actuellement vers aucun dispositif.',
    action: V5Button(
      onPressed: onCreateMobilization,
      label: 'Nouvelle mobilisation',
      icon: Icons.add_rounded,
      tone: V5ButtonTone.tonal,
    ),
  );
}

class _PlatformLoadingState extends StatelessWidget {
  const _PlatformLoadingState();

  @override
  Widget build(BuildContext context) => const _StateCard(
    key: Key('platform-mobilization-loading'),
    icon: Icons.sync_rounded,
    title: 'Chargement de la mobilisation…',
    message: 'Lecture du contexte actif et de sa coordination.',
    loading: true,
  );
}

class _PlatformErrorState extends StatelessWidget {
  const _PlatformErrorState();

  @override
  Widget build(BuildContext context) => const _StateCard(
    key: Key('platform-mobilization-error'),
    icon: Icons.cloud_off_outlined,
    title: 'Lecture de la plateforme impossible',
    message: 'Les informations ne sont pas disponibles pour le moment.',
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final accent = PlatformAdminIdentity.accent(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(V5Spacing.xl),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: [
          if (loading)
            V5ActivityIndicator(
              key: const Key('platform-loading-indicator'),
              color: accent,
              size: 28,
            )
          else
            Icon(icon, color: accent, size: 34),
          const SizedBox(height: V5Spacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: V5Spacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (action != null) ...[
            const SizedBox(height: V5Spacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

String _contextLabel(MobilizationContextType type) => switch (type) {
  MobilizationContextType.fire => 'Incendie',
  MobilizationContextType.flood => 'Inondation',
  MobilizationContextType.heatwave => 'Canicule',
  MobilizationContextType.event => 'Événement',
  MobilizationContextType.whitePlan => 'Plan blanc',
  MobilizationContextType.other => 'Autre',
};

IconData _contextIcon(MobilizationContextType type) => switch (type) {
  MobilizationContextType.fire => Icons.local_fire_department_rounded,
  MobilizationContextType.flood => Icons.flood_rounded,
  MobilizationContextType.heatwave => Icons.thermostat_rounded,
  MobilizationContextType.event => Icons.event_rounded,
  MobilizationContextType.whitePlan => Icons.local_hospital_outlined,
  MobilizationContextType.other => Icons.category_outlined,
};

String _statusLabel(MobilizationStatus status) => switch (status) {
  MobilizationStatus.draft => 'Mobilisation préparée',
  MobilizationStatus.active => 'Mobilisation active',
  MobilizationStatus.inactive => 'Mobilisation préparée',
  MobilizationStatus.archived => 'Mobilisation archivée',
};

String _coordinatorOptionLabel(UserDisplayIdentity identity) =>
    '${identity.displayName} · ${_coordinatorSupportingLabel(identity)}';

String _coordinatorSupportingLabel(UserDisplayIdentity identity) =>
    [identity.professionLabel, ?identity.organizationLabel].join(' · ');
