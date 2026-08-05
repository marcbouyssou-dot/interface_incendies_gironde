import 'package:flutter/material.dart';

import '../theme/v5_foundation.dart';

enum MissionCardState {
  available,
  urgent,
  almostComplete,
  complete,
  past,
  loading,
}

class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.state,
    required this.locationType,
    required this.locationName,
    required this.dateLabel,
    required this.timeLabel,
    required this.need,
    required this.professionTitle,
    required this.professions,
    required this.primaryAction,
    required this.secondaryDetails,
    this.locationTypeKey,
    this.timingBadge,
    this.secondaryAction,
    this.secondaryDetailsExpanded = true,
    this.secondaryDetailsToggleKey,
    this.professionalPalette = false,
  });

  const MissionCard.loading({super.key})
    : state = MissionCardState.loading,
      locationType = '',
      locationName = '',
      dateLabel = '',
      timeLabel = '',
      need = const SizedBox.shrink(),
      professionTitle = '',
      professions = const [],
      primaryAction = const SizedBox.shrink(),
      secondaryDetails = const SizedBox.shrink(),
      locationTypeKey = null,
      timingBadge = null,
      secondaryAction = null,
      secondaryDetailsExpanded = true,
      secondaryDetailsToggleKey = null,
      professionalPalette = false;

  final MissionCardState state;
  final String locationType;
  final String locationName;
  final String dateLabel;
  final String timeLabel;
  final Key? locationTypeKey;
  final Widget need;
  final String professionTitle;
  final List<Widget> professions;
  final Widget primaryAction;
  final Widget secondaryDetails;
  final Widget? timingBadge;
  final Widget? secondaryAction;
  final bool secondaryDetailsExpanded;
  final Key? secondaryDetailsToggleKey;
  final bool professionalPalette;

  @override
  Widget build(BuildContext context) {
    if (state == MissionCardState.loading) {
      return const _MissionCardLoading();
    }

    final colors = context.v5Colors;
    final accent = _accentFor(colors);
    final card = Semantics(
      container: true,
      label: _semanticLabel,
      child: Container(
        key: const Key('mission-card-surface'),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(V5Radius.card),
          border: professionalPalette
              ? null
              : Border.all(
                  color: accent.withValues(
                    alpha: state == MissionCardState.available ? 0.24 : 0.48,
                  ),
                  width: state == MissionCardState.urgent ? 1.5 : 1,
                ),
          boxShadow: professionalPalette
              ? [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.045),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ]
              : state == MissionCardState.urgent
              ? V5Elevation.level2(colors)
              : V5Elevation.level1(colors),
        ),
        child: Padding(
          padding: professionalPalette
              ? const EdgeInsets.fromLTRB(16, 17, 16, 14)
              : const EdgeInsets.fromLTRB(
                  V5Spacing.lg,
                  V5Spacing.xl,
                  V5Spacing.lg,
                  V5Spacing.xl,
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                locationType.toUpperCase(),
                key: locationTypeKey,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
              ),
              SizedBox(height: professionalPalette ? 4 : V5Spacing.xs),
              Text(
                locationName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: professionalPalette ? 14 : V5Spacing.lg),
              _MissionSchedule(
                dateLabel: dateLabel,
                timeLabel: timeLabel,
                timingBadge: timingBadge,
                professionalPalette: professionalPalette,
              ),
              SizedBox(height: professionalPalette ? 14 : V5Spacing.lg),
              Text(
                professionTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: professionalPalette ? 14 : null,
                ),
              ),
              SizedBox(height: professionalPalette ? 7 : V5Spacing.sm),
              Wrap(
                spacing: V5Spacing.xs,
                runSpacing: V5Spacing.xs,
                children: professions,
              ),
              SizedBox(height: professionalPalette ? 13 : V5Spacing.lg),
              need,
              SizedBox(height: professionalPalette ? 14 : V5Spacing.lg),
              primaryAction,
              if (secondaryDetailsExpanded) ...[
                SizedBox(height: professionalPalette ? 16 : V5Spacing.xl),
                secondaryDetails,
              ] else ...[
                SizedBox(height: professionalPalette ? 2 : V5Spacing.xs),
                _MissionDetailsDisclosure(
                  toggleKey: secondaryDetailsToggleKey,
                  professionalPalette: professionalPalette,
                  child: secondaryDetails,
                ),
              ],
              if (secondaryAction != null) ...[
                const SizedBox(height: V5Spacing.md),
                secondaryAction!,
              ],
            ],
          ),
        ),
      ),
    );

    if (state != MissionCardState.past) return card;
    return Opacity(opacity: 0.72, child: card);
  }

  Color _accentFor(V5Colors colors) => switch (state) {
    MissionCardState.available => colors.info,
    MissionCardState.urgent => colors.danger,
    MissionCardState.almostComplete => colors.warning,
    MissionCardState.complete =>
      professionalPalette ? colors.outline : colors.success,
    MissionCardState.past => colors.outline,
    MissionCardState.loading => colors.outline,
  };

  String get _semanticLabel => switch (state) {
    MissionCardState.available => 'Mission disponible à $locationName',
    MissionCardState.urgent => 'Mission urgente à $locationName',
    MissionCardState.almostComplete =>
      'Mission presque complète à $locationName',
    MissionCardState.complete => 'Mission complète à $locationName',
    MissionCardState.past => 'Mission passée à $locationName',
    MissionCardState.loading => 'Chargement de la mission',
  };
}

