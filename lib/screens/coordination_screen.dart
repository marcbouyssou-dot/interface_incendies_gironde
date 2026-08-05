import 'package:flutter/material.dart';

import '../models/health_profession.dart';
import '../models/need.dart';
import '../models/profession_quotas.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import '../utils/csv_export.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';
import '../widgets/mission_location_details.dart';
import 'create_need_screen.dart';

abstract final class _StatisticsVisuals {
  static const background = Color(0xFFF5F5F3);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF7C817F);
}

List<CoordinationNeed> missionsVisibleToResponsible({
  required List<CoordinationNeed> missions,
  required List<ResponsePlace> locations,
  required ResponsibleAccess? access,
}) {
  if (access == null || !access.active) return const [];
  if (access.roles.contains(ResponsibleRole.coordinator)) return missions;
  if (!access.roles.contains(ResponsibleRole.siteManager)) return const [];
  return missions
      .where((mission) {
        final location = responsePlaceForNeed(mission, locations);
        final locationId = location?.id ?? mission.locationId;
        return locationId != null && access.locationIds.contains(locationId);
      })
      .toList(growable: false);
}

({int past, int current, int upcoming}) _missionTimingCounts(
  Iterable<CoordinationNeed> missions,
  DateTime now,
) {
  var past = 0;
  var current = 0;
  var upcoming = 0;
  for (final mission in missions) {
    if (mission.endAt case final endAt? when !now.isBefore(endAt)) {
      past++;
    } else if (mission.startAt case final startAt? when now.isBefore(startAt)) {
      upcoming++;
    } else {
      current++;
    }
  }
  return (past: past, current: current, upcoming: upcoming);
}

enum _DashboardPeriod { today, last7Days, last30Days }

extension _DashboardPeriodLabel on _DashboardPeriod {
  String get label => switch (this) {
    _DashboardPeriod.today => 'Aujourd’hui',
    _DashboardPeriod.last7Days => '7 derniers jours',
    _DashboardPeriod.last30Days => '30 derniers jours',
  };

  int get dayCount => switch (this) {
    _DashboardPeriod.today => 1,
    _DashboardPeriod.last7Days => 7,
    _DashboardPeriod.last30Days => 30,
  };
}

List<CoordinationNeed> _missionsForDashboardPeriod(
  Iterable<CoordinationNeed> missions,
  _DashboardPeriod period,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: period.dayCount - 1));
  final end = today.add(const Duration(days: 1));
  return missions
      .where((mission) {
        final missionStart = mission.startAt ?? mission.endAt;
        final missionEnd = mission.endAt ?? mission.startAt;
        if (missionStart == null || missionEnd == null) return true;
        return missionStart.isBefore(end) && missionEnd.isAfter(start);
      })
      .toList(growable: false);
}

class _LocationDashboardStats {
  const _LocationDashboardStats({
    required this.id,
    required this.name,
    required this.missionCount,
    required this.quotas,
  });

  final String id;
  final String name;
  final int missionCount;
  final ProfessionQuotas quotas;

  int get required => quotas.requiredTotal;
  int get mobilized => quotas.registeredTotal;
  int get remaining =>
      quotas.values.fold(0, (total, quota) => total + quota.missing);
  double get coverage => required == 0 ? 0 : quotas.coverage;
}

