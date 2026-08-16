import 'package:flutter/material.dart';

import '../coordinator/cockpit_view_data.dart';
import '../coordinator/territory_view_data.dart';
import '../models/need.dart';
import '../theme/v5_foundation.dart';
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

class _OperationalTerritoryMapState extends State<OperationalTerritoryMap>
    with SingleTickerProviderStateMixin {
  final _transformationController = TransformationController();
  late final AnimationController _recenterController;
  Animation<Matrix4>? _recenterAnimation;
  String? _selectedLocationId;

  @override
  void initState() {
    super.initState();
    _recenterController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addListener(() {
          final animation = _recenterAnimation;
          if (animation != null) {
            _transformationController.value = animation.value;
          }
        });
  }

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

  @override
  void dispose() {
    _recenterController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _selectPoint(CockpitMapPoint point) {
    setState(() => _selectedLocationId = point.location.id);
  }

  void _clearSelection() {
    setState(() => _selectedLocationId = null);
  }

  void _recenter() {
    _recenterController.stop();
    if (MediaQuery.disableAnimationsOf(context)) {
      _transformationController.value = Matrix4.identity();
      return;
    }
    _recenterAnimation =
        Matrix4Tween(
          begin: Matrix4.copy(_transformationController.value),
          end: Matrix4.identity(),
        ).animate(
          CurvedAnimation(
            parent: _recenterController,
            curve: Curves.easeOutCubic,
          ),
        );
    _recenterController.forward(from: 0);
  }

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
    final renderedPoints = [
      ...widget.points,
    ]..sort((left, right) => _markerLayer(left).compareTo(_markerLayer(right)));
    final selectedPoint = widget.points
        .where((point) => point.location.id == _selectedLocationId)
        .firstOrNull;
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
            return Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    key: const Key('cockpit-map-interactive-viewer'),
                    transformationController: _transformationController,
                    minScale: 1,
                    maxScale: 3,
                    boundaryMargin: EdgeInsets.zero,
                    constrained: true,
                    panEnabled: true,
                    scaleEnabled: true,
                    trackpadScrollCausesScale: true,
                    onInteractionStart: (_) => _recenterController.stop(),
                    child: RepaintBoundary(
                      child: SizedBox.fromSize(
                        size: constraints.biggest,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _TerritoryMapPainter(colors: colors),
                              ),
                            ),
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _transformationController,
                                builder: (context, _) {
                                  final mapScale = _transformationController
                                      .value
                                      .getMaxScaleOnAxis()
                                      .clamp(1.0, 3.0);
                                  return Stack(
                                    children: [
                                      for (final point in renderedPoints)
                                        _MapMarker(
                                          point: point,
                                          mapSize: constraints.biggest,
                                          mapScale: mapScale,
                                          colors: colors,
                                          isSelected:
                                              point.location.id ==
                                              _selectedLocationId,
                                          onSelected: () => _selectPoint(point),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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

int _markerLayer(CockpitMapPoint point) => point.visualPriority;

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.point,
    required this.mapSize,
    required this.mapScale,
    required this.colors,
    required this.isSelected,
    required this.onSelected,
  });

  static const _minimumLongitude = -1.35;
  static const _maximumLongitude = 0.15;
  static const _minimumLatitude = 44.2;
  static const _maximumLatitude = 45.65;

  final CockpitMapPoint point;
  final Size mapSize;
  final double mapScale;
  final V5Colors colors;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final markerSize = 44 / mapScale;
    final horizontal =
        ((point.longitude - _minimumLongitude) /
                (_maximumLongitude - _minimumLongitude))
            .clamp(0.0, 1.0)
            .toDouble();
    final vertical =
        (1 -
                (point.latitude - _minimumLatitude) /
                    (_maximumLatitude - _minimumLatitude))
            .clamp(0.0, 1.0)
            .toDouble();
    final availableWidth = (mapSize.width - 20)
        .clamp(0.0, double.infinity)
        .toDouble();
    final legendReserve = MediaQuery.textScalerOf(context).scale(1) >= 1.6
        ? 120.0
        : 72.0;
    const controlReserve = 58.0;
    final availableHeight = (mapSize.height - legendReserve - controlReserve)
        .clamp(0.0, double.infinity)
        .toDouble();
    final marker = _OperationalMarker(
      point: point,
      isSelected: isSelected,
      mapScale: mapScale,
    );
    final centerX = 10 + availableWidth * horizontal;
    final centerY = controlReserve + availableHeight * vertical;

    return Positioned(
      left: (centerX - markerSize / 2).clamp(0, mapSize.width - markerSize),
      top: (centerY - markerSize / 2).clamp(0, mapSize.height - markerSize),
      width: markerSize,
      height: markerSize,
      child: Semantics(
        key: Key('cockpit-map-location-${point.location.id}'),
        button: true,
        selected: isSelected,
        label: '${point.accessibilityLabel} Afficher la fiche du centre.',
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSelected,
            child: marker,
          ),
        ),
      ),
    );
  }
}

