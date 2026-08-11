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
import '../screens/information_consent_screen.dart';
import '../theme/app_theme.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../utils/french_date_time.dart';
import '../utils/mission_timing.dart';
import 'brand_mark.dart';
import 'mission_card.dart';
import 'mission_location_details.dart';
import 'native_interactions.dart';
import 'mobilization_design_system.dart';
import 'v5_controls.dart';
import 'v5_form_system.dart';

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
                  fontSize: 12,
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
    this.compact = false,
  });

  final TerritorialGroup? value;
  final ValueChanged<TerritorialGroup?> onChanged;
  final Key? fieldKey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: fieldKey,
      initialValue: value?.name ?? 'all',
      isExpanded: true,
      style: compact
          ? const TextStyle(
              color: AppColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            )
          : null,
      decoration: InputDecoration(
        isDense: compact,
        prefixIcon: Icon(Icons.map_outlined, size: compact ? 18 : 20),
        prefixIconConstraints: compact
            ? const BoxConstraints(minWidth: 38, minHeight: 38)
            : null,
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 11 : 14,
          vertical: compact ? 9 : 12,
        ),
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
      selectedItemBuilder: compact
          ? (context) => [
              const Text('Tous'),
              for (final group in TerritorialGroup.values)
                Text(group.label, overflow: TextOverflow.ellipsis),
            ]
          : null,
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
    final colors = context.v5Colors;
    final (label, color, background) = switch (status) {
      NeedStatus.critical => (
        'Critique',
        colors.danger,
        colors.dangerContainer,
      ),
      NeedStatus.toComplete => (
        'À compléter',
        colors.warning,
        colors.warningContainer,
      ),
      NeedStatus.complete => (
        'Complet',
        colors.success,
        colors.successContainer,
      ),
    };
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
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
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

enum _MissionTiming { past, current, upcoming }

class MissionTimingPill extends StatelessWidget {
  const MissionTimingPill({
    super.key,
    required this.mission,
    this.professionalPalette = false,
  });

