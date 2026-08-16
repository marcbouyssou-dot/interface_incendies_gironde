import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/services/push_installation_id.dart';

void main() {
  test('generates a stable-format 128-bit web installation id', () {
    final random = _RecordingRandom([
      0,
      1,
      0x12,
      0x123,
      0x1234,
      0xabcd,
      0xfffe,
      0xffff,
    ]);

    final installationId = generatePushInstallationId(random);

    expect(installationId, '00000001001201231234abcdfffeffff');
    expect(installationId, hasLength(32));
    expect(installationId, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(random.requestedMaxima, List.filled(8, 1 << 16));
  });

  test('does not reuse a generated value across calls', () {
    final random = _RecordingRandom([
      ...List.filled(8, 0),
      ...List.filled(8, 1),
    ]);

    final first = generatePushInstallationId(random);
    final second = generatePushInstallationId(random);

    expect(first, isNot(second));
  });
}

class _RecordingRandom implements Random {
  _RecordingRandom(this._values);

  final List<int> _values;
  final List<int> requestedMaxima = [];
  int _index = 0;

  @override
  int nextInt(int max) {
    requestedMaxima.add(max);
    final value = _values[_index++];
    expect(value, inInclusiveRange(0, max - 1));
    return value;
  }

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}
