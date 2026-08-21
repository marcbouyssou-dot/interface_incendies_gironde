import 'package:flutter/material.dart';

import '../models/operation.dart';
import '../platform_admin/platform_admin_history_view_data.dart';
import '../platform_admin/platform_admin_statistics_view_data.dart';
import '../repositories/platform_admin_history_read_repository.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../utils/operation_presentation.dart';
import '../widgets/professional_page_header.dart';

class PlatformAdminHistoryScreen extends StatefulWidget {
  const PlatformAdminHistoryScreen({
    super.key,
    required this.dataSource,
    this.referenceTime,
  });

  final PlatformAdminHistoryDataSource dataSource;
  final DateTime? referenceTime;

  @override
  State<PlatformAdminHistoryScreen> createState() =>
      _PlatformAdminHistoryScreenState();
}

class _PlatformAdminHistoryScreenState
    extends State<PlatformAdminHistoryScreen> {
  late Stream<PlatformAdminHistoryViewData> _history;
  final _searchController = TextEditingController();
  PlatformAdminHistoryFilter _filter = const PlatformAdminHistoryFilter();

  @override
  void initState() {
    super.initState();
    _history = widget.dataSource.watchHistory();
  }

  @override
  void didUpdateWidget(covariant PlatformAdminHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.dataSource, widget.dataSource)) {
      _history = widget.dataSource.watchHistory();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilters(PlatformAdminHistoryViewData data) async {
    final selected = await showModalBottomSheet<PlatformAdminHistoryFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _HistoryFilterSheet(data: data, initial: _filter),
    );
    if (selected != null && mounted) setState(() => _filter = selected);
  }

  void _openOperation(PlatformHistoryOperation operation) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => PlatformAdminHistoryDetailScreen(entry: operation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _history,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const _HistoryMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Historique indisponible',
          message: 'Réessayez dans quelques instants.',
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }
      final data = snapshot.data!;
      final operations = data.filtered(
        _filter,
        now: widget.referenceTime ?? DateTime.now(),
      );
      return CustomScrollView(
        key: const PageStorageKey('platform-admin-history'),
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
                  'Historique',
                  key: const Key('platform-admin-history-title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: V5Spacing.xs),
                Text(
                  'Retrouvez les opérations terminées et archivées.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.v5Colors.textSecondary,
                  ),
                ),
                const SizedBox(height: V5Spacing.lg),
                TextField(
                  key: const Key('platform-history-search'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Rechercher',
                    hintText: 'Nom, territoire, type…',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) =>
                      setState(() => _filter = _filter.copyWith(search: value)),
                ),
                const SizedBox(height: V5Spacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('platform-history-filters'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => _openFilters(data),
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(
                      _filter.activeCount == 0
                          ? 'Filtrer'
                          : 'Filtres (${_filter.activeCount})',
                    ),
                  ),
                ),
                if (_filter.activeCount > 0) ...[
                  const SizedBox(height: V5Spacing.sm),
                  _ActiveHistoryFilters(
                    filter: _filter,
                    data: data,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                ],
                const SizedBox(height: V5Spacing.lg),
                Text(
                  '${operations.length} opération${operations.length > 1 ? 's' : ''}',
                  key: const Key('platform-history-result-count'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: V5Spacing.sm),
                if (operations.isEmpty)
                  const _HistoryEmptyState()
                else
                  for (var index = 0; index < operations.length; index++) ...[
                    _HistoryOperationCard(
                      entry: operations[index],
                      onTap: () => _openOperation(operations[index]),
                    ),
                    if (index < operations.length - 1)
                      const SizedBox(height: V5Spacing.sm),
                  ],
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _HistoryOperationCard extends StatelessWidget {
  const _HistoryOperationCard({required this.entry, required this.onTap});

  final PlatformHistoryOperation entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final operation = entry.operation;
    final colors = context.v5Colors;
    return Semantics(
      button: true,
      label:
          '${operation.name}. ${operationStatusLabel(operation.status)}. '
          '${entry.missionCount} missions. Ouvrir le bilan.',
      child: Material(
        color: colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V5Radius.card),
          side: BorderSide(color: colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('platform-history-operation-${operation.id}'),
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
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: V5Spacing.sm),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: V5Spacing.xs),
                Wrap(
                  spacing: V5Spacing.xs,
                  runSpacing: V5Spacing.xs,
                  children: [
                    _HistoryTag(
                      label: operationStatusLabel(operation.status),
                      icon: operation.status == OperationStatus.archived
                          ? Icons.archive_outlined
                          : Icons.task_alt_rounded,
                    ),
                    _HistoryTag(
                      label: operationTypeLabel(operation.type),
                      icon: Icons.category_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: V5Spacing.sm),
                Text(
                  _operationPeriod(context, operation),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
                if (entry.territories.isNotEmpty) ...[
                  const SizedBox(height: V5Spacing.xxs),
                  Text(
                    entry.territories
                        .map((territory) => territory.label)
                        .join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: V5Spacing.sm),
                Text(
                  entry.coordinatorUid == null
                      ? 'Coordinateur · Non nommé'
                      : 'Coordinateur · ${entry.coordinatorUid}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: V5Spacing.md),
                _HistoryMetricWrap(entry: entry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryMetricWrap extends StatelessWidget {
  const _HistoryMetricWrap({required this.entry});

  final PlatformHistoryOperation entry;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final singleColumn = MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final columns = singleColumn ? 1 : 2;
      final width =
          (constraints.maxWidth - V5Spacing.xs * (columns - 1)) / columns;
      final values = [
        ('${entry.mobilizationCount}', 'mobilisations'),
        ('${entry.missionCount}', 'missions'),
        ('${entry.mobilizedProfessionalCount}', 'professionnels'),
        (_coverageLabel(entry.coverage), 'couverture finale'),
        ('${entry.remainingProfessionalCount}', 'besoins restants'),
        ('${entry.criticalMissionCount}', 'critiques finales'),
      ];
      return Wrap(
        spacing: V5Spacing.xs,
        runSpacing: V5Spacing.xs,
        children: [
          for (final value in values)
            SizedBox(
              width: width,
              child: _HistoryInlineMetric(value: value.$1, label: value.$2),
            ),
        ],
      );
    },
  );
}

class _HistoryInlineMetric extends StatelessWidget {
  const _HistoryInlineMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    padding: const EdgeInsets.all(V5Spacing.xs),
    decoration: BoxDecoration(
      color: context.v5Colors.surfaceMuted,
      borderRadius: BorderRadius.circular(V5Radius.compact),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$value ',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          TextSpan(text: label),
        ],
      ),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.v5Colors.textSecondary),
    ),
  );
}

class _HistoryTag extends StatelessWidget {
  const _HistoryTag({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: V5Spacing.xs,
      vertical: V5Spacing.xxs,
    ),
    decoration: BoxDecoration(
      color: context.v5Colors.surfaceMuted,
      borderRadius: BorderRadius.circular(V5Radius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: context.v5Colors.textSecondary),
        const SizedBox(width: V5Spacing.xxs),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
      ],
    ),
  );
}

class _ActiveHistoryFilters extends StatelessWidget {
  const _ActiveHistoryFilters({
    required this.filter,
    required this.data,
    required this.onChanged,
  });

  final PlatformAdminHistoryFilter filter;
  final PlatformAdminHistoryViewData data;
  final ValueChanged<PlatformAdminHistoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final territory = data.territories
        .where((item) => item.id == filter.territoryId)
        .firstOrNull;
    return Wrap(
      spacing: V5Spacing.xs,
      runSpacing: V5Spacing.xs,
      children: [
        if (filter.period != PlatformHistoryPeriod.all)
          InputChip(
            label: Text(filter.period.label),
            onDeleted: () =>
                onChanged(filter.copyWith(period: PlatformHistoryPeriod.all)),
          ),
        if (territory != null)
          InputChip(
            label: Text(territory.label),
            onDeleted: () => onChanged(filter.copyWith(clearTerritory: true)),
          ),
        if (filter.type case final type?)
          InputChip(
            label: Text(operationTypeLabel(type)),
            onDeleted: () => onChanged(filter.copyWith(clearType: true)),
          ),
        if (filter.status case final status?)
          InputChip(
            label: Text(operationStatusLabel(status)),
            onDeleted: () => onChanged(filter.copyWith(clearStatus: true)),
          ),
      ],
    );
  }
}

class _HistoryFilterSheet extends StatefulWidget {
  const _HistoryFilterSheet({required this.data, required this.initial});

  final PlatformAdminHistoryViewData data;
  final PlatformAdminHistoryFilter initial;

  @override
  State<_HistoryFilterSheet> createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends State<_HistoryFilterSheet> {
  late PlatformAdminHistoryFilter _value = widget.initial;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .82,
    minChildSize: .5,
    maxChildSize: .96,
    builder: (context, controller) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            V5Spacing.lg,
            0,
            V5Spacing.lg,
            V5Spacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Filtres',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              TextButton(
                key: const Key('platform-history-clear-filters'),
                onPressed: () => setState(
                  () => _value = PlatformAdminHistoryFilter(
                    search: _value.search,
                  ),
                ),
                child: const Text('Tout effacer'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.symmetric(horizontal: V5Spacing.lg),
            children: [
              _HistoryChoiceSection<PlatformHistoryPeriod>(
                title: 'Période',
                values: PlatformHistoryPeriod.values,
                selected: _value.period,
                label: (value) => value.label,
                onSelected: (value) =>
                    setState(() => _value = _value.copyWith(period: value)),
              ),
              if (widget.data.territories.isNotEmpty)
                _HistoryChoiceSection<String?>(
                  title: 'Territoire',
                  values: [
                    null,
                    ...widget.data.territories.map((item) => item.id),
                  ],
                  selected: _value.territoryId,
                  label: (value) => value == null
                      ? 'Tous'
                      : widget.data.territories
                            .firstWhere((item) => item.id == value)
                            .label,
                  onSelected: (value) => setState(
                    () => _value = _value.copyWith(
                      territoryId: value,
                      clearTerritory: value == null,
                    ),
                  ),
                ),
              if (widget.data.types.isNotEmpty)
                _HistoryChoiceSection<OperationType?>(
                  title: 'Type',
                  values: [null, ...widget.data.types],
                  selected: _value.type,
                  label: (value) =>
                      value == null ? 'Tous' : operationTypeLabel(value),
                  onSelected: (value) => setState(
                    () => _value = _value.copyWith(
                      type: value,
                      clearType: value == null,
                    ),
                  ),
                ),
              _HistoryChoiceSection<OperationStatus?>(
                title: 'Statut final',
                values: const [
                  null,
                  OperationStatus.completed,
                  OperationStatus.archived,
                ],
                selected: _value.status,
                label: (value) =>
                    value == null ? 'Tous' : operationStatusLabel(value),
                onSelected: (value) => setState(
                  () => _value = _value.copyWith(
                    status: value,
                    clearStatus: value == null,
                  ),
                ),
              ),
              const SizedBox(height: V5Spacing.xl),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(V5Spacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('platform-history-apply-filters'),
              onPressed: () => Navigator.pop(context, _value),
              child: const Text('Afficher les résultats'),
            ),
          ),
        ),
      ],
    ),
  );
}