List<_LocationDashboardStats> _locationDashboardStats(
  Iterable<CoordinationNeed> missions,
  Iterable<ResponsePlace> locations,
) {
  final missionsByLocation = <String, List<CoordinationNeed>>{};
  final locationNames = <String, String>{};
  for (final mission in missions) {
    final location = responsePlaceForNeed(mission, locations);
    final missionPlace = mission.place.trim();
    final missionLocationId = mission.locationId?.trim();
    final id = location?.id.trim().isNotEmpty == true
        ? location!.id.trim()
        : missionLocationId?.isNotEmpty == true
        ? missionLocationId!
        : 'legacy:${missionPlace.toLowerCase()}';
    final name = location?.name.trim().isNotEmpty == true
        ? location!.name.trim()
        : missionPlace.isNotEmpty
        ? missionPlace
        : 'Lieu non renseigné';
    missionsByLocation.putIfAbsent(id, () => []).add(mission);
    locationNames[id] = name;
  }
  final stats = missionsByLocation.entries
      .map(
        (entry) => _LocationDashboardStats(
          id: entry.key,
          name: locationNames[entry.key]!,
          missionCount: entry.value.length,
          quotas: ProfessionQuotas.aggregate(
            entry.value.map((mission) => mission.professionQuotas),
          ),
        ),
      )
      .toList(growable: false);
  stats.sort((first, second) {
    final coverageComparison = first.coverage.compareTo(second.coverage);
    if (coverageComparison != 0) return coverageComparison;
    final remainingComparison = second.remaining.compareTo(first.remaining);
    if (remainingComparison != 0) return remainingComparison;
    return first.name.compareTo(second.name);
  });
  return stats;
}

String _csvRow(Iterable<Object?> values) => values
    .map((value) {
      final text = value?.toString() ?? '';
      return '"${text.replaceAll('"', '""')}"';
    })
    .join(';');

String _coordinatorDashboardCsv({
  required _DashboardPeriod period,
  required int totalMissions,
  required int pastMissions,
  required int currentMissions,
  required int upcomingMissions,
  required int remainingProfessionals,
  required double coverage,
  required ProfessionQuotas professionQuotas,
  required List<_LocationDashboardStats> locationStats,
}) {
  final rows = <String>[
    _csvRow([
      'Section',
      'Libellé',
      'Période',
      'Nombre de missions',
      'Missions passées',
      'Missions en cours',
      'Missions à venir',
      'Quota total demandé',
      'Professionnels mobilisés',
      'Professionnels encore recherchés',
      'Taux de couverture (%)',
    ]),
    _csvRow([
      'Global',
      'Toutes les missions',
      period.label,
      totalMissions,
      pastMissions,
      currentMissions,
      upcomingMissions,
      professionQuotas.requiredTotal,
      professionQuotas.registeredTotal,
      remainingProfessionals,
      (coverage * 100).round(),
    ]),
    for (final profession in HealthProfessionRegistry.values)
      _csvRow([
        'Profession',
        profession.label,
        period.label,
        null,
        null,
        null,
        null,
        professionQuotas.quotaFor(profession.id).required,
        professionQuotas.quotaFor(profession.id).registered,
        professionQuotas.quotaFor(profession.id).missing,
        (professionQuotas.quotaFor(profession.id).required == 0
                ? 0
                : professionQuotas.quotaFor(profession.id).coverage * 100)
            .round(),
      ]),
    for (final stats in locationStats)
      _csvRow([
        'Lieu',
        stats.name,
        period.label,
        stats.missionCount,
        null,
        null,
        null,
        stats.required,
        stats.mobilized,
        stats.remaining,
        (stats.coverage * 100).round(),
      ]),
  ];
  return '\ufeff${rows.join('\r\n')}\r\n';
}

String _dashboardCsvFileName(_DashboardPeriod period, DateTime now) {
  final date = [
    now.year.toString().padLeft(4, '0'),
    now.month.toString().padLeft(2, '0'),
    now.day.toString().padLeft(2, '0'),
  ].join('-');
  return 'tableau-de-bord-${period.name}-$date.csv';
}

class CoordinationScreen extends StatefulWidget {
  const CoordinationScreen({super.key});

  @override
  State<CoordinationScreen> createState() => _CoordinationScreenState();
}

