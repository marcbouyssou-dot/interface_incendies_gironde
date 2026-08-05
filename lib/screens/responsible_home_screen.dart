import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/profession_quotas.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import 'coordination_screen.dart' show missionsVisibleToResponsible;
import 'create_need_screen.dart';

class ResponsibleHomeScreen extends StatefulWidget {
  const ResponsibleHomeScreen({super.key});

  @override
  State<ResponsibleHomeScreen> createState() => _ResponsibleHomeScreenState();
}

class _ResponsibleHomeScreenState extends State<ResponsibleHomeScreen> {
  LiveCoordinationData? _liveData;
  Stream<List<CoordinationNeed>>? _missions;
  Stream<List<ResponsePlace>>? _locations;
  Stream<ResponsibleAccess?>? _responsibleAccess;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liveData = LiveCoordinationDataScope.of(context);
    if (identical(liveData, _liveData)) return;
    _liveData = liveData;
    _missions = liveData.watchMissions();
    _locations = liveData.watchLocations();
    _responsibleAccess = liveData.watchResponsibleAccess();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return ColoredBox(
      key: const Key('responsible-home'),
      color: colors.canvas,
      child: StreamBuilder<ResponsibleAccess?>(
        stream: _responsibleAccess,
        builder: (context, accessSnapshot) {
          if (accessSnapshot.hasError) {
            return const _ResponsibleHomeUnavailable();
          }
          if (!accessSnapshot.hasData &&
              accessSnapshot.connectionState == ConnectionState.waiting) {
            return const _ResponsibleHomeLoading();
          }
          return StreamBuilder<List<CoordinationNeed>>(
            stream: _missions,
            builder: (context, missionsSnapshot) {
              if (missionsSnapshot.hasError) {
                return const _ResponsibleHomeUnavailable();
              }
              if (!missionsSnapshot.hasData) {
                return const _ResponsibleHomeLoading();
              }
              return StreamBuilder<List<ResponsePlace>>(
                stream: _locations,
                builder: (context, locationsSnapshot) {
                  if (locationsSnapshot.hasError) {
                    return const _ResponsibleHomeUnavailable();
                  }
                  if (!locationsSnapshot.hasData) {
                    return const _ResponsibleHomeLoading();
                  }
                  return _ResponsibleHomeContent(
                    access: accessSnapshot.data,
                    missions: missionsSnapshot.data!,
                    locations: locationsSnapshot.data!,
                    onCreateNeed: _openCreateNeed,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _openCreateNeed() {
    final liveData = _liveData!;
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: CreateNeedScreen(
            onViewMission: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

class _ResponsibleHomeContent extends StatelessWidget {
  const _ResponsibleHomeContent({
    required this.access,
    required this.missions,
    required this.locations,
    required this.onCreateNeed,
  });

  final ResponsibleAccess? access;
  final List<CoordinationNeed> missions;
  final List<ResponsePlace> locations;
  final VoidCallback onCreateNeed;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final visibleMissions = missionsVisibleToResponsible(
      missions: missions,
      locations: locations,
      access: access,
    );
    final planningNeeds = visibleMissions
        .where((need) => need.isActive && !need.isCancelled)
        .toList(growable: false);
    final openNeeds = planningNeeds
        .where((need) => need.status != NeedStatus.complete)
        .toList(growable: false);
    final quotas = ProfessionQuotas.aggregate(
      planningNeeds.map((need) => need.professionQuotas),
    );
    final remaining = quotas.values.fold<int>(
      0,
      (total, quota) => total + quota.missing,
    );
    final verdict = switch (remaining) {
      0 => 'Tout est couvert',
      1 => '1 poste reste à couvrir.',
      _ => '$remaining postes restent à couvrir.',
    };
    final teamSummary = quotas.requiredTotal == 0
        ? 'Aucune mobilisation n’est nécessaire pour le moment.'
        : quotas.registeredTotal == 0
        ? 'Aucun professionnel n’est encore confirmé sur le planning actuel.'
        : quotas.registeredTotal == 1
        ? '1 professionnel est confirmé sur le planning actuel.'
        : '${quotas.registeredTotal} professionnels sont confirmés sur le '
              'planning actuel.';

    return CustomScrollView(
      key: const PageStorageKey('responsible-home-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 44),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ResponsibleTopBar(),
                    const SizedBox(height: V5Spacing.xxl),
                    _PlanningHero(verdict: verdict, secured: remaining == 0),
                    const SizedBox(height: V5Spacing.xl),
                    _PlanningProgress(
                      registered: quotas.registeredTotal,
                      required: quotas.requiredTotal,
                      progress: quotas.coverage,
                    ),
                    const SizedBox(height: V5Spacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('responsible-create-need'),
                        onPressed: onCreateNeed,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: colors.info,
                          foregroundColor: _foregroundFor(colors.info, colors),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              V5Radius.control,
                            ),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Créer un besoin'),
                      ),
                    ),
                    const SizedBox(height: V5Spacing.xxxl),
                    Text(
                      'Besoins ouverts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: V5Spacing.md),
                    _OpenNeedsList(needs: openNeeds),
                    const SizedBox(height: V5Spacing.xxxl),
                    Text(
                      'Équipe',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: V5Spacing.md),
                    _TeamSummary(message: teamSummary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _foregroundFor(Color background, V5Colors colors) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : colors.canvas;
  }
}

class _ResponsibleTopBar extends StatelessWidget {
  const _ResponsibleTopBar();

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Text(
      'Responsable',
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: colors.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _PlanningProgress extends StatelessWidget {
  const _PlanningProgress({
    required this.registered,
    required this.required,
    required this.progress,
  });

  final int registered;
  final int required;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required == 0
              ? 'Aucun poste planifié'
              : '$registered sur $required postes couverts',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: V5Spacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(V5Radius.pill),
          child: LinearProgressIndicator(
            key: const Key('responsible-planning-progress'),
            value: progress,
            minHeight: 5,
            backgroundColor: colors.surfaceMuted,
            color: colors.info,
          ),
        ),
      ],
    );
  }
}

class _PlanningHero extends StatelessWidget {
  const _PlanningHero({required this.verdict, required this.secured});

  final String verdict;
  final bool secured;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Mon planning est-il sécurisé ? $verdict',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mon planning est-il sécurisé ?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.info,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: V5Spacing.sm),
            Text(
              verdict,
              key: const Key('responsible-planning-verdict'),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: colors.info,
                fontSize: 36,
                height: 1.06,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: V5Spacing.md),
            Container(
              width: 34,
              height: 5,
              decoration: BoxDecoration(
                color: secured
                    ? colors.info
                    : colors.info.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(V5Radius.pill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenNeedsList extends StatelessWidget {
  const _OpenNeedsList({required this.needs});

  final List<CoordinationNeed> needs;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    if (needs.isEmpty) {
      return Container(
        key: const Key('responsible-open-needs-empty'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: V5Spacing.lg,
          vertical: V5Spacing.xl,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(V5Radius.card),
        ),
        child: Text(
          'Aucun besoin ouvert.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return Container(
      key: const Key('responsible-open-needs'),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < needs.length; index++) ...[
            _OpenNeedRow(need: needs[index]),
            if (index < needs.length - 1)
              Divider(
                height: 1,
                thickness: 0.5,
                indent: V5Spacing.lg,
                endIndent: V5Spacing.lg,
                color: colors.outline.withValues(alpha: 0.75),
              ),
          ],
        ],
      ),
    );
  }
}

class _OpenNeedRow extends StatelessWidget {
  const _OpenNeedRow({required this.need});

  final CoordinationNeed need;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final remaining = need.professionQuotas.values.fold<int>(
      0,
      (total, quota) => total + quota.missing,
    );
    final attentionColor = need.status == NeedStatus.critical
        ? colors.danger
        : colors.warning;
    return Padding(
      key: Key('responsible-open-need-${need.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: V5Spacing.lg,
        vertical: V5Spacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  need.place,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: V5Spacing.md),
              Text(
                remaining == 1
                    ? '1 poste à couvrir'
                    : '$remaining postes à couvrir',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: attentionColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: V5Spacing.sm),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: colors.textSecondary,
              ),
              const SizedBox(width: V5Spacing.xs),
              Expanded(
                child: Text(
                  '${need.date} · ${need.time}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamSummary extends StatelessWidget {
  const _TeamSummary({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      key: const Key('responsible-team-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(V5Spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.people_outline_rounded, size: 20, color: colors.info),
          const SizedBox(width: V5Spacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsibleHomeLoading extends StatelessWidget {
  const _ResponsibleHomeLoading();

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(color: colors.info, strokeWidth: 2),
      ),
    );
  }
}

class _ResponsibleHomeUnavailable extends StatelessWidget {
  const _ResponsibleHomeUnavailable();

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(V5Spacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            'Le planning est temporairement indisponible.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
          ),
        ),
      ),
    );
  }
}
