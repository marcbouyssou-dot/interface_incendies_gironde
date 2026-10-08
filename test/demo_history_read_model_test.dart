import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/repositories/demo_history_read_repository.dart';

void main() {
  test('synthetic actor keeps one identity with several historical roles', () {
    final actor = DemoActor.fromMap('demo-actor-01', {
      'id': 'demo-actor-01',
      'operationId': 'action-a',
      'label': 'Acteur fictif 01',
      'roles': ['coordinateur', 'responsable'],
      'professions': <String>[],
      'historicalSiteIds': ['site-x'],
    });

    expect(actor.operationId, 'action-a');
    expect(actor.roles, ['coordinateur', 'responsable']);
    expect(actor.historicalSiteIds, ['site-x']);
  });

  test('synthetic engagement preserves explicitly unknown ninth status', () {
    final engagement = DemoEngagement.fromMap('demo-engagement-09', {
      'id': 'demo-engagement-09',
      'operationId': 'action-a',
      'actorId': 'demo-actor-01',
      'missionId': 'mission-09',
      'locationId': 'site-x',
      'profession': 'physiotherapist',
      'status': 'unknown',
      'statusKnown': false,
    });

    expect(engagement.statusKnown, isFalse);
    expect(engagement.status, 'unknown');
  });

  test('synthetic documents reject mismatched IDs and invented statuses', () {
    expect(
      () => DemoActor.fromMap('demo-actor-01', {
        'id': 'demo-actor-02',
      }),
      throwsFormatException,
    );
    expect(
      () => DemoEngagement.fromMap('demo-engagement-01', {
        'id': 'demo-engagement-01',
        'operationId': 'action-a',
        'actorId': 'demo-actor-01',
        'missionId': 'mission-01',
        'locationId': 'site-x',
        'profession': 'physiotherapist',
        'status': 'unknown',
        'statusKnown': true,
      }),
      throwsFormatException,
    );
  });
}
