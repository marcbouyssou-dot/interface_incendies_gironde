import 'package:flutter/material.dart';

import '../models/need.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';

class SlotsScreen extends StatefulWidget {
  const SlotsScreen({super.key});

  @override
  State<SlotsScreen> createState() => _SlotsScreenState();
}

class _SlotsScreenState extends State<SlotsScreen> {
  int _filter = 0;
  TerritorialGroup? _group;

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
              itemBuilder: (context, index) => NeedCard(
                key: ValueKey(visibleNeeds[index].place),
                need: visibleNeeds[index],
              ),
              separatorBuilder: (_, _) => const SizedBox(height: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _select(int index) => setState(() => _filter = index);
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
                    'InterfaceRecup33',
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
