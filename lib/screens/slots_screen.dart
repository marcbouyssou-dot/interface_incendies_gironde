import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/profession_quotas.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';
import 'create_need_screen.dart';

abstract final class _MissionsVisuals {
  static const background = Color(0xFFF5F5F3);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF7C817F);
}

class _MissionFilterMemory {
  static int status = 0;
  static TerritorialGroup? group;
}

class SlotsScreen extends StatefulWidget {
  const SlotsScreen({super.key});

  @override
  State<SlotsScreen> createState() => _SlotsScreenState();
}

class _SlotsScreenState extends State<SlotsScreen> {
  int _filter = _MissionFilterMemory.status;
  TerritorialGroup? _group = _MissionFilterMemory.group;
  String? _editingMissionId;
  LiveCoordinationData? _liveData;
  Stream<List<CoordinationNeed>>? _missions;
  Stream<List<ResponsePlace>>? _locations;
  Stream<ResponsibleAccess?>? _responsibleAccess;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liveData = LiveCoordinationDataScope.of(context);
    if (!identical(liveData, _liveData)) {
      _liveData = liveData;
      _missions = liveData.watchMissions();
      _locations = liveData.watchLocations();
      _responsibleAccess = liveData.watchResponsibleAccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ResponsibleAccess?>(
      stream: _responsibleAccess,
      builder: (context, accessSnapshot) => StreamBuilder<List<CoordinationNeed>>(
        stream: _missions,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _MissionsPageSurface(
              child: CriticalDataUnavailableState(
                stateKey: Key('missions-unavailable-state'),
                eyebrow: 'Missions',
                title: 'Missions temporairement indisponibles',
                message:
                    'Nous ne pouvons pas charger les missions pour le moment.',
                safetyMessage:
                    'Les dernières missions reçues ne sont pas affichées afin '
                    'd’éviter toute information périmée.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const _MissionsPageSurface(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return StreamBuilder<List<ResponsePlace>>(
            stream: _locations,
            builder: (context, locationsSnapshot) {
              if (locationsSnapshot.hasError) {
                return const _MissionsPageSurface(
                  child: CriticalDataUnavailableState(
                    stateKey: Key('mission-locations-unavailable-state'),
                    eyebrow: 'Missions',
                    title: 'Informations des centres indisponibles',
                    message:
                        'Nous ne pouvons pas charger les informations des '
                        'centres pour le moment.',
                    safetyMessage:
                        'Les missions associées aux lieux ne sont pas affichées '
                        'afin d’éviter toute information périmée.',
                  ),
                );
              }
              if (!locationsSnapshot.hasData) {
                return const _MissionsPageSurface(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _buildContent(
                snapshot.data!,
                locationsSnapshot.data!,
                accessSnapshot.hasError ? null : accessSnapshot.data,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(
    List<CoordinationNeed> missions,
    List<ResponsePlace> locations,
    ResponsibleAccess? access,
  ) {
    final statusNeeds = _filter == 0
        ? missions
        : missions.where((need) => need.status.index == _filter - 1).toList();
    final visibleNeeds = _group == null
        ? statusNeeds
        : statusNeeds.where((need) => need.group == _group).toList();
    return PageContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth <= 556
              ? 18.0
              : (constraints.maxWidth - 520) / 2;
          return Material(
            color: _MissionsVisuals.background,
            child: CustomScrollView(
              key: const PageStorageKey('slots'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    16,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _CrisisHeader(missions: missions),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
                        decoration: BoxDecoration(
                          color: _MissionsVisuals.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _MissionsVisuals.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x09173052),
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: TerritorialGroupFilter(
                                      key: const Key(
                                        'slots-territorial-filter',
                                      ),
                                      fieldKey: ValueKey(
                                        'slots-territorial-${_group?.name ?? 'all'}',
                                      ),
                                      value: _group,
                                      onChanged: _selectGroup,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  key: const Key('reset-mission-filters'),
                                  tooltip: 'Réinitialiser les filtres',
                                  style: IconButton.styleFrom(
                                    foregroundColor: _MissionsVisuals.textMuted,
                                    disabledForegroundColor:
                                        _MissionsVisuals.border,
                                    minimumSize: const Size(44, 44),
                                  ),
                                  onPressed: _hasActiveFilters
                                      ? _resetFilters
                                      : null,
                                  icon: const Icon(
                                    Icons.restart_alt_rounded,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 40,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _FilterChip(
                                    label: 'Toutes',
                                    selected: _filter == 0,
                                    onTap: () => _select(0),
                                  ),
                                  _FilterChip(
                                    label: 'Prioritaires',
                                    selected: _filter == 1,
                                    onTap: () => _select(1),
                                  ),
                                  _FilterChip(
                                    label: 'Renforts attendus',
                                    selected: _filter == 2,
                                    onTap: () => _select(2),
                                  ),
                                  _FilterChip(
                                    label: 'Équipes complètes',
                                    selected: _filter == 3,
                                    onTap: () => _select(3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _MissionResultsHeader(
                        count: visibleNeeds.length,
                        filtered: _hasActiveFilters,
                      ),
                    ],
                  ),
                ),
                if (visibleNeeds.isEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      32,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _MissionsEmptyState(filtered: _hasActiveFilters),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      32,
                    ),
                    sliver: SliverList.separated(
                      itemCount: visibleNeeds.length,
                      itemBuilder: (context, index) {
                        final need = visibleNeeds[index];
                        final location = responsePlaceForNeed(need, locations);
                        final locationId = need.locationId ?? location?.id;
                        final canEdit =
                            access?.hasPrivilegedAccess == true &&
                            locationId != null &&
                            access!.canManage(locationId) &&
                            need.isActive &&
                            !need.isCancelled;
                        return NeedCard(
                          key: ValueKey(need.place),
                          need: need,
                          location: location,
                          harmonized: true,
                          professionalHome: true,
                          featured: index == 0,
                          isMissionEditorOpening: _editingMissionId == need.id,
                          isMissionEditorBlocked: _editingMissionId != null,
                          onEditMission: canEdit
                              ? () => _openMissionEditor(context, need)
                              : null,
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 18),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool get _hasActiveFilters => _filter != 0 || _group != null;

  void _select(int index) {
    _MissionFilterMemory.status = index;
    setState(() => _filter = index);
  }

  void _selectGroup(TerritorialGroup? group) {
    _MissionFilterMemory.group = group;
    setState(() => _group = group);
  }

  void _resetFilters() {
    if (!_hasActiveFilters) return;
    _MissionFilterMemory.status = 0;
    _MissionFilterMemory.group = null;
    setState(() {
      _filter = 0;
      _group = null;
    });
  }

  Future<void> _openMissionEditor(
    BuildContext context,
    CoordinationNeed mission,
  ) async {
    if (_editingMissionId != null) return;
    setState(() => _editingMissionId = mission.id);
    try {
      await openMissionEditor(context, mission);
    } finally {
      if (mounted) setState(() => _editingMissionId = null);
    }
  }
}

class _CrisisHeader extends StatelessWidget {
  const _CrisisHeader({required this.missions});

  final List<CoordinationNeed> missions;

  @override
  Widget build(BuildContext context) {
    final totalQuotas = ProfessionQuotas.aggregate(
      missions.map((mission) => mission.professionQuotas),
    );
    final required = totalQuotas.requiredTotal;
    final mobilized = totalQuotas.registeredTotal;
    final remaining = (required - mobilized).clamp(0, required);
    final coverage = required == 0 ? 0.0 : totalQuotas.coverage;
    final remainingLabel = remaining == 0
        ? 'Toutes les équipes sont constituées'
        : remaining == 1
        ? '1 renfort encore attendu'
        : '$remaining renforts encore attendus';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MOBSANTÉ',
                    style: TextStyle(
                      color: _MissionsVisuals.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Votre mobilisation compte',
                    style: TextStyle(
                      color: _MissionsVisuals.navy,
                      fontSize: 26,
                      height: 1.1,
                      letterSpacing: -0.65,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Choisissez une mission où votre présence fera la différence.',
                    style: TextStyle(
                      color: _MissionsVisuals.textMuted,
                      fontSize: 13,
                      height: 1.38,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            BrandMark(size: 46),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
          decoration: BoxDecoration(
            color: _MissionsVisuals.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _MissionsVisuals.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x09173052),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.groups_2_outlined,
                    size: 20,
                    color: _MissionsVisuals.navy,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      remainingLabel,
                      style: const TextStyle(
                        color: _MissionsVisuals.navy,
                        fontSize: 15.5,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(coverage * 100).round()} %',
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedCoverageIndicator(value: coverage, minHeight: 10),
              const SizedBox(height: 8),
              Text(
                'Mobilisation couverte à ${(coverage * 100).round()} %',
                style: const TextStyle(
                  color: _MissionsVisuals.textMuted,
                  fontSize: 11,
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

class _MissionResultsHeader extends StatelessWidget {
  const _MissionResultsHeader({required this.count, required this.filtered});

  final int count;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 mission' : '$count missions';
    return Row(
      children: [
        Expanded(
          child: Text(
            filtered
                ? 'Missions correspondant à vos choix'
                : 'Les missions qui ont besoin de vous',
            style: const TextStyle(
              color: _MissionsVisuals.navy,
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _MissionsVisuals.fieldBackground,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: _MissionsVisuals.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _MissionsEmptyState extends StatelessWidget {
  const _MissionsEmptyState({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: _MissionsVisuals.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _MissionsVisuals.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08173052),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: _MissionsVisuals.textMuted,
            size: 30,
          ),
          const SizedBox(height: 11),
          Text(
            filtered
                ? 'Aucune mission ne correspond à vos choix'
                : 'Aucune mission n’attend de renfort',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _MissionsVisuals.navy,
              fontSize: 15,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            filtered
                ? 'Essayez un autre secteur ou un autre niveau de besoin.'
                : 'Revenez bientôt pour découvrir les prochains besoins.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _MissionsVisuals.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionsPageSurface extends StatelessWidget {
  const _MissionsPageSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: _MissionsVisuals.background, child: child);
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? _MissionsVisuals.navy : Colors.white,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? _MissionsVisuals.navy : _MissionsVisuals.border,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : _MissionsVisuals.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
