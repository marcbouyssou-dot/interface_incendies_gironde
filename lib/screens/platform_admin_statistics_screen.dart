import 'package:flutter/material.dart';

import '../platform_admin/platform_admin_statistics_view_data.dart';
import '../repositories/platform_admin_statistics_read_repository.dart';
import '../theme/v5_foundation.dart';
import '../utils/operation_presentation.dart';
import '../widgets/professional_page_header.dart';

class PlatformAdminStatisticsScreen extends StatefulWidget {
  const PlatformAdminStatisticsScreen({super.key, required this.dataSource});

  final PlatformAdminStatisticsDataSource dataSource;

  @override
  State<PlatformAdminStatisticsScreen> createState() =>
      _PlatformAdminStatisticsScreenState();
}

class _PlatformAdminStatisticsScreenState
    extends State<PlatformAdminStatisticsScreen> {
  static const _allOperations = '__all_operations__';

  late Stream<PlatformAdminStatisticsViewData> _statistics;
  String? _operationId;

  @override
  void initState() {
    super.initState();
    _statistics = widget.dataSource.watchStatistics();
  }

  @override
  void didUpdateWidget(covariant PlatformAdminStatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.dataSource, widget.dataSource)) {
      _statistics = widget.dataSource.watchStatistics();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _statistics,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const _StatisticsMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Statistiques indisponibles',
          message: 'Réessayez dans quelques instants.',
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }
      final data = snapshot.data!;
      final selected = data.operationById(_operationId);
      final selectedId = selected?.operation.id;
      return CustomScrollView(
        key: const PageStorageKey('platform-admin-statistics'),
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
                Text(
                  'Statistiques',
                  key: const Key('platform-admin-statistics-title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: V5Spacing.xs),
                Text(
                  'Lecture opérationnelle actuelle, globale ou par opération.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.v5Colors.textSecondary,
                  ),
                ),
                const SizedBox(height: V5Spacing.lg),
                DropdownButtonFormField<String>(
                  key: ValueKey('statistics-operation-${selectedId ?? 'all'}'),
                  initialValue: selectedId ?? _allOperations,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Périmètre statistique',
                    prefixIcon: Icon(Icons.filter_alt_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: _allOperations,
                      child: Text('Toutes les opérations'),
                    ),
                    for (final operation in data.operations)
                      DropdownMenuItem(
                        value: operation.operation.id,
                        child: Text(
                          operation.operation.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(
                    () => _operationId = value == _allOperations ? null : value,
                  ),
                ),
                const SizedBox(height: V5Spacing.xl),
                if (selected == null)
                  _PlatformStatistics(data: data)
                else
                  _OperationStatistics(statistics: selected),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _PlatformStatistics extends StatelessWidget {
  const _PlatformStatistics({required this.data});

  final PlatformAdminStatisticsViewData data;

  @override
  Widget build(BuildContext context) {
    final dashboard = data.dashboard;
    final mostTense = data.platform.mostTenseProfession;
    return Column(
      key: const Key('platform-statistics-overview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatisticsSectionTitle(
          title: 'Vue plateforme',
          subtitle: 'Situation consolidée de toutes les opérations.',
        ),
        const SizedBox(height: V5Spacing.md),
        _StatisticsMetricGrid(
          metrics: [
            _StatisticsMetricData(
              key: const Key('statistics-platform-critical'),
              icon: Icons.warning_amber_rounded,
              value: '${dashboard.criticalMissionCount}',
              label: 'missions critiques',
              tone: dashboard.criticalMissionCount == 0
                  ? _MetricTone.success
                  : _MetricTone.danger,
            ),
            _StatisticsMetricData(
              key: const Key('statistics-platform-coverage'),
              icon: Icons.donut_large_rounded,
              value: _coverageLabel(dashboard.coverage),
              label: 'couverture globale',
              tone: _coverageTone(dashboard.coverage),
            ),
            _StatisticsMetricData(
              key: const Key('statistics-platform-operations'),
              icon: Icons.domain_rounded,
              value: '${dashboard.activeOperationCount}',
              label: 'opérations actives',
            ),
            _StatisticsMetricData(
              key: const Key('statistics-platform-mobilizations'),
              icon: Icons.hub_rounded,
              value: '${dashboard.activeMobilizationCount}',
              label: 'mobilisations actives',
            ),
            _StatisticsMetricData(
              key: const Key('statistics-platform-missions'),
              icon: Icons.assignment_rounded,
              value: '${dashboard.activeMissionCount}',
              label: 'missions actives',
            ),
            _StatisticsMetricData(
              key: const Key('statistics-platform-professionals'),
              icon: Icons.groups_rounded,
              value: '${dashboard.mobilizedProfessionalCount}',
              label: 'professionnels mobilisés',
            ),
            _StatisticsMetricData(
              key: const Key('statistics-platform-tense-profession'),
              icon: Icons.medical_services_outlined,
              value: mostTense?.shortLabel ?? 'Aucune',
              label: 'profession la plus tendue',
              detail: mostTense == null
                  ? 'besoin couvert'
                  : '${mostTense.missing} restant${mostTense.missing > 1 ? 's' : ''}',
              tone: mostTense == null
                  ? _MetricTone.success
                  : _MetricTone.warning,
            ),
            _StatisticsMetricData(
              key: const Key('statistics-platform-establishments'),
              icon: Icons.local_hospital_outlined,
              value: '${dashboard.establishmentCount}',
              label: 'établissements concernés',
            ),
          ],
        ),
        const SizedBox(height: V5Spacing.xxl),
        _StatisticsBreakdowns(breakdown: data.platform),
      ],
    );
  }
}

class _OperationStatistics extends StatelessWidget {
  const _OperationStatistics({required this.statistics});

  final OperationAdminStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final operation = statistics.operation;
    final snapshot = statistics.snapshot;
    final tenseProfessions = statistics.breakdown.tenseProfessions;
    return Column(
      key: Key('operation-statistics-${operation.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(V5Spacing.md),
          decoration: BoxDecoration(
            color: context.v5Colors.surfaceElevated,
            borderRadius: BorderRadius.circular(V5Radius.section),
            border: Border.all(color: context.v5Colors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                operation.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: V5Spacing.sm),
              Wrap(
                spacing: V5Spacing.xs,
                runSpacing: V5Spacing.xs,
                children: [
                  _InformationChip(
                    icon: Icons.circle_rounded,
                    label: operationStatusLabel(operation.status),
                  ),
                  for (final territory in statistics.territoryLabels)
                    _InformationChip(
                      icon: Icons.public_rounded,
                      label: territory,
                    ),
                ],
              ),
              const SizedBox(height: V5Spacing.md),
              _CoordinatorLine(uid: statistics.coordinatorUid),
            ],
          ),
        ),
        const SizedBox(height: V5Spacing.xl),
        _StatisticsSectionTitle(
          title: 'Situation de l’opération',
          subtitle: operationStatusLabel(operation.status),
        ),
        const SizedBox(height: V5Spacing.md),
        _StatisticsMetricGrid(
          metrics: [
            _StatisticsMetricData(
              key: const Key('statistics-operation-mobilizations'),
              icon: Icons.hub_rounded,
              value: '${snapshot.mobilizations.length}',
              label: 'mobilisations',
            ),
            _StatisticsMetricData(
              key: const Key('statistics-operation-missions'),
              icon: Icons.assignment_rounded,
              value: '${snapshot.missionCount}',
              label: 'missions actives',
            ),
            _StatisticsMetricData(
              key: const Key('statistics-operation-critical'),
              icon: Icons.warning_amber_rounded,
              value: '${snapshot.criticalMissionCount}',
              label: 'missions critiques',
              tone: snapshot.criticalMissionCount == 0
                  ? _MetricTone.success
                  : _MetricTone.danger,
            ),
            _StatisticsMetricData(
              key: const Key('statistics-operation-coverage'),
              icon: Icons.donut_large_rounded,
              value: _coverageLabel(snapshot.coverage),
              label: 'couverture',
              tone: _coverageTone(snapshot.coverage),
            ),
            _StatisticsMetricData(
              key: const Key('statistics-operation-remaining'),
              icon: Icons.person_search_outlined,
              value: '${statistics.remainingProfessionalCount}',
              label: 'besoins restants',
              tone: statistics.remainingProfessionalCount == 0
                  ? _MetricTone.success
                  : _MetricTone.warning,
            ),
            _StatisticsMetricData(
              key: const Key('statistics-operation-professionals'),
              icon: Icons.groups_rounded,
              value: '${snapshot.mobilizedProfessionalCount}',
              label: 'professionnels mobilisés',
            ),
            _StatisticsMetricData(
              key: const Key('statistics-operation-establishments'),
              icon: Icons.local_hospital_outlined,
              value: '${snapshot.establishmentCount}',
              label: 'établissements concernés',
            ),
          ],
        ),
        const SizedBox(height: V5Spacing.xxl),
        _TenseProfessions(professions: tenseProfessions),
        const SizedBox(height: V5Spacing.xxl),
        _StatisticsBreakdowns(breakdown: statistics.breakdown),
      ],
    );
  }
}

