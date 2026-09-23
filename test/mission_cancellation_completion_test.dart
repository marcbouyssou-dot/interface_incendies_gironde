import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/repositories/mission_cancellation_completion.dart';

void main() {
  const writeTimeout = Duration(milliseconds: 10);
  const confirmationTimeout = Duration(milliseconds: 100);

  test('immediate cancellation success completes normally', () async {
    await awaitMissionCancellationCompletion(
      write: () async {},
      remoteConfirmations: const Stream.empty(),
      writeTimeout: writeTimeout,
      confirmationTimeout: confirmationTimeout,
    );
  });

  test('late write confirmation after initial timeout is accepted', () async {
    await awaitMissionCancellationCompletion(
      write: () => Future<void>.delayed(const Duration(milliseconds: 30)),
      remoteConfirmations: const Stream.empty(),
      writeTimeout: writeTimeout,
      confirmationTimeout: confirmationTimeout,
    );
  });

  test('timeout followed by remote cancelled state is accepted', () async {
    final writeNeverCompletes = Completer<void>();

    await awaitMissionCancellationCompletion(
      write: () => writeNeverCompletes.future,
      remoteConfirmations: Stream<bool>.periodic(
        const Duration(milliseconds: 20),
        (index) => index > 0,
      ).take(2),
      writeTimeout: writeTimeout,
      confirmationTimeout: confirmationTimeout,
    );
  });

  test('permission denied remains a real error', () async {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );

    await expectLater(
      awaitMissionCancellationCompletion(
        write: () async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          throw error;
        },
        remoteConfirmations: const Stream.empty(),
        writeTimeout: writeTimeout,
        confirmationTimeout: confirmationTimeout,
      ),
      throwsA(
        isA<FirebaseException>().having(
          (candidate) => candidate.code,
          'code',
          'permission-denied',
        ),
      ),
    );
  });

  test(
    'network error without cancellation confirmation remains an error',
    () async {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      await expectLater(
        awaitMissionCancellationCompletion(
          write: () => Future<void>.error(error),
          remoteConfirmations: const Stream.empty(),
          writeTimeout: writeTimeout,
          confirmationTimeout: confirmationTimeout,
        ),
        throwsA(
          isA<FirebaseException>().having(
            (candidate) => candidate.code,
            'code',
            'unavailable',
          ),
        ),
      );
    },
  );

  test('timeout without remote confirmation remains an error', () async {
    final writeNeverCompletes = Completer<void>();

    await expectLater(
      awaitMissionCancellationCompletion(
        write: () => writeNeverCompletes.future,
        remoteConfirmations: const Stream.empty(),
        writeTimeout: writeTimeout,
        confirmationTimeout: const Duration(milliseconds: 30),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