class _HistoryChoiceSection<T> extends StatelessWidget {
  const _HistoryChoiceSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: V5Spacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: V5Spacing.sm),
        Wrap(
          spacing: V5Spacing.sm,
          runSpacing: V5Spacing.sm,
          children: [
            for (final value in values)
              ChoiceChip(
                key: ValueKey('history-filter-$title-${label(value)}'),
                selected: selected == value,
                label: Text(label(value)),
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
      ],
    ),
  );
}

class PlatformAdminHistoryDetailScreen extends StatelessWidget {
  const PlatformAdminHistoryDetailScreen({super.key, required this.entry});

  final PlatformHistoryOperation entry;

  @override
  Widget build(BuildContext context) {
    final operation = entry.operation;
    return Scaffold(
      backgroundColor: context.v5Colors.canvas,
      appBar: AppBar(title: const Text('Bilan d’opération')),
      body: SafeArea(
        child: ListView(
          key: const PageStorageKey('platform-admin-history-detail'),
          padding: const EdgeInsets.fromLTRB(
            V5Spacing.lg,
            V5Spacing.lg,
            V5Spacing.lg,
            V5Spacing.xxxl,
          ),
          children: [
            Text(
              operation.name,
              key: const Key('platform-history-detail-title'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: V5Spacing.sm),
            Wrap(
              spacing: V5Spacing.xs,
              runSpacing: V5Spacing.xs,
              children: [
                _HistoryTag(
                  label: operationStatusLabel(operation.status),
                  icon: Icons.task_alt_rounded,
                ),
                _HistoryTag(
                  label: operationTypeLabel(operation.type),
                  icon: Icons.category_outlined,
                ),
              ],
            ),
            const SizedBox(height: V5Spacing.md),
            _HistoryDetailLine(
              icon: Icons.calendar_today_outlined,
              label: 'Dates',
              value: _operationPeriod(context, operation),
            ),
            _HistoryDetailLine(
              icon: Icons.public_rounded,
              label: 'Territoires',
              value: entry.territories.isEmpty
                  ? 'Non défini'
                  : entry.territories
                        .map((territory) => territory.label)
                        .join(', '),
            ),
            _HistoryDetailLine(
              key: const Key('platform-history-detail-coordinator'),
              icon: Icons.supervisor_account_outlined,
              label: 'Coordinateur',
              value: entry.coordinatorUid ?? 'Non nommé',
            ),
            const SizedBox(height: V5Spacing.xxl),
            _HistoryDetailSection(
              key: const Key('platform-history-final-statistics'),
              title: 'Statistiques finales disponibles',
              child: _HistoryMetricWrap(entry: entry),
            ),
            const SizedBox(height: V5Spacing.xl),
            _HistoryDetailSection(
              key: const Key('platform-history-mobilizations'),
              title: 'Mobilisations · ${entry.mobilizationCount}',
              child: entry.statistics.snapshot.mobilizations.isEmpty
                  ? const Text('Aucune mobilisation rattachée.')
                  : Column(
                      children: [
                        for (
                          var index = 0;
                          index <
                              entry.statistics.snapshot.mobilizations.length;
                          index++
                        ) ...[
                          _HistorySimpleRow(
                            icon: Icons.hub_outlined,
                            title: entry
                                .statistics
                                .snapshot
                                .mobilizations[index]
                                .name,
                            subtitle: entry
                                .statistics
                                .snapshot
                                .mobilizations[index]
                                .subtitle,
                          ),
                          if (index <
                              entry.statistics.snapshot.mobilizations.length -
                                  1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: V5Spacing.xl),
            _HistoryDetailSection(
              key: const Key('platform-history-establishments'),
              title:
                  'Établissements · ${entry.statistics.breakdown.establishments.length}',
              child: entry.statistics.breakdown.establishments.isEmpty
                  ? const Text('Aucun établissement disponible.')
                  : Column(
                      children: [
                        for (
                          var index = 0;
                          index <
                              entry.statistics.breakdown.establishments.length;
                          index++
                        ) ...[
                          _HistorySimpleRow(
                            icon: Icons.local_hospital_outlined,
                            title: entry
                                .statistics
                                .breakdown
                                .establishments[index]
                                .label,
                            subtitle:
                                '${entry.statistics.breakdown.establishments[index].missionCount} mission${entry.statistics.breakdown.establishments[index].missionCount > 1 ? 's' : ''}',
                          ),
                          if (index <
                              entry.statistics.breakdown.establishments.length -
                                  1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: V5Spacing.xl),
            _HistoryDetailSection(
              key: const Key('platform-history-professions'),
              title: 'Répartition par profession',
              child: entry.statistics.breakdown.professions.isEmpty
                  ? const Text('Aucune répartition disponible.')
                  : Column(
                      children: [
                        for (
                          var index = 0;
                          index < entry.statistics.breakdown.professions.length;
                          index++
                        ) ...[
                          _HistoryProfessionRow(
                            profession:
                                entry.statistics.breakdown.professions[index],
                          ),
                          if (index <
                              entry.statistics.breakdown.professions.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryDetailLine extends StatelessWidget {
  const _HistoryDetailLine({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: V5Spacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: context.v5Colors.textSecondary),
        const SizedBox(width: V5Spacing.xs),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label · ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _HistoryDetailSection extends StatelessWidget {
  const _HistoryDetailSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(V5Spacing.md),
    decoration: BoxDecoration(
      color: context.v5Colors.surfaceElevated,
      borderRadius: BorderRadius.circular(V5Radius.section),
      border: Border.all(color: context.v5Colors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: V5Spacing.md),
        child,
      ],
    ),
  );
}

class _HistorySimpleRow extends StatelessWidget {
  const _HistorySimpleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: V5Spacing.sm),
    child: Row(
      children: [
        Icon(icon, color: context.v5Colors.textSecondary),
        const SizedBox(width: V5Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: V5Spacing.xxs),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.v5Colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HistoryProfessionRow extends StatelessWidget {
  const _HistoryProfessionRow({required this.profession});

  final ProfessionStatistics profession;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: V5Spacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            profession.label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: V5Spacing.sm),
        Text(
          '${profession.registered} / ${profession.required}',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(V5Spacing.xl),
    decoration: BoxDecoration(
      color: context.v5Colors.surfaceMuted,
      borderRadius: BorderRadius.circular(V5Radius.section),
    ),
    child: const Column(
      children: [
        Icon(Icons.history_toggle_off_rounded, size: 32),
        SizedBox(height: V5Spacing.sm),
        Text('Aucune opération ne correspond à ces critères.'),
      ],
    ),
  );
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
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
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

String _operationPeriod(BuildContext context, Operation operation) {
  final localizations = MaterialLocalizations.of(context);
  final start = localizations.formatMediumDate(operation.startAt);
  final end = operation.endAt == null
      ? localizations.formatMediumDate(operation.updatedAt)
      : localizations.formatMediumDate(operation.endAt!);
  return '$start – $end';
}

String _coverageLabel(double? coverage) =>
    coverage == null ? '—' : '${(coverage * 100).round()} %';
