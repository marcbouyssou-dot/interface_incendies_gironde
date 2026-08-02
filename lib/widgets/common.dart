import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/health_profession.dart';
import '../models/need.dart';
import '../models/professional_equipment.dart';
import '../models/volunteer_profile.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../screens/engagement_confirmation_screen.dart';
import '../theme/app_theme.dart';
import 'mission_location_details.dart';

class PageContainer extends StatelessWidget {
  const PageContainer({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: child,
      ),
    );
  }
}

abstract final class AppFormLayout {
  static const pagePadding = EdgeInsets.fromLTRB(20, 20, 20, 36);
  static const actionBarPadding = EdgeInsets.fromLTRB(20, 12, 20, 12);
  static const double fieldSpacing = 14;
  static const double sectionSpacing = 24;
  static const double sectionTransitionSpacing = 10;
  static const double titleSpacing = 12;
  static const double actionHeight = 56;
}

class FormSectionTitle extends StatelessWidget {
  const FormSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.orange,
                  fontSize: 11,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 7),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

bool isInvalidResponsibleAccessError(Object? error) =>
    error is ResponsibleAccessFormatException;

class InvalidResponsibleAccessState extends StatelessWidget {
  const InvalidResponsibleAccessState({super.key});

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: ListView(
        key: const Key('invalid-responsible-access-state'),
        padding: const EdgeInsets.fromLTRB(20, 42, 20, 32),
        children: [
          const PageHeader(
            eyebrow: 'Accès responsable',
            title: 'Configuration d’accès invalide',
            subtitle:
                'Votre compte responsable contient une configuration de '
                'rôles incorrecte.',
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.red,
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun accès d’administration n’a été accordé.',
                    key: const Key('invalid-responsible-access-message'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Contactez un coordinateur MobSanté.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CriticalDataUnavailableState extends StatelessWidget {
  const CriticalDataUnavailableState({
    super.key,
    required this.stateKey,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.safetyMessage,
  });

  final Key stateKey;
  final String eyebrow;
  final String title;
  final String message;
  final String safetyMessage;

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: ListView(
        key: stateKey,
        padding: const EdgeInsets.fromLTRB(20, 42, 20, 32),
        children: [
          PageHeader(eyebrow: eyebrow, title: title, subtitle: message),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.orange,
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    safetyMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Réessayez dans quelques instants.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.action});
  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null)
          Text(
            action!,
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class TerritorialGroupFilter extends StatelessWidget {
  const TerritorialGroupFilter({
    super.key,
    required this.value,
    required this.onChanged,
    this.fieldKey,
  });

  final TerritorialGroup? value;
  final ValueChanged<TerritorialGroup?> onChanged;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: fieldKey,
      initialValue: value?.name ?? 'all',
      isExpanded: true,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.map_outlined, size: 20),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: [
        const DropdownMenuItem(value: 'all', child: Text('Tous les secteurs')),
        ...TerritorialGroup.values.map(
          (group) => DropdownMenuItem(
            value: group.name,
            child: Text(group.label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (selected) {
        onChanged(
          selected == null || selected == 'all'
              ? null
              : TerritorialGroup.values.byName(selected),
        );
      },
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final NeedStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      NeedStatus.critical => ('Critique', AppColors.red, AppColors.redSoft),
      NeedStatus.toComplete => (
        'À compléter',
        AppColors.orange,
        AppColors.orangeSoft,
      ),
      NeedStatus.complete => ('Complet', AppColors.green, AppColors.greenSoft),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

enum _MissionTiming { past, current, upcoming }

class MissionTimingPill extends StatelessWidget {
  const MissionTimingPill({super.key, required this.mission});

  final CoordinationNeed mission;

  @override
  Widget build(BuildContext context) {
    final timing = _timingAt(DateTime.now());
    if (timing == null) return const SizedBox.shrink();
    final (label, icon, color, background) = switch (timing) {
      _MissionTiming.past => (
        'Passée',
        Icons.history_rounded,
        AppColors.textMuted,
        AppColors.background,
      ),
      _MissionTiming.current => (
        'En cours',
        Icons.play_circle_outline_rounded,
        AppColors.green,
        AppColors.greenSoft,
      ),
      _MissionTiming.upcoming => (
        'À venir',
        Icons.schedule_rounded,
        AppColors.orange,
        AppColors.orangeSoft,
      ),
    };
    return Semantics(
      label: 'Mission $label',
      child: Container(
        key: Key('mission-timing-${mission.id}'),
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: 0.34), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                letterSpacing: 0.1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _MissionTiming? _timingAt(DateTime now) {
    final startAt = mission.startAt;
    final endAt = mission.endAt;
    if (endAt != null && !now.isBefore(endAt)) return _MissionTiming.past;
    if (startAt != null && now.isBefore(startAt)) {
      return _MissionTiming.upcoming;
    }
    if (startAt != null || endAt != null) return _MissionTiming.current;
    return null;
  }
}

class CoverageBar extends StatelessWidget {
  const CoverageBar({super.key, required this.need});
  final CoordinationNeed need;

  @override
  Widget build(BuildContext context) {
    final color = switch (need.status) {
      NeedStatus.critical => AppColors.red,
      NeedStatus.toComplete => AppColors.orange,
      NeedStatus.complete => AppColors.green,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfessionQuotaRows(need: need),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${(need.coverage * 100).round()}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedCoverageIndicator(
          value: need.coverage,
          color: color,
          minHeight: 8,
        ),
      ],
    );
  }
}

class AnimatedCoverageIndicator extends StatelessWidget {
  const AnimatedCoverageIndicator({
    super.key,
    required this.value,
    this.color = AppColors.orange,
    this.minHeight = 16,
  });

  final double value;
  final Color color;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) => ClipRRect(
        borderRadius: BorderRadius.circular(minHeight),
        child: LinearProgressIndicator(
          minHeight: minHeight,
          value: animatedValue,
          color: color,
          backgroundColor: AppColors.border,
        ),
      ),
    );
  }
}

class _ProfessionQuotaRows extends StatelessWidget {
  const _ProfessionQuotaRows({required this.need, this.emphasized = false});

  final CoordinationNeed need;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final visibleProfessions = HealthProfessionRegistry.values
        .where(
          (profession) =>
              need.professionQuotas.quotaFor(profession.id).hasActivity,
        )
        .toList(growable: false);
    return Column(
      children: [
        for (var index = 0; index < visibleProfessions.length; index++) ...[
          _ProfessionQuotaRow(
            need: need,
            profession: visibleProfessions[index],
            emphasized: emphasized,
          ),
          if (index < visibleProfessions.length - 1)
            SizedBox(height: emphasized ? 10 : 6),
        ],
      ],
    );
  }
}

class _ProfessionQuotaRow extends StatelessWidget {
  const _ProfessionQuotaRow({
    required this.need,
    required this.profession,
    required this.emphasized,
  });

  final CoordinationNeed need;
  final HealthProfessionDefinition profession;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final quota = need.professionQuotas.quotaFor(profession.id);
    if (emphasized) {
      final color = quota.isCovered
          ? AppColors.green
          : quota.coverage < .5
          ? AppColors.red
          : AppColors.orange;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    profession.missionLabel,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.24)),
                  ),
                  child: Text(
                    '${quota.registered} / ${quota.required}',
                    key: Key('mission-quota-${profession.id}'),
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            AnimatedCoverageIndicator(
              value: quota.coverage,
              color: color,
              minHeight: 7,
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            profession.missionLabel,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${quota.registered} / ${quota.required}',
          key: Key('mission-quota-${profession.id}'),
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _MissionCardSectionTitle extends StatelessWidget {
  const _MissionCardSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _MissionCardSectionDivider extends StatelessWidget {
  const _MissionCardSectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Divider(height: 1, thickness: 1, color: AppColors.border),
    );
  }
}

class NeedCard extends StatelessWidget {
  const NeedCard({
    super.key,
    required this.need,
    this.location,
    this.compact = false,
    this.onEditMission,
    this.isMissionEditorOpening = false,
    this.isMissionEditorBlocked = false,
  });
  final CoordinationNeed need;
  final ResponsePlace? location;
  final bool compact;
  final VoidCallback? onEditMission;
  final bool isMissionEditorOpening;
  final bool isMissionEditorBlocked;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      need.place.toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  MissionTimingPill(mission: need),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                location?.type.label ?? 'Lieu d’intervention',
                key: const Key('mission-location-type'),
                style: const TextStyle(
                  color: AppColors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              MissionLocationDetails(location: location),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aujourd’hui',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _operationalTime(need.time),
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const _MissionCardSectionDivider(),
              const _MissionCardSectionTitle('PROFESSIONNELS RECHERCHÉS'),
              const SizedBox(height: 12),
              _ProfessionQuotaRows(need: need, emphasized: true),
              if (need.equipment
                  .where((item) => item.trim().isNotEmpty)
                  .isNotEmpty) ...[
                const _MissionCardSectionDivider(),
                const _MissionCardSectionTitle('MATÉRIEL DEMANDÉ'),
                const SizedBox(height: 10),
                Wrap(
                  key: const Key('mission-equipment-text'),
                  spacing: 7,
                  runSpacing: 7,
                  children: need.equipment
                      .where((item) => item.trim().isNotEmpty)
                      .map(
                        (item) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            item,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 12,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const _MissionCardSectionDivider(),
              _NeedActions(need: need, location: location),
              if (onEditMission != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: Key('edit-mission-${need.id}'),
                    onPressed: isMissionEditorBlocked ? null : onEditMission,
                    icon: isMissionEditorOpening
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_outlined),
                    label: Text(
                      isMissionEditorOpening
                          ? 'Modification en cours…'
                          : 'Modifier la mission',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _operationalTime(String time) {
    return time
        .replaceAll(':00', 'h')
        .replaceAll(' — ', ' → ')
        .replaceAll(':', 'h');
  }
}

class _NeedActions extends StatefulWidget {
  const _NeedActions({required this.need, required this.location});

  final CoordinationNeed need;
  final ResponsePlace? location;

  @override
  State<_NeedActions> createState() => _NeedActionsState();
}

class _NeedActionsState extends State<_NeedActions> {
  LiveCoordinationData? _liveData;
  Stream<EngagementInfo?>? _engagement;

  CoordinationNeed get need => widget.need;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStream();
  }

  @override
  void didUpdateWidget(_NeedActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.need.id != widget.need.id) {
      _engagement = null;
      _updateStream();
    }
  }

  void _updateStream() {
    final liveData = LiveCoordinationDataScope.of(context);
    if (!identical(liveData, _liveData) || _engagement == null) {
      _liveData = liveData;
      _engagement = liveData.watchMyEngagement(need.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EngagementInfo?>(
      stream: _engagement,
      builder: (context, engagementSnapshot) {
        if (engagementSnapshot.hasError) {
          return const FilledButton(
            onPressed: null,
            child: Text('Statut indisponible'),
          );
        }
        if (engagementSnapshot.connectionState == ConnectionState.waiting &&
            !engagementSnapshot.hasData) {
          return const FilledButton(
            onPressed: null,
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final engagement = engagementSnapshot.data;
        if (engagement != null) {
          final actionLabel = switch (engagement.status) {
            EngagementStatus.pending => 'CONFIRMER MA PARTICIPATION',
            EngagementStatus.confirmed => 'PARTICIPATION CONFIRMÉE',
            EngagementStatus.standby => 'RENFORT',
            EngagementStatus.cancelled => 'JE M’ENGAGE À NOUVEAU',
          };
          final actionIcon = switch (engagement.status) {
            EngagementStatus.pending => Icons.schedule_rounded,
            EngagementStatus.confirmed => Icons.check_circle_rounded,
            EngagementStatus.standby => Icons.groups_rounded,
            EngagementStatus.cancelled => Icons.cancel_rounded,
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _EngagementStatusBadge(status: engagement.status),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed:
                    engagement.status == EngagementStatus.cancelled ||
                        engagement.status == EngagementStatus.pending
                    ? () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => _RegistrationSheet(
                          need: need,
                          location: widget.location,
                        ),
                      )
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.greenSoft,
                  disabledForegroundColor: AppColors.green,
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: Icon(actionIcon),
                label: Text(actionLabel),
              ),
              if (engagement.status == EngagementStatus.standby) ...[
                const SizedBox(height: 8),
                const Text(
                  'Vous serez contacté si nécessaire.',
                  textAlign: TextAlign.center,
                ),
              ],
              if (engagement.status != EngagementStatus.cancelled) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: Key('cancel-engagement-${need.id}'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _CancelEngagementDialog(
                      need: need,
                      engagement: engagement,
                    ),
                  ),
                  child: const Text('Annuler mon engagement'),
                ),
              ],
            ],
          );
        }
        return FilledButton.icon(
          onPressed: need.status == NeedStatus.complete
              ? null
              : () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) =>
                      _RegistrationSheet(need: need, location: widget.location),
                ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.greenSoft,
            disabledForegroundColor: AppColors.green,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          icon: Icon(
            need.status == NeedStatus.complete
                ? Icons.check_circle_rounded
                : Icons.bolt_rounded,
          ),
          label: Text(
            need.status == NeedStatus.complete
                ? 'MISSION COMPLÈTE'
                : '❤️ JE M’ENGAGE',
          ),
        );
      },
    );
  }
}

class _EngagementStatusBadge extends StatelessWidget {
  const _EngagementStatusBadge({required this.status});

  final EngagementStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (status) {
      EngagementStatus.pending => (AppColors.orange, AppColors.orangeSoft),
      EngagementStatus.confirmed => (AppColors.green, AppColors.greenSoft),
      EngagementStatus.standby => (AppColors.navy, AppColors.background),
      EngagementStatus.cancelled => (AppColors.red, AppColors.redSoft),
    };
    return Container(
      key: Key('engagement-status-${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CancelEngagementDialog extends StatefulWidget {
  const _CancelEngagementDialog({required this.need, required this.engagement});

  final CoordinationNeed need;
  final EngagementInfo engagement;

  @override
  State<_CancelEngagementDialog> createState() =>
      _CancelEngagementDialogState();
}

class _CancelEngagementDialogState extends State<_CancelEngagementDialog> {
  bool _submitting = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await RepositoryScope.of(
        context,
      ).cancelEngagement(widget.need.id).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre désengagement a bien été enregistré.'),
        ),
      );
    } on RepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Le désengagement n’a pas pu être enregistré. Réessayez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Se désengager de cette mission ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.need.place),
          Text(widget.need.date),
          Text(widget.need.time),
          Text(widget.engagement.profession.label),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('confirm-cancel-engagement'),
          onPressed: _submitting ? null : _confirm,
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirmer mon désengagement'),
        ),
      ],
    );
  }
}

class MissionCancellationButton extends StatelessWidget {
  const MissionCancellationButton({super.key, required this.need});

  final CoordinationNeed need;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: Key('cancel-mission-${need.id}'),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => _CancelMissionDialog(need: need),
      ),
      icon: const Icon(Icons.cancel_outlined),
      label: const Text('Annuler ce besoin'),
    );
  }
}