  final CoordinationNeed mission;
  final bool professionalPalette;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final timing = _timingAt(DateTime.now());
    if (timing == null) return const SizedBox.shrink();
    final (label, icon, color, background) = switch (timing) {
      _MissionTiming.past => (
        'Passée',
        Icons.history_rounded,
        colors.textSecondary,
        colors.surfaceMuted,
      ),
      _MissionTiming.current => (
        'Aujourd’hui',
        Icons.play_circle_outline_rounded,
        professionalPalette ? colors.info : colors.success,
        professionalPalette ? colors.infoContainer : colors.successContainer,
      ),
      _MissionTiming.upcoming => (
        'À venir',
        Icons.schedule_rounded,
        professionalPalette ? colors.info : colors.warning,
        professionalPalette ? colors.infoContainer : colors.warningContainer,
      ),
    };
    return Semantics(
      label: 'Mission $label',
      child: Container(
        key: Key('mission-timing-${mission.id}'),
        constraints: BoxConstraints(minHeight: professionalPalette ? 26 : 32),
        padding: EdgeInsets.symmetric(
          horizontal: professionalPalette ? 7 : 10,
          vertical: professionalPalette ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(30),
          border: professionalPalette
              ? null
              : Border.all(color: color.withValues(alpha: 0.34), width: 1.2),
          boxShadow: professionalPalette
              ? null
              : [
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
            Icon(icon, size: professionalPalette ? 13 : 16, color: color),
            SizedBox(width: professionalPalette ? 4 : 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                letterSpacing: 0.1,
                fontWeight: professionalPalette
                    ? FontWeight.w700
                    : FontWeight.w900,
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
    this.semanticLabel = 'Progression',
  });

  final double value;
  final Color color;
  final double minHeight;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: semanticLabel,
      value: '${(value * 100).round()} pour cent',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduceMotion ? value : 0, end: value),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, animatedValue, _) => ClipRRect(
            borderRadius: BorderRadius.circular(minHeight),
            child: LinearProgressIndicator(
              minHeight: minHeight,
              value: animatedValue,
              color: color,
              backgroundColor: context.v5Colors.outline,
            ),
          ),
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
    final colors = context.v5Colors;
    final quota = need.professionQuotas.quotaFor(profession.id);
    if (emphasized) {
      final color = quota.isCovered
          ? colors.success
          : quota.coverage < .5
          ? colors.danger
          : colors.warning;
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
                    style: TextStyle(
                      color: colors.textPrimary,
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
                    color: colors.surfaceElevated,
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
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${quota.registered} / ${quota.required}',
          key: Key('mission-quota-${profession.id}'),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _MissionCardSectionTitle extends StatelessWidget {
  const _MissionCardSectionTitle(
    this.label, {
    this.harmonized = false,
    this.professionalHome = false,
  });

  final String label;
  final bool harmonized;
  final bool professionalHome;

  @override
  Widget build(BuildContext context) {
    if (harmonized) {
      return Text(
        label,
        style: TextStyle(
          color: professionalHome
              ? context.v5Colors.textSecondary
              : context.v5Colors.textPrimary,
          fontSize: 12,
          height: professionalHome ? 1.2 : null,
          letterSpacing: professionalHome ? 0.15 : 0.65,
          fontWeight: FontWeight.w800,
        ),
      );
    }
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
            style: TextStyle(
              color: context.v5Colors.textSecondary,
              fontSize: 12,
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
  const _MissionCardSectionDivider({this.harmonized = false});

  final bool harmonized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: harmonized ? 16 : 20),
      child: Divider(height: 1, thickness: 1, color: context.v5Colors.outline),
    );
  }
}

class NeedCard extends StatelessWidget {
  const NeedCard({
    super.key,
    required this.need,
    this.location,
    this.compact = false,
    this.harmonized = false,
    this.professionalHome = false,
    this.professionalJourney = false,
    this.professionalDetailsExpanded = true,
    this.featured = false,
    this.onEditMission,
    this.isMissionEditorOpening = false,
    this.isMissionEditorBlocked = false,
    this.preferredProfession,
  });
  final CoordinationNeed need;
  final ResponsePlace? location;
  final bool compact;
  final bool harmonized;
  final bool professionalHome;
  final bool professionalJourney;
  final bool professionalDetailsExpanded;
  final bool featured;
  final VoidCallback? onEditMission;
  final bool isMissionEditorOpening;
  final bool isMissionEditorBlocked;
  final VolunteerProfession? preferredProfession;

  @override
  Widget build(BuildContext context) {
    if (professionalHome) {
      return _buildProfessionalHomeContent(context);
    }
    final colors = context.v5Colors;
    final useStackedHeader = MediaQuery.textScalerOf(context).scale(12) >= 18;
    final timing = MissionTimingPill(mission: need);
    final content = Padding(
      padding: harmonized
          ? const EdgeInsets.fromLTRB(18, 18, 18, 20)
          : const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (useStackedHeader) ...[
            Text(
              need.place.toUpperCase(),
              style: harmonized
                  ? TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      height: 1.15,
                      letterSpacing: -0.25,
                      fontWeight: FontWeight.w800,
                    )
                  : Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: V5Spacing.xs),
            timing,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    need.place.toUpperCase(),
                    style: harmonized
                        ? TextStyle(
                            color: colors.textPrimary,
                            fontSize: 18,
                            height: 1.15,
                            letterSpacing: -0.25,
                            fontWeight: FontWeight.w800,
                          )
                        : Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 12),
                timing,
              ],
            ),
          const SizedBox(height: 5),
          Text(
            location?.type.label ?? 'Lieu d’intervention',
            key: const Key('mission-location-type'),
            style: TextStyle(
              color: harmonized ? colors.textSecondary : colors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          MissionLocationDetails(location: location),
          SizedBox(height: harmonized ? 14 : 18),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: harmonized ? 11 : 12,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(harmonized ? 12 : 14),
              border: Border.all(color: colors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  need.startAt == null
                      ? need.date
                      : FrenchDateTime.relativeDate(need.startAt!),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: harmonized ? 12 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  need.time,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: harmonized ? 20 : 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _MissionCardSectionDivider(harmonized: harmonized),
          _MissionCardSectionTitle(
            'PROFESSIONNELS RECHERCHÉS',
            harmonized: harmonized,
          ),
          const SizedBox(height: 12),
          _ProfessionQuotaRows(need: need, emphasized: true),
          if (need.equipment
              .where((item) => item.trim().isNotEmpty)
              .isNotEmpty) ...[
            _MissionCardSectionDivider(harmonized: harmonized),
            _MissionCardSectionTitle(
              'MATÉRIEL DEMANDÉ',
              harmonized: harmonized,
            ),
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
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(
                          harmonized ? 20 : 10,
                        ),
                        border: Border.all(color: colors.outline),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          color: colors.textPrimary,
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
          _MissionCardSectionDivider(harmonized: harmonized),
          _NeedActions(need: need, location: location),
          if (onEditMission != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key('edit-mission-${need.id}'),
                style: harmonized
                    ? OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        minimumSize: const Size.fromHeight(52),
                        side: BorderSide(color: colors.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      )
                    : null,
                onPressed: isMissionEditorBlocked ? null : onEditMission,
                icon: isMissionEditorOpening
                    ? const SizedBox.square(
                        dimension: 18,
                        child: V5ActivityIndicator(),
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
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _semanticSummary,
      child: _animatedCard(context, content),
    );
  }

  String get _semanticSummary {
    final required = need.professionQuotas.requiredTotal;
    final registered = need.professionQuotas.registeredTotal;
    final remaining = (required - registered).clamp(0, required);
    final professions = need.professionQuotas.values
        .where((quota) => quota.required > 0)
        .map(
          (quota) =>
              HealthProfessionRegistry.byId(quota.professionId)?.missionLabel ??
              quota.professionId,
        )
        .join(', ');
    final status = switch (need.status) {
      NeedStatus.critical => 'critique',
      NeedStatus.toComplete => 'à compléter',
      NeedStatus.complete => 'complet',
    };
    final filled = registered == 1
        ? '1 poste pourvu'
        : '$registered postes pourvus';
    final open = remaining == 1
        ? '1 poste à couvrir'
        : '$remaining postes à couvrir';
    return 'Besoin pour ${professions.isEmpty ? 'profession non précisée' : professions}, '
        '${need.place}, ${need.date}, ${need.time}. État : $status. '
        '$filled sur $required, $open.';
  }

  Widget _buildProfessionalHomeContent(BuildContext context) {
    final colors = context.v5Colors;
    final required = need.professionQuotas.requiredTotal;
    final registered = need.professionQuotas.registeredTotal;
    final remaining = (required - registered).clamp(0, required);
    final remainingLabel = remaining == 0
        ? 'L’équipe est désormais au complet.'
        : remaining == 1
        ? '1 professionnel est encore attendu.'
        : '$remaining professionnels sont encore attendus.';
    final equipment = need.equipment
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
    final details = need.details?.trim();
    final professionsWithActivity = HealthProfessionRegistry.values
        .where(
          (profession) =>
              need.professionQuotas.quotaFor(profession.id).hasActivity,
        )
        .toList(growable: false);
    final professionsStillNeeded = professionsWithActivity
        .where(
          (profession) =>
              !need.professionQuotas.quotaFor(profession.id).isCovered,
        )
        .toList(growable: false);
    final matchingProfession = preferredProfession == null
        ? null
        : HealthProfessionRegistry.byId(preferredProfession!.canonicalId!);
    final visibleProfessions =
        matchingProfession != null &&
            need.professionQuotas.quotaFor(matchingProfession.id).hasActivity
        ? [matchingProfession]
        : professionsStillNeeded.isEmpty
        ? professionsWithActivity.take(1).toList(growable: false)
        : professionsStillNeeded.take(1).toList(growable: false);
    final past = isMissionPast(need);
    final impactType = need.isCancelled || !need.isActive
        ? ImpactBannerType.cancelled
        : past
        ? ImpactBannerType.past
        : switch (need.status) {
            NeedStatus.critical => ImpactBannerType.priority,
            NeedStatus.toComplete => ImpactBannerType.reinforcementsExpected,
            NeedStatus.complete => ImpactBannerType.teamComplete,
          };

    final missionCardState = need.isCancelled || !need.isActive
        ? MissionCardState.cancelled
        : past
        ? MissionCardState.past
        : switch (need.status) {
            NeedStatus.critical => MissionCardState.urgent,
            NeedStatus.toComplete => MissionCardState.almostComplete,
            NeedStatus.complete => MissionCardState.complete,
          };

    return MissionCard(
      state: missionCardState,
      professionalPalette: professionalJourney,
      locationType: location?.type.label ?? 'Lieu d’intervention',
      locationTypeKey: const Key('mission-location-type'),
      locationName: need.place,
      dateLabel: need.startAt == null
          ? need.date
          : FrenchDateTime.relativeDate(need.startAt!),
      timeLabel: need.time,
      timingBadge: MissionTimingPill(
        mission: need,
        professionalPalette: professionalJourney,
      ),
      need: ImpactBanner(
        key: Key('mission-priority-${need.id}'),
        type: impactType,
        message: remainingLabel,
        messageIcon: Icons.groups_2_rounded,
        professionalPalette: professionalJourney,
      ),
      professionTitle: professionalJourney
          ? 'Profession recherchée'
          : remaining > 0
          ? 'Qui est attendu ?'
          : 'Qui s’est mobilisé ?',
      professions: [
        for (final profession in visibleProfessions)
          ProfessionChip(
            label: profession.missionLabel,
            professionalPalette: professionalJourney,
            state: need.professionQuotas.quotaFor(profession.id).isCovered
                ? ProfessionChipState.covered
                : ProfessionChipState.needed,
          ),
      ],
      primaryAction: _NeedActions(
        need: need,
        location: location,
        professionalHome: true,
        professionalJourney: professionalJourney,
        showActionIcon: !professionalJourney,
      ),
      secondaryDetailsExpanded: professionalDetailsExpanded,
      secondaryDetailsToggleKey: Key('mission-details-${need.id}'),
      secondaryDetails: SectionCard(
        title: 'Détails de la mission',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _MissionCardSectionTitle(
              'Accès et contact',
              harmonized: true,
              professionalHome: true,
            ),
            MissionLocationDetails(location: location, compact: true),
            const _MissionCardSectionDivider(harmonized: true),
            const _MissionCardSectionTitle(
              'Répartition des renforts',
              harmonized: true,
              professionalHome: true,
            ),
            const SizedBox(height: 10),
            _ProfessionQuotaRows(need: need),
            if (equipment.isNotEmpty) ...[
              const _MissionCardSectionDivider(harmonized: true),
              const _MissionCardSectionTitle(
                'Matériel à prévoir',
                harmonized: true,
                professionalHome: true,
              ),
              const SizedBox(height: 10),
              Wrap(
                key: const Key('mission-equipment-text'),
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final item in equipment)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(
                          MobilizationTokens.radiusPill,
                        ),
                        border: Border.all(color: colors.outline),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (details != null && details.isNotEmpty) ...[
              const _MissionCardSectionDivider(harmonized: true),
              const _MissionCardSectionTitle(
                'Message du centre',
                harmonized: true,
                professionalHome: true,
              ),
              const SizedBox(height: 9),
              Container(
                key: const Key('mission-comment-text'),
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  details,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      secondaryAction: onEditMission == null
          ? null
          : SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key('edit-mission-${need.id}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: colors.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: isMissionEditorBlocked ? null : onEditMission,
                icon: isMissionEditorOpening
                    ? const SizedBox.square(
                        dimension: 18,
                        child: V5ActivityIndicator(),
                      )
                    : const Icon(Icons.edit_outlined),
                label: Text(
                  isMissionEditorOpening
                      ? 'Modification en cours…'
                      : 'Modifier la mission',
                ),
              ),
            ),
    );
  }

  Widget _animatedCard(BuildContext context, Widget content) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final colors = context.v5Colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: harmonized
          ? Container(
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(
                  professionalHome
                      ? MobilizationTokens.radiusCard
                      : MobilizationTokens.radiusContentCard,
                ),
                border: Border.all(
                  color: featured ? colors.accent : colors.outline,
                  width: featured ? 1.35 : 1,
                ),
                boxShadow: featured
                    ? V5Elevation.level2(colors)
                    : V5Elevation.level1(colors),
              ),
              child: content,
            )
          : Card(child: content),
    );
  }
}

class _NeedActions extends StatefulWidget {
  const _NeedActions({
    required this.need,
    required this.location,
    this.professionalHome = false,
    this.professionalJourney = false,
    this.showActionIcon = true,
  });

  final CoordinationNeed need;
  final ResponsePlace? location;
  final bool professionalHome;
  final bool professionalJourney;
  final bool showActionIcon;

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

  Widget _actionButton({
    required VoidCallback? onPressed,
    required ButtonStyle style,
    required IconData icon,
    required String label,
  }) {
    if (!widget.showActionIcon) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(
        icon,
        size: widget.professionalHome
            ? MobilizationTokens.actionIconSize
            : null,
      ),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return StreamBuilder<EngagementInfo?>(
      stream: _engagement,
      builder: (context, engagementSnapshot) {
        if (engagementSnapshot.hasError) {
          return FilledButton(
            onPressed: null,
            child: Text(
              widget.professionalHome
                  ? 'Mobilisation temporairement indisponible'
                  : 'Statut indisponible',
            ),
          );
        }
        if (engagementSnapshot.connectionState == ConnectionState.waiting &&
            !engagementSnapshot.hasData) {
          return const FilledButton(
            onPressed: null,
            child: SizedBox.square(dimension: 20, child: V5ActivityIndicator()),
          );
        }
        final engagement = engagementSnapshot.data;
        if (!isMissionOperational(need)) {
          return engagement == null
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.centerLeft,
                  child: _EngagementStatusBadge(
                    status: engagement.status,
                    professionalPalette: widget.professionalJourney,
                  ),
                );
        }
        if (engagement != null) {
          final actionLabel = widget.professionalHome
              ? switch (engagement.status) {
                  EngagementStatus.pending => 'Finaliser ma participation',
                  EngagementStatus.confirmed => 'Participation confirmée',
                  EngagementStatus.standby => 'Renfort disponible',
                  EngagementStatus.cancelled => 'Je me mobilise à nouveau',
                }
              : switch (engagement.status) {
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
                child: _EngagementStatusBadge(
                  status: engagement.status,
                  professionalPalette: widget.professionalJourney,
                ),
              ),
              const SizedBox(height: 8),
              _actionButton(
                onPressed:
                    engagement.status == EngagementStatus.cancelled ||
                        engagement.status == EngagementStatus.pending
                    ? () => showNativeBottomSheet<void>(
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
                  backgroundColor: widget.professionalJourney
                      ? colors.info
                      : AppColors.orange,
                  foregroundColor: widget.professionalJourney
                      ? _contrastingForeground(colors.info, colors)
                      : Colors.white,
                  disabledBackgroundColor: widget.professionalJourney
                      ? engagement.status == EngagementStatus.confirmed
                            ? colors.successContainer
                            : colors.surfaceMuted
                      : AppColors.greenSoft,
                  disabledForegroundColor: widget.professionalJourney
                      ? engagement.status == EngagementStatus.confirmed
                            ? colors.success
                            : colors.textSecondary
                      : AppColors.green,
                  minimumSize: Size.fromHeight(
                    widget.professionalJourney
                        ? 49
                        : MobilizationTokens.actionHeight,
                  ),
                  elevation: widget.professionalJourney ? 0 : null,
                  shadowColor: widget.professionalJourney
                      ? Colors.transparent
                      : null,
                  shape: widget.professionalJourney
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(V5Radius.control),
                        )
                      : widget.professionalHome
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            MobilizationTokens.radiusSection,
                          ),
                        )
                      : null,
                  textStyle: widget.professionalHome
                      ? TextStyle(
                          fontSize: widget.professionalJourney ? 15 : 16,
                          fontWeight: FontWeight.w900,
                        )
                      : null,
                ),
                icon: actionIcon,
                label: actionLabel,
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
                  child: const Text(
                    'Annuler mon engagement pour cette mission',
                  ),
                ),
              ],
            ],
          );
        }
        return _actionButton(
          onPressed: need.status == NeedStatus.complete
              ? null
              : () => showNativeBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) =>
                      _RegistrationSheet(need: need, location: widget.location),
                ),
          style: FilledButton.styleFrom(
            backgroundColor: widget.professionalJourney
                ? colors.info
                : AppColors.orange,
            foregroundColor: widget.professionalJourney
                ? _contrastingForeground(colors.info, colors)
                : Colors.white,
            disabledBackgroundColor: widget.professionalJourney
                ? colors.surfaceMuted
                : AppColors.greenSoft,
            disabledForegroundColor: widget.professionalJourney
                ? colors.textSecondary
                : AppColors.green,
            minimumSize: Size.fromHeight(
              widget.professionalJourney ? 49 : MobilizationTokens.actionHeight,
            ),
            elevation: widget.professionalJourney ? 0 : null,
            shadowColor: widget.professionalJourney ? Colors.transparent : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                widget.professionalJourney
                    ? V5Radius.control
                    : widget.professionalHome
                    ? MobilizationTokens.radiusSection
                    : 15,
              ),
            ),
            textStyle: widget.professionalHome
                ? TextStyle(
                    fontSize: widget.professionalJourney ? 15 : 16,
                    fontWeight: FontWeight.w900,
                  )
                : null,
          ),
          icon: need.status == NeedStatus.complete
              ? Icons.check_circle_rounded
              : Icons.bolt_rounded,
          label: need.status == NeedStatus.complete
              ? widget.professionalHome
                    ? 'Équipe au complet'
                    : 'MISSION COMPLÈTE'
              : widget.professionalHome
              ? 'Je me mobilise'
              : '❤️ JE M’ENGAGE',
        );
      },
    );
  }

  Color _contrastingForeground(Color background, V5Colors colors) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : colors.canvas;
  }
}

