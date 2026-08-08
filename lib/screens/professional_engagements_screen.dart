import 'dart:async';

import 'package:flutter/cupertino.dart';
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
  _EngagementPeriod _period = _EngagementPeriod.upcoming;

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
    final visible = allEngagements
        .where((item) => _periodFor(item.mission) == _period)
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth <= 556
            ? 18.0
            : (constraints.maxWidth - 520) / 2;
        return CustomScrollView(
          key: const PageStorageKey('professional-engagements'),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                18,
              ),
              sliver: SliverList.list(
                children: [
                  const ProfessionalPageHeader(
                    title: 'Mes engagements',
                    subtitle: 'Retrouvez vos mobilisations à venir et passées.',
                  ),
                  const SizedBox(height: V5Spacing.lg),
                  CupertinoSlidingSegmentedControl<_EngagementPeriod>(
                    key: const Key('professional-engagement-periods'),
                    groupValue: _period,
                    thumbColor: context.v5Colors.surfaceElevated,
                    backgroundColor: context.v5Colors.surfaceMuted,
                    onValueChanged: (value) {
                      if (value != null) setState(() => _period = value);
                    },
                    children: const {
                      _EngagementPeriod.upcoming: Padding(
                        padding: EdgeInsets.symmetric(vertical: 9),
                        child: Text('À venir'),
                      ),
                      _EngagementPeriod.current: Padding(
                        padding: EdgeInsets.symmetric(vertical: 9),
                        child: Text('En cours'),
                      ),
                      _EngagementPeriod.past: Padding(
                        padding: EdgeInsets.symmetric(vertical: 9),
                        child: Text('Passés'),
                      ),
                    },
                  ),
                ],
              ),
            ),
            if (_waiting.isNotEmpty && allEngagements.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: V5ActivityIndicator()),
              )
            else if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EngagementEmptyState(period: _period),
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
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    return _EngagementCard(
                      mission: item.mission,
                      engagement: item.engagement,
                      location: responsePlaceForNeed(
                        item.mission,
                        widget.locations,
                      ),
                    );
                  },
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: V5Spacing.sm),
                ),
              ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
        boxShadow: V5Elevation.level1(colors),
      ),
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
              _EngagementStatus(status: engagement.status),
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
                  label: 'Je ne suis plus disponible',
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

class _EngagementStatus extends StatelessWidget {
  const _EngagementStatus({required this.status});

  final EngagementStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final (color, background) = switch (status) {
      EngagementStatus.confirmed => (colors.success, colors.successContainer),
      EngagementStatus.pending => (colors.warning, colors.warningContainer),
      EngagementStatus.standby => (colors.info, colors.infoContainer),
      EngagementStatus.cancelled => (colors.textSecondary, colors.surfaceMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(V5Radius.pill),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EngagementEmptyState extends StatelessWidget {
  const _EngagementEmptyState({required this.period});

  final _EngagementPeriod period;

  @override
  Widget build(BuildContext context) {
    final message = switch (period) {
      _EngagementPeriod.upcoming => 'Aucun engagement à venir.',
      _EngagementPeriod.current => 'Aucune mission en cours.',
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
