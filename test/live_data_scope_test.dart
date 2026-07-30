import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

void main() {
  test(
    'volunteer engagement streams are cached and indexed by mission',
    () async {
      final repository = _ControlledEngagementRepository();
      final data = LiveCoordinationData(repository);
      final missionA = <EngagementInfo?>[];
      final missionB = <EngagementInfo?>[];
      final firstA = data.watchMyEngagement('mission-a').listen(missionA.add);
      final firstB = data.watchMyEngagement('mission-b').listen(missionB.add);

      repository.emit('mission-a', null);
      repository.emit(
        'mission-b',
        const EngagementInfo(
          missionId: 'mission-b',
          volunteerId: 'mock-volunteer',
          profession: VolunteerProfession.mk,
          status: EngagementStatus.confirmed,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.factories, {'mission-a': 1, 'mission-b': 1});
      expect(missionA, [null]);
      expect(missionB.single?.status, EngagementStatus.confirmed);

      repository.emit(
        'mission-a',
        const EngagementInfo(
          missionId: 'mission-a',
          volunteerId: 'mock-volunteer',
          profession: VolunteerProfession.pp,
          status: EngagementStatus.cancelled,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final replayedA = await data.watchMyEngagement('mission-a').first;
      expect(replayedA?.status, EngagementStatus.cancelled);
      expect(repository.factories['mission-a'], 1);

      repository.emit(
        'mission-a',
        const EngagementInfo(
          missionId: 'mission-a',
          volunteerId: 'mock-volunteer',
          profession: VolunteerProfession.pp,
          status: EngagementStatus.confirmed,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(missionA.last?.status, EngagementStatus.confirmed);

      await firstA.cancel();
      await firstB.cancel();
      await data.dispose();
      await repository.disposeControllers();
    },
  );
}

class _ControlledEngagementRepository extends MockCoordinationRepository {
  final Map<String, StreamController<EngagementInfo?>> _controllers = {};
  final Map<String, int> factories = {};

  @override
  Stream<EngagementInfo?> watchMyEngagement(String missionId) {
    factories.update(missionId, (count) => count + 1, ifAbsent: () => 1);
    return _controllers
        .putIfAbsent(
          missionId,
          () => StreamController<EngagementInfo?>.broadcast(sync: true),
        )
        .stream;
  }

  void emit(String missionId, EngagementInfo? engagement) {
    _controllers[missionId]!.add(engagement);
  }

  Future<void> disposeControllers() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }
}
