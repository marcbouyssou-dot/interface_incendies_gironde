import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/app_theme.dart';
import '../utils/app_page_route.dart';
import '../widgets/common.dart';
import '../widgets/mission_location_details.dart';
import 'about_screen.dart';
import 'legal_notice_screen.dart';
import 'location_detail_screen.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  TerritorialGroup? _group;
  LiveCoordinationData? _liveData;
  Stream<List<ResponsePlace>>? _locations;
  Stream<List<CoordinationNeed>>? _missions;
  Stream<ResponsibleAccess?>? _responsibleAccess;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liveData = LiveCoordinationDataScope.of(context);
    if (!identical(liveData, _liveData)) {
      _liveData = liveData;
      _locations = liveData.watchLocations();
      _missions = liveData.watchMissions();
      _responsibleAccess = liveData.watchResponsibleAccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ResponsePlace>>(
      stream: _locations,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const CriticalDataUnavailableState(
            stateKey: Key('places-unavailable-state'),
            eyebrow: 'Lieux',
            title: 'Informations des centres indisponibles',
            message:
                'Nous ne pouvons pas charger les informations des centres '
                'pour le moment.',
            safetyMessage:
                'Les dernières données reçues ne sont pas affichées afin '
                'd’éviter toute information périmée.',
          );
        }
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            sliver: SliverList.list(
              children: [
                const PageHeader(
                  eyebrow: 'Dispositif territorial',
                  title: 'Lieux',
                  subtitle: 'Les points d’intervention mobilisés en Gironde.',
                ),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        key: const Key('about-entry'),
                        leading: const Icon(Icons.info_outline_rounded),
                        title: const Text('À propos'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          AppPageRoute<void>(
                            builder: (_) => const AboutScreen(),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const Key('legal-notice-entry'),
                        dense: true,
                        leading: const Icon(Icons.gavel_outlined, size: 21),
                        title: const Text('Mentions légales'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          AppPageRoute<void>(
                            builder: (_) => const LegalNoticeScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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
              itemBuilder: (context, index) => _PlaceCard(
                place: visiblePlaces[index],
                onTap: () => Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) => LiveCoordinationDataScope(
                      data: _liveData!,
                      child: LocationDetailScreen(
                        location: visiblePlaces[index],
                        missions: _missions,
                        locations: _locations,
                        responsibleAccess: _responsibleAccess,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onTap});
  final ResponsePlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (place.type) {
      ResponsePlaceType.civilianReceptionSite => Icons.warehouse_outlined,
      ResponsePlaceType.redCross => Icons.medical_services_outlined,
      ResponsePlaceType.otherPartnerSite => Icons.handshake_outlined,
      ResponsePlaceType.sdisStation => Icons.local_fire_department_outlined,
      ResponsePlaceType.interventionSector => Icons.location_city_outlined,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('place-card-${place.id}'),
        onTap: onTap,
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
                    if (place.verifiedAddress != null) ...[
                      const SizedBox(height: 4),
                      LocationAddressLine(location: place),
                    ],
                    const SizedBox(height: 7),
                    _ActivityStatus(
                      active: place.isActive,
                      operational: place.isOperational,
                    ),
                    const SizedBox(height: 7),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Voir le lieu',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(Icons.chevron_right_rounded, size: 17),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityStatus extends StatelessWidget {
  const _ActivityStatus({required this.active, required this.operational});
  final bool active;
  final bool operational;

  @override
  Widget build(BuildContext context) {
    final color = !operational
        ? AppColors.orange
        : active
        ? AppColors.green
        : AppColors.textMuted;
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
          !operational
              ? 'Non opérationnel'
              : active
              ? 'Actif'
              : 'Inactif',
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
