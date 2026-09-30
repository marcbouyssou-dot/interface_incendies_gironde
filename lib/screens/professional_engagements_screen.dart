import 'dart:async';

import 'package:flutter/material.dart';

import '../models/need.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../theme/v5_foundation.dart';
import '../utils/french_date_time.dart';
import '../utils/mission_timing.dart';
import '../widgets/common.dart';
import '../widgets/mission_location_details.dart';
import '../widgets/professional_page_header.dart';
import '../widgets/v5_controls.dart';

enum _EngagementPeriod { upcoming, current, past }

typedef _EngagementItem =
    ({CoordinationNeed mission, EngagementInfo engagement});

class ProfessionalEngagementsScreen extends StatefulWidget {
  const ProfessionalEngagementsScreen({super.key});

  @override
  State<ProfessionalEngagementsScreen> createState() =>
      _ProfessionalEngagementsScreenState();
}

class _ProfessionalEngagementsScreenState
    extends State<ProfessionalEngagementsScreen> {
  LiveCoordinationData? _liveData;
  Stream<List<CoordinationNeed>>? _missions;
  Stream<List<ResponsePlace>>? _locations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liveData = LiveCoordinationDataScope.of(context);
    if (identical(liveData, _liveData)) return;
    _liveData = liveData;
    _missions = liveData.watchMissions();
    _locations = liveData.watchLocations();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.v5Colors.canvas,
      child: StreamBuilder<List<CoordinationNeed>>(
        stream: _missions,
        builder: (context, missionSnapshot) {
          if (missionSnapshot.hasError) {
            return const _EngagementLoadError();
          }
          if (!missionSnapshot.hasData) {
            return const Center(child: V5ActivityIndicator());
          }
          return StreamBuilder<List<ResponsePlace>>(
            stream: _locations,
            builder: (context, locationSnapshot) {
              if (locationSnapshot.hasError) {
                return const _EngagementLoadError();
              }
              if (!locationSnapshot.hasData) {
                return const Center(child: V5ActivityIndicator());
              }
              return _ProfessionalEngagementCollection(
                liveData: _liveData!,
                missions: missionSnapshot.data!,
                locations: locationSnapshot.data!,
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfessionalEngagementCollection extends StatefulWidget {
  const _ProfessionalEngagementCollection({
    required this.liveData,
    required this.missions,
    required this.locations,
  });

  final LiveCoordinationData liveData;
  final List<CoordinationNeed> missions;
  final List<ResponsePlace> locations;

  @override
  State<_ProfessionalEngagementCollection> createState() =>
      _ProfessionalEngagementCollectionState();
}

class _ProfessionalEngagementCollectionState
    extends State<_ProfessionalEngagementCollection> {
  final Map<String, StreamSubscription<EngagementInfo?>> _subscriptions = {};
  final Map<String, EngagementInfo?> _engagements = {};
  final Set<String> _waiting = {};
  bool _pastExpanded = false;

  @override
  void initState() {
    super.initState();
    _syncSubscriptions();
  }

  @override
  void didUpdateWidget(_ProfessionalEngagementCollection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.liveData, widget.liveData) ||
        oldWidget.missions != widget.missions) {
      _syncSubscriptions();
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  void _syncSubscriptions() {
    final ids = widget.missions.map((mission) => mission.id).toSet();
    for (final id in _subscriptions.keys.toList(growable: false)) {
      if (ids.contains(id)) continue;
      unawaited(_subscriptions.remove(id)?.cancel());
      _engagements.remove(id);
      _waiting.remove(id);
    }
    for (final id in ids) {
      if (_subscriptions.containsKey(id)) continue;
      _waiting.add(id);
      _subscriptions[id] = widget.liveData
          .watchMyEngagement(id)
          .listen(
            (engagement) {
              if (!mounted) return;
              setState(() {
                _waiting.remove(id);
                _engagements[id] = engagement;
              });
            },
            onError: (_, _) {
              if (!mounted) return;
              setState(() {
                _waiting.remove(id);
                _engagements[id] = null;
              });
            },
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEngagements =
        widget.missions
            .where((mission) => _engagements[mission.id] != null)
            .map(
              (mission) =>
                  (mission: mission, engagement: _engagements[mission.id]!),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final aDate = a.mission.startAt ?? DateTime(9999);
            final bDate = b.mission.startAt ?? DateTime(9999);
            return aDate.compareTo(bDate);
          });
    final today = allEngagements
        .where((item) => _periodFor(item.mission) == _EngagementPeriod.current)
        .toList(growable: false);
    final upcoming = allEngagements
        .where((item) => _periodFor(item.mission) == _EngagementPeriod.upcoming)
        .toList(growable: false);
    final past = allEngagements
        .where((item) => _periodFor(item.mission) == _EngagementPeriod.past)
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth <= 556
            ? 18.0
            : (constraints.maxWidth - 520) / 2;
        return ListView(
          key: const PageStorageKey('professional-engagements'),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            10,
            horizontalPadding,
            36,
          ),
          children: [
            const ProfessionalIdentityHeader(),
            const SizedBox(height: V5Spacing.md),
            if (_waiting.isNotEmpty && allEngagements.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: V5Spacing.xl),
                child: Center(child: V5ActivityIndicator()),
              )
            else ...[
              _EngagementPeriodSection(
                title: 'AUJOURD’HUI',
                emptyMessage: 'Aucun engagement aujourd’hui.',
                items: today,
                locations: widget.locations,
              ),
              const SizedBox(height: V5Spacing.lg),
              _EngagementPeriodSection(
                title: 'À VENIR',
                emptyMessage: 'Aucun engagement à venir.',
                items: upcoming,
                locations: widget.locations,
              ),
              const SizedBox(height: V5Spacing.lg),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const Key('professional-past-engagements'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  initiallyExpanded: _pastExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() => _pastExpanded = expanded);
                  },
                  title: Text(
                    'PASSÉS (${past.length})',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: context.v5Colors.textSecondary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  children: [
                    if (past.isEmpty)
                      const _EngagementEmptyState(
                        period: _EngagementPeriod.past,
                      )
                    else
                      _EngagementCards(
                        items: past,
                        locations: widget.locations,
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  _EngagementPeriod _periodFor(CoordinationNeed mission) {
    if (!mission.isActive || mission.isCancelled) {
      return _EngagementPeriod.past;
    }
    return switch (missionTemporalState(mission)) {
      MissionTemporalState.upcoming => _EngagementPeriod.upcoming,
      MissionTemporalState.current => _EngagementPeriod.current,
      MissionTemporalState.past => _EngagementPeriod.past,
    };
  }
}

class _EngagementPeriodSection extends StatelessWidget {
  const _EngagementPeriodSection({
    required this.title,
    required this.emptyMessage,
    required this.items,
    required this.locations,
  });

  final String title;
  final String emptyMessage;
  final List<_EngagementItem> items;
  final List<ResponsePlace> locations;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: context.v5Colors.info,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: V5Spacing.sm),
      if (items.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(V5Spacing.md),
          decoration: BoxDecoration(
            color: context.v5Colors.surfaceMuted,
            borderRadius: BorderRadius.circular(V5Radius.control),
          ),
          child: Text(
            emptyMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.v5Colors.textSecondary,
            ),
          ),
        )
      else
        _EngagementCards(items: items, locations: locations),
    ],
  );
}

class _EngagementCards extends StatelessWidget {
  const _EngagementCards({required this.items, required this.locations});

  final List<_EngagementItem> items;
  final List<ResponsePlace> locations;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < items.length; index++) ...[
        _EngagementCard(
          mission: items[index].mission,
          engagement: items[index].engagement,
          location: responsePlaceForNeed(items[index].mission, locations),
        ),
        if (index < items.length - 1)
          const SizedBox(height: V5Spacing.sm),
      ],
    ],
  );
}

class _EngagementCard extends StatelessWidget {
  const _EngagementCard({
    required this.mission,
    required this.engagement,
    required this.location,
  });

  final CoordinationNeed mission;
  final EngagementInfo engagement;
  final ResponsePlace? location;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return V5Card(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
      boxShadow: V5Elevation.level1(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  mission.place,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              V5StatusPill(
                label: engagement.status.label,
                tone: switch (engagement.status) {
                  EngagementStatus.confirmed => V5StatusTone.success,
                  EngagementStatus.pending => V5StatusTone.warning,
                  EngagementStatus.standby => V5StatusTone.info,
                  EngagementStatus.cancelled => V5StatusTone.neutral,
                },
              ),
            ],
          ),
          const SizedBox(height: V5Spacing.sm),
          _EngagementLine(
            icon: Icons.calendar_today_outlined,
            value: mission.startAt == null
                ? mission.date
                : FrenchDateTime.relativeDate(mission.startAt!),
          ),
          const SizedBox(height: 6),
          _EngagementLine(icon: Icons.schedule_rounded, value: mission.time),
          const SizedBox(height: 6),
          _EngagementLine(
            icon: Icons.medical_services_outlined,
            value: engagement.profession.label,
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: V5Spacing.sm),
              title: Text(
                'Informations pratiques',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: colors.textSecondary),
              ),
              children: [
                MissionLocationDetails(location: location, compact: true),
                if (mission.equipment.isNotEmpty) ...[
                  const SizedBox(height: V5Spacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Matériel : ${mission.equipment.join(' • ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                EngagementCancellationButton(
                  need: mission,
                  engagement: engagement,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EngagementLine extends StatelessWidget {
  const _EngagementLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: context.v5Colors.textSecondary),
      const SizedBox(width: V5Spacing.xs),
      Expanded(
        child: Text(value, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}

class _EngagementEmptyState extends StatelessWidget {
  const _EngagementEmptyState({required this.period});

  final _EngagementPeriod period;

  @override
  Widget build(BuildContext context) {
    final message = switch (period) {
      _EngagementPeriod.upcoming => 'Aucun engagement à venir.',
      _EngagementPeriod.current => 'Aucun engagement aujourd’hui.',
      _EngagementPeriod.past => 'Aucun engagement passé.',
    };
    return Padding(
      padding: const EdgeInsets.all(V5Spacing.xl),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _EngagementLoadError extends StatelessWidget {
  const _EngagementLoadError();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(V5Spacing.xl),
      child: Text(
        'Vos engagements sont temporairement indisponibles.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}