class _EngagementStatusBadge extends StatelessWidget {
  const _EngagementStatusBadge({
    required this.status,
    this.professionalPalette = false,
  });

  final EngagementStatus status;
  final bool professionalPalette;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final (color, background) = switch (status) {
      EngagementStatus.pending => (colors.warning, colors.warningContainer),
      EngagementStatus.confirmed => (colors.success, colors.successContainer),
      EngagementStatus.standby =>
        professionalPalette
            ? (colors.info, colors.infoContainer)
            : (colors.textPrimary, colors.surfaceMuted),
      EngagementStatus.cancelled =>
        professionalPalette
            ? (colors.textSecondary, colors.surfaceMuted)
            : (colors.danger, colors.dangerContainer),
    };
    return Container(
      key: Key('engagement-status-${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MobilizationTokens.radiusPill),
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

class EngagementCancellationButton extends StatelessWidget {
  const EngagementCancellationButton({
    super.key,
    required this.need,
    required this.engagement,
    this.label = 'Annuler mon engagement pour cette mission',
  });

  final CoordinationNeed need;
  final EngagementInfo engagement;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (!isMissionOperational(need) ||
        engagement.status == EngagementStatus.cancelled) {
      return const SizedBox.shrink();
    }
    return TextButton(
      key: Key('cancel-engagement-${need.id}'),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) =>
            _CancelEngagementDialog(need: need, engagement: engagement),
      ),
      child: Text(label),
    );
  }
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
    return V5Dialog(
      title: 'Annuler mon engagement ?',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mission : ${widget.need.place}'),
          Text('Date : ${widget.need.date}'),
          Text('Horaires : ${widget.need.time}'),
          Text('Profession : ${widget.engagement.profession.label}'),
          const SizedBox(height: 12),
          const Text(
            'Votre participation sera annulée et vous ne serez plus compté '
            'parmi les professionnels mobilisés pour cette mission.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.red)),
          ],
        ],
      ),
      actions: [
        V5DialogAction(
          label: 'Retour',
          onPressed: _submitting ? null : () => Navigator.pop(context),
        ),
        V5DialogAction(
          key: const Key('confirm-cancel-engagement'),
          label: _submitting ? 'Désengagement…' : 'Confirmer mon désengagement',
          onPressed: _submitting ? null : _confirm,
          style: V5DialogActionStyle.destructive,
          loading: _submitting,
        ),
      ],
    );
  }
}