class _CancelMissionDialog extends StatefulWidget {
  const _CancelMissionDialog({required this.need});
  final CoordinationNeed need;

  @override
  State<_CancelMissionDialog> createState() => _CancelMissionDialogState();
}

class _CancelMissionDialogState extends State<_CancelMissionDialog> {
  final _reason = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await RepositoryScope.of(context)
          .cancelMission(widget.need.id, _reason.text)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Le besoin a été annulé.')));
    } on RepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'L’annulation n’a pas pu être enregistrée. Réessayez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Annuler ce besoin ?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cette mission ne sera plus proposée aux professionnels. '
              'Les engagements existants resteront conservés dans '
              'l’historique.',
            ),
            const SizedBox(height: 14),
            Text(widget.need.place),
            Text('${widget.need.date} • ${widget.need.time}'),
            Text('MK engagés : ${widget.need.registeredPhysiotherapists}'),
            Text('PP engagés : ${widget.need.registeredPodiatrists}'),
            const SizedBox(height: 14),
            TextField(
              key: const Key('cancellation-reason'),
              controller: _reason,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motif de l’annulation',
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        FilledButton(
          key: const Key('confirm-cancel-mission'),
          onPressed: _submitting ? null : _confirm,
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirmer l’annulation'),
        ),
      ],
    );
  }
}

