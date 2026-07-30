import 'package:flutter/material.dart';

import '../models/health_profession.dart';
import '../models/need.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class CoordinationScreen extends StatefulWidget {
  const CoordinationScreen({super.key});

  @override
  State<CoordinationScreen> createState() => _CoordinationScreenState();
}

class _CoordinationScreenState extends State<CoordinationScreen> {
  LiveCoordinationData? _liveData;
  Stream<List<CoordinationNeed>>? _missions;
  Stream<ResponsibleAccess?>? _responsibleAccess;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liveData = LiveCoordinationDataScope.of(context);
    if (!identical(liveData, _liveData)) {
      _liveData = liveData;
      _missions = liveData.watchMissions();
      _responsibleAccess = liveData.watchResponsibleAccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CoordinationNeed>>(
      stream: _missions,
      builder: (context, missionsSnapshot) {
        if (!missionsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<ResponsibleAccess?>(
          stream: _responsibleAccess,
          builder: (context, accessSnapshot) =>
              _buildContent(missionsSnapshot.data!, accessSnapshot.data),
        );
      },
    );
  }

  Widget _buildContent(
    List<CoordinationNeed> missions,
    ResponsibleAccess? access,
  ) {
    final critical = missions
        .where((need) => need.status == NeedStatus.critical)
        .length;
    final incomplete = missions
        .where((need) => need.status == NeedStatus.toComplete)
        .length;
    final complete = missions
        .where((need) => need.status == NeedStatus.complete)
        .length;
    final required = missions.fold(0, (sum, item) => sum + item.requiredPeople);
    final mobilized = missions.fold(
      0,
      (sum, item) => sum + item.registeredPeople,
    );
    final remaining = (required - mobilized).clamp(0, required);
    final coverage = required == 0
        ? 0.0
        : (mobilized / required).clamp(0, 1).toDouble();
    return PageContainer(
      child: CustomScrollView(
        key: const PageStorageKey('coordination'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            sliver: SliverList.list(
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.orange,
                      size: 28,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'SITUATION',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const Text(
                  'COUVERTURE',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${(coverage * 100).round()} %',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 64,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 22),
                AnimatedCoverageIndicator(value: coverage, minHeight: 22),
                const SizedBox(height: 12),
                Text(
                  'Encore $remaining professionnels',
                  style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 30),
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
                    const SizedBox(width: 9),
                    Expanded(
                      child: _StatusMetric(
                        label: 'À compléter',
                        value: incomplete,
                        color: AppColors.orange,
                        background: AppColors.orangeSoft,
                      ),
                    ),
                    const SizedBox(width: 9),
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
                const SizedBox(height: 34),
                const Text(
                  'MISSIONS',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList.separated(
              itemCount: missions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _SituationRow(
                key: ValueKey(missions[index].id),
                need: missions[index],
                access: access,
              ),
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
  const _SituationRow({super.key, required this.need, required this.access});
  final CoordinationNeed need;
  final ResponsibleAccess? access;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    need.place,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StatusPill(status: need.status),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              need.group.label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            CoverageBar(need: need),
            const SizedBox(height: 14),
            if (access?.isCoordinator == true) _MissionEngagements(need: need),
            _ResponsibleMissionActions(need: need, access: access),
          ],
        ),
      ),
    );
  }
}

class _ResponsibleMissionActions extends StatelessWidget {
  const _ResponsibleMissionActions({required this.need, required this.access});

  final CoordinationNeed need;
  final ResponsibleAccess? access;

  @override
  Widget build(BuildContext context) {
    if (access == null ||
        need.createdBy == null ||
        need.createdBy != access!.uid ||
        !need.isActive ||
        need.isCancelled) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: MissionCancellationButton(need: need),
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
