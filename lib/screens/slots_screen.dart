import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/profession_quotas.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/v5_foundation.dart';
import '../utils/french_date_time.dart';
import '../widgets/common.dart';
import '../widgets/decision_header.dart';
import '../widgets/mobilization_design_system.dart';
import 'create_need_screen.dart';

class _MissionFilterMemory {
  static int status = 0;
  static TerritorialGroup? group;
  static String? date;
}

class SlotsScreen extends StatefulWidget {
  const SlotsScreen({super.key, this.professionalJourney = false});

  final bool professionalJourney;

  @override
  State<SlotsScreen> createState() => _SlotsScreenState();
}

class _SlotsScreenState extends State<SlotsScreen> {
  int _filter = _MissionFilterMemory.status;
  TerritorialGroup? _group = _MissionFilterMemory.group;
  String? _date = _MissionFilterMemory.date;
  bool _showAdvancedFilters = _MissionFilterMemory.status != 0;
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
    final professionalJourney = widget.professionalJourney;
    final statusNeeds = _filter == 0
        ? missions
        : missions.where((need) => need.status.index == _filter - 1).toList();
    final selectedDate = professionalJourney ? _date : null;
    final dateNeeds = selectedDate == null
        ? statusNeeds
        : statusNeeds
              .where((need) => _missionDateLabel(need) == selectedDate)
              .toList();
    final visibleNeeds = _group == null
        ? dateNeeds
        : dateNeeds.where((need) => need.group == _group).toList();
    final availableDateValues = <String>{
      for (final mission in missions) _missionDateLabel(mission),
    };
    if (selectedDate != null) availableDateValues.add(selectedDate);
    final availableDates = availableDateValues.toList(growable: false);
    final hasPrivilegedAccess = access?.hasPrivilegedAccess == true;
    return PageContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth <= 556
              ? 18.0
              : (constraints.maxWidth - 520) / 2;
          return Material(
            color: context.v5Colors.canvas,
            child: CustomScrollView(
              key: const PageStorageKey('slots'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    professionalJourney ? 24 : 16,
                    horizontalPadding,
                    18,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _MissionDecisionHeader(
                        missions: professionalJourney ? visibleNeeds : missions,
                        professionalJourney: professionalJourney,
                        showOverview:
                            hasPrivilegedAccess && !professionalJourney,
                        group: _group,
                        date: _date,
                        availableDates: availableDates,
                        onGroupChanged: _selectGroup,
                        onDateChanged: _selectDate,
                      ),
                      if (!professionalJourney) ...[
                        const SizedBox(height: 16),
                        _MissionFilters(
                          group: _group,
                          status: _filter,
                          showAdvanced: _showAdvancedFilters,
                          hasActiveFilters: _hasActiveFilters,
                          onGroupChanged: _selectGroup,
                          onStatusChanged: _select,
                          onToggleAdvanced: () => setState(
                            () => _showAdvancedFilters = !_showAdvancedFilters,
                          ),
                          onReset: _resetFilters,
                        ),
                      ],
                      const SizedBox(height: 22),
                      _MissionResultsHeader(
                        count: visibleNeeds.length,
                        filtered: _hasActiveFilters,
                        professionalJourney: professionalJourney,
                        status: _filter,
                        showAdvanced: _showAdvancedFilters,
                        hasActiveFilters: _hasActiveFilters,
                        onStatusChanged: _select,
                        onToggleAdvanced: () => setState(
                          () => _showAdvancedFilters = !_showAdvancedFilters,
                        ),
                        onReset: _resetFilters,
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
                      36,
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
                      36,
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
                          professionalJourney: professionalJourney,
                          professionalDetailsExpanded:
                              hasPrivilegedAccess && !professionalJourney,
                          featured: index == 0,
                          isMissionEditorOpening: _editingMissionId == need.id,
                          isMissionEditorBlocked: _editingMissionId != null,
                          onEditMission: canEdit && !professionalJourney
                              ? () => _openMissionEditor(context, need)
                              : null,
                        );
                      },
                      separatorBuilder: (_, _) =>
                          SizedBox(height: professionalJourney ? 16 : 24),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool get _hasActiveFilters =>
      _filter != 0 ||
      _group != null ||
      (widget.professionalJourney && _date != null);

  void _select(int index) {
    _MissionFilterMemory.status = index;
    setState(() => _filter = index);
  }

  void _selectGroup(TerritorialGroup? group) {
    _MissionFilterMemory.group = group;
    setState(() => _group = group);
  }

  void _selectDate(String? date) {
    _MissionFilterMemory.date = date;
    setState(() => _date = date);
  }

  void _resetFilters() {
    if (!_hasActiveFilters) return;
    _MissionFilterMemory.status = 0;
    _MissionFilterMemory.group = null;
    _MissionFilterMemory.date = null;
    setState(() {
      _filter = 0;
      _group = null;
      _date = null;
      _showAdvancedFilters = false;
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

String _missionDateLabel(CoordinationNeed mission) => mission.startAt == null
    ? mission.date
    : FrenchDateTime.relativeDate(mission.startAt!);

class _MissionDecisionHeader extends StatelessWidget {
  const _MissionDecisionHeader({
    required this.missions,
    required this.professionalJourney,
    required this.showOverview,
    required this.group,
    required this.date,
    required this.availableDates,
    required this.onGroupChanged,
    required this.onDateChanged,
  });

  final List<CoordinationNeed> missions;
  final bool professionalJourney;
  final bool showOverview;
  final TerritorialGroup? group;
  final String? date;
  final List<String> availableDates;
  final ValueChanged<TerritorialGroup?> onGroupChanged;
  final ValueChanged<String?> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
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
    final urgentCount = missions
        .where((mission) => mission.status == NeedStatus.critical)
        .length;
    final decisionState = missions.isEmpty
        ? DecisionHeaderState.noUpdates
        : urgentCount > 0
        ? DecisionHeaderState.urgentMission
        : DecisionHeaderState.newMissions;
    final secondary = missions.isEmpty
        ? 'Aucune équipe ne recherche de renfort pour le moment.'
        : decisionState == DecisionHeaderState.urgentMission
        ? 'Une mission prioritaire attend encore des renforts.'
        : 'Des équipes ont besoin de vous.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecisionHeader(
          state: decisionState,
          verdict: professionalJourney
              ? switch ((missions.isEmpty, decisionState)) {
                  (true, _) =>
                    'Aucune mission ne correspond actuellement à vos critères.',
                  (false, DecisionHeaderState.urgentMission) =>
                    urgentCount == 1
                        ? '1 mission urgente nécessite votre attention.'
                        : '$urgentCount missions urgentes nécessitent votre attention.',
                  (false, _) when missions.length == 1 =>
                    '1 mission correspond à vos critères.',
                  (false, _) =>
                    '${missions.length} missions correspondent à vos critères.',
                }
              : missions.isEmpty
              ? 'Rien de nouveau pour l’instant'
              : 'Où aider aujourd’hui ?',
          secondary: secondary,
          verdictColor: professionalJourney ? colors.info : null,
          showSecondary: !professionalJourney,
        ),
        if (professionalJourney) ...[
          const SizedBox(height: V5Spacing.lg),
          Wrap(
            spacing: V5Spacing.xs,
            runSpacing: V5Spacing.xs,
            children: [
              _HeroFilterChip(
                chipKey: const Key('professional-hero-where'),
                icon: Icons.location_on_outlined,
                label: 'Où',
                activeValue: group?.label,
                selectedValue: group?.name ?? 'all',
                options: [
                  const _HeroFilterOption(
                    value: 'all',
                    label: 'Tous les secteurs',
                  ),
                  for (final value in TerritorialGroup.values)
                    _HeroFilterOption(value: value.name, label: value.label),
                ],
                onSelected: (value) => onGroupChanged(
                  value == 'all' ? null : TerritorialGroup.values.byName(value),
                ),
              ),
              _HeroFilterChip(
                chipKey: const Key('professional-hero-when'),
                icon: Icons.calendar_today_outlined,
                label: 'Quand',
                activeValue: date,
                selectedValue: date ?? 'all',
                options: [
                  const _HeroFilterOption(
                    value: 'all',
                    label: 'Toutes les dates',
                  ),
                  for (final value in availableDates)
                    _HeroFilterOption(value: value, label: value),
                ],
                onSelected: (value) =>
                    onDateChanged(value == 'all' ? null : value),
              ),
            ],
          ),
        ],
        if (showOverview) ...[
          const SizedBox(height: 14),
          ImpactBanner(
            key: const Key('mission-coverage-overview'),
            type: ImpactBannerType.mobilizationCovered,
            compact: true,
            message: remainingLabel,
            messageIcon: Icons.groups_2_outlined,
            trailing: Text(
              '${(coverage * 100).round()} %',
              style: TextStyle(
                color: colors.success,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedCoverageIndicator(
                  value: coverage,
                  color: colors.success,
                  minHeight: 4,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HeroFilterChip extends StatelessWidget {
  const _HeroFilterChip({
    required this.chipKey,
    required this.icon,
    required this.label,
    required this.activeValue,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
  });

  final Key chipKey;
  final IconData icon;
  final String label;
  final String? activeValue;
  final String selectedValue;
  final List<_HeroFilterOption> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final hasSelection = activeValue != null;
    return CupertinoButton(
      key: chipKey,
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      pressedOpacity: 0.72,
      onPressed: () => _showOptions(context),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, maxWidth: 236),
        padding: const EdgeInsets.symmetric(horizontal: V5Spacing.sm),
        decoration: BoxDecoration(
          color: hasSelection
              ? Color.alphaBlend(
                  colors.info.withValues(alpha: 0.06),
                  colors.surfaceElevated,
                )
              : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(V5Radius.pill),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.035),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: hasSelection ? colors.info : colors.textSecondary,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                activeValue ?? label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasSelection ? colors.info : colors.textPrimary,
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: colors.textSecondary.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    final colors = context.v5Colors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: colors.shadow.withValues(alpha: 0.28),
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 260),
        reverseDuration: Duration(milliseconds: 210),
      ),
      builder: (sheetContext) => _ProfessionalFilterSheet(
        title: label == 'Où' ? 'Où aider ?' : 'Quand aider ?',
        selectedValue: selectedValue,
        options: options,
        onSelected: (value) {
          onSelected(value);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }
}

class _HeroFilterOption {
  const _HeroFilterOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _ProfessionalFilterSheet extends StatelessWidget {
  const _ProfessionalFilterSheet({
    required this.title,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
  });

  final String title;
  final String selectedValue;
  final List<_HeroFilterOption> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(V5Radius.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.outline.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(V5Radius.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Divider(height: 1, thickness: 0.5, color: colors.outline),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  itemCount: options.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 8,
                    endIndent: 8,
                    color: colors.outline.withValues(alpha: 0.7),
                  ),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final selected = option.value == selectedValue;
                    return CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size.fromHeight(52),
                      pressedOpacity: 0.68,
                      onPressed: () => onSelected(option.value),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.label,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16,
                                height: 1.2,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (selected)
                            Icon(
                              CupertinoIcons.check_mark,
                              size: 19,
                              color: colors.info,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionResultsHeader extends StatelessWidget {
  const _MissionResultsHeader({
    required this.count,
    required this.filtered,
    required this.professionalJourney,
    required this.status,
    required this.showAdvanced,
    required this.hasActiveFilters,
    required this.onStatusChanged,
    required this.onToggleAdvanced,
    required this.onReset,
  });

  final int count;
  final bool filtered;
  final bool professionalJourney;
  final int status;
  final bool showAdvanced;
  final bool hasActiveFilters;
  final ValueChanged<int> onStatusChanged;
  final VoidCallback onToggleAdvanced;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final label = count == 1 ? '1 mission' : '$count missions';
    if (professionalJourney) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Missions',
                  key: const Key('professional-missions-section-title'),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _MissionCount(label: label),
              const SizedBox(width: V5Spacing.xxs),
              IconButton(
                key: const Key('professional-secondary-filters'),
                tooltip: showAdvanced
                    ? 'Masquer les filtres secondaires'
                    : 'Filtres secondaires',
                style: IconButton.styleFrom(
                  foregroundColor: showAdvanced
                      ? colors.info
                      : colors.textSecondary,
                  backgroundColor: showAdvanced
                      ? colors.infoContainer
                      : Colors.transparent,
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onToggleAdvanced,
                icon: const Icon(Icons.tune_rounded, size: 18),
              ),
              if (hasActiveFilters)
                IconButton(
                  key: const Key('professional-reset-filters'),
                  tooltip: 'Réinitialiser les filtres',
                  style: IconButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                ),
            ],
          ),
          if (showAdvanced) ...[
            const SizedBox(height: V5Spacing.xs),
            SizedBox(
              height: 32,
              child: ListView(
                key: const Key('professional-status-filters'),
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'Toutes',
                    selected: status == 0,
                    professionalPalette: true,
                    onTap: () => onStatusChanged(0),
                  ),
                  _FilterChip(
                    label: 'Prioritaires',
                    selected: status == 1,
                    professionalPalette: true,
                    onTap: () => onStatusChanged(1),
                  ),
                  _FilterChip(
                    label: 'Renforts attendus',
                    selected: status == 2,
                    professionalPalette: true,
                    onTap: () => onStatusChanged(2),
                  ),
                  _FilterChip(
                    label: 'Équipes complètes',
                    selected: status == 3,
                    professionalPalette: true,
                    onTap: () => onStatusChanged(3),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            filtered
                ? 'Missions correspondant à vos choix'
                : 'Les missions qui ont besoin de vous',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _MissionCount(label: label),
      ],
    );
  }
}

class _MissionCount extends StatelessWidget {
  const _MissionCount({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(MobilizationTokens.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MissionsEmptyState extends StatelessWidget {
  const _MissionsEmptyState({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(MobilizationTokens.radiusCard),
        border: Border.all(color: colors.outline),
        boxShadow: V5Elevation.level1(colors),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: colors.textSecondary, size: 30),
          const SizedBox(height: 11),
          Text(
            filtered
                ? 'Aucune mission ne correspond à vos choix'
                : 'Aucune mission n’attend de renfort',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
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
              color: colors.textSecondary,
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
    return ColoredBox(color: context.v5Colors.canvas, child: child);
  }
}

class _MissionFilters extends StatelessWidget {
  const _MissionFilters({
    required this.group,
    required this.status,
    required this.showAdvanced,
    required this.hasActiveFilters,
    required this.onGroupChanged,
    required this.onStatusChanged,
    required this.onToggleAdvanced,
    required this.onReset,
  });

  final TerritorialGroup? group;
  final int status;
  final bool showAdvanced;
  final bool hasActiveFilters;
  final ValueChanged<TerritorialGroup?> onGroupChanged;
  final ValueChanged<int> onStatusChanged;
  final VoidCallback onToggleAdvanced;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TerritorialGroupFilter(
                  key: const Key('slots-territorial-filter'),
                  fieldKey: ValueKey(
                    'slots-territorial-${group?.name ?? 'all'}',
                  ),
                  value: group,
                  onChanged: onGroupChanged,
                  compact: true,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const Key('toggle-advanced-mission-filters'),
              tooltip: showAdvanced
                  ? 'Masquer les filtres de statut'
                  : 'Filtrer par statut',
              style: IconButton.styleFrom(
                foregroundColor: showAdvanced
                    ? colors.accent
                    : colors.textSecondary,
                backgroundColor: showAdvanced
                    ? colors.warningContainer
                    : Colors.transparent,
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onToggleAdvanced,
              icon: const Icon(Icons.tune_rounded, size: 18),
            ),
            const SizedBox(width: 2),
            IconButton(
              key: const Key('reset-mission-filters'),
              tooltip: 'Réinitialiser les filtres',
              style: IconButton.styleFrom(
                foregroundColor: colors.textSecondary,
                disabledForegroundColor: colors.outline,
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: hasActiveFilters ? onReset : null,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
            ),
          ],
        ),
        if (showAdvanced) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'Toutes',
                  selected: status == 0,
                  onTap: () => onStatusChanged(0),
                ),
                _FilterChip(
                  label: 'Prioritaires',
                  selected: status == 1,
                  onTap: () => onStatusChanged(1),
                ),
                _FilterChip(
                  label: 'Renforts attendus',
                  selected: status == 2,
                  onTap: () => onStatusChanged(2),
                ),
                _FilterChip(
                  label: 'Équipes complètes',
                  selected: status == 3,
                  onTap: () => onStatusChanged(3),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.professionalPalette = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool professionalPalette;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final selectedColor = professionalPalette ? colors.info : colors.brand;
    final selectedForeground =
        ThemeData.estimateBrightnessForColor(selectedColor) == Brightness.dark
        ? Colors.white
        : colors.canvas;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? selectedColor : colors.surface,
          shape: StadiumBorder(
            side: BorderSide(color: selected ? selectedColor : colors.outline),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? selectedForeground : colors.textSecondary,
                    fontSize: 10.5,
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