class _RegistrationSheet extends StatefulWidget {
  const _RegistrationSheet({required this.need, required this.location});
  final CoordinationNeed need;
  final ResponsePlace? location;

  @override
  State<_RegistrationSheet> createState() => _RegistrationSheetState();
}

class _RegistrationSheetState extends State<_RegistrationSheet> {
  VolunteerProfession _profession = VolunteerProfession.mk;
  ProfessionalIdType _professionalIdType = ProfessionalIdType.none;
  bool _hasCpts = false;
  final Set<String> _selectedEquipment = {};
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _professionalIdController = TextEditingController();
  final _cptsIdController = TextEditingController();
  final _cptsController = TextEditingController();
  final _otherEquipmentController = TextEditingController();
  bool _submitting = false;
  bool _loadingProfile = true;
  bool _editingProfile = true;
  String? _profileError;
  VolunteerProfile? _profile;
  bool _profileLoadStarted = false;

  List<VolunteerProfession> get _professions => HealthProfessionRegistry.values
      .map((definition) => volunteerProfessionFromId(definition.id))
      .toList(growable: false);

  bool _isAvailable(VolunteerProfession profession) {
    final quota = widget.need.professionQuotas.quotaFor(
      profession.canonicalId!,
    );
    return quota.required > 0 && quota.registered < quota.required;
  }

