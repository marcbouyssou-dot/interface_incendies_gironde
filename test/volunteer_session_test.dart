import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/firebase_startup_gate.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/firestore_coordination_repository.dart';

void main() {
  test('a responsible identity cannot create a volunteer engagement', () {
    expect(
      canStartVolunteerEngagement(hasUser: true, isAnonymous: false),
      isFalse,
    );
  });

  test('an anonymous or missing identity starts the volunteer flow', () {
    expect(
      canStartVolunteerEngagement(hasUser: true, isAnonymous: true),
      isTrue,
    );
    expect(
      canStartVolunteerEngagement(hasUser: false, isAnonymous: false),
      isTrue,
    );
  });

  test('a historical responsible primary session is replaced', () {
    expect(
      mustCreateAnonymousVolunteerSession(hasUser: true, isAnonymous: false),
      isTrue,
    );
    expect(
      mustCreateAnonymousVolunteerSession(hasUser: true, isAnonymous: true),
      isFalse,
    );
  });

  test('existing Firestore engagements are classified idempotently', () {
    for (final (status, expected) in [
      ('pending', EngagementCreationResult.alreadyPending),
      ('confirmed', EngagementCreationResult.alreadyConfirmed),
      ('standby', EngagementCreationResult.alreadyStandby),
      (null, EngagementCreationResult.alreadyConfirmed),
    ]) {
      final classification = classifyExistingEngagement({
        'volunteerId': 'anonymous',
        'status': ?status,
      }, 'anonymous');
      expect(classification.ownerMatches, isTrue);
      expect(classification.result, expected);
    }
    expect(
      classifyExistingEngagement({
        'volunteerId': 'anonymous',
        'status': 'cancelled',
      }, 'anonymous').result,
      isNull,
    );
  });

  test('an inconsistent Firestore volunteer is rejected', () {
    final classification = classifyExistingEngagement({
      'volunteerId': 'another',
      'status': 'pending',
    }, 'anonymous');
    expect(classification.ownerMatches, isFalse);
  });
}
