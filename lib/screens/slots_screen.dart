import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../models/need.dart';
import '../models/profession_quotas.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';
import 'create_need_screen.dart';

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
            return const CriticalDataUnavailableState(
              stateKey: Key('missions-unavailable-state'),
              eyebrow: 'Missions',
              title: 'Missions temporairement indisponibles',
              message:
                  'Nous ne pouvons pas charger les missions pour le moment.',
              safetyMessage:
                  'Les dernières missions reçues ne sont pas affichées afin '
                  'd’éviter toute information périmée.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<List<ResponsePlace>>(
            stream: _locations,
            builder: (context, locationsSnapshot) {
              if (locationsSnapshot.hasError) {
                return const CriticalDataUnavailableState(
                  stateKey: Key('mission-locations-unavailable-state'),
                  eyebrow: 'Missions',
                  title: 'Informations des centres indisponibles',
                  message:
                      'Nous ne pouvons pas charger les informations des centres '
                      'pour le moment.',
                  safetyMessage:
                      'Les missions associées aux lieux ne sont pas affichées '
                      'afin d’éviter toute information périmée.',
                );
              }
              if (!locationsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
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
      child: CustomScrollView(
        key: const PageStorageKey('slots'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            sliver: SliverList.list(
              children: [
                _CrisisHeader(missions: missions),
                const SizedBox(height: 24),
                TerritorialGroupFilter(
                  key: const Key('slots-territorial-filter'),
                  fieldKey: ValueKey(
                    'slots-territorial-${_group?.name ?? 'all'}',
                  ),
                  value: _group,
                  onChanged: _selectGroup,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'Tous',
                        selected: _filter == 0,
                        onTap: () => _select(0),
                      ),
                      _FilterChip(
                        label: 'Critiques',
                        selected: _filter == 1,
                        onTap: () => _select(1),
                      ),
                      _FilterChip(
                        label: 'À compléter',
                        selected: _filter == 2,
                        onTap: () => _select(2),
                      ),
                      _FilterChip(
                        label: 'Complets',
                        selected: _filter == 3,
                        onTap: () => _select(3),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const Key('reset-mission-filters'),
                    onPressed: _hasActiveFilters ? _resetFilters : null,
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Réinitialiser les filtres'),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          eyebrow: AppIdentity.productName,
          title: 'Missions',
          subtitle: AppIdentity.productSubtitle,
          trailing: BrandMark(size: 48),
        ),
        const SizedBox(height: 24),
        Text(
          'Encore $remaining professionnels à mobiliser',
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        AnimatedCoverageIndicator(value: coverage, minHeight: 18),
        const SizedBox(height: 10),
        Text(
          '${(coverage * 100).round()} % de couverture',
          style: const TextStyle(
            color: AppColors.orange,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
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
      child: Material(
        color: selected ? AppColors.navy : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.navy : AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
