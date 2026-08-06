import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/v5_foundation.dart';

/// Shared visual tokens for the MobSanté mobilization experience.
abstract final class MobilizationTokens {
  static const Color pageBackground = Color(0xFFF6F7F8);
  static const Color fieldBackground = Color(0xFFF1F1EF);

  static const double spaceXs = 6;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double spaceXxl = 24;

  static const double radiusCompact = 12;
  static const double radiusSection = 14;
  static const double radiusContentCard = 18;
  static const double radiusCard = 18;
  static const double radiusPill = 999;

  static const double actionHeight = 56;
  static const double iconSize = 20;
  static const double actionIconSize = 21;

  static const EdgeInsets heroPadding = EdgeInsets.fromLTRB(20, 22, 20, 24);
  static const EdgeInsets sectionPadding = EdgeInsets.all(15);
  static const EdgeInsets bannerPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 10,
  );

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A173052), blurRadius: 16, offset: Offset(0, 5)),
  ];

  static const List<BoxShadow> featuredCardShadow = [
    BoxShadow(color: Color(0x12F37A32), blurRadius: 20, offset: Offset(0, 5)),
    BoxShadow(color: Color(0x07173052), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> subtleShadow = [
    BoxShadow(color: Color(0x09173052), blurRadius: 14, offset: Offset(0, 4)),
  ];
}

enum ImpactBannerType {
  priority,
  reinforcementsExpected,
  teamComplete,
  mobilizationCovered,
  past,
  cancelled,
}

class ImpactBanner extends StatelessWidget {
  const ImpactBanner({
    super.key,
    required this.type,
    this.message,
    this.messageIcon,
    this.trailing,
    this.footer,
    this.compact = false,
    this.professionalPalette = false,
  });

  final ImpactBannerType type;
  final String? message;
  final IconData? messageIcon;
  final Widget? trailing;
  final Widget? footer;
  final bool compact;
  final bool professionalPalette;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final (label, icon, color, background) = switch (type) {
      ImpactBannerType.priority => (
        'Besoin prioritaire',
        Icons.priority_high_rounded,
        colors.danger,
        colors.dangerContainer,
      ),
      ImpactBannerType.reinforcementsExpected => (
        'Renforts attendus',
        Icons.groups_2_outlined,
        colors.warning,
        colors.warningContainer,
      ),
      ImpactBannerType.teamComplete => (
        'Équipe complète',
        Icons.check_circle_outline_rounded,
        professionalPalette ? colors.textSecondary : colors.success,
        professionalPalette ? colors.surfaceMuted : colors.successContainer,
      ),
      ImpactBannerType.mobilizationCovered => (
        'Mobilisation couverte',
        Icons.verified_outlined,
        colors.success,
        colors.successContainer,
      ),
      ImpactBannerType.past => (
        'Mission passée',
        Icons.history_rounded,
        colors.textSecondary,
        colors.surfaceMuted,
      ),
      ImpactBannerType.cancelled => (
        'Mission annulée',
        Icons.cancel_outlined,
        colors.textSecondary,
        colors.surfaceMuted,
      ),
    };
    final resolvedMessage = message?.trim();

    if (professionalPalette) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            color.withValues(alpha: 0.065),
            colors.surfaceElevated,
          ),
          borderRadius: BorderRadius.circular(V5Radius.compact),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 7),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (resolvedMessage != null && resolvedMessage.isNotEmpty)
                      TextSpan(
                        text: ' · $resolvedMessage',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                style: const TextStyle(fontSize: 12.5, height: 1.25),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: V5Spacing.xs),
              trailing!,
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: MobilizationTokens.bannerPadding,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.surface.withValues(alpha: 0.32),
          background,
        ),
        borderRadius: BorderRadius.circular(MobilizationTokens.radiusSection),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    letterSpacing: 0.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (compact && trailing != null) ...[
                const SizedBox(width: MobilizationTokens.spaceSm),
                trailing!,
              ],
            ],
          ),
          if (resolvedMessage != null && resolvedMessage.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(messageIcon ?? icon, color: color, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    resolvedMessage,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!compact && trailing != null) ...[
                  const SizedBox(width: MobilizationTokens.spaceSm),
                  trailing!,
                ],
              ],
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 9), footer!],
        ],
      ),
    );
  }
}

enum ProfessionChipState { needed, covered }

class ProfessionChip extends StatelessWidget {
  const ProfessionChip({
    super.key,
    required this.label,
    this.state = ProfessionChipState.needed,
    this.professionalPalette = false,
  });

