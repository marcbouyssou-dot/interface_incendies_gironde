import 'package:flutter/material.dart';

import '../models/health_profession.dart';
import '../models/need.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/v5_foundation.dart';
import '../widgets/professional_page_header.dart';
import 'coordination_screen.dart' show missionsVisibleToResponsible;

extension on EngagementStatus {
  String get responsibleLabel => switch (this) {
    EngagementStatus.confirmed => 'Confirmé',
    EngagementStatus.pending => 'En attente',
    EngagementStatus.standby => 'En réserve',
    EngagementStatus.cancelled => 'Annulé',
  };

  String get filterLabel => switch (this) {
    EngagementStatus.confirmed => 'Confirmés',
    EngagementStatus.pending => 'En attente',
    EngagementStatus.standby => 'En réserve',
    EngagementStatus.cancelled => 'Annulés',
  };
}

const _responsibleStatusOrder = [
  EngagementStatus.confirmed,
  EngagementStatus.pending,
  EngagementStatus.standby,
  EngagementStatus.cancelled,
];

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
  EngagementStatus _status = EngagementStatus.confirmed;

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
                      return Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            color: context.v5Colors.accent,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }
                    final locations = locationsSnapshot.data!;
                    final visibleNeeds =
                        missionsVisibleToResponsible(
                              missions: missionsSnapshot.data!,
                              locations: locations,
                              access: accessSnapshot.data,
                              previewLocationId: widget.previewLocationId,
                            )
                            .where((need) => need.isActive && !need.isCancelled)
                            .toList(growable: false);
                    return _ResponsibleTeamContent(
                      needs: visibleNeeds,
                      locations: locations,
                      access: accessSnapshot.data,
                      selectedStatus: _status,
                      onStatusChanged: (status) =>
                          setState(() => _status = status),
                    );
                  },
                ),
          ),
    );
  }
}

class _ResponsibleTeamContent extends StatelessWidget {
  const _ResponsibleTeamContent({
    required this.needs,
    required this.locations,
    required this.access,
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  final List<CoordinationNeed> needs;
  final List<ResponsePlace> locations;
  final ResponsibleAccess? access;
  final EngagementStatus selectedStatus;
  final ValueChanged<EngagementStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return ColoredBox(
      color: colors.canvas,
      child: CustomScrollView(
        key: const PageStorageKey('responsible-team'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MobSantePageHeader(
                        title: 'Mon équipe',
                        subtitle:
                            'Retrouvez les professionnels mobilisés sur vos besoins.',
                      ),
                      const SizedBox(height: V5Spacing.lg),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final status in _responsibleStatusOrder) ...[
                              _StatusChip(
                                status: status,
                                selected: status == selectedStatus,
                                onSelected: () => onStatusChanged(status),
                              ),
                              if (status != _responsibleStatusOrder.last)
                                const SizedBox(width: V5Spacing.xs),
                            ],
                          ],
                        ),
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
                    const SizedBox(height: V5Spacing.xl),
                itemBuilder: (context, index) {
                  final need = needs[index];
                  final location = responsePlaceForNeed(need, locations);
                  final locationId = need.locationId ?? location?.id;
                  final canManage =
                      access?.isCoordinator == true &&
                      locationId != null &&
                      access!.canManage(locationId);
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: _MissionTeamSection(
                        need: need,
                        selectedStatus: selectedStatus,
                        canManage: canManage,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.selected,
    required this.onSelected,
  });

  final EngagementStatus status;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return ChoiceChip(
      key: Key('responsible-team-filter-${status.name}'),
      label: Text(status.filterLabel),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: colors.accent,
      backgroundColor: colors.surfaceElevated,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(V5Radius.pill),
      ),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? colors.onAccent : colors.textSecondary,
      ),
    );
  }
}

class _MissionTeamSection extends StatefulWidget {
  const _MissionTeamSection({
    required this.need,
    required this.selectedStatus,
    required this.canManage,
  });

  final CoordinationNeed need;
  final EngagementStatus selectedStatus;
  final bool canManage;

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
    return Column(
      key: Key('responsible-team-${widget.need.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.need.place, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: V5Spacing.xxs),
        Text(
          '${widget.need.date} · ${widget.need.time}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: V5Spacing.sm),
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
              return LinearProgressIndicator(
                minHeight: 2,
                color: colors.accent,
              );
            }
            final engagements = snapshot.data!
                .where(
                  (engagement) => engagement.status == widget.selectedStatus,
                )
                .toList(growable: false);
            if (engagements.isEmpty) {
              return Text(
                'Aucun professionnel ${widget.selectedStatus.filterLabel.toLowerCase()} '
                'sur cette mission.',
                style: Theme.of(context).textTheme.bodySmall,
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(V5Radius.section),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = 0; index < engagements.length; index++) ...[
                    _TeamMemberRow(
                      engagement: engagements[index],
                      missionLabel: widget.need.place,
                      canManage: widget.canManage,
                    ),
                    if (index < engagements.length - 1)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: V5Spacing.md,
                        color: colors.outline,
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TeamMemberRow extends StatefulWidget {
  const _TeamMemberRow({
    required this.engagement,
    required this.missionLabel,
    required this.canManage,
  });

  final EngagementInfo engagement;
  final String missionLabel;
  final bool canManage;

  @override
  State<_TeamMemberRow> createState() => _TeamMemberRowState();
}

class _TeamMemberRowState extends State<_TeamMemberRow> {
  bool _updating = false;

  Future<void> _update(EngagementStatus status) async {
    if (_updating || status == widget.engagement.status) return;
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
    final colors = context.v5Colors;
    final engagement = widget.engagement;
    final profession =
        HealthProfessionRegistry.byId(
          engagement.profession.canonicalId!,
        )?.missionLabel ??
        engagement.profession.label;
    final statusColor = switch (engagement.status) {
      EngagementStatus.confirmed => colors.success,
      EngagementStatus.pending => colors.accent,
      EngagementStatus.standby ||
      EngagementStatus.cancelled => colors.textSecondary,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 62),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    engagement.volunteerId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$profession · ${widget.missionLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: V5Spacing.sm),
            Text(
              engagement.status.responsibleLabel,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: statusColor),
            ),
            if (widget.canManage) ...[
              const SizedBox(width: V5Spacing.xxs),
              if (_updating)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                PopupMenuButton<EngagementStatus>(
                  key: Key('engagement-menu-${engagement.documentId}'),
                  tooltip: 'Modifier le statut',
                  iconColor: colors.accent,
                  onSelected: _update,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: EngagementStatus.confirmed,
                      child: Text('Confirmer'),
                    ),
                    PopupMenuItem(
                      value: EngagementStatus.standby,
                      child: Text('Mettre en réserve'),
                    ),
                    PopupMenuItem(
                      value: EngagementStatus.cancelled,
                      child: Text('Annuler'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
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