  bool get _hasAvailableProfession => _professions.any(_isAvailable);

  bool get _isVeterinarian => _profession == VolunteerProfession.veterinarian;

  List<ProfessionalIdType> get _professionalIdTypeOptions => _isVeterinarian
      ? const [ProfessionalIdType.ordinal]
      : ProfessionalIdType.values;

  List<ProfessionalEquipmentDefinition> get _equipmentOptions =>
      ProfessionalEquipmentRegistry.forProfession(_profession.canonicalId!);

  List<String> get _incompatibleEquipment => _selectedEquipment
      .where(
        (item) => !ProfessionalEquipmentRegistry.isCompatible(
          item,
          _profession.canonicalId!,
        ),
      )
      .toList(growable: false);

  bool get _equipmentDetailsRequired =>
      ProfessionalEquipmentRegistry.requiresDetails(_selectedEquipment);

  bool get _hasValidProfessionalIdentifier => isValidProfessionalIdentifier(
    _professionalIdType,
    _professionalIdController.text,
  );

  bool get _isProfessionalIdentifierReady {
    final value = _professionalIdController.text.trim();
    if (_professionalIdType == ProfessionalIdType.rpps) {
      return RegExp(r'^\d{11}$').hasMatch(value);
    }
    return _professionalIdType == ProfessionalIdType.ordinal &&
        value.isNotEmpty;
  }

