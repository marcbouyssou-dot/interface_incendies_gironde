import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/common.dart';
import 'coordination_screen.dart' show missionsVisibleToResponsible;
import 'create_need_screen.dart';

class ResponsibleNeedsScreen extends StatefulWidget {
  const ResponsibleNeedsScreen({super.key, this.previewLocationId});

  final String? previewLocationId;

  @override
  State<ResponsibleNeedsScreen> createState() => _ResponsibleNeedsScreenState();
}

class _ResponsibleNeedsScreenState extends State<ResponsibleNeedsScreen> {
  LiveCoordinationData? _liveData;
  Stream<List<CoordinationNeed>>? _missions;
  Stream<List<ResponsePlace>>? _locations;
  Stream<ResponsibleAccess?>? _access;
  String? _editingMissionId;

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
                      return const _NeedsMessage(
                        message:
                            'Les besoins sont temporairement indisponibles.',
                      );
                    }
                    if (!missionsSnapshot.hasData ||
                        !locationsSnapshot.hasData) {
                      return const _NeedsLoading();
                    }
                    final locations = locationsSnapshot.data!;
                    final needs =
                        missionsVisibleToResponsible(
                              missions: missionsSnapshot.data!,
                              locations: locations,
                              access: accessSnapshot.data,
                              previewLocationId: widget.previewLocationId,
                            )
                            .where((need) => need.isActive && !need.isCancelled)
                            .toList(growable: false);
                    return _ResponsibleNeedsContent(
                      needs: needs,
                      locations: locations,
                      access: accessSnapshot.data,
                      editingMissionId: _editingMissionId,
                      onCreateNeed: _openCreateNeed,
                      onEditNeed: _openEditor,
                    );
                  },
                ),
          ),
    );
  }

  void _openCreateNeed() {
    final liveData = _liveData!;
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: CreateNeedScreen(
            onViewMission: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(CoordinationNeed need) async {
    if (_editingMissionId != null) return;
    setState(() => _editingMissionId = need.id);
    try {
      await openMissionEditor(context, need);
    } finally {
      if (mounted) setState(() => _editingMissionId = null);
    }
  }
}

class _ResponsibleNeedsContent extends StatelessWidget {
  const _ResponsibleNeedsContent({
    required this.needs,
    required this.locations,
    required this.access,
    required this.editingMissionId,
    required this.onCreateNeed,
    required this.onEditNeed,
  });

  final List<CoordinationNeed> needs;
  final List<ResponsePlace> locations;
  final ResponsibleAccess? access;
  final String? editingMissionId;
  final VoidCallback onCreateNeed;
  final ValueChanged<CoordinationNeed> onEditNeed;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return ColoredBox(
      color: colors.canvas,
      child: CustomScrollView(
        key: const PageStorageKey('responsible-needs'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Besoins',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: V5Spacing.xs),
                      Text(
                        'Suivez et ajustez les besoins de vos centres.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: V5Spacing.xl),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('responsible-needs-create'),
                          onPressed: onCreateNeed,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: colors.info,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                V5Radius.control,
                              ),
                            ),
                          ),
                          child: const Text('Créer un besoin'),
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
              child: _NeedsMessage(message: 'Aucun besoin en cours.'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverList.separated(
                itemCount: needs.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: V5Spacing.md),
                itemBuilder: (context, index) {
                  final need = needs[index];
                  final location = responsePlaceForNeed(need, locations);
                  final locationId = need.locationId ?? location?.id;
                  final canManage =
                      access != null &&
                      locationId != null &&
                      access!.canManage(locationId) &&
                      need.isActive &&
                      !need.isCancelled;
                  final canCancel = canManage && need.createdBy == access!.uid;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: _ResponsibleNeedCard(
                        need: need,
                        canEdit: canManage,
                        canCancel: canCancel,
                        editing: editingMissionId == need.id,
                        editorBlocked: editingMissionId != null,
                        onEdit: () => onEditNeed(need),
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

class _ResponsibleNeedCard extends StatelessWidget {
  const _ResponsibleNeedCard({
    required this.need,
    required this.canEdit,
    required this.canCancel,
    required this.editing,
    required this.editorBlocked,
    required this.onEdit,
  });

  final CoordinationNeed need;
  final bool canEdit;
  final bool canCancel;
  final bool editing;
  final bool editorBlocked;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final required = need.professionQuotas.requiredTotal;
    final registered = need.professionQuotas.registeredTotal;
    final remaining = need.professionQuotas.values.fold<int>(
      0,
      (total, quota) => total + quota.missing,
    );
    final progress = required == 0 ? 1.0 : need.professionQuotas.coverage;
    return Container(
      key: Key('responsible-need-${need.id}'),
      padding: const EdgeInsets.all(V5Spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(need.place, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: V5Spacing.xs),
          Text(
            '${need.date} · ${need.time}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: V5Spacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$registered sur $required postes couverts',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: colors.textPrimary),
                ),
              ),
              Text(
                remaining == 0
                    ? 'Complet'
                    : remaining == 1
                    ? '1 à couvrir'
                    : '$remaining à couvrir',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: remaining == 0 ? colors.success : colors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: V5Spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(V5Radius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: colors.surfaceMuted,
              color: remaining == 0 ? colors.success : colors.info,
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: V5Spacing.lg),
            Wrap(
              spacing: V5Spacing.sm,
              runSpacing: V5Spacing.sm,
              children: [
                OutlinedButton(
                  key: Key('responsible-edit-need-${need.id}'),
                  onPressed: editorBlocked ? null : onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.info,
                    minimumSize: const Size(0, 44),
                    side: BorderSide(color: colors.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(V5Radius.control),
                    ),
                  ),
                  child: Text(editing ? 'Ouverture…' : 'Modifier'),
                ),
                if (canCancel) MissionCancellationButton(need: need),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NeedsLoading extends StatelessWidget {
  const _NeedsLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}

class _NeedsMessage extends StatelessWidget {
  const _NeedsMessage({required this.message});

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