class _CoordinatorLine extends StatelessWidget {
  const _CoordinatorLine({required this.uid});

  final String? uid;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.supervisor_account_outlined,
        size: 20,
        color: context.v5Colors.textSecondary,
      ),
      const SizedBox(width: V5Spacing.xs),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Coordinateur',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: V5Spacing.xxs),
            Text(
              uid == null ? 'Non nommé' : 'Nommé · $uid',
              key: const Key('statistics-operation-coordinator'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.v5Colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _InformationChip extends StatelessWidget {
  const _InformationChip({required this.icon, required this.label});

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

class _TenseProfessions extends StatelessWidget {
  const _TenseProfessions({required this.professions});

  final List<ProfessionStatistics> professions;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('statistics-tense-professions'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _StatisticsSectionTitle(title: 'Professions en tension'),
      const SizedBox(height: V5Spacing.sm),
      if (professions.isEmpty)
        const _CompactInformation(
          icon: Icons.check_circle_outline_rounded,
          text: 'Aucune profession en tension.',
        )
      else
        Wrap(
          spacing: V5Spacing.xs,
          runSpacing: V5Spacing.xs,
          children: [
            for (final profession in professions)
              _InformationChip(
                icon: Icons.medical_services_outlined,
                label:
                    '${profession.label} · ${profession.missing} restant${profession.missing > 1 ? 's' : ''}',
              ),
          ],
        ),
    ],
  );
}

class _StatisticsMetricGrid extends StatelessWidget {
  const _StatisticsMetricGrid({required this.metrics});

  final List<_StatisticsMetricData> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final singleColumn =
          constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final columns = singleColumn ? 1 : 2;
      final width =
          (constraints.maxWidth - V5Spacing.sm * (columns - 1)) / columns;
      return Wrap(
        key: const Key('statistics-metric-grid'),
        spacing: V5Spacing.sm,
        runSpacing: V5Spacing.sm,
        children: [
          for (final metric in metrics)
            SizedBox(
              width: width,
              child: _StatisticsMetric(metric: metric),
            ),
        ],
      );
    },
  );
}

