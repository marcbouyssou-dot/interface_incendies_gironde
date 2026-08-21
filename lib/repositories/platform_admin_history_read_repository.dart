import 'dart:async';

import '../models/mobilization.dart';
import '../models/need.dart';
import '../models/operation.dart';
import '../models/territory.dart';
import '../platform_admin/platform_admin_history_view_data.dart';
import '../platform_admin/platform_admin_statistics_view_data.dart';
import 'coordination_repository.dart';
import 'operation_read_repository.dart';
import 'platform_read_repository.dart';

abstract interface class PlatformAdminHistoryDataSource {
  Stream<PlatformAdminHistoryViewData> watchHistory();
}

class RepositoryPlatformAdminHistoryDataSource
    implements PlatformAdminHistoryDataSource {
  const RepositoryPlatformAdminHistoryDataSource({
    required this.platformRepository,
    this.operationRepository,
    this.missionRepository,
  });

  final PlatformReadRepository platformRepository;
  final OperationReadRepository? operationRepository;
  final MultiMobilizationCoordinationReadRepository? missionRepository;

  @override
  Stream<PlatformAdminHistoryViewData> watchHistory() {
    final operationStream =
        operationRepository?.watchOperations() ??
        Stream<List<Operation>>.value(const []);
    final mobilizationStream = platformRepository.watchMobilizations(
      includeInactive: true,
    );
    final territoryStream = platformRepository.watchTerritories();

    return Stream<PlatformAdminHistoryViewData>.multi((controller) {
      List<Operation>? operations;
      List<Mobilization>? mobilizations;
      List<Territory>? territories;
      List<CoordinationNeed>? missions;
      Set<String>? observedMobilizationIds;
      StreamSubscription<List<CoordinationNeed>>? missionSubscription;
      var missionGeneration = 0;

      void addError(Object error, StackTrace stackTrace) {
        controller.addError(error, stackTrace);
      }

      void emitWhenReady() {
        final currentOperations = operations;
        final currentMobilizations = mobilizations;
        final currentTerritories = territories;
        final currentMissions = missions;
        if (currentOperations == null ||
            currentMobilizations == null ||
            currentTerritories == null ||
            currentMissions == null) {
          return;
        }
        final statistics = PlatformAdminStatisticsViewData.fromData(
          operations: currentOperations,
          mobilizations: currentMobilizations,
          missions: currentMissions,
          territories: currentTerritories,
        );
        controller.add(PlatformAdminHistoryViewData.fromStatistics(statistics));
      }

      void refreshMissionStream() {
        final currentOperations = operations;
        final currentMobilizations = mobilizations;
        if (currentOperations == null || currentMobilizations == null) return;
        final historicalOperationIds = currentOperations
            .where(
              (operation) => {
                OperationStatus.completed,
                OperationStatus.archived,
              }.contains(operation.status),
            )
            .map((operation) => operation.id)
            .toSet();
        final mobilizationIds = currentMobilizations
            .where(
              (mobilization) =>
                  historicalOperationIds.contains(mobilization.operationId),
            )
            .map((mobilization) => mobilization.id)
            .toSet();
        if (_sameIds(observedMobilizationIds, mobilizationIds)) return;
        observedMobilizationIds = Set.unmodifiable(mobilizationIds);
        missions = null;
        final generation = ++missionGeneration;
        unawaited(missionSubscription?.cancel());
        final stream = missionRepository == null || mobilizationIds.isEmpty
            ? Stream<List<CoordinationNeed>>.value(const [])
            : missionRepository!.watchMissionsForMobilizations(mobilizationIds);
        missionSubscription = stream.listen((value) {
          if (generation != missionGeneration) return;
          missions = value;
          emitWhenReady();
        }, onError: addError);
      }

      final subscriptions = <StreamSubscription<dynamic>>[
        operationStream.listen((value) {
          operations = value;
          refreshMissionStream();
          emitWhenReady();
        }, onError: addError),
        mobilizationStream.listen((value) {
          mobilizations = value;
          refreshMissionStream();
          emitWhenReady();
        }, onError: addError),
        territoryStream.listen((value) {
          territories = value;
          emitWhenReady();
        }, onError: addError),
      ];
      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await missionSubscription?.cancel();
      };
    });
  }

  static bool _sameIds(Set<String>? left, Set<String> right) {
    if (left == null || left.length != right.length) return false;
    return left.containsAll(right);
  }
}
