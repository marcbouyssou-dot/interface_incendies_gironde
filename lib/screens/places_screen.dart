import 'package:flutter/material.dart';

import '../models/need.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  TerritorialGroup? _group;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ResponsePlace>>(
      stream: RepositoryScope.of(context).watchLocations(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildContent(snapshot.data!);
      },
    );
  }

  Widget _buildContent(List<ResponsePlace> locations) {
    final visiblePlaces = _group == null
        ? locations
        : locations.where((place) => place.group == _group).toList();
    return PageContainer(
      child: CustomScrollView(
        key: const PageStorageKey('places'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            sliver: SliverList.list(
              children: [
                const PageHeader(
                  eyebrow: 'Dispositif territorial',
                  title: 'Lieux',
                  subtitle: 'Les points d’intervention mobilisés en Gironde.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'URPS MK Nouvelle-Aquitaine',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Version RC1',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '2026',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 20),
                TerritorialGroupFilter(
                  key: const Key('places-territorial-filter'),
                  value: _group,
                  onChanged: (group) => setState(() => _group = group),
                ),
                const SizedBox(height: 18),
                SectionTitle(title: '${visiblePlaces.length} lieux référencés'),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList.separated(
              itemCount: visiblePlaces.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _PlaceCard(place: visiblePlaces[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place});
  final ResponsePlace place;

  @override
  Widget build(BuildContext context) {
    final icon = switch (place.type) {
      ResponsePlaceType.civilianReceptionSite => Icons.warehouse_outlined,
      ResponsePlaceType.redCross => Icons.medical_services_outlined,
      ResponsePlaceType.otherPartnerSite => Icons.handshake_outlined,
      ResponsePlaceType.sdisStation => Icons.local_fire_department_outlined,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: AppColors.orange),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    place.group.label,
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.type.label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.publicAddressLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 7),
                  _ActivityStatus(active: place.isActive),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityStatus extends StatelessWidget {
  const _ActivityStatus({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.green : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          active ? 'Actif' : 'Inactif',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
