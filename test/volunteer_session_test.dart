import 'package:flutter_test/flutter_test.dart';
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
}