  final String label;
  final ProfessionChipState state;
  final bool professionalPalette;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final covered = state == ProfessionChipState.covered;
    final color = covered
        ? colors.success
        : professionalPalette
        ? colors.info
        : colors.warning;
    return Container(
      constraints: BoxConstraints(minHeight: professionalPalette ? 30 : 34),
      padding: EdgeInsets.symmetric(
        horizontal: professionalPalette ? 9 : 10,
        vertical: professionalPalette ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: professionalPalette ? 0.065 : 0.08),
        borderRadius: BorderRadius.circular(MobilizationTokens.radiusPill),
        border: professionalPalette
            ? null
            : Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            covered
                ? Icons.check_circle_rounded
                : Icons.add_circle_outline_rounded,
            color: color,
            size: professionalPalette ? 14 : 16,
          ),
          SizedBox(width: professionalPalette ? 5 : 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: professionalPalette ? 11.5 : 12,
                fontWeight: professionalPalette
                    ? FontWeight.w700
                    : FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.backgroundColor = Colors.transparent,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: colors.textSecondary, size: 17),
                const SizedBox(width: MobilizationTokens.spaceSm),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    letterSpacing: 0.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class MobilizationHeroCard extends StatelessWidget {
  const MobilizationHeroCard({
    super.key,
    required this.locationType,
    required this.locationName,
    required this.dateLabel,
    required this.timeLabel,
    required this.impactBanner,
    required this.professionTitle,
    required this.professions,
    required this.primaryAction,
    required this.secondaryDetails,
    this.locationTypeKey,
    this.timingBadge,
    this.secondaryAction,
    this.featured = false,
    this.secondaryDetailsExpanded = true,
    this.secondaryDetailsToggleKey,
  });

  final String locationType;
  final String locationName;
  final String dateLabel;
  final String timeLabel;
  final Key? locationTypeKey;
  final Widget impactBanner;
  final String professionTitle;
  final List<Widget> professions;
  final Widget primaryAction;
  final Widget secondaryDetails;
  final Widget? timingBadge;
  final Widget? secondaryAction;
  final bool featured;
  final bool secondaryDetailsExpanded;
  final Key? secondaryDetailsToggleKey;

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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MobilizationTokens.radiusCard),
          border: Border.all(
            color: featured ? AppColors.orange : AppColors.border,
            width: featured ? 1.35 : 1,
          ),
          boxShadow: featured
              ? MobilizationTokens.featuredCardShadow
              : MobilizationTokens.cardShadow,
        ),
        child: Padding(
          padding: MobilizationTokens.heroPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LIEU DE MOBILISATION',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: MobilizationTokens.spaceXs),
              Text(
                locationType,
                key: locationTypeKey,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 23,
                  height: 1.1,
                  letterSpacing: -0.6,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                locationName,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: MobilizationTokens.bannerPadding,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F4),
                  borderRadius: BorderRadius.circular(
                    MobilizationTokens.radiusSection,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.navy,
                      size: MobilizationTokens.iconSize,
                    ),
                    const SizedBox(width: MobilizationTokens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateLabel,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            timeLabel,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 18,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (timingBadge != null) ...[
                      const SizedBox(width: 10),
                      timingBadge!,
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                professionTitle,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  height: 1.2,
                  letterSpacing: -0.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: MobilizationTokens.spaceSm,
                runSpacing: MobilizationTokens.spaceSm,
                children: professions,
              ),
              const SizedBox(height: 18),
              impactBanner,
              const SizedBox(height: 20),
              primaryAction,
              if (secondaryDetailsExpanded) ...[
                const SizedBox(height: 26),
                secondaryDetails,
              ] else ...[
                const SizedBox(height: 10),
                _SecondaryDetailsDisclosure(
                  toggleKey: secondaryDetailsToggleKey,
                  child: secondaryDetails,
                ),
              ],
              if (secondaryAction != null) ...[
                const SizedBox(height: 18),
                secondaryAction!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryDetailsDisclosure extends StatefulWidget {
  const _SecondaryDetailsDisclosure({required this.child, this.toggleKey});

  final Widget child;
  final Key? toggleKey;

  @override
  State<_SecondaryDetailsDisclosure> createState() =>
      _SecondaryDetailsDisclosureState();
}

class _SecondaryDetailsDisclosureState
    extends State<_SecondaryDetailsDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          child: TextButton.icon(
            key: widget.toggleKey,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              minimumSize: const Size(0, 42),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
            ),
            label: Text(_expanded ? 'Masquer les détails' : 'Voir les détails'),
          ),
        ),
        if (_expanded) ...[const SizedBox(height: 4), widget.child],
      ],
    );
  }
}
