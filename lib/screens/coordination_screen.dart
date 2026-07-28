import 'package:flutter/material.dart';

import '../models/need.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class CoordinationScreen extends StatelessWidget {
  const CoordinationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CoordinationNeed>>(
      stream: RepositoryScope.of(context).watchMissions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildContent(snapshot.data!);
      },
    );
  }

  Widget _buildContent(List<CoordinationNeed> missions) {
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
              itemBuilder: (context, index) =>
                  _SituationRow(need: missions[index]),
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
  const _SituationRow({required this.need});
  final CoordinationNeed need;

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
          ],
        ),
      ),
    );
  }
}