class MissionCancellationButton extends StatelessWidget {
  const MissionCancellationButton({
    super.key,
    required this.need,
    this.label = 'Annuler ce besoin',
    this.showIcon = true,
    this.foregroundColor,
  });

  final CoordinationNeed need;
  final String label;
  final bool showIcon;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    void onPressed() {
      showDialog<void>(
        context: context,
        builder: (_) => _CancelMissionDialog(need: need),
      );
    }

    if (!showIcon) {
      return TextButton(
        key: Key('cancel-mission-${need.id}'),
        onPressed: onPressed,
        style: foregroundColor == null
            ? null
            : TextButton.styleFrom(foregroundColor: foregroundColor),
        child: Text(label),
      );
    }
    return OutlinedButton.icon(
      key: Key('cancel-mission-${need.id}'),
      onPressed: onPressed,
      icon: const Icon(Icons.cancel_outlined),
      label: Text(label),
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
    return V5Dialog(
      title: 'Annuler ce besoin ?',
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
            V5TextField(
              key: const Key('cancellation-reason'),
              label: 'Motif de l’annulation',
              controller: _reason,
              maxLength: 300,
              maxLines: 3,
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.red)),
          ],
        ),
      ),
      actions: [
        V5DialogAction(
          label: 'Retour',
          onPressed: _submitting ? null : () => Navigator.pop(context),
        ),
        V5DialogAction(
          key: const Key('confirm-cancel-mission'),
          label: _submitting ? 'Annulation…' : 'Confirmer l’annulation',
          onPressed: _submitting ? null : _confirm,
          style: V5DialogActionStyle.destructive,
          loading: _submitting,
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
    final colors = context.v5Colors;
    if (_loadingProfile) {
      return SafeArea(
        child: ColoredBox(
          color: colors.canvas,
          child: const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: V5ActivityIndicator()),
          ),
        ),
      );
    }
    if (_profileError != null) {
      return SafeArea(
        child: ColoredBox(
          color: colors.canvas,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.dangerContainer,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.danger.withValues(alpha: 0.24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: colors.danger,
                      size: 30,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _profileError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    V5Button(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.onAccent,
                      onPressed: () {
                        setState(() {
                          _loadingProfile = true;
                          _profileError = null;
                        });
                        _loadProfile();
                      },
                      label: 'Réessayer',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return SafeArea(
      child: ColoredBox(
        color: colors.canvas,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            18,
            8,
            18,
            28 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PROFIL PROFESSIONNEL',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'S’inscrire à la mission',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 24,
                                  height: 1.12,
                                  letterSpacing: -0.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.need.place,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        const BrandMark(size: 46),
                      ],
                    ),
                    const SizedBox(height: AppFormLayout.sectionSpacing),
                    if (_isProfessionalIdentifierReady)
                      const _ProfessionalIdentifierReadyNotice()
                    else
                      _ProfessionalIdentifierRequiredNotice(
                        ordinalOnly: _isVeterinarian,
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('profile-information-consent-entry'),
                        onPressed: () => Navigator.of(context).push(
                          AppPageRoute<void>(
                            builder: (_) => const InformationConsentScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.fact_check_outlined, size: 17),
                        label: const Text('Informations et consentement'),
                      ),
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
                      _ProfileFormCard(
                        eyebrow: 'PROFESSION ET IDENTIFIANT',
                        title: 'Profession',
                        icon: Icons.medical_services_outlined,
                        child: RadioGroup<VolunteerProfession>(
                          groupValue: _profession,
                          onChanged: (value) => _selectProfession(value!),
                          child: Column(
                            children: [
                              for (final profession in _professions)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 7),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colors.surfaceMuted,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: colors.outline),
                                    ),
                                    child: RadioListTile<VolunteerProfession>(
                                      key: Key(
                                        'profession-${profession.canonicalId}',
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                      value: profession,
                                      enabled: _isAvailable(profession),
                                      title: Text(profession.label),
                                      subtitle: _isAvailable(profession)
                                          ? null
                                          : const Text(
                                              'Aucun besoin disponible',
                                            ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ProfileFormCard(
                        eyebrow: 'INFORMATIONS OBLIGATOIRES',
                        title: 'Identité',
                        icon: Icons.person_outline_rounded,
                        child: Column(
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final firstNameField = TextFormField(
                                  controller: _firstNameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Prénom',
                                  ),
                                  validator: _required,
                                );
                                final lastNameField = TextFormField(
                                  controller: _lastNameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Nom',
                                  ),
                                  validator: _required,
                                );
                                if (constraints.maxWidth < 300) {
                                  return Column(
                                    children: [
                                      firstNameField,
                                      const SizedBox(
                                        height: AppFormLayout.fieldSpacing,
                                      ),
                                      lastNameField,
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: firstNameField),
                                    const SizedBox(width: 12),
                                    Expanded(child: lastNameField),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: AppFormLayout.fieldSpacing),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone',
                              ),
                              validator: _phone,
                            ),
                            const SizedBox(height: AppFormLayout.fieldSpacing),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              validator: _email,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ProfileFormCard(
                        eyebrow: 'EXERCICE PROFESSIONNEL',
                        title: 'Identifiant professionnel',
                        icon: Icons.badge_outlined,
                        child: Column(
                          children: [
                            KeyedSubtree(
                              key: ValueKey(
                                'professional-id-type-${_isVeterinarian ? 'ordinal' : 'all'}',
                              ),
                              child: DropdownButtonFormField<ProfessionalIdType>(
                                key: const Key('professional-id-type'),
                                initialValue: _professionalIdType,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Identifiant professionnel *',
                                  helperText: 'Obligatoire pour participer.',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                items: _professionalIdTypeOptions
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(
                                          type.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
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
                            if (_professionalIdType !=
                                ProfessionalIdType.none) ...[
                              const SizedBox(
                                height: AppFormLayout.fieldSpacing,
                              ),
                              TextFormField(
                                key: const Key('professional-id-value'),
                                controller: _professionalIdController,
                                keyboardType:
                                    _professionalIdType ==
                                        ProfessionalIdType.rpps
                                    ? TextInputType.number
                                    : TextInputType.text,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  if (_professionalIdType ==
                                      ProfessionalIdType.rpps)
                                    FilteringTextInputFormatter.digitsOnly
                                  else
                                    FilteringTextInputFormatter.deny(
                                      RegExp(r'^\s+'),
                                    ),
                                  LengthLimitingTextInputFormatter(
                                    _professionalIdentifierMaxLength,
                                  ),
                                ],
                                decoration: InputDecoration(
                                  labelText:
                                      _professionalIdType ==
                                          ProfessionalIdType.rpps
                                      ? 'Numéro RPPS *'
                                      : 'Numéro ordinal *',
                                  helperText:
                                      _professionalIdType ==
                                          ProfessionalIdType.rpps
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ProfileFormCard(
                        eyebrow: 'RATTACHEMENT TERRITORIAL',
                        title: 'CPTS',
                        icon: Icons.hub_outlined,
                        child: Column(
                          children: [
                            DropdownButtonFormField<bool>(
                              key: const Key('cpts-choice'),
                              initialValue: _hasCpts,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'CPTS',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: false,
                                  child: Text(
                                    'Aucune',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: true,
                                  child: Text(
                                    'Renseigner une CPTS',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                              const SizedBox(
                                height: AppFormLayout.fieldSpacing,
                              ),
                              TextFormField(
                                controller: _cptsIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Identifiant CPTS',
                                ),
                                validator: _required,
                              ),
                              const SizedBox(
                                height: AppFormLayout.fieldSpacing,
                              ),
                              TextFormField(
                                controller: _cptsController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'CPTS',
                                ),
                                validator: _required,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ProfileFormCard(
                        eyebrow: 'MATÉRIEL DISPONIBLE',
                        title: 'Matériel que je peux apporter',
                        icon: Icons.medical_services_outlined,
                        child: Column(
                          children: [
                            for (final equipment in _equipmentOptions)
                              V5CheckboxTile(
                                key: Key('equipment-${equipment.id}'),
                                dense: true,
                                label: equipment.label,
                                value: _selectedEquipment.contains(
                                  equipment.id,
                                ),
                                onChanged: (selected) => setState(() {
                                  if (selected) {
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
                                V5CheckboxTile(
                                  key: Key('legacy-equipment-$equipment'),
                                  dense: true,
                                  label:
                                      ProfessionalEquipmentRegistry.displayLabel(
                                        equipment,
                                      ),
                                  subtitle: 'Non proposé pour cette profession',
                                  value: true,
                                  onChanged: (selected) {
                                    if (selected == false) {
                                      setState(
                                        () => _selectedEquipment.remove(
                                          equipment,
                                        ),
                                      );
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    V5Button(
                      expanded: true,
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      loading: _submitting,
                      onPressed: _submitting || !_hasAvailableProfession
                          ? null
                          : _submit,
                      label: _submitting
                          ? 'Confirmation…'
                          : 'CONFIRMER MA PARTICIPATION',
                    ),
                  ],
                ),
              ),
            ),
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
      AppPageRoute<void>(
        builder: (_) => EngagementConfirmationScreen(
          need: widget.need,
          profession: _profession,
          location: widget.location,
          result: result,
        ),
      ),
    );
  }
}

class _ProfileFormCard extends StatelessWidget {
  const _ProfileFormCard({
    required this.eyebrow,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline),
        boxShadow: V5Elevation.level1(colors),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: colors.textPrimary, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 17,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

class _ProfessionalIdentifierRequiredNotice extends StatelessWidget {
  const _ProfessionalIdentifierRequiredNotice({required this.ordinalOnly});

  final bool ordinalOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      key: const Key('professional-identifier-required'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.warningContainer,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.badge_outlined, color: colors.warning, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profil à compléter',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ordinalOnly
                      ? 'Votre numéro ordinal est obligatoire pour participer. '
                            'Complétez votre profil avant de confirmer votre '
                            'participation.'
                      : 'Un numéro RPPS ou ordinal est obligatoire pour '
                            'participer. Complétez votre profil avant de '
                            'confirmer votre participation.',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

class _ProfessionalIdentifierReadyNotice extends StatelessWidget {
  const _ProfessionalIdentifierReadyNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      key: const Key('professional-identifier-ready'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.successContainer,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: colors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: colors.success,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profil prêt à participer',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Votre identifiant professionnel est renseigné.',
                  style: TextStyle(
                    color: colors.textSecondary,
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
    final colors = context.v5Colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline),
        boxShadow: V5Elevation.level1(colors),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: colors.textPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MON PROFIL',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      profile.displayName,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: colors.outline),
          ),
          _ProfileSummaryItem(
            icon: Icons.medical_services_outlined,
            label: 'Profession',
            value: profile.profession.label,
          ),
          const SizedBox(height: 10),
          _ProfileSummaryItem(
            icon: Icons.phone_outlined,
            label: 'Téléphone',
            value: profile.phone,
          ),
          if (profile.email?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            _ProfileSummaryItem(
              icon: Icons.mail_outline_rounded,
              label: 'Email',
              value: profile.email!.trim(),
            ),
          ],
          if (profile.effectiveProfessionalIdType != ProfessionalIdType.none)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _ProfileSummaryItem(
                icon: Icons.badge_outlined,
                label: profile.effectiveProfessionalIdType.label,
                value: profile.effectiveProfessionalIdValue,
              ),
            ),
          const SizedBox(height: 10),
          _ProfileSummaryItem(
            icon: Icons.hub_outlined,
            label: 'CPTS',
            value: profile.cptsLabel?.trim().isNotEmpty ?? false
                ? profile.cptsLabel!
                : 'Aucune CPTS',
          ),
          if (profile.equipment.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ProfileSummaryItem(
              icon: Icons.medical_services_outlined,
              label: 'Matériel disponible',
              value: ProfessionalEquipmentRegistry.normalizeStoredValues(
                profile.equipment,
              ).map(ProfessionalEquipmentRegistry.displayLabel).join(' • '),
            ),
            if (profile.otherEquipmentDetails?.trim().isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _ProfileSummaryItem(
                  icon: Icons.add_box_outlined,
                  label: 'Précision',
                  value: profile.otherEquipmentDetails!.trim(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileSummaryItem extends StatelessWidget {
  const _ProfileSummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.textSecondary, size: 17),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  letterSpacing: 0.45,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
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