class _MissionSchedule extends StatelessWidget {
  const _MissionSchedule({
    required this.dateLabel,
    required this.timeLabel,
    this.timingBadge,
    this.professionalPalette = false,
  });

  final String dateLabel;
  final String timeLabel;
  final Widget? timingBadge;
  final bool professionalPalette;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: professionalPalette ? 12 : V5Spacing.md,
        vertical: professionalPalette ? 9 : V5Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: professionalPalette
            ? Color.alphaBlend(
                colors.surface.withValues(alpha: 0.64),
                colors.surfaceMuted,
              )
            : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(
          professionalPalette ? V5Radius.control : V5Radius.section,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            color: professionalPalette
                ? colors.textSecondary
                : colors.textPrimary,
            size: professionalPalette ? 16 : 20,
          ),
          SizedBox(width: professionalPalette ? 9 : V5Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: professionalPalette ? 11 : null,
                  ),
                ),
                SizedBox(height: professionalPalette ? 1 : V5Spacing.xxs),
                Text(
                  timeLabel,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: professionalPalette ? 17 : null,
                  ),
                ),
              ],
            ),
          ),
          if (timingBadge != null) ...[
            const SizedBox(width: V5Spacing.xs),
            timingBadge!,
          ],
        ],
      ),
    );
  }
}

class _MissionDetailsDisclosure extends StatefulWidget {
  const _MissionDetailsDisclosure({
    required this.child,
    this.toggleKey,
    this.professionalPalette = false,
  });

  final Widget child;
  final Key? toggleKey;
  final bool professionalPalette;

  @override
  State<_MissionDetailsDisclosure> createState() =>
      _MissionDetailsDisclosureState();
}

class _MissionDetailsDisclosureState extends State<_MissionDetailsDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          key: widget.toggleKey,
          style: TextButton.styleFrom(
            foregroundColor: colors.textSecondary,
            padding: EdgeInsets.symmetric(
              vertical: widget.professionalPalette ? 2 : V5Spacing.xs,
            ),
            minimumSize: const Size(0, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: TextStyle(
              fontSize: widget.professionalPalette ? 12.5 : null,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(
            _expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: widget.professionalPalette ? 17 : null,
          ),
          label: Text(_expanded ? 'Masquer les détails' : 'Voir les détails'),
        ),
        if (_expanded) ...[const SizedBox(height: V5Spacing.xxs), widget.child],
      ],
    );
  }
}

class _MissionCardLoading extends StatelessWidget {
  const _MissionCardLoading();

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Semantics(
      label: 'Chargement de la mission',
      child: Container(
        key: const Key('mission-card-loading'),
        padding: const EdgeInsets.all(V5Spacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(V5Radius.card),
          border: Border.all(color: colors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MissionSkeleton(widthFactor: 0.38, height: 12, colors: colors),
            const SizedBox(height: V5Spacing.sm),
            _MissionSkeleton(widthFactor: 0.72, height: 24, colors: colors),
            const SizedBox(height: V5Spacing.lg),
            _MissionSkeleton(widthFactor: 1, height: 68, colors: colors),
            const SizedBox(height: V5Spacing.lg),
            _MissionSkeleton(widthFactor: 0.54, height: 18, colors: colors),
            const SizedBox(height: V5Spacing.sm),
            _MissionSkeleton(widthFactor: 0.82, height: 34, colors: colors),
            const SizedBox(height: V5Spacing.lg),
            _MissionSkeleton(widthFactor: 1, height: 52, colors: colors),
          ],
        ),
      ),
    );
  }
}

class _MissionSkeleton extends StatelessWidget {
  const _MissionSkeleton({
    required this.widthFactor,
    required this.height,
    required this.colors,
  });

  final double widthFactor;
  final double height;
  final V5Colors colors;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(V5Radius.compact),
        ),
      ),
    );
  }
}