  int get _professionalIdentifierMaxLength =>
      _professionalIdType == ProfessionalIdType.rpps ? 11 : 32;

  void _trimProfessionalIdentifier() {
    final normalized = _professionalIdController.text.trim();
    if (normalized == _professionalIdController.text) return;
    _professionalIdController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  void _applyProfessionalIdentifierTypeForProfession() {
    if (!_isVeterinarian || _professionalIdType == ProfessionalIdType.ordinal) {
      return;
    }
    _professionalIdType = ProfessionalIdType.ordinal;
    _professionalIdController.clear();
  }

  void _selectProfession(VolunteerProfession profession) {
    setState(() {
      _profession = profession;
      _applyProfessionalIdentifierTypeForProfession();
    });
  }

  @override
  void initState() {
    super.initState();
    _profession = _professions.firstWhere(
      _isAvailable,
      orElse: () => _professions.first,
    );
    _applyProfessionalIdentifierTypeForProfession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileLoadStarted) return;
    _profileLoadStarted = true;
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _professionalIdController.dispose();
    _cptsIdController.dispose();
    _cptsController.dispose();
    _otherEquipmentController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await RepositoryScope.of(context).getVolunteerProfile();
      if (!mounted) return;
      if (profile != null) {
        _firstNameController.text = profile.firstName;
        _lastNameController.text = profile.lastName;
        _phoneController.text = profile.phone;
        _emailController.text = profile.email ?? '';
        _professionalIdType = profile.effectiveProfessionalIdType;
        _professionalIdController.text = profile.effectiveProfessionalIdValue;
        _cptsIdController.text = profile.cptsId ?? '';
        _cptsController.text = profile.cptsLabel ?? '';
        _hasCpts =
            (profile.cptsId?.trim().isNotEmpty ?? false) ||
            (profile.cptsLabel?.trim().isNotEmpty ?? false);
        _selectedEquipment
          ..clear()
          ..addAll(
            ProfessionalEquipmentRegistry.normalizeStoredValues(
              profile.equipment.map(
                (item) =>
                    item.trim().toLowerCase().startsWith('autre matériel :')
                    ? ProfessionalEquipmentId.otherEquipment
                    : item,
              ),
            ),
          );
        final legacyOtherEquipment = profile.equipment
            .where(
              (item) =>
                  item.trim().toLowerCase().startsWith('autre matériel :'),
            )
            .map(
              (item) =>
                  item.substring(item.toLowerCase().indexOf(':') + 1).trim(),
            )
            .where((item) => item.isNotEmpty)
            .toList();
        final otherEquipment =
            profile.otherEquipmentDetails?.trim().isNotEmpty == true
            ? [profile.otherEquipmentDetails!.trim()]
            : legacyOtherEquipment;
        if (otherEquipment.isNotEmpty) {
          _selectedEquipment.add(ProfessionalEquipmentId.otherEquipment);
          _otherEquipmentController.text = otherEquipment.join(', ');
        }
        final profileProfessionAvailable = _isAvailable(profile.profession);
        if (profileProfessionAvailable) {
          _profession = profile.profession;
        }
        _applyProfessionalIdentifierTypeForProfession();
      }
      setState(() {
        _profile = profile;
        _editingProfile = profile == null || !_isAvailable(profile.profession);
        _loadingProfile = false;
        _profileError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _profileError = 'Votre profil n’a pas pu être chargé.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_profileError != null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_profileError!),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _loadingProfile = true;
                    _profileError = null;
                  });
                  _loadProfile();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'S’inscrire à la mission',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 5),
              Text(
                widget.need.place,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppFormLayout.sectionSpacing),
              if (_isProfessionalIdentifierReady)
                const _ProfessionalIdentifierReadyNotice()
              else
                _ProfessionalIdentifierRequiredNotice(
                  ordinalOnly: _isVeterinarian,
                ),
              const SizedBox(height: AppFormLayout.fieldSpacing),
              if (_profile != null && !_editingProfile) ...[
                _ProfileSummary(profile: _profile!),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => setState(() => _editingProfile = true),
                  child: Text(
                    _isProfessionalIdentifierReady
                        ? 'Modifier mes informations'
                        : 'Compléter mon profil',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_editingProfile) ...[
                const FormSectionTitle(title: 'Profession'),
                const SizedBox(height: AppFormLayout.titleSpacing),
                RadioGroup<VolunteerProfession>(
                  groupValue: _profession,
                  onChanged: (value) => _selectProfession(value!),
                  child: Column(
                    children: [
                      for (final profession in _professions)
                        RadioListTile<VolunteerProfession>(
                          key: Key('profession-${profession.canonicalId}'),
                          contentPadding: EdgeInsets.zero,
                          value: profession,
                          enabled: _isAvailable(profession),
                          title: Text(profession.label),
                          subtitle: _isAvailable(profession)
                              ? null
                              : const Text('Aucun besoin disponible'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppFormLayout.fieldSpacing),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Prénom'),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nom'),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppFormLayout.fieldSpacing),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                  validator: _phone,
                ),
                const SizedBox(height: AppFormLayout.fieldSpacing),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: _email,
                ),
                const SizedBox(height: AppFormLayout.fieldSpacing),
                KeyedSubtree(
                  key: ValueKey(
                    'professional-id-type-${_isVeterinarian ? 'ordinal' : 'all'}',
                  ),
                  child: DropdownButtonFormField<ProfessionalIdType>(
                    key: const Key('professional-id-type'),
                    initialValue: _professionalIdType,
                    decoration: const InputDecoration(
                      labelText: 'Identifiant professionnel *',
                      helperText: 'Obligatoire pour participer.',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: _professionalIdTypeOptions
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    validator: (type) {
                      if (_isVeterinarian) {
                        return type == ProfessionalIdType.ordinal
                            ? null
                            : 'Le numéro ordinal est obligatoire.';
                      }
                      return type == ProfessionalIdType.rpps ||
                              type == ProfessionalIdType.ordinal
                          ? null
                          : 'Choisissez un identifiant RPPS ou ordinal.';
                    },
                    onChanged: (type) {
                      if (type == null) return;
                      setState(() {
                        _professionalIdType = type;
                        if (type == ProfessionalIdType.none) {
                          _professionalIdController.clear();
                        }
                      });
                    },
                  ),
                ),
                if (_professionalIdType != ProfessionalIdType.none) ...[
                  const SizedBox(height: AppFormLayout.fieldSpacing),
                  TextFormField(
                    key: const Key('professional-id-value'),
                    controller: _professionalIdController,
                    keyboardType: _professionalIdType == ProfessionalIdType.rpps
                        ? TextInputType.number
                        : TextInputType.text,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      if (_professionalIdType == ProfessionalIdType.rpps)
                        FilteringTextInputFormatter.digitsOnly
                      else
                        FilteringTextInputFormatter.deny(RegExp(r'^\s+')),
                      LengthLimitingTextInputFormatter(
                        _professionalIdentifierMaxLength,
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: _professionalIdType == ProfessionalIdType.rpps
                          ? 'Numéro RPPS *'
                          : 'Numéro ordinal *',
                      helperText: _professionalIdType == ProfessionalIdType.rpps
                          ? '11 chiffres.'
                          : '32 caractères maximum, délivré par votre ordre.',
                      counterText: '',
                    ),
                    validator: _professionalId,
                    onChanged: (_) => setState(() {}),
                    onTapOutside: (_) {
                      _trimProfessionalIdentifier();
                      setState(() {});
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    onFieldSubmitted: (_) {
                      _trimProfessionalIdentifier();
                      setState(() {});
                      FocusScope.of(context).nextFocus();
                    },
                  ),
                ],
                const SizedBox(height: AppFormLayout.fieldSpacing),
                DropdownButtonFormField<bool>(
                  key: const Key('cpts-choice'),
                  initialValue: _hasCpts,
                  decoration: const InputDecoration(labelText: 'CPTS'),
                  items: const [
                    DropdownMenuItem(value: false, child: Text('Aucune')),
                    DropdownMenuItem(
                      value: true,
                      child: Text('Renseigner une CPTS'),
                    ),
                  ],
                  onChanged: (hasCpts) {
                    if (hasCpts == null) return;
                    setState(() {
                      _hasCpts = hasCpts;
                      if (!hasCpts) {
                        _cptsIdController.clear();
                        _cptsController.clear();
                      }
                    });
                  },
                ),
                if (_hasCpts) ...[
                  const SizedBox(height: AppFormLayout.fieldSpacing),
                  TextFormField(
                    controller: _cptsIdController,
                    decoration: const InputDecoration(
                      labelText: 'Identifiant CPTS',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: AppFormLayout.fieldSpacing),
                  TextFormField(
                    controller: _cptsController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'CPTS'),
                    validator: _required,
                  ),
                ],
                const SizedBox(height: AppFormLayout.sectionSpacing),
                const FormSectionTitle(title: 'Matériel que je peux apporter'),
                const SizedBox(height: AppFormLayout.titleSpacing),
                for (final equipment in _equipmentOptions)
                  CheckboxListTile(
                    key: Key('equipment-${equipment.id}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(equipment.label),
                    value: _selectedEquipment.contains(equipment.id),
                    onChanged: (selected) => setState(() {
                      if (selected ?? false) {
                        _selectedEquipment.add(equipment.id);
                      } else {
                        _selectedEquipment.remove(equipment.id);
                      }
                    }),
                  ),
                if (_incompatibleEquipment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Équipement déjà enregistré',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  for (final equipment in _incompatibleEquipment)
                    CheckboxListTile(
                      key: Key('legacy-equipment-$equipment'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        ProfessionalEquipmentRegistry.displayLabel(equipment),
                      ),
                      subtitle: const Text('Non proposé pour cette profession'),
                      value: true,
                      onChanged: (selected) {
                        if (selected == false) {
                          setState(() => _selectedEquipment.remove(equipment));
                        }
                      },
                    ),
                ],
                if (_equipmentDetailsRequired)
                  TextFormField(
                    key: const Key('other-equipment-details'),
                    controller: _otherEquipmentController,
                    decoration: const InputDecoration(
                      labelText: 'Précisez le matériel',
                    ),
                    validator: _required,
                  ),
                const SizedBox(height: AppFormLayout.sectionSpacing),
              ],
              SizedBox(
                width: double.infinity,
                height: AppFormLayout.actionHeight,
                child: FilledButton(
                  onPressed: _submitting || !_hasAvailableProfession
                      ? null
                      : _submit,
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('CONFIRMER MA PARTICIPATION'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Champ requis' : null;
  }

  static String? _phone(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return 'Champ requis';
    if (normalized.replaceAll(RegExp(r'\D'), '').length < 6) {
      return 'Téléphone trop court';
    }
    return null;
  }

  static String? _email(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return 'Champ requis';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      return 'Email invalide';
    }
    return null;
  }

  String? _professionalId(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return _professionalIdType == ProfessionalIdType.rpps
          ? 'Saisissez votre numéro RPPS.'
          : 'Saisissez votre numéro ordinal.';
    }
    if (_professionalIdType == ProfessionalIdType.rpps &&
        !RegExp(r'^\d{11}$').hasMatch(normalized)) {
      return 'Le numéro RPPS doit contenir exactement 11 chiffres.';
    }
    if (_professionalIdType == ProfessionalIdType.ordinal &&
        normalized.length > 32) {
      return 'Le numéro ordinal ne peut pas dépasser 32 caractères.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    _trimProfessionalIdentifier();
    if (!_hasValidProfessionalIdentifier) {
      setState(() => _editingProfile = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isVeterinarian
                ? 'Complétez votre profil avec votre numéro ordinal avant de '
                      'participer.'
                : 'Complétez votre profil avec un numéro RPPS ou ordinal '
                      'avant de participer.',
          ),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    late final EngagementCreationResult result;
    try {
      result = await RepositoryScope.of(context).createEngagement(
        missionId: widget.need.id,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        professionalIdType: _professionalIdType,
        professionalIdValue: _professionalIdController.text,
        cptsId: _hasCpts ? _cptsIdController.text : null,
        cptsLabel: _hasCpts ? _cptsController.text : null,
        profession: _profession,
        equipment: ProfessionalEquipmentRegistry.normalizeStoredValues(
          _selectedEquipment,
        ),
        otherEquipmentDetails: _equipmentDetailsRequired
            ? _otherEquipmentController.text
            : null,
      );
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    } catch (error, stackTrace) {
      debugPrint('Erreur UI createEngagement : $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L’inscription n’a pas pu être enregistrée. Réessayez.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => EngagementConfirmationScreen(
          need: widget.need,
          location: widget.location,
          result: result,
        ),
      ),
    );
  }
}

class _ProfessionalIdentifierRequiredNotice extends StatelessWidget {
  const _ProfessionalIdentifierRequiredNotice({required this.ordinalOnly});

  final bool ordinalOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('professional-identifier-required'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.badge_outlined, color: AppColors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ordinalOnly
                  ? 'Votre numéro ordinal est obligatoire pour participer. '
                        'Complétez votre profil avant de confirmer votre '
                        'participation.'
                  : 'Un numéro RPPS ou ordinal est obligatoire pour '
                        'participer. Complétez votre profil avant de confirmer '
                        'votre participation.',
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalIdentifierReadyNotice extends StatelessWidget {
  const _ProfessionalIdentifierReadyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('professional-identifier-ready'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.green, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profil prêt à participer',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Votre identifiant professionnel est renseigné.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});

  final VolunteerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.displayName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(profile.profession.label),
          Text(profile.phone),
          if (profile.effectiveProfessionalIdType != ProfessionalIdType.none)
            Text(
              '${profile.effectiveProfessionalIdType.label} '
              '${profile.effectiveProfessionalIdValue}',
            ),
          Text(
            profile.cptsLabel?.trim().isNotEmpty ?? false
                ? profile.cptsLabel!
                : 'Aucune CPTS',
          ),
          if (profile.equipment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              ProfessionalEquipmentRegistry.normalizeStoredValues(
                profile.equipment,
              ).map(ProfessionalEquipmentRegistry.displayLabel).join(' • '),
            ),
            if (profile.otherEquipmentDetails?.trim().isNotEmpty ?? false)
              Text(profile.otherEquipmentDetails!.trim()),
          ],
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
