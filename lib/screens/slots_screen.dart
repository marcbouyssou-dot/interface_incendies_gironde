import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../models/need.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';
import 'create_need_screen.dart';

class SlotsScreen extends StatefulWidget {
  const SlotsScreen({super.key});

  @override
  State<SlotsScreen> createState() => _SlotsScreenState();
}

class _SlotsScreenState extends State<SlotsScreen> {
  int _filter = 0;
  TerritorialGroup? _group;
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
                  value: _group,
                  onChanged: (group) => setState(() => _group = group),
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

  void _select(int index) => setState(() => _filter = index);

  void _openMissionEditor(BuildContext context, CoordinationNeed mission) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SafeArea(child: CreateNeedScreen(mission: mission)),
        ),
      ),
    );
  }
}

class _CrisisHeader extends StatelessWidget {
  const _CrisisHeader({required this.missions});

  final List<CoordinationNeed> missions;

  @override
  Widget build(BuildContext context) {
    final required = missions.fold(0, (sum, item) => sum + item.requiredPeople);
    final mobilized = missions.fold(
      0,
      (sum, item) => sum + item.registeredPeople,
    );
    final remaining = (required - mobilized).clamp(0, required);
    final coverage = required == 0
        ? 0.0
        : (mobilized / required).clamp(0, 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BrandMark(),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppIdentity.shortName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Incendies Gironde',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
