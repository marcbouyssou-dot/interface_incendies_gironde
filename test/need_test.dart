import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/need.dart';

void main() {
  CoordinationNeed createNeed({
    required int registeredPhysiotherapists,
    required int registeredPodiatrists,
  }) {
    return CoordinationNeed(
      id: 'mission-test',
      place: 'Lieu test',
      group: TerritorialGroup.southGironde,
      date: 'Aujourd’hui',
      time: '09:00 — 12:00',
      requiredPhysiotherapists: 2,
      registeredPhysiotherapists: registeredPhysiotherapists,
      requiredPodiatrists: 1,
      registeredPodiatrists: registeredPodiatrists,
      equipment: const [],
    );
  }

  test('le besoin est complet uniquement lorsque les deux quotas le sont', () {
    expect(
      createNeed(
        registeredPhysiotherapists: 2,
        registeredPodiatrists: 0,
      ).status,
      NeedStatus.toComplete,
    );
    expect(
      createNeed(
        registeredPhysiotherapists: 2,
        registeredPodiatrists: 1,
      ).status,
      NeedStatus.complete,
    );
  });
}
