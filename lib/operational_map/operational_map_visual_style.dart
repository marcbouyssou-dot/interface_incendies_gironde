import 'operational_map_feature.dart';

class OperationalMapStatusVisualStyle {
  const OperationalMapStatusVisualStyle({
    required this.color,
    required this.strokeColor,
    required this.overviewRadius,
    required this.detailRadius,
    required this.opacity,
    required this.strokeWidth,
    required this.haloRadius,
    required this.haloOpacity,
  });

  final String color;
  final String strokeColor;
  final double overviewRadius;
  final double detailRadius;
  final double opacity;
  final double strokeWidth;
  final double haloRadius;
  final double haloOpacity;
}

abstract final class OperationalMapVisualStyle {
  static const statusStyles =
      <OperationalMapStatus, OperationalMapStatusVisualStyle>{
        OperationalMapStatus.critical: OperationalMapStatusVisualStyle(
          color: '#C92F43',
          strokeColor: '#FFFFFF',
          overviewRadius: 10,
          detailRadius: 15,
          opacity: 1,
          strokeWidth: 3,
          haloRadius: 17,
          haloOpacity: 0.24,
        ),
        OperationalMapStatus.watch: OperationalMapStatusVisualStyle(
          color: '#DC7A00',
          strokeColor: '#FFF3DF',
          overviewRadius: 8,
          detailRadius: 12,
          opacity: 0.94,
          strokeWidth: 2,
          haloRadius: 13,
          haloOpacity: 0.12,
        ),
        OperationalMapStatus.covered: OperationalMapStatusVisualStyle(
          color: '#397A66',
          strokeColor: '#E7F0EC',
          overviewRadius: 5,
          detailRadius: 8,
          opacity: 0.62,
          strokeWidth: 1.25,
          haloRadius: 0,
          haloOpacity: 0,
        ),
        OperationalMapStatus.noMission: OperationalMapStatusVisualStyle(
          color: '#87919D',
          strokeColor: '#F4F6F8',
          overviewRadius: 3.5,
          detailRadius: 5,
          opacity: 0.38,
          strokeWidth: 0.75,
          haloRadius: 0,
          haloOpacity: 0,
        ),
      };

  static OperationalMapStatusVisualStyle forStatus(
    OperationalMapStatus status,
  ) => statusStyles[status]!;

  static List<Object> get centerRadiusExpression => <Object>[
    'interpolate',
    <Object>['linear'],
    <Object>['zoom'],
    7,
    _matchStatus((style) => style.overviewRadius),
    13,
    _matchStatus((style) => style.detailRadius),
  ];

  static List<Object> get centerColorExpression =>
      _matchStatus((style) => style.color);

  static List<Object> get centerOpacityExpression =>
      _matchStatus((style) => style.opacity);

  static List<Object> get centerStrokeColorExpression =>
      _matchStatus((style) => style.strokeColor);

  static List<Object> get centerStrokeWidthExpression =>
      _matchStatus((style) => style.strokeWidth);

  static List<Object> get clusterColorExpression => <Object>[
    'step',
    <Object>['get', 'maxSeverity'],
    forStatus(OperationalMapStatus.noMission).color,
    1,
    forStatus(OperationalMapStatus.covered).color,
    2,
    forStatus(OperationalMapStatus.watch).color,
    3,
    forStatus(OperationalMapStatus.critical).color,
  ];

  static List<Object> get clusterOpacityExpression => const <Object>[
    'step',
    <Object>['get', 'maxSeverity'],
    0.48,
    1,
    0.62,
    2,
    0.92,
    3,
    1.0,
  ];

  static List<Object> get clusterStrokeWidthExpression => const <Object>[
    'step',
    <Object>['get', 'maxSeverity'],
    1.0,
    1,
    1.25,
    2,
    2.0,
    3,
    3.0,
  ];

  static List<Object> _matchStatus(
    Object Function(OperationalMapStatusVisualStyle style) valueFor,
  ) {
    return <Object>[
      'match',
      <Object>['get', 'status'],
      OperationalMapStatus.critical.wireValue,
      valueFor(forStatus(OperationalMapStatus.critical)),
      OperationalMapStatus.watch.wireValue,
      valueFor(forStatus(OperationalMapStatus.watch)),
      OperationalMapStatus.covered.wireValue,
      valueFor(forStatus(OperationalMapStatus.covered)),
      valueFor(forStatus(OperationalMapStatus.noMission)),
    ];
  }
}
