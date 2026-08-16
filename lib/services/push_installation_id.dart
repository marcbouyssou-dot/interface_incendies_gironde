import 'dart:math';

const int _segmentCount = 8;
const int _segmentRadixLimit = 1 << 16;
const int _segmentWidth = 4;

String generatePushInstallationId(Random random) => List.generate(
  _segmentCount,
  (_) => random
      .nextInt(_segmentRadixLimit)
      .toRadixString(16)
      .padLeft(_segmentWidth, '0'),
).join();
