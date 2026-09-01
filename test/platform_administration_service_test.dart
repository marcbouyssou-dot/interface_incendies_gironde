import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/services/firebase_platform_administration_service.dart';
import 'package:interface_incendies_gironde/services/platform_administration_service.dart';

void main() {
  test('create and update send the exact backend payload', () async {
    final calls = <({String name, Map<String, Object?> data})>[];
    final service = FirebasePlatformAdministrationService(
      callable: (name, data) async {
        calls.add((name: name, data: Map.of(data)));
        return {'status': 'ok'};
      },
    );
    const draft = MobilizationAdministrationDraft(
      mobilizationId: 'canicule-gironde-2026',
      territoryId: 'gironde',
      name: ' Canicule Gironde ',
      subtitle: ' Dispositif départemental ',
      contextType: MobilizationContextType.heatwave,
    );

    await service.createMobilization(draft);
    await service.updateMobilization(draft);

    expect(calls.map((call) => call.name), [
      'createMobilization',
      'updateMobilization',
    ]);
    expect(calls.first.data, {
      'mobilizationId': 'canicule-gironde-2026',
      'territoryId': 'gironde',
      'name': 'Canicule Gironde',
      'subtitle': 'Dispositif départemental',
      'contextType': 'heatwave',
    });
    expect(calls.first.data.containsKey('status'), isFalse);
  });

  test(
    'lifecycle and assignment actions use only existing callables',
    () async {
      final calls = <({String name, Map<String, Object?> data})>[];
      final service = FirebasePlatformAdministrationService(
        callable: (name, data) async {
          calls.add((name: name, data: Map.of(data)));
          return {'status': 'ok'};
        },
      );

      await service.activateMobilization('mobilization-1');
      await service.deactivateMobilization('mobilization-1');
      await service.archiveMobilization('mobilization-1');
      await service.assignMobilizationCoordinator(
        mobilizationId: 'mobilization-1',
        uid: 'coordinator-1',
      );
      await service.removeMobilizationCoordinator(
        mobilizationId: 'mobilization-1',
        uid: 'coordinator-1',
      );
      await service.setOperationCoordinator(
        operationId: 'operation-1',
        uid: 'coordinator-1',
      );

      expect(calls.map((call) => call.name), [
        'activateMobilization',
        'deactivateMobilization',
        'archiveMobilization',
        'assignMobilizationCoordinator',
        'removeMobilizationCoordinator',
        'setOperationCoordinator',
      ]);
      expect(calls[0].data, {'mobilizationId': 'mobilization-1'});
      expect(calls[3].data, {
        'mobilizationId': 'mobilization-1',
        'uid': 'coordinator-1',
      });
      expect(calls[5].data, {
        'operationId': 'operation-1',
        'uid': 'coordinator-1',
      });
    },
  );

  test('invalid payload is rejected before the callable', () async {
    var calls = 0;
    final service = FirebasePlatformAdministrationService(
      callable: (name, data) async {
        calls++;
        return {'status': 'ok'};
      },
    );

    expect(
      () => service.createMobilization(
        const MobilizationAdministrationDraft(
          mobilizationId: 'INVALID ID',
          territoryId: 'gironde',
          name: 'Canicule',
          subtitle: 'Sous-titre',
          contextType: MobilizationContextType.heatwave,
        ),
      ),
      throwsA(isA<PlatformAdministrationException>()),
    );
    expect(calls, 0);
  });

  test(
    'targeted push test sends only the current installation identifier',
    () async {
      final calls = <({String name, Map<String, Object?> data})>[];
      final service = FirebasePlatformAdministrationService(
        currentUserUid: () => 'platform-admin',
        callable: (name, data) async {
          calls.add((name: name, data: Map.of(data)));
          return {'sent': true};
        },
      );

      await service.sendTargetedPushTest(installationId: 'current-device');

      expect(calls, hasLength(1));
      expect(calls.single.name, 'sendTargetedPushTest');
      expect(calls.single.data, {
        'installationId': 'current-device',
        'confirmation': 'SEND_ONE_TEST_PUSH',
      });
      expect(calls.single.data.keys, hasLength(2));
      expect(calls.single.data.toString(), isNot(contains('platform-admin')));
    },
  );

  test('targeted push availability uses the read-only confirmation', () async {
    final calls = <({String name, Map<String, Object?> data})>[];
    final service = FirebasePlatformAdministrationService(
      currentUserUid: () => 'platform-admin',
      callable: (name, data) async {
        calls.add((name: name, data: Map.of(data)));
        return {'available': true};
      },
    );

    expect(
      await service.canSendTargetedPushTest(installationId: 'current-device'),
      isTrue,
    );
    expect(calls.single.data, {
      'installationId': 'current-device',
      'confirmation': 'CHECK_TEST_PUSH',
    });
  });

  test('callable failures remain technical and readable', () async {
    final unavailable = FirebasePlatformAdministrationService(
      callable: (name, data) => throw FirebaseFunctionsException(
        code: 'unavailable',
        message: 'network',
      ),
    );
    final stale = FirebasePlatformAdministrationService(
      callable: (name, data) => throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'state changed',
      ),
    );

    await expectLater(
      unavailable.activateMobilization('mobilization-1'),
      throwsA(
        isA<PlatformAdministrationException>().having(
          (error) => error.message,
          'message',
          contains('indisponible'),
        ),
      ),
    );
    await expectLater(
      stale.activateMobilization('mobilization-1'),
      throwsA(
        isA<PlatformAdministrationException>().having(
          (error) => error.message,
          'message',
          contains('état actuel'),
        ),
      ),
    );
  });

  test('malformed callable response is unavailable', () async {
    final service = FirebasePlatformAdministrationService(
      callable: (name, data) async => 'unexpected',
    );

    await expectLater(
      service.archiveMobilization('mobilization-1'),
      throwsA(
        isA<PlatformAdministrationException>().having(
          (error) => error.message,
          'message',
          contains('indisponible'),
        ),
      ),
    );
  });

  test('unauthenticated expires the session and blocks later calls', () async {
    var calls = 0;
    final service = FirebasePlatformAdministrationService(
      callable: (name, data) {
        calls++;
        throw FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'expired',
        );
      },
    );
    addTearDown(service.sessionState.dispose);

    expect(
      service.sessionState.value,
      PlatformAdministrationSessionState.valid,
    );
    await expectLater(
      service.activateMobilization('mobilization-1'),
      throwsA(
        isA<PlatformAdministrationException>().having(
          (error) => error.message,
          'message',
          'Votre session a expiré. Reconnectez-vous.',
        ),
      ),
    );
    expect(
      service.sessionState.value,
      PlatformAdministrationSessionState.expired,
    );

    await expectLater(
      service.deactivateMobilization('mobilization-1'),
      throwsA(isA<PlatformAdministrationException>()),
    );
    expect(calls, 1);
  });

  test('creation id is stable, normalized and contains no personal data', () {
    expect(
      createMobilizationId('Événement Gironde', now: DateTime.utc(2026, 8, 10)),
      'evenement-gironde-2026',
    );
  });
}
