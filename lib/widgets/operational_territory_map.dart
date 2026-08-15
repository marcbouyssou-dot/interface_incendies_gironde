import 'package:flutter/material.dart';

import '../coordinator/cockpit_view_data.dart';
import '../coordinator/territory_view_data.dart';
import '../models/need.dart';
import '../theme/v5_foundation.dart';
import 'territory_components.dart';

class OperationalTerritoryMap extends StatelessWidget {
  const OperationalTerritoryMap({
    super.key,
    required this.points,
    required this.locationCount,
    required this.missionCount,
    required this.tensionCount,
    required this.onViewMission,
    this.height = 280,
  });

  final List<CockpitMapPoint> points;
  final int locationCount;
  final int missionCount;
  final int tensionCount;
  final ValueChanged<CoordinationNeed> onViewMission;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final missionPoints = points.where((point) => point.hasMission).toList();
    final critical = missionPoints
        .where((point) => point.status == TerritoryOperationalStatus.critical)
        .length;
    final watch = missionPoints
        .where((point) => point.status == TerritoryOperationalStatus.watch)
        .length;
    final renderedPoints = [
      ...points,
    ]..sort((left, right) => _markerLayer(left).compareTo(_markerLayer(right)));
    final summary =
        'Carte opérationnelle de Gironde. '
        '$locationCount établissements, '
        '$missionCount missions, '
        '$tensionCount tensions. '
        '$critical établissements critiques et $watch à surveiller.';

    return Semantics(
      key: const Key('cockpit-map-semantics'),
      container: true,
      explicitChildNodes: true,
      label: summary,
      child: Container(
        key: const Key('cockpit-operational-map'),
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(V5Radius.large),
          border: Border.all(color: colors.outline),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _TerritoryMapPainter(colors: colors),
                ),
              ),
              for (final point in renderedPoints)
                _MapMarker(
                  point: point,
                  mapSize: constraints.biggest,
                  colors: colors,
                  onViewMission: onViewMission,
                ),
              Positioned(
                top: V5Spacing.sm,
                right: V5Spacing.sm,
                child: _MapCounters(
                  locationCount: locationCount,
                  missionCount: missionCount,
                  tensionCount: tensionCount,
                ),
              ),
              const Positioned(
                left: V5Spacing.sm,
                right: V5Spacing.sm,
                bottom: V5Spacing.sm,
                child: _MapLegend(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _markerLayer(CockpitMapPoint point) {
  if (!point.hasMission) return 0;
  return switch (point.status) {
    TerritoryOperationalStatus.stable => 1,
    TerritoryOperationalStatus.watch => 2,
    TerritoryOperationalStatus.critical => 3,
  };
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.point,
    required this.mapSize,
    required this.colors,
    required this.onViewMission,
  });

  static const _minimumLongitude = -1.35;
  static const _maximumLongitude = 0.15;
  static const _minimumLatitude = 44.2;
  static const _maximumLatitude = 45.65;

  final CockpitMapPoint point;
  final Size mapSize;
  final V5Colors colors;
  final ValueChanged<CoordinationNeed> onViewMission;

  @override
  Widget build(BuildContext context) {
    final markerSize = point.hasMission ? 44.0 : 7.0;
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
    final availableWidth = (mapSize.width - markerSize - 20)
        .clamp(0.0, double.infinity)
        .toDouble();
    final legendReserve = MediaQuery.textScalerOf(context).scale(1) >= 1.6
        ? 120.0
        : 72.0;
    final availableHeight = (mapSize.height - markerSize - legendReserve)
        .clamp(0.0, double.infinity)
        .toDouble();
    final marker = point.hasMission
        ? Center(
            child: SizedBox.square(
              dimension: 30,
              child: _MissionMarker(point: point),
            ),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(color: colors.surfaceElevated, width: 1),
            ),
          );

    return Positioned(
      left: 10 + availableWidth * horizontal,
      top: 10 + availableHeight * vertical,
      width: markerSize,
      height: markerSize,
      child: point.hasMission
          ? Semantics(
              key: Key('cockpit-map-location-${point.location.id}'),
              button: true,
              label:
                  '${point.location.name}, ${point.missionCount} mission${point.missionCount > 1 ? 's' : ''}, '
                  '${point.status.label.toLowerCase()}. Ouvrir la mission.',
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: point.primaryMission == null
                      ? null
                      : () => onViewMission(point.primaryMission!),
                  child: marker,
                ),
              ),
            )
          : ExcludeSemantics(child: marker),
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

class _MissionMarker extends StatelessWidget {
  const _MissionMarker({required this.point});

  final CockpitMapPoint point;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final color = territoryStatusColor(point.status, colors);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: colors.surfaceElevated, width: 2),
        boxShadow: V5Elevation.level1(colors),
      ),
      child: Center(
        child: point.missionCount > 1
            ? Text(
                '${point.missionCount}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              )
            : const Icon(
                Icons.local_hospital_rounded,
                color: Colors.white,
                size: 15,
              ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

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
    ];
    return Semantics(
      label:
          'Légende. Rouge : critique. Orange : à surveiller. Vert : couvert.',
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

  final TerritoryOperationalStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: territoryStatusColor(status, colors),
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
