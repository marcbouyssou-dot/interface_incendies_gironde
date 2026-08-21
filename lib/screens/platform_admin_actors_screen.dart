import 'package:flutter/material.dart';

import '../platform_admin/platform_actor_view_data.dart';
import '../repositories/platform_actor_read_repository.dart';
import '../theme/platform_admin_identity.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/professional_page_header.dart';

class PlatformAdminActorsScreen extends StatefulWidget {
  const PlatformAdminActorsScreen({super.key, required this.repository});

  final PlatformActorReadRepository repository;

  @override
  State<PlatformAdminActorsScreen> createState() =>
      _PlatformAdminActorsScreenState();
}

class _PlatformAdminActorsScreenState extends State<PlatformAdminActorsScreen> {
  late Future<PlatformActorDirectoryViewData> _directory;
  final _searchController = TextEditingController();
  PlatformActorKind _kind = PlatformActorKind.professional;
  PlatformActorFilter _filter = const PlatformActorFilter();

  @override
  void initState() {
    super.initState();
    _directory = widget.repository.loadDirectory();
  }

  @override
  void didUpdateWidget(covariant PlatformAdminActorsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _directory = widget.repository.loadDirectory();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _directory = widget.repository.loadDirectory());
    await _directory;
  }

  Future<void> _openFilters(PlatformActorDirectoryViewData directory) async {
    final selected = await showModalBottomSheet<PlatformActorFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) =>
          _PlatformActorFilterSheet(directory: directory, initial: _filter),
    );
    if (selected != null && mounted) setState(() => _filter = selected);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _directory,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _ActorMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Acteurs indisponibles',
          message: snapshot.error is PlatformActorReadException
              ? (snapshot.error! as PlatformActorReadException).message
              : 'Réessayez dans quelques instants.',
          onRetry: _reload,
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }
      final directory = snapshot.data!;
      return RefreshIndicator.adaptive(
        onRefresh: _reload,
        child: CustomScrollView(
          key: const PageStorageKey('platform-admin-actors'),
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
                    'Acteurs et fichiers',
                    key: const Key('platform-admin-actors-title'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: V5Spacing.xs),
                  Text(
                    'Retrouvez les acteurs et leurs participations.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.v5Colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: V5Spacing.lg),
                  _ActorKindSelector(
                    selected: _kind,
                    onSelected: (value) => setState(() => _kind = value),
                  ),
                  const SizedBox(height: V5Spacing.md),
                  TextField(
                    key: const Key('platform-actor-search'),
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Rechercher',
                      hintText: 'Nom, mission, opération…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setState(
                      () => _filter = _filter.copyWith(search: value),
                    ),
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('platform-actor-filters'),
                      onPressed: () => _openFilters(directory),
                      icon: const Icon(Icons.tune_rounded),
                      label: Text(
                        _filter.activeCount == 0
                            ? 'Filtrer'
                            : 'Filtres (${_filter.activeCount})',
                      ),
                    ),
                  ),
                  const SizedBox(height: V5Spacing.lg),
                  ..._actorCards(directory),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  List<Widget> _actorCards(PlatformActorDirectoryViewData directory) {
    final widgets = switch (_kind) {
      PlatformActorKind.professional =>
        directory
            .filteredProfessionals(_filter)
            .map(
              (actor) => _ProfessionalActorCard(
                actor: actor,
                onTap: () =>
                    _openDetail(PlatformProfessionalDetailScreen(actor: actor)),
              ),
            ),
      PlatformActorKind.coordinator =>
        directory
            .filteredCoordinators(_filter)
            .map(
              (actor) => _CoordinatorActorCard(
                actor: actor,
                onTap: () =>
                    _openDetail(PlatformCoordinatorDetailScreen(actor: actor)),
              ),
            ),
      PlatformActorKind.manager =>
        directory
            .filteredManagers(_filter)
            .map(
              (actor) => _ManagerActorCard(
                actor: actor,
                onTap: () =>
                    _openDetail(PlatformManagerDetailScreen(actor: actor)),
              ),
            ),
    }.toList(growable: false);
    if (widgets.isEmpty) {
      return const [_EmptyActors()];
    }
    return [
      Text(
        '${widgets.length} ${_kind.label.toLowerCase()}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: V5Spacing.sm),
      for (var index = 0; index < widgets.length; index++) ...[
        widgets[index],
        if (index < widgets.length - 1) const SizedBox(height: V5Spacing.sm),
      ],
    ];
  }

  void _openDetail(Widget screen) {
    Navigator.of(context).push(AppPageRoute<void>(builder: (_) => screen));
  }
}

class _ActorKindSelector extends StatelessWidget {
  const _ActorKindSelector({required this.selected, required this.onSelected});

  final PlatformActorKind selected;
  final ValueChanged<PlatformActorKind> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: V5Spacing.sm,
    runSpacing: V5Spacing.sm,
    children: [
      for (final kind in PlatformActorKind.values)
        ChoiceChip(
          key: Key('platform-actor-kind-${kind.name}'),
          selected: kind == selected,
          onSelected: (_) => onSelected(kind),
          label: Text(kind.label),
        ),
    ],
  );
}

