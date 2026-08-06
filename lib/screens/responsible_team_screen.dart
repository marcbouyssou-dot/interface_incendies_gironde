import 'package:flutter/material.dart';

import '../models/health_profession.dart';
import '../models/need.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../theme/v5_foundation.dart';
import 'coordination_screen.dart' show missionsVisibleToResponsible;

class ResponsibleTeamScreen extends StatefulWidget {
  const ResponsibleTeamScreen({super.key, this.previewLocationId});

  final String? previewLocationId;

  @override
  State<ResponsibleTeamScreen> createState() => _ResponsibleTeamScreenState();
}

class _ResponsibleTeamScreenState extends State<ResponsibleTeamScreen> {
  LiveCoordinationData? _liveData;
  Stream<List<CoordinationNeed>>? _missions;
  Stream<List<ResponsePlace>>? _locations;
  Stream<ResponsibleAccess?>? _access;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liveData = LiveCoordinationDataScope.of(context);
    if (identical(liveData, _liveData)) return;
    _liveData = liveData;
    _missions = liveData.watchMissions();
    _locations = liveData.watchLocations();
    _access = liveData.watchResponsibleAccess();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ResponsibleAccess?>(
      stream: _access,
      builder: (context, accessSnapshot) =>
          StreamBuilder<List<CoordinationNeed>>(
            stream: _missions,
            builder: (context, missionsSnapshot) =>
                StreamBuilder<List<ResponsePlace>>(
                  stream: _locations,
                  builder: (context, locationsSnapshot) {
                    if (accessSnapshot.hasError ||
                        missionsSnapshot.hasError ||
                        locationsSnapshot.hasError) {
                      return const _TeamStateMessage(
                        message: 'L’équipe est temporairement indisponible.',
                      );
                    }
                    if (!missionsSnapshot.hasData ||
                        !locationsSnapshot.hasData) {
                      return const Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final visibleNeeds =
                        missionsVisibleToResponsible(
                              missions: missionsSnapshot.data!,
                              locations: locationsSnapshot.data!,
                              access: accessSnapshot.data,
                              previewLocationId: widget.previewLocationId,
                            )
                            .where((need) => need.isActive && !need.isCancelled)
                            .toList(growable: false);
                    return _ResponsibleTeamContent(needs: visibleNeeds);
                  },
                ),
          ),
    );
  }
}

class _ResponsibleTeamContent extends StatelessWidget {
  const _ResponsibleTeamContent({required this.needs});

  final List<CoordinationNeed> needs;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return ColoredBox(
      color: colors.canvas,
      child: CustomScrollView(
        key: const PageStorageKey('responsible-team'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Équipe',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: V5Spacing.xs),
                      Text(
                        'Professionnels confirmés ou en attente sur vos besoins.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (needs.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _TeamStateMessage(
                message: 'Aucun besoin actif sur votre périmètre.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverList.separated(
                itemCount: needs.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: V5Spacing.md),
                itemBuilder: (context, index) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _MissionTeamSection(need: needs[index]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MissionTeamSection extends StatefulWidget {
  const _MissionTeamSection({required this.need});

  final CoordinationNeed need;

  @override
  State<_MissionTeamSection> createState() => _MissionTeamSectionState();
}

class _MissionTeamSectionState extends State<_MissionTeamSection> {
  LiveCoordinationData? _liveData;
  Stream<List<EngagementInfo>>? _engagements;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStream();
  }

  @override
  void didUpdateWidget(_MissionTeamSection oldWidget) {
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
    final colors = context.v5Colors;
    return Container(
      key: Key('responsible-team-${widget.need.id}'),
      padding: const EdgeInsets.all(V5Spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.need.place,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: V5Spacing.xxs),
          Text(
            '${widget.need.date} · ${widget.need.time}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: V5Spacing.md),
          StreamBuilder<List<EngagementInfo>>(
            stream: _engagements,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Informations indisponibles.',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              if (!snapshot.hasData) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              final engagements = snapshot.data!
                  .where(
                    (engagement) =>
                        engagement.status != EngagementStatus.cancelled,
                  )
                  .toList(growable: false);
              if (engagements.isEmpty) {
                return Text(
                  'Aucun professionnel confirmé ou en attente.',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              return Column(
                children: [
                  for (var index = 0; index < engagements.length; index++) ...[
                    _TeamMemberRow(engagement: engagements[index]),
                    if (index < engagements.length - 1)
                      Divider(
                        height: V5Spacing.lg,
                        thickness: 0.5,
                        color: colors.outline,
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TeamMemberRow extends StatelessWidget {
  const _TeamMemberRow({required this.engagement});

  final EngagementInfo engagement;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final profession =
        HealthProfessionRegistry.byId(
          engagement.profession.canonicalId!,
        )?.missionLabel ??
        engagement.profession.label;
    final statusColor = switch (engagement.status) {
      EngagementStatus.confirmed => colors.success,
      EngagementStatus.pending || EngagementStatus.standby => colors.warning,
      EngagementStatus.cancelled => colors.textSecondary,
    };
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_outline_rounded,
            size: 17,
            color: colors.info,
          ),
        ),
        const SizedBox(width: V5Spacing.sm),
        Expanded(
          child: Text(
            profession,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
        ),
        const SizedBox(width: V5Spacing.sm),
        Text(
          engagement.status.label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: statusColor),
        ),
      ],
    );
  }
}

class _TeamStateMessage extends StatelessWidget {
  const _TeamStateMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(V5Spacing.xl),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}