enum _MetricTone { neutral, success, warning, danger }

class _StatisticsMetricData {
  const _StatisticsMetricData({
    required this.key,
    required this.icon,
    required this.value,
    required this.label,
    this.detail,
    this.tone = _MetricTone.neutral,
  });

  final Key key;
  final IconData icon;
  final String value;
  final String label;
  final String? detail;
  final _MetricTone tone;
}

class _StatisticsMetric extends StatelessWidget {
  const _StatisticsMetric({required this.metric});

  final _StatisticsMetricData metric;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final foreground = switch (metric.tone) {
      _MetricTone.neutral => colors.textPrimary,
      _MetricTone.success => colors.success,
      _MetricTone.warning => colors.warning,
      _MetricTone.danger => colors.danger,
    };
    return Semantics(
      container: true,
      label:
          '${metric.value}, ${metric.label}${metric.detail == null ? '' : ', ${metric.detail}'}',
      child: ExcludeSemantics(
        child: Container(
          key: metric.key,
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.all(V5Spacing.sm),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(V5Radius.section),
            border: Border.all(color: foreground.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(metric.icon, size: 19, color: foreground),
              const SizedBox(height: V5Spacing.xs),
              Text(
                metric.value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: V5Spacing.xxs),
              Text(
                metric.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (metric.detail case final detail?) ...[
                const SizedBox(height: V5Spacing.xxs),
                Text(
                  detail,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatisticsBreakdowns extends StatelessWidget {
  const _StatisticsBreakdowns({required this.breakdown});

  final OperationalStatisticsBreakdown breakdown;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('statistics-breakdowns'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _ProfessionBreakdown(professions: breakdown.professions),
      const SizedBox(height: V5Spacing.xxl),
      _GroupBreakdown(
        key: const Key('statistics-territories'),
        title: 'Par territoire',
        emptyText: 'Aucun territoire concerné.',
        groups: breakdown.territories,
      ),
      const SizedBox(height: V5Spacing.xxl),
      _GroupBreakdown(
        key: const Key('statistics-establishments'),
        title: 'Par établissement',
        emptyText: 'Aucun établissement concerné.',
        groups: breakdown.establishments,
      ),
    ],
  );
}

class _ProfessionBreakdown extends StatelessWidget {
  const _ProfessionBreakdown({required this.professions});

  final List<ProfessionStatistics> professions;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('statistics-professions'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _StatisticsSectionTitle(title: 'Par profession'),
      const SizedBox(height: V5Spacing.sm),
      if (professions.isEmpty)
        const _CompactInformation(
          icon: Icons.medical_services_outlined,
          text: 'Aucun besoin professionnel actif.',
        )
      else
        _BreakdownCard(
          children: [
            for (var index = 0; index < professions.length; index++) ...[
              _BreakdownRow(
                key: Key('statistics-profession-${professions[index].id}'),
                label: professions[index].label,
                registered: professions[index].registered,
                required: professions[index].required,
                missing: professions[index].missing,
                coverage: professions[index].coverage,
              ),
              if (index < professions.length - 1) const Divider(height: 1),
            ],
          ],
        ),
    ],
  );
}

class _GroupBreakdown extends StatelessWidget {
  const _GroupBreakdown({
    super.key,
    required this.title,
    required this.emptyText,
    required this.groups,
  });

  final String title;
  final String emptyText;
  final List<OperationalGroupStatistics> groups;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _StatisticsSectionTitle(title: title),
      const SizedBox(height: V5Spacing.sm),
      if (groups.isEmpty)
        _CompactInformation(icon: Icons.layers_outlined, text: emptyText)
      else
        _BreakdownCard(
          children: [
            for (var index = 0; index < groups.length; index++) ...[
              _BreakdownRow(
                key: Key('statistics-group-${groups[index].id}'),
                label: groups[index].label,
                registered: groups[index].registered,
                required: groups[index].required,
                missing: groups[index].missing,
                coverage: groups[index].coverage,
                missionCount: groups[index].missionCount,
              ),
              if (index < groups.length - 1) const Divider(height: 1),
            ],
          ],
        ),
    ],
  );
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: V5Spacing.md),
    decoration: BoxDecoration(
      color: context.v5Colors.surfaceElevated,
      borderRadius: BorderRadius.circular(V5Radius.section),
      border: Border.all(color: context.v5Colors.outline),
    ),
    child: Column(children: children),
  );
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    super.key,
    required this.label,
    required this.registered,
    required this.required,
    required this.missing,
    required this.coverage,
    this.missionCount,
  });

