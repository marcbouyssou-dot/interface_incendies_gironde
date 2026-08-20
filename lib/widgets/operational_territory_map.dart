import 'dart:async';

import 'package:flutter/material.dart';

import '../coordinator/cockpit_view_data.dart';
import '../coordinator/territory_view_data.dart';
import '../models/need.dart';
import '../operational_map/maplibre_operational_map.dart';
import '../operational_map/operational_map_feature.dart';
import '../operational_map/operational_map_renderer.dart';
import '../operational_map/operational_map_surface.dart';
import '../theme/v5_foundation.dart';
import 'cockpit_operational_map_adapter.dart';
import 'territory_components.dart';
import 'v5_controls.dart';

class OperationalTerritoryMap extends StatefulWidget {
  const OperationalTerritoryMap({
    super.key,
    required this.points,
    required this.locationCount,
    required this.missionCount,
    required this.tensionCount,
    required this.onViewLocation,
    this.height = 280,
  });

  final List<CockpitMapPoint> points;
  final int locationCount;
  final int missionCount;
  final int tensionCount;
  final ValueChanged<ResponsePlace> onViewLocation;
  final double height;

  @override
  State<OperationalTerritoryMap> createState() =>
      _OperationalTerritoryMapState();
}

class _OperationalTerritoryMapState extends State<OperationalTerritoryMap> {
  String? _selectedLocationId;
  OperationalMapRenderer? _mapRenderer;