class _ProfessionalActorCard extends StatelessWidget {
  const _ProfessionalActorCard({required this.actor, required this.onTap});

  final PlatformProfessionalViewData actor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _ActorCard(
    key: Key('professional-${actor.uid}'),
    icon: Icons.medical_services_outlined,
    title: actor.displayName,
    subtitle: actor.professionLabel,
    facts: [
      '${actor.participations.length} participation(s)',
      if (actor.cptsLabel != null) actor.cptsLabel!,
      if (actor.departmentLabel != null) actor.departmentLabel!,
    ],
    onTap: onTap,
  );
}

class _CoordinatorActorCard extends StatelessWidget {
  const _CoordinatorActorCard({required this.actor, required this.onTap});

  final PlatformCoordinatorViewData actor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _ActorCard(
    key: Key('coordinator-${actor.uid}'),
    icon: Icons.hub_outlined,
    title: actor.displayName,
    subtitle: actor.active ? 'Coordinateur actif' : 'Coordinateur inactif',
    statusActive: actor.active,
    facts: [
      '${actor.operations.length} opération(s)',
      '${actor.mobilizations.length} mobilisation(s)',
    ],
    onTap: onTap,
  );
}

class _ManagerActorCard extends StatelessWidget {
  const _ManagerActorCard({required this.actor, required this.onTap});

  final PlatformManagerViewData actor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _ActorCard(
    key: Key('manager-${actor.uid}'),
    icon: Icons.local_hospital_outlined,
    title: actor.displayName,
    subtitle: actor.active ? 'Responsable actif' : 'Responsable inactif',
    statusActive: actor.active,
    facts: [
      '${actor.locations.length} établissement(s)',
      '${actor.operations.length} opération(s)',
    ],
    onTap: onTap,
  );
}

