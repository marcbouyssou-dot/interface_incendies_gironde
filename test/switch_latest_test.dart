import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/utils/switch_latest.dart';

void main() {
  test('switchLatest follows the current auth identity only', () async {
    final auth = StreamController<String>();
    final firstUser = StreamController<String>();
    final secondUser = StreamController<String>();
    final values = <String>[];
    final subscription = switchLatest(
      auth.stream,
      (uid) => uid == 'anonymous-a' ? firstUser.stream : secondUser.stream,
    ).listen(values.add);

    auth.add('anonymous-a');
    await Future<void>.delayed(Duration.zero);
    firstUser.add('pending-a');
    await Future<void>.delayed(Duration.zero);

    auth.add('anonymous-b');
    await Future<void>.delayed(Duration.zero);
    firstUser.add('confirmed-a');
    secondUser.add('pending-b');
    await Future<void>.delayed(Duration.zero);

    expect(values, ['pending-a', 'pending-b']);

    await subscription.cancel();
    await auth.close();
    await firstUser.close();
    await secondUser.close();
  });

  test('switchLatest restores the same persisted anonymous stream', () async {
    final auth = StreamController<String>();
    final engagement = StreamController<String>.broadcast();
    final values = <String>[];
    final subscription = switchLatest(
      auth.stream,
      (_) => engagement.stream,
    ).listen(values.add);

    auth.add('stable-anonymous-uid');
    await Future<void>.delayed(Duration.zero);
    engagement.add('pending');
    await Future<void>.delayed(Duration.zero);

    auth.add('stable-anonymous-uid');
    await Future<void>.delayed(Duration.zero);
    engagement.add('confirmed');
    await Future<void>.delayed(Duration.zero);

    expect(values, ['pending', 'confirmed']);

    await subscription.cancel();
    await auth.close();
    await engagement.close();
  });

  test(
    'responsible login and logout do not replace volunteer identity',
    () async {
      final volunteerAuth = StreamController<String>.broadcast();
      final responsibleAuth = StreamController<String?>.broadcast();
      final engagement = StreamController<String>.broadcast();
      final values = <String>[];
      final subscription = switchLatest(
        volunteerAuth.stream,
        (_) => engagement.stream,
      ).listen(values.add);

      volunteerAuth.add('stable-anonymous-uid');
      await Future<void>.delayed(Duration.zero);
      engagement.add('pending');
      responsibleAuth.add('responsible-uid');
      responsibleAuth.add(null);
      await Future<void>.delayed(Duration.zero);
      engagement.add('confirmed');
      await Future<void>.delayed(Duration.zero);

      expect(values, ['pending', 'confirmed']);

      await subscription.cancel();
      await volunteerAuth.close();
      await responsibleAuth.close();
      await engagement.close();
    },
  );
}