  @override
  void didUpdateWidget(covariant OperationalTerritoryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedLocationId != null &&
        !widget.points.any(
          (point) => point.location.id == _selectedLocationId,
        )) {
      _selectedLocationId = null;
    }
  }

  void _selectPoint(CockpitMapPoint point) {
    setState(() => _selectedLocationId = point.location.id);
    unawaited(_mapRenderer?.selectCenter(point.location.id));
  }

  void _clearSelection() {
    if (_selectedLocationId == null) return;
    setState(() => _selectedLocationId = null);
    unawaited(_mapRenderer?.deselectCenter());
  }

  void _handleMapSelection(OperationalMapFeature? feature) {
    final nextId = feature?.id;
    if (nextId == _selectedLocationId || !mounted) return;
    setState(() => _selectedLocationId = nextId);
  }

  void _handleRendererChanged(OperationalMapRenderer? renderer) =>
      _mapRenderer = renderer;

  void _recenter() => unawaited(_mapRenderer?.recenterCamera());

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final missionPoints = widget.points
        .where((point) => point.hasMission)
        .toList();
    final critical = missionPoints
        .where((point) => point.status == TerritoryOperationalStatus.critical)
        .length;
    final watch = missionPoints
        .where((point) => point.status == TerritoryOperationalStatus.watch)
        .length;
    final selectedPoint = widget.points
        .where((point) => point.location.id == _selectedLocationId)
        .firstOrNull;
    final mapFeatures = <OperationalMapFeature>[
      for (final point in widget.points)
        operationalMapFeatureFromCockpitPoint(
          point,
          selected: point.location.id == _selectedLocationId,
        ),
    ];
    final mapSurfaceRequest = OperationalMapSurfaceRequest(
      features: mapFeatures,
      accessibilityFeatures: <OperationalMapAccessibilityFeature>[
        for (final point in widget.points)
          OperationalMapAccessibilityFeature(
            id: point.location.id,
            label: '${point.accessibilityLabel} Afficher la fiche du centre.',
            selected: point.location.id == _selectedLocationId,
            visualDiameter: point.visualDiameter,
            missionCount: point.missionCount,
            onTap: () => _selectPoint(point),
          ),
      ],
      mapKey: const Key('cockpit-map-interactive-viewer'),
      onSelectionChanged: _handleMapSelection,
      onRendererChanged: _handleRendererChanged,
    );
    final summary =
        'Carte opérationnelle de Gironde. '
        '${widget.locationCount} établissements, '
        '${widget.missionCount} missions, '
        '${widget.tensionCount} tensions. '
        '$critical établissements critiques et $watch à surveiller.';

    return Semantics(
      key: const Key('cockpit-map-semantics'),
      container: true,
      explicitChildNodes: true,
      label: summary,
      child: Container(
        key: const Key('cockpit-operational-map'),
        height: widget.height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(V5Radius.large),
          border: Border.all(color: colors.outline),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final transitionDuration = MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160);
            final mapSurface = OperationalMapSurfaceRegistry.build(
              context,
              mapSurfaceRequest,
              productionBuilder: buildMapLibreOperationalMapSurface,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: OperationalMapSurfaceRegistry.hasDebugBuilder
                      ? mapSurface
                      : ExcludeSemantics(child: mapSurface),
                ),
                if (!OperationalMapSurfaceRegistry.hasDebugBuilder)
                  for (final point in widget.points)
                    Semantics(
                      key: Key('cockpit-map-location-${point.location.id}'),
                      button: true,
                      selected: point.location.id == _selectedLocationId,
                      label:
                          '${point.accessibilityLabel} Afficher la fiche du centre.',
                      onTap: () => _selectPoint(point),
                      child: const SizedBox.shrink(),
                    ),
                Positioned(
                  top: V5Spacing.sm,
                  left: V5Spacing.sm,
                  child: _RecenterButton(onPressed: _recenter),
                ),
                Positioned(
                  top: V5Spacing.sm,
                  right: V5Spacing.sm,
                  child: _MapCounters(
                    locationCount: widget.locationCount,
                    missionCount: widget.missionCount,
                    tensionCount: widget.tensionCount,
                  ),
                ),
                Positioned(
                  left: V5Spacing.sm,
                  right: V5Spacing.sm,
                  bottom: V5Spacing.sm,
                  child: AnimatedSwitcher(
                    duration: transitionDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: selectedPoint == null
                        ? const _MapLegend(key: ValueKey('cockpit-map-legend'))
                        : _SelectedLocationCard(
                            key: ValueKey(
                              'cockpit-map-card-${selectedPoint.location.id}',
                            ),
                            point: selectedPoint,
                            onClose: _clearSelection,
                            onViewLocation: () =>
                                widget.onViewLocation(selectedPoint.location),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MapCounters extends StatelessWidget {
  const _MapCounters({
    required this.locationCount,
    required this.missionCount,
    required this.tensionCount,
  });

  final int locationCount;
  final int missionCount;
  final int tensionCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final rows = [
      (
        '$locationCount',
        locationCount == 1 ? 'établissement' : 'établissements',
      ),
      ('$missionCount', missionCount == 1 ? 'mission' : 'missions'),
      ('$tensionCount', tensionCount == 1 ? 'tension' : 'tensions'),
    ];
    return Semantics(
      key: const Key('cockpit-map-counters'),
      label: rows.map((row) => '${row.$1} ${row.$2}').join(', '),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: V5Spacing.sm,
            vertical: V5Spacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceElevated.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(V5Radius.control),
            border: Border.all(color: colors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in rows)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${row.$1} ',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: row.$2),
                    ],
                  ),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Semantics(
      button: true,
      label: 'Recentrer la carte',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceElevated.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(V5Radius.control),
            border: Border.all(color: colors.outline),
          ),
          child: IconButton(
            key: const Key('cockpit-map-recenter'),
            tooltip: 'Recentrer la carte',
            onPressed: onPressed,
            icon: const Icon(Icons.center_focus_strong_rounded),
            color: colors.textPrimary,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

class _SelectedLocationCard extends StatelessWidget {
  const _SelectedLocationCard({
    super.key,
    required this.point,
    required this.onClose,
    required this.onViewLocation,
  });

  final CockpitMapPoint point;
  final VoidCallback onClose;
  final VoidCallback onViewLocation;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final statusColor = point.hasMission
        ? territoryStatusColor(point.status, colors)
        : colors.textSecondary;
    final missionLabel = point.missionCount == 1
        ? '1 mission active'
        : '${point.missionCount} missions actives';
    return Semantics(
      key: const Key('cockpit-map-selection-card'),
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          V5Spacing.md,
          V5Spacing.xs,
          V5Spacing.sm,
          V5Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceElevated.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(V5Radius.card),
          border: Border(left: BorderSide(color: statusColor, width: 4)),
          boxShadow: V5Elevation.level2(colors),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    point.location.name,
                    key: const Key('cockpit-map-selected-location-name'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('cockpit-map-close-card'),
                  tooltip: 'Fermer la fiche',
                  onPressed: onClose,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (!point.hasMission)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LocationStatusLabel(point: point, color: statusColor),
                  const SizedBox(height: V5Spacing.xxs),
                  Text(
                    'Aucune mission active',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              )
            else ...[
              _LocationStatusLabel(point: point, color: statusColor),
              const SizedBox(height: V5Spacing.xxs),
              Text(
                '$missionLabel · ${point.coveragePercent} % de couverture',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (point.nextDeadlineLabel != null) ...[
                const SizedBox(height: V5Spacing.xxs),
                Text(
                  'Prochaine échéance · '
                  '${point.nextDeadlineHorizon?.label ?? 'Plus tard'} · '
                  '${point.nextDeadlineLabel}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
              if (point.mostNeededProfession != null) ...[
                const SizedBox(height: V5Spacing.xxs),
                Text(
                  'Profession en tension · ${point.mostNeededProfession}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: statusColor),
                ),
              ],
            ],
            const SizedBox(height: V5Spacing.sm),
            V5Button(
              key: const Key('cockpit-map-view-location'),
              expanded: true,
              compact: true,
              icon: point.hasMission
                  ? Icons.monitor_heart_outlined
                  : Icons.location_on_outlined,
              label: point.hasMission ? 'Voir la situation' : 'Voir le centre',
              tone: point.hasMission
                  ? V5ButtonTone.primary
                  : V5ButtonTone.secondary,
              backgroundColor: point.hasMission ? statusColor : null,
              foregroundColor: point.hasMission ? Colors.white : null,
              onPressed: onViewLocation,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationStatusLabel extends StatelessWidget {
  const _LocationStatusLabel({required this.point, required this.color});

  final CockpitMapPoint point;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      point.operationalStateLabel,
      key: const Key('cockpit-map-selected-location-status'),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    const items = [
      _LegendItem(
        status: TerritoryOperationalStatus.critical,
        label: 'Critique',
      ),
      _LegendItem(
        status: TerritoryOperationalStatus.watch,
        label: 'À surveiller',
      ),
      _LegendItem(status: TerritoryOperationalStatus.stable, label: 'Couvert'),
      _LegendItem(status: null, label: 'Aucune mission'),
    ];
    return Semantics(
      label:
          'Légende. Rouge : critique. Orange : à surveiller. '
          'Vert : couvert. Gris : aucune mission active.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: V5Spacing.sm,
            vertical: V5Spacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceElevated.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(V5Radius.control),
            border: Border.all(color: colors.outline),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: items,
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.status, required this.label});

  final TerritoryOperationalStatus? status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: status == null
                ? colors.textSecondary.withValues(alpha: 0.62)
                : territoryStatusColor(status!, colors),
            shape: BoxShape.circle,
          ),
          child: const SizedBox.square(dimension: 8),
        ),
        const SizedBox(width: V5Spacing.xxs),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
      ],
    );
  }
}