class _ActorCard extends StatelessWidget {
  const _ActorCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.facts,
    required this.onTap,
    this.statusActive,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> facts;
  final VoidCallback onTap;
  final bool? statusActive;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(V5Radius.card),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.all(V5Spacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: PlatformAdminIdentity.accent(context)),
              const SizedBox(width: V5Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: V5Spacing.xxs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: statusActive == false
                            ? context.v5Colors.textSecondary
                            : null,
                      ),
                    ),
                    const SizedBox(height: V5Spacing.xs),
                    Wrap(
                      spacing: V5Spacing.sm,
                      runSpacing: V5Spacing.xxs,
                      children: [
                        for (final fact in facts)
                          Text(
                            fact,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.v5Colors.textSecondary,
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PlatformActorFilterSheet extends StatefulWidget {
  const _PlatformActorFilterSheet({
    required this.directory,
    required this.initial,
  });

  final PlatformActorDirectoryViewData directory;
  final PlatformActorFilter initial;

  @override
  State<_PlatformActorFilterSheet> createState() =>
      _PlatformActorFilterSheetState();
}

class _PlatformActorFilterSheetState extends State<_PlatformActorFilterSheet> {
  late PlatformActorFilter _value = widget.initial;

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
                key: const Key('platform-actor-clear-filters'),
                onPressed: () => setState(
                  () => _value = PlatformActorFilter(search: _value.search),
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
              _FilterSection(
                title: 'Profession',
                values: widget.directory.professions,
                selected: _value.profession,
                onSelected: (value) => setState(
                  () => _value = _value.copyWith(
                    profession: value,
                    clearProfession: value == null,
                  ),
                ),
              ),
              _ReferenceFilterSection(
                title: 'Opération',
                values: widget.directory.operations,
                selected: _value.operationId,
                onSelected: (value) => setState(
                  () => _value = _value.copyWith(
                    operationId: value,
                    clearOperation: value == null,
                  ),
                ),
              ),
              _FilterSection(
                title: 'Département',
                values: widget.directory.departments,
                selected: _value.department,
                onSelected: (value) => setState(
                  () => _value = _value.copyWith(
                    department: value,
                    clearDepartment: value == null,
                  ),
                ),
              ),
              _FilterSection(
                title: 'Région / territoire',
                values: widget.directory.regions,
                selected: _value.region,
                onSelected: (value) => setState(
                  () => _value = _value.copyWith(
                    region: value,
                    clearRegion: value == null,
                  ),
                ),
              ),
              _ReferenceFilterSection(
                title: 'CPTS',
                values: widget.directory.cpts,
                selected: _value.cptsId,
                onSelected: (value) => setState(
                  () => _value = _value.copyWith(
                    cptsId: value,
                    clearCpts: value == null,
                  ),
                ),
              ),
              _ReferenceFilterSection(
                title: 'Établissement',
                values: widget.directory.locations,
                selected: _value.locationId,
                onSelected: (value) => setState(
                  () => _value = _value.copyWith(
                    locationId: value,
                    clearLocation: value == null,
                  ),
                ),
              ),
              _FilterSection(
                title: 'Statut de participation',
                values: const ['confirmed', 'pending', 'standby', 'cancelled'],
                labels: const {
                  'confirmed': 'Confirmé',
                  'pending': 'En attente',
                  'standby': 'Renfort',
                  'cancelled': 'Annulé',
                },
                selected: _value.participationStatus,
                onSelected: (value) => setState(
                  () => _value = _value.copyWith(
                    participationStatus: value,
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
              key: const Key('platform-actor-apply-filters'),
              onPressed: () => Navigator.pop(context, _value),
              child: const Text('Afficher les résultats'),
            ),
          ),
        ),
      ],
    ),
  );
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.labels = const {},
  });

  final String title;
  final List<String> values;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
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
                FilterChip(
                  selected: selected == value,
                  label: Text(labels[value] ?? value),
                  onSelected: (active) => onSelected(active ? value : null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReferenceFilterSection extends StatelessWidget {
  const _ReferenceFilterSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<PlatformActorReference> values;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => _FilterSection(
    title: title,
    values: values.map((item) => item.id).toList(growable: false),
    labels: {for (final item in values) item.id: item.label},
    selected: selected,
    onSelected: onSelected,
  );
}

class PlatformProfessionalDetailScreen extends StatelessWidget {
  const PlatformProfessionalDetailScreen({super.key, required this.actor});

  final PlatformProfessionalViewData actor;

  @override
  Widget build(BuildContext context) => _ActorDetailScaffold(
    title: actor.displayName,
    subtitle: actor.professionLabel,
    children: [
      _DetailFacts(
        values: [
          if (actor.cptsLabel != null) ('CPTS', actor.cptsLabel!),
          if (actor.departmentLabel != null)
            ('Département', actor.departmentLabel!),
          if (actor.regionLabel != null) ('Région', actor.regionLabel!),
          ('Participations', '${actor.participations.length}'),
        ],
      ),
      const SizedBox(height: V5Spacing.xl),
      Text(
        'Historique des participations',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: V5Spacing.sm),
      for (final participation in actor.participations)
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(V5Spacing.md),
            title: Text(participation.missionLabel),
            subtitle: Text(
              [
                participation.operationLabel,
                participation.locationLabel,
                participation.statusLabel,
              ].whereType<String>().join(' · '),
            ),
          ),
        ),
      const SizedBox(height: V5Spacing.md),
      Text(
        'Les coordonnées personnelles ne sont pas exposées dans ce périmètre.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.v5Colors.textSecondary),
      ),
    ],
  );
}