class _OperationalMarker extends StatelessWidget {
  const _OperationalMarker({
    required this.point,
    required this.isSelected,
    required this.mapScale,
  });

  final CockpitMapPoint point;
  final bool isSelected;
  final double mapScale;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final markerColor = point.hasMission
        ? territoryStatusColor(point.status, colors)
        : colors.textSecondary.withValues(alpha: 0.62);
    final visualSize = point.visualDiameter / mapScale;
    final selectedSize = (point.visualDiameter + 8).clamp(40, 44) / mapScale;
    final badgeOffset =
        ((44 - point.visualDiameter) / 2 - 5).clamp(0, 44) / mapScale;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 140);
    return SizedBox.square(
      dimension: 44 / mapScale,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: duration,
            width: isSelected ? selectedSize : visualSize,
            height: isSelected ? selectedSize : visualSize,
            decoration: BoxDecoration(
              color: isSelected
                  ? markerColor.withValues(alpha: 0.18)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: markerColor, width: 2 / mapScale)
                  : null,
            ),
            child: Center(
              child: AnimatedContainer(
                key: Key('cockpit-map-point-${point.location.id}'),
                duration: duration,
                width: visualSize,
                height: visualSize,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.surfaceElevated,
                    width: 2 / mapScale,
                  ),
                  boxShadow: point.hasMission
                      ? V5Elevation.level1(colors)
                      : null,
                ),
                child: point.hasMission
                    ? Icon(
                        Icons.local_hospital_rounded,
                        color: Colors.white,
                        size: 14 / mapScale,
                      )
                    : null,
              ),
            ),
          ),
          if (point.showsMissionBadge)
            Positioned(
              top: badgeOffset,
              right: badgeOffset,
              child: Container(
                key: Key('cockpit-map-badge-${point.location.id}'),
                width: 17 / mapScale,
                height: 17 / mapScale,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: markerColor, width: 1.5 / mapScale),
                ),
                child: Text(
                  '${point.missionCount}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9 / mapScale,
                    height: 1,
                    color: markerColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
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

class _TerritoryMapPainter extends CustomPainter {
  const _TerritoryMapPainter({required this.colors});

  final V5Colors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final territory = Path()
      ..moveTo(size.width * 0.28, size.height * 0.05)
      ..lineTo(size.width * 0.55, size.height * 0.08)
      ..lineTo(size.width * 0.76, size.height * 0.21)
      ..lineTo(size.width * 0.84, size.height * 0.43)
      ..lineTo(size.width * 0.72, size.height * 0.68)
      ..lineTo(size.width * 0.52, size.height * 0.83)
      ..lineTo(size.width * 0.30, size.height * 0.76)
      ..lineTo(size.width * 0.17, size.height * 0.55)
      ..lineTo(size.width * 0.20, size.height * 0.27)
      ..close();
    canvas.drawPath(
      territory,
      Paint()
        ..color = colors.surfaceElevated.withValues(alpha: 0.72)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      territory,
      Paint()
        ..color = colors.outline
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    final guide = Paint()
      ..color = colors.outline.withValues(alpha: 0.48)
      ..strokeWidth = 0.8;
    for (final fraction in const [0.33, 0.66]) {
      canvas.drawLine(
        Offset(size.width * fraction, size.height * 0.12),
        Offset(size.width * fraction, size.height * 0.78),
        guide,
      );
    }
    canvas.drawLine(
      Offset(size.width * 0.16, size.height * 0.42),
      Offset(size.width * 0.84, size.height * 0.42),
      guide,
    );
  }

  @override
  bool shouldRepaint(covariant _TerritoryMapPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
