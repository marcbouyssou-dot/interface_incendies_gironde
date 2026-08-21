import 'dart:async';

import '../models/mobilization.dart';
import '../models/need.dart';
import '../models/operation.dart';
import '../models/territory.dart';
import '../platform_admin/platform_admin_statistics_view_data.dart';
import 'coordination_repository.dart';
import 'operation_read_repository.dart';
import 'platform_read_repository.dart';

abstract interface class PlatformAdminStatisticsDataSource {
  Stream<PlatformAdminStatisticsViewData> watchStatistics();
}

class RepositoryPlatformAdminStatisticsDataSource
    implements PlatformAdminStatisticsDataSource {
  const RepositoryPlatformAdminStatisticsDataSource({
    required this.platformRepository,
    this.operationRepository,
    this.missionRepository,
  });

  final PlatformReadRepository platformRepository;
  final OperationReadRepository? operationRepository;
  final MultiMobilizationCoordinationReadRepository? missionRepository;

  @override
  Stream<PlatformAdminStatisticsViewData> watchStatistics() {
    final operationStream =
        operationRepository?.watchOperations() ??
        Stream<List<Operation>>.value(const []);
    final mobilizationStream = platformRepository.watchMobilizations(
      includeInactive: true,
    );
    final missionStream =
        missionRepository?.watchAllActiveMissions() ??
        Stream<List<CoordinationNeed>>.value(const []);
    final territoryStream = platformRepository.watchTerritories();

    return Stream<PlatformAdminStatisticsViewData>.multi((controller) {
      List<Operation>? operations;
      List<Mobilization>? mobilizations;
      List<CoordinationNeed>? missions;
      List<Territory>? territories;
      var completedStreams = 0;

      void emitWhenReady() {
        final currentOperations = operations;
        final currentMobilizations = mobilizations;
        final currentMissions = missions;
        final currentTerritories = territories;
        if (currentOperations == null ||
            currentMobilizations == null ||
            currentMissions == null ||
            currentTerritories == null) {
          return;
        }
        controller.add(
          PlatformAdminStatisticsViewData.fromData(
            operations: currentOperations,
            mobilizations: currentMobilizations,
            missions: currentMissions,
            territories: currentTerritories,
          ),
        );
      }

      void addError(Object error, StackTrace stackTrace) {
        controller.addError(error, stackTrace);
      }

      void markDone() {
        completedStreams++;
        if (completedStreams == 4) controller.close();
      }

      final subscriptions = <StreamSubscription<dynamic>>[
        operationStream.listen(
          (value) {
            operations = value;
            emitWhenReady();
          },
          onError: addError,
          onDone: markDone,
        ),
        mobilizationStream.listen(
          (value) {
            mobilizations = value;
            emitWhenReady();
          },
          onError: addError,
          onDone: markDone,
        ),
        missionStream.listen(
          (value) {
            missions = value;
            emitWhenReady();
          },
          onError: addError,
          onDone: markDone,
        ),
        territoryStream.listen(
          (value) {
            territories = value;
            emitWhenReady();
          },
          onError: addError,
          onDone: markDone,
        ),
      ];
      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }
}