class PlatformCoordinatorDetailScreen extends StatelessWidget {
  const PlatformCoordinatorDetailScreen({super.key, required this.actor});

  final PlatformCoordinatorViewData actor;

  @override
  Widget build(BuildContext context) => _ActorDetailScaffold(
    title: actor.displayName,
    subtitle: actor.active ? 'Coordinateur actif' : 'Coordinateur inactif',
    children: [
      _DetailFacts(
        values: [
          ('Identifiant', actor.uid),
          ('Opérations pilotées', '${actor.operations.length}'),
          ('Mobilisations', '${actor.mobilizations.length}'),
        ],
      ),
      const SizedBox(height: V5Spacing.xl),
      _ReferenceList(title: 'Opérations', values: actor.operations),
      _ReferenceList(
        title: 'Mobilisations',
        values: actor.mobilizations
            .map(
              (item) => PlatformActorReference(
                id: item.id,
                label: '${item.label} · ${item.active ? 'Active' : 'Inactive'}',
              ),
            )
            .toList(growable: false),
      ),
    ],
  );
}

class PlatformManagerDetailScreen extends StatelessWidget {
  const PlatformManagerDetailScreen({super.key, required this.actor});

  final PlatformManagerViewData actor;

  @override
  Widget build(BuildContext context) => _ActorDetailScaffold(
    title: actor.displayName,
    subtitle: actor.active ? 'Responsable actif' : 'Responsable inactif',
    children: [
      _DetailFacts(
        values: [
          ('Identifiant', actor.uid),
          ('Établissements', '${actor.locations.length}'),
          ('Opérations concernées', '${actor.operations.length}'),
        ],
      ),
      const SizedBox(height: V5Spacing.xl),
      _ReferenceList(title: 'Établissements', values: actor.locations),
      _ReferenceList(title: 'Territoires', values: actor.territories),
      _ReferenceList(title: 'Opérations', values: actor.operations),
    ],
  );
}

class _ActorDetailScaffold extends StatelessWidget {
  const _ActorDetailScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fiche acteur')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(V5Spacing.lg),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: V5Spacing.xs),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.v5Colors.textSecondary,
            ),
          ),
          const SizedBox(height: V5Spacing.xl),
          ...children,
          const SizedBox(height: V5Spacing.xxxl),
        ],
      ),
    ),
  );
}

class _DetailFacts extends StatelessWidget {
  const _DetailFacts({required this.values});

  final List<(String, String)> values;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(V5Spacing.md),
      child: Column(
        children: [
          for (var index = 0; index < values.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(values[index].$1)),
                const SizedBox(width: V5Spacing.md),
                Flexible(
                  child: Text(
                    values[index].$2,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (index < values.length - 1) const Divider(),
          ],
        ],
      ),
    ),
  );
}

class _ReferenceList extends StatelessWidget {
  const _ReferenceList({required this.title, required this.values});

  final String title;
  final List<PlatformActorReference> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: V5Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: V5Spacing.sm),
          for (final value in values)
            ListTile(
              minTileHeight: 44,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chevron_right_rounded),
              title: Text(value.label),
            ),
        ],
      ),
    );
  }
}

class _EmptyActors extends StatelessWidget {
  const _EmptyActors();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: V5Spacing.xxxl),
    child: Column(
      children: [
        Icon(
          Icons.person_search_outlined,
          size: 40,
          color: context.v5Colors.textSecondary,
        ),
        const SizedBox(height: V5Spacing.sm),
        const Text('Aucun acteur ne correspond à ces filtres.'),
      ],
    ),
  );
}

class _ActorMessage extends StatelessWidget {
  const _ActorMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(V5Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: V5Spacing.md),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: V5Spacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: V5Spacing.lg),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}