  final String label;
  final int registered;
  final int required;
  final int missing;
  final double coverage;
  final int? missionCount;

  @override
  Widget build(BuildContext context) {
    final critical = missing > 0;
    return Semantics(
      container: true,
      label:
          '$label. $registered sur $required mobilisés. $missing besoins restants${missionCount == null ? '' : '. $missionCount missions'}.',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: V5Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: V5Spacing.sm),
                  Text(
                    '$registered / $required',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: critical
                          ? context.v5Colors.warning
                          : context.v5Colors.success,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: V5Spacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(V5Radius.pill),
                child: LinearProgressIndicator(
                  value: coverage,
                  minHeight: 6,
                  color: critical
                      ? context.v5Colors.warning
                      : context.v5Colors.success,
                  backgroundColor: context.v5Colors.surfaceMuted,
                ),
              ),
              const SizedBox(height: V5Spacing.xs),
              Text(
                [
                  '$missing restant${missing > 1 ? 's' : ''}',
                  if (missionCount case final count?)
                    '$count mission${count > 1 ? 's' : ''}',
                ].join(' · '),
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
}

class _StatisticsSectionTitle extends StatelessWidget {
  const _StatisticsSectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (subtitle case final subtitle?) ...[
        const SizedBox(height: V5Spacing.xxs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.v5Colors.textSecondary,
          ),
        ),
      ],
    ],
  );
}

class _CompactInformation extends StatelessWidget {
  const _CompactInformation({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    padding: const EdgeInsets.all(V5Spacing.sm),
    decoration: BoxDecoration(
      color: context.v5Colors.surfaceMuted,
      borderRadius: BorderRadius.circular(V5Radius.compact),
    ),
    child: Row(
      children: [
        Icon(icon, color: context.v5Colors.textSecondary),
        const SizedBox(width: V5Spacing.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _StatisticsMessage extends StatelessWidget {
  const _StatisticsMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(V5Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: context.v5Colors.textSecondary),
          const SizedBox(height: V5Spacing.md),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: V5Spacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.v5Colors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

String _coverageLabel(double? coverage) =>
    coverage == null ? '—' : '${(coverage * 100).round()} %';

_MetricTone _coverageTone(double? coverage) {
  if (coverage == null) return _MetricTone.neutral;
  if (coverage >= .8) return _MetricTone.success;
  if (coverage >= .5) return _MetricTone.warning;
  return _MetricTone.danger;
}