class _CoordinationScreenState extends State<CoordinationScreen> {
  String? _editingMissionId;
  _DashboardPeriod _dashboardPeriod = _DashboardPeriod.today;
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
      builder: (context, accessSnapshot) {
        if (accessSnapshot.hasError) {
          if (isInvalidResponsibleAccessError(accessSnapshot.error)) {
            return const InvalidResponsibleAccessState();
          }
          return const _ResponsibleAccessUnavailableState();
        }
        if (accessSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<List<CoordinationNeed>>(
          stream: _missions,
          builder: (context, missionsSnapshot) {
            if (missionsSnapshot.hasError) {
              return const CriticalDataUnavailableState(
                stateKey: Key('situation-missions-unavailable-state'),
                eyebrow: 'Situation',
                title: 'Situation temporairement indisponible',
                message:
                    'Nous ne pouvons pas charger les besoins et missions '
                    'pour le moment.',
                safetyMessage:
                    'Les dernières données reçues ne sont pas affichées afin '
                    'd’éviter toute information périmée.',
              );
            }
            if (!missionsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<List<ResponsePlace>>(
              stream: _locations,
              builder: (context, locationsSnapshot) {
                if (locationsSnapshot.hasError) {
                  return const CriticalDataUnavailableState(
                    stateKey: Key('situation-locations-unavailable-state'),
                    eyebrow: 'Situation',
                    title: 'Informations des centres indisponibles',
                    message:
                        'Nous ne pouvons pas charger les informations des '
                        'centres pour le moment.',
                    safetyMessage:
                        'Par sécurité, les données associées aux lieux ne '
                        'sont pas affichées.',
                  );
                }
                if (!locationsSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildContent(
                  missionsSnapshot.data!,
                  locationsSnapshot.data!,
                  accessSnapshot.data,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContent(
    List<CoordinationNeed> missions,
    List<ResponsePlace> locations,
    ResponsibleAccess? access,
  ) {
    final visibleMissions = missionsVisibleToResponsible(
      missions: missions,
      locations: locations,
      access: access,
    );
    final now = DateTime.now();
    final dashboardMissions = access?.isCoordinator == true
        ? _missionsForDashboardPeriod(visibleMissions, _dashboardPeriod, now)
        : visibleMissions;
    final critical = dashboardMissions
        .where((need) => need.status == NeedStatus.critical)
        .length;
    final incomplete = dashboardMissions
        .where((need) => need.status == NeedStatus.toComplete)
        .length;
    final complete = dashboardMissions
        .where((need) => need.status == NeedStatus.complete)
        .length;
    final totalQuotas = ProfessionQuotas.aggregate(
      dashboardMissions.map((mission) => mission.professionQuotas),
    );
    final required = totalQuotas.requiredTotal;
    final mobilized = totalQuotas.registeredTotal;
    final remaining = (required - mobilized).clamp(0, required);
    final coverage = required == 0 ? 0.0 : totalQuotas.coverage;
    final timingCounts = _missionTimingCounts(dashboardMissions, now);
    final locationStats = _locationDashboardStats(dashboardMissions, locations);
    return PageContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth <= 556
              ? 18.0
              : (constraints.maxWidth - 520) / 2;
          return Material(
            color: _StatisticsVisuals.background,
            child: CustomScrollView(
              key: const PageStorageKey('coordination'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    18,
                  ),
                  sliver: SliverList.list(
                    children: [
                      const _StatisticsPageHeader(),
                      const SizedBox(height: 20),
                      if (access?.isCoordinator == true)
                        _CoordinatorGlobalDashboard(
                          totalMissions: dashboardMissions.length,
                          pastMissions: timingCounts.past,
                          currentMissions: timingCounts.current,
                          upcomingMissions: timingCounts.upcoming,
                          mobilizedProfessionals: mobilized,
                          remainingProfessionals: remaining,
                          coverage: coverage,
                          professionQuotas: totalQuotas,
                          locationStats: locationStats,
                          selectedPeriod: _dashboardPeriod,
                          onPeriodChanged: (period) {
                            setState(() => _dashboardPeriod = period);
                          },
                        )
                      else
                        _SiteCoverageOverview(
                          coverage: coverage,
                          remainingProfessionals: remaining,
                        ),
                      const SizedBox(height: 14),
                      _StatisticsCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _StatisticsSectionHeader(
                              eyebrow: 'VUE GLOBALE',
                              title: 'État des missions',
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatusMetric(
                                    label: 'Critiques',
                                    value: critical,
                                    color: AppColors.red,
                                    background: AppColors.redSoft,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatusMetric(
                                    label: 'À compléter',
                                    value: incomplete,
                                    color: AppColors.orange,
                                    background: AppColors.orangeSoft,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatusMetric(
                                    label: 'Complets',
                                    value: complete,
                                    color: AppColors.green,
                                    background: AppColors.greenSoft,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _StatisticsSectionHeader(
                        eyebrow: 'MISSIONS',
                        title: 'Toutes les missions',
                        trailing: '${visibleMissions.length}',
                      ),
                      const SizedBox(height: 11),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    36,
                  ),
                  sliver: SliverList.separated(
                    itemCount: visibleMissions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _SituationRow(
                      key: ValueKey(visibleMissions[index].id),
                      need: visibleMissions[index],
                      location: responsePlaceForNeed(
                        visibleMissions[index],
                        locations,
                      ),
                      access: access,
                      isMissionEditorOpening:
                          _editingMissionId == visibleMissions[index].id,
                      isMissionEditorBlocked: _editingMissionId != null,
                      onEditMission: () =>
                          _openMissionEditor(context, visibleMissions[index]),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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

class _StatisticsPageHeader extends StatelessWidget {
  const _StatisticsPageHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SITUATION',
                style: TextStyle(
                  color: _StatisticsVisuals.textMuted,
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Statistiques',
                style: TextStyle(
                  color: _StatisticsVisuals.navy,
                  fontSize: 28,
                  height: 1.1,
                  letterSpacing: -0.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Couverture opérationnelle des missions.',
                style: TextStyle(
                  color: _StatisticsVisuals.textMuted,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 16),
        BrandMark(size: 46),
      ],
    );
  }
}

class _StatisticsSectionHeader extends StatelessWidget {
  const _StatisticsSectionHeader({
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: _StatisticsVisuals.textMuted,
                  fontSize: 9,
                  letterSpacing: 1.05,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: _StatisticsVisuals.navy,
                  fontSize: 19,
                  height: 1.15,
                  letterSpacing: -0.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: _StatisticsVisuals.textMuted,
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: _StatisticsVisuals.fieldBackground,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _StatisticsVisuals.border),
            ),
            child: Text(
              trailing!,
              style: const TextStyle(
                color: _StatisticsVisuals.navy,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _StatisticsVisuals.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _StatisticsVisuals.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A173052),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SiteCoverageOverview extends StatelessWidget {
  const _SiteCoverageOverview({
    required this.coverage,
    required this.remainingProfessionals,
  });

  final double coverage;
  final int remainingProfessionals;

  @override
  Widget build(BuildContext context) {
    return _StatisticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StatisticsSectionHeader(
            eyebrow: 'VUE GLOBALE',
            title: 'Taux de couverture',
          ),
          const SizedBox(height: 14),
          Text(
            '${(coverage * 100).round()} %',
            style: const TextStyle(
              color: _StatisticsVisuals.navy,
              fontSize: 52,
              height: 1,
              letterSpacing: -1.6,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedCoverageIndicator(value: coverage, minHeight: 12),
          const SizedBox(height: 11),
          Text(
            'Encore $remainingProfessionals professionnels',
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsibleAccessUnavailableState extends StatelessWidget {
  const _ResponsibleAccessUnavailableState();

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: ListView(
        key: const Key('responsible-access-unavailable-state'),
        padding: const EdgeInsets.fromLTRB(20, 42, 20, 32),
        children: [
          const PageHeader(
            eyebrow: 'Accès responsable',
            title: 'Accès temporairement indisponible',
            subtitle:
                'Nous ne pouvons pas vérifier vos droits d’accès pour le '
                'moment.',
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.lock_clock_outlined,
                    color: AppColors.orange,
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Par sécurité, aucun accès privilégié n’est affiché.',
                    key: const Key('responsible-access-unavailable-message'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Réessayez dans quelques instants.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordinatorGlobalDashboard extends StatelessWidget {
  const _CoordinatorGlobalDashboard({
    required this.totalMissions,
    required this.pastMissions,
    required this.currentMissions,
    required this.upcomingMissions,
    required this.mobilizedProfessionals,
    required this.remainingProfessionals,
    required this.coverage,
    required this.professionQuotas,
    required this.locationStats,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  final int totalMissions;
  final int pastMissions;
  final int currentMissions;
  final int upcomingMissions;
  final int mobilizedProfessionals;
  final int remainingProfessionals;
  final double coverage;
  final ProfessionQuotas professionQuotas;
  final List<_LocationDashboardStats> locationStats;
  final _DashboardPeriod selectedPeriod;
  final ValueChanged<_DashboardPeriod> onPeriodChanged;

  Future<void> _exportCsv(BuildContext context) async {
    final exported = await exportCsvFile(
      fileName: _dashboardCsvFileName(selectedPeriod, DateTime.now()),
      contents: _coordinatorDashboardCsv(
        period: selectedPeriod,
        totalMissions: totalMissions,
        pastMissions: pastMissions,
        currentMissions: currentMissions,
        upcomingMissions: upcomingMissions,
        remainingProfessionals: remainingProfessionals,
        coverage: coverage,
        professionQuotas: professionQuotas,
        locationStats: locationStats,
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          exported
              ? 'Le tableau de bord a été exporté au format CSV.'
              : 'L’export CSV est disponible depuis la version web.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('coordinator-global-dashboard'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatisticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _StatisticsSectionHeader(
                      eyebrow: 'TABLEAU DE BORD GLOBAL',
                      title: 'Période observée',
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    key: const Key('dashboard-export-csv'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _StatisticsVisuals.navy,
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      side: const BorderSide(color: _StatisticsVisuals.border),
                    ),
                    onPressed: () => _exportCsv(context),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Exporter en CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final period in _DashboardPeriod.values)
                    ChoiceChip(
                      key: Key('dashboard-period-${period.name}'),
                      label: Text(period.label),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                      selected: selectedPeriod == period,
                      showCheckmark: false,
                      selectedColor: AppColors.orange,
                      backgroundColor: _StatisticsVisuals.fieldBackground,
                      side: BorderSide(
                        color: selectedPeriod == period
                            ? AppColors.orange
                            : _StatisticsVisuals.border,
                      ),
                      labelStyle: TextStyle(
                        color: selectedPeriod == period
                            ? Colors.white
                            : _StatisticsVisuals.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                      onSelected: (selected) {
                        if (selected) onPeriodChanged(period);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _StatisticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StatisticsSectionHeader(
                eyebrow: 'VUE GLOBALE',
                title: 'Chiffres clés',
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$totalMissions',
                    key: const Key('dashboard-total-missions'),
                    style: const TextStyle(
                      color: _StatisticsVisuals.navy,
                      fontSize: 50,
                      height: 0.9,
                      letterSpacing: -1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 3),
                      child: Text(
                        'missions au total',
                        style: TextStyle(
                          color: _StatisticsVisuals.textMuted,
                          fontSize: 13,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '${(coverage * 100).round()} %',
                    key: const Key('dashboard-global-coverage'),
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontSize: 25,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedCoverageIndicator(value: coverage, minHeight: 10),
              const SizedBox(height: 7),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Taux global de couverture',
                  style: TextStyle(
                    color: _StatisticsVisuals.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DashboardMetric(
                      metricKey: const Key('dashboard-past-missions'),
                      label: 'Passées',
                      value: pastMissions,
                      color: _StatisticsVisuals.textMuted,
                      background: _StatisticsVisuals.fieldBackground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DashboardMetric(
                      metricKey: const Key('dashboard-current-missions'),
                      label: 'En cours',
                      value: currentMissions,
                      color: AppColors.green,
                      background: AppColors.greenSoft,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DashboardMetric(
                      metricKey: const Key('dashboard-upcoming-missions'),
                      label: 'À venir',
                      value: upcomingMissions,
                      color: AppColors.orange,
                      background: AppColors.orangeSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _DashboardMetric(
                      metricKey: const Key('dashboard-mobilized-professionals'),
                      label: 'Professionnels mobilisés',
                      value: mobilizedProfessionals,
                      color: AppColors.green,
                      background: AppColors.greenSoft,
                      compactLabel: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DashboardMetric(
                      metricKey: const Key('dashboard-remaining-professionals'),
                      label: 'Encore recherchés',
                      value: remainingProfessionals,
                      color: AppColors.orange,
                      background: AppColors.orangeSoft,
                      compactLabel: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _StatisticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StatisticsSectionHeader(
                eyebrow: 'COUVERTURE PAR PROFESSION',
                title: 'Couverture des métiers',
              ),
              const SizedBox(height: 14),
              for (
                var index = 0;
                index < HealthProfessionRegistry.values.length;
                index++
              ) ...[
                _ProfessionDashboardRow(
                  profession: HealthProfessionRegistry.values[index],
                  quota: professionQuotas.quotaFor(
                    HealthProfessionRegistry.values[index].id,
                  ),
                ),
                if (index < HealthProfessionRegistry.values.length - 1)
                  const SizedBox(height: 9),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _StatisticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StatisticsSectionHeader(
                eyebrow: 'COUVERTURE PAR LIEU',
                title: 'Couverture des centres',
                subtitle: 'Du moins couvert au mieux couvert',
              ),
              const SizedBox(height: 14),
              if (locationStats.isEmpty)
                const Text(
                  'Aucune mission associée à un lieu.',
                  style: TextStyle(
                    color: _StatisticsVisuals.textMuted,
                    fontSize: 12,
                  ),
                )
              else
                for (var index = 0; index < locationStats.length; index++) ...[
                  _LocationDashboardRow(stats: locationStats[index]),
                  if (index < locationStats.length - 1)
                    const SizedBox(height: 9),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfessionDashboardRow extends StatelessWidget {
  const _ProfessionDashboardRow({
    required this.profession,
    required this.quota,
  });

  final HealthProfessionDefinition profession;
  final ProfessionQuota quota;

  @override
  Widget build(BuildContext context) {
    final coverage = quota.required == 0 ? 0.0 : quota.coverage;
    final color = quota.required == 0
        ? AppColors.textMuted
        : quota.isCovered
        ? AppColors.green
        : coverage < .5
        ? AppColors.red
        : AppColors.orange;
    return Container(
      key: Key('dashboard-profession-${profession.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profession.label,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(coverage * 100).round()} %',
                key: Key('dashboard-profession-${profession.id}-coverage'),
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _DashboardBreakdownValue(
                  valueKey: Key(
                    'dashboard-profession-${profession.id}-required',
                  ),
                  label: 'Demandé',
                  value: quota.required,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DashboardBreakdownValue(
                  valueKey: Key(
                    'dashboard-profession-${profession.id}-mobilized',
                  ),
                  label: 'Mobilisés',
                  value: quota.registered,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DashboardBreakdownValue(
                  valueKey: Key(
                    'dashboard-profession-${profession.id}-remaining',
                  ),
                  label: 'Recherchés',
                  value: quota.missing,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          AnimatedCoverageIndicator(
            value: coverage,
            color: color,
            minHeight: 8,
          ),
        ],
      ),
    );
  }
}

class _LocationDashboardRow extends StatelessWidget {
  const _LocationDashboardRow({required this.stats});

  final _LocationDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final color = stats.required == 0
        ? AppColors.textMuted
        : stats.coverage >= 1
        ? AppColors.green
        : stats.coverage < .5
        ? AppColors.red
        : AppColors.orange;
    return Container(
      key: Key('dashboard-location-${stats.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stats.name,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(stats.coverage * 100).round()} %',
                key: Key('dashboard-location-${stats.id}-coverage'),
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${stats.missionCount} mission${stats.missionCount > 1 ? 's' : ''}',
            key: Key('dashboard-location-${stats.id}-missions'),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _DashboardBreakdownValue(
                  valueKey: Key('dashboard-location-${stats.id}-required'),
                  label: 'Demandé',
                  value: stats.required,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DashboardBreakdownValue(
                  valueKey: Key('dashboard-location-${stats.id}-mobilized'),
                  label: 'Mobilisés',
                  value: stats.mobilized,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DashboardBreakdownValue(
                  valueKey: Key('dashboard-location-${stats.id}-remaining'),
                  label: 'Recherchés',
                  value: stats.remaining,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          AnimatedCoverageIndicator(
            value: stats.coverage,
            color: color,
            minHeight: 8,
          ),
        ],
      ),
    );
  }
}

class _DashboardBreakdownValue extends StatelessWidget {
  const _DashboardBreakdownValue({
    required this.valueKey,
    required this.label,
    required this.value,
  });

  final Key valueKey;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          key: valueKey,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 18,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.metricKey,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
    this.compactLabel = true,
  });

  final Key metricKey;
  final String label;
  final int value;
  final Color color;
  final Color background;
  final bool compactLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compactLabel ? 82 : 100),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            key: metricKey,
            style: TextStyle(
              color: color,
              fontSize: 26,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: compactLabel ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: compactLabel ? 10 : 11,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final int value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SituationRow extends StatelessWidget {
  const _SituationRow({
    super.key,
    required this.need,
    required this.location,
    required this.access,
    required this.isMissionEditorOpening,
    required this.isMissionEditorBlocked,
    required this.onEditMission,
  });
  final CoordinationNeed need;
  final ResponsePlace? location;
  final ResponsibleAccess? access;
  final bool isMissionEditorOpening;
  final bool isMissionEditorBlocked;
  final VoidCallback onEditMission;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _StatisticsVisuals.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _StatisticsVisuals.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08173052),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  need.place,
                  style: const TextStyle(
                    color: _StatisticsVisuals.navy,
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(status: need.status),
            ],
          ),
          const SizedBox(height: 7),
          MissionTimingPill(mission: need),
          const SizedBox(height: 6),
          Text(
            need.group.label,
            style: const TextStyle(
              color: _StatisticsVisuals.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            location?.type.label ?? 'Lieu d’intervention',
            style: const TextStyle(
              color: _StatisticsVisuals.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          MissionLocationDetails(location: location, compact: true),
          const SizedBox(height: 14),
          CoverageBar(need: need),
          const SizedBox(height: 14),
          if (access?.isCoordinator == true) _MissionEngagements(need: need),
          _ResponsibleMissionActions(
            need: need,
            location: location,
            access: access,
            isMissionEditorOpening: isMissionEditorOpening,
            isMissionEditorBlocked: isMissionEditorBlocked,
            onEditMission: onEditMission,
          ),
        ],
      ),
    );
  }
}

class _ResponsibleMissionActions extends StatelessWidget {
  const _ResponsibleMissionActions({
    required this.need,
    required this.location,
    required this.access,
    required this.isMissionEditorOpening,
    required this.isMissionEditorBlocked,
    required this.onEditMission,
  });

  final CoordinationNeed need;
  final ResponsePlace? location;
  final ResponsibleAccess? access;
  final bool isMissionEditorOpening;
  final bool isMissionEditorBlocked;
  final VoidCallback onEditMission;

  @override
  Widget build(BuildContext context) {
    final currentAccess = access;
    final locationId = need.locationId ?? location?.id;
    if (currentAccess == null ||
        !currentAccess.hasPrivilegedAccess ||
        locationId == null ||
        !currentAccess.canManage(locationId) ||
        !need.isActive ||
        need.isCancelled) {
      return const SizedBox.shrink();
    }
    final canCancel =
        need.createdBy != null && need.createdBy == currentAccess.uid;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: Key('edit-mission-${need.id}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _StatisticsVisuals.navy,
              minimumSize: const Size(0, 48),
              side: const BorderSide(color: _StatisticsVisuals.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: isMissionEditorBlocked ? null : onEditMission,
            icon: isMissionEditorOpening
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.edit_outlined),
            label: Text(
              isMissionEditorOpening
                  ? 'Modification en cours…'
                  : 'Modifier la mission',
            ),
          ),
          if (canCancel) MissionCancellationButton(need: need),
        ],
      ),
    );
  }
}

class _MissionEngagements extends StatefulWidget {
  const _MissionEngagements({required this.need});

  final CoordinationNeed need;

  @override
  State<_MissionEngagements> createState() => _MissionEngagementsState();
}

class _MissionEngagementsState extends State<_MissionEngagements> {
  LiveCoordinationData? _liveData;
  Stream<List<EngagementInfo>>? _engagements;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStream();
  }

  @override
  void didUpdateWidget(_MissionEngagements oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.need.id != widget.need.id) {
      _engagements = null;
      _updateStream();
    }
  }

  void _updateStream() {
    final liveData = LiveCoordinationDataScope.of(context);
    if (!identical(liveData, _liveData) || _engagements == null) {
      _liveData = liveData;
      _engagements = liveData.watchMissionEngagements(widget.need.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EngagementInfo>>(
      stream: _engagements,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Engagements indisponibles',
            style: TextStyle(
              color: AppColors.red,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          );
        }
        final engagements = snapshot.data;
        if (engagements == null) {
          return const LinearProgressIndicator();
        }
        if (engagements.isEmpty) {
          return const Text(
            'Aucun engagé',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          );
        }
        return Column(
          children: engagements
              .map((engagement) => _EngagementRow(engagement: engagement))
              .toList(growable: false),
        );
      },
    );
  }
}

class _EngagementRow extends StatefulWidget {
  const _EngagementRow({required this.engagement});

  final EngagementInfo engagement;

  @override
  State<_EngagementRow> createState() => _EngagementRowState();
}

class _EngagementRowState extends State<_EngagementRow> {
  bool _updating = false;

  Future<void> _update(EngagementStatus status) async {
    setState(() => _updating = true);
    try {
      await RepositoryScope.of(context).updateEngagementStatus(
        missionId: widget.engagement.missionId,
        volunteerId: widget.engagement.volunteerId,
        status: status,
      );
    } on RepositoryException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final engagement = widget.engagement;
    final profession =
        HealthProfessionRegistry.byId(
          engagement.profession.canonicalId!,
        )?.shortLabel ??
        engagement.profession.label;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$profession • ${engagement.status.label}',
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_updating)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            PopupMenuButton<EngagementStatus>(
              key: Key('engagement-menu-${engagement.documentId}'),
              tooltip: 'Modifier le statut',
              onSelected: _update,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: EngagementStatus.confirmed,
                  child: Text('Confirmer'),
                ),
                PopupMenuItem(
                  value: EngagementStatus.standby,
                  child: Text('Renfort'),
                ),
                PopupMenuItem(
                  value: EngagementStatus.cancelled,
                  child: Text('Annuler'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
