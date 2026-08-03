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

abstract final class _PlacesVisuals {
  static const background = Color(0xFFF5F5F3);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF7C817F);
}

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth <= 556
              ? 18.0
              : (constraints.maxWidth - 520) / 2;
          return Material(
            color: _PlacesVisuals.background,
            child: CustomScrollView(
              key: const PageStorageKey('places'),
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
                      const _PlacesHeader(),
                      const SizedBox(height: 18),
                      _PlacesInfoLinks(
                        onOpenAbout: () => Navigator.of(context).push(
                          AppPageRoute<void>(
                            builder: (_) => const AboutScreen(),
                          ),
                        ),
                        onOpenLegalNotice: () => Navigator.of(context).push(
                          AppPageRoute<void>(
                            builder: (_) => const LegalNoticeScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                        decoration: BoxDecoration(
                          color: _PlacesVisuals.surface,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: _PlacesVisuals.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'FILTRER PAR SECTEUR',
                              style: TextStyle(
                                color: _PlacesVisuals.textMuted,
                                fontSize: 9,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 9),
                            TerritorialGroupFilter(
                              key: const Key('places-territorial-filter'),
                              value: _group,
                              onChanged: (group) =>
                                  setState(() => _group = group),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _PlacesResultsHeader(count: visiblePlaces.length),
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
                    itemCount: visiblePlaces.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 11),
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
        },
      ),
    );
  }
}

class _PlacesHeader extends StatelessWidget {
  const _PlacesHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DISPOSITIF TERRITORIAL',
          style: TextStyle(
            color: _PlacesVisuals.textMuted,
            fontSize: 10,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Lieux',
          style: TextStyle(
            color: _PlacesVisuals.navy,
            fontSize: 28,
            height: 1.1,
            letterSpacing: -0.7,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Les points d’intervention mobilisés en Gironde.',
          style: TextStyle(
            color: _PlacesVisuals.textMuted,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PlacesInfoLinks extends StatelessWidget {
  const _PlacesInfoLinks({
    required this.onOpenAbout,
    required this.onOpenLegalNotice,
  });

  final VoidCallback onOpenAbout;
  final VoidCallback onOpenLegalNotice;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _PlacesVisuals.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: _PlacesVisuals.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: _PlacesInfoLink(
              key: const Key('about-entry'),
              icon: Icons.info_outline_rounded,
              label: 'À propos',
              onTap: onOpenAbout,
            ),
          ),
          const SizedBox(
            height: 32,
            child: VerticalDivider(width: 1, color: _PlacesVisuals.border),
          ),
          Expanded(
            child: _PlacesInfoLink(
              key: const Key('legal-notice-entry'),
              icon: Icons.gavel_outlined,
              label: 'Mentions légales',
              onTap: onOpenLegalNotice,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacesInfoLink extends StatelessWidget {
  const _PlacesInfoLink({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _PlacesVisuals.navy, size: 19),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _PlacesVisuals.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlacesResultsHeader extends StatelessWidget {
  const _PlacesResultsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RÉPERTOIRE',
          style: TextStyle(
            color: _PlacesVisuals.textMuted,
            fontSize: 9,
            letterSpacing: 1.05,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$count lieux référencés',
          style: const TextStyle(
            color: _PlacesVisuals.navy,
            fontSize: 19,
            letterSpacing: -0.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
    return Material(
      color: _PlacesVisuals.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _PlacesVisuals.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('place-card-${place.id}'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 132),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _PlacesVisuals.fieldBackground,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, color: _PlacesVisuals.navy, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: const TextStyle(
                              color: _PlacesVisuals.navy,
                              fontSize: 17,
                              height: 1.15,
                              letterSpacing: -0.25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            place.type.label,
                            style: const TextStyle(
                              color: _PlacesVisuals.textMuted,
                              fontSize: 12,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: _PlacesVisuals.textMuted,
                        size: 21,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.map_outlined,
                        color: _PlacesVisuals.textMuted,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        place.group.label,
                        style: const TextStyle(
                          color: _PlacesVisuals.navy,
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (place.verifiedAddress != null) ...[
                  const SizedBox(height: 7),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.location_on_outlined,
                          color: _PlacesVisuals.textMuted,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(child: LocationAddressLine(location: place)),
                    ],
                  ),
                ],
                const SizedBox(height: 13),
                Row(
                  children: [
                    _ActivityStatus(
                      active: place.isActive,
                      operational: place.isOperational,
                    ),
                    const Spacer(),
                    const Text(
                      'Voir le lieu',
                      style: TextStyle(
                        color: _PlacesVisuals.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: _PlacesVisuals.navy,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
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
