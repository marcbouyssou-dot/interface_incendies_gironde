import '../models/executive_dashboard_snapshot.dart';
import '../models/health_profession.dart';
import '../models/mobilization.dart';
import '../models/need.dart';
import '../models/operation.dart';
import '../models/operational_scope.dart';
import '../models/profession_quotas.dart';
import '../models/territory.dart';

class PlatformAdminStatisticsViewData {
  PlatformAdminStatisticsViewData._({
    required this.dashboard,
    required this.platform,
    required this.operations,
  });

  factory PlatformAdminStatisticsViewData.fromData({
    required List<Operation> operations,
    required List<Mobilization> mobilizations,
    required List<CoordinationNeed> missions,
    required List<Territory> territories,
  }) {
    final dashboard = ExecutiveDashboardSnapshot(
      operations: operations,
      mobilizations: mobilizations,
      missions: missions,
    );
    final mobilizationById = {
      for (final mobilization in mobilizations) mobilization.id: mobilization,
    };
    final territoryById = {
      for (final territory in territories) territory.id: territory,
    };
    final operationStatistics =
        dashboard.operationSnapshots
            .map(
              (snapshot) => OperationAdminStatistics(
                operation: snapshot.operation,
                snapshot: snapshot,
                territories: _operationTerritories(
                  snapshot.operation,
                  snapshot.mobilizations,
                  territoryById,
                ),
                breakdown: OperationalStatisticsBreakdown.fromMissions(
                  snapshot.missions,
                  mobilizationById: mobilizationById,
                  territoryById: territoryById,
                ),
              ),
            )
            .toList(growable: false)
          ..sort(_compareOperations);
    return PlatformAdminStatisticsViewData._(
      dashboard: dashboard,
      platform: OperationalStatisticsBreakdown.fromMissions(
        dashboard.missions,
        mobilizationById: mobilizationById,
        territoryById: territoryById,
      ),
      operations: List.unmodifiable(operationStatistics),
    );
  }

  final ExecutiveDashboardSnapshot dashboard;
  final OperationalStatisticsBreakdown platform;
  final List<OperationAdminStatistics> operations;

  OperationAdminStatistics? operationById(String? operationId) {
    if (operationId == null) return null;
    for (final operation in operations) {
      if (operation.operation.id == operationId) return operation;
    }
    return null;
  }

  static int _compareOperations(
    OperationAdminStatistics left,
    OperationAdminStatistics right,
  ) {
    final statusOrder = <OperationStatus, int>{
      OperationStatus.active: 0,
      OperationStatus.suspended: 1,
      OperationStatus.planned: 2,
      OperationStatus.draft: 3,
      OperationStatus.completed: 4,
      OperationStatus.archived: 5,
    };
    final byStatus = statusOrder[left.operation.status]!.compareTo(
      statusOrder[right.operation.status]!,
    );
    if (byStatus != 0) return byStatus;
    return left.operation.startAt.compareTo(right.operation.startAt);
  }

  static List<OperationStatisticsTerritory> _operationTerritories(
    Operation operation,
    List<Mobilization> mobilizations,
    Map<String, Territory> territoryById,
  ) {
    final ids = operation.scopeRefs
        .where((ref) => ref.kind == OperationalScopeKind.territory)
        .map((ref) => ref.id)
        .toSet();
    if (ids.isEmpty) {
      ids.addAll(mobilizations.map((mobilization) => mobilization.territoryId));
    }
    final values =
        ids
            .map((id) {
              final territory = territoryById[id];
              return OperationStatisticsTerritory(
                id: id,
                label: territory == null
                    ? id
                    : '${territory.name} · ${territory.code}',
              );
            })
            .toList(growable: false)
          ..sort((left, right) => left.label.compareTo(right.label));
    return List.unmodifiable(values);
  }
}

class OperationAdminStatistics {
  const OperationAdminStatistics({
    required this.operation,
    required this.snapshot,
    required this.territories,
    required this.breakdown,
  });

  final Operation operation;
  final OperationExecutiveSnapshot snapshot;
  final List<OperationStatisticsTerritory> territories;
  final OperationalStatisticsBreakdown breakdown;

  List<String> get territoryLabels =>
      List.unmodifiable(territories.map((territory) => territory.label));
  int get remainingProfessionalCount => breakdown.remainingProfessionalCount;
  String? get coordinatorUid => operation.coordinatorUid;
}

class OperationStatisticsTerritory {
  const OperationStatisticsTerritory({required this.id, required this.label});

  final String id;
  final String label;
}

class OperationalStatisticsBreakdown {
  const OperationalStatisticsBreakdown._({
    required this.professions,
    required this.territories,
    required this.establishments,
    required this.remainingProfessionalCount,
  });

  factory OperationalStatisticsBreakdown.fromMissions(
    Iterable<CoordinationNeed> source, {
    required Map<String, Mobilization> mobilizationById,
    required Map<String, Territory> territoryById,
  }) {
    final missions = source
        .where((mission) => mission.isActive && !mission.isCancelled)
        .toList(growable: false);
    final aggregate = ProfessionQuotas.aggregate(
      missions.map((mission) => mission.professionQuotas),
    );
    final professions =
        aggregate.values
            .where((quota) => quota.hasActivity)
            .map(ProfessionStatistics.fromQuota)
            .toList(growable: false)
          ..sort(_compareProfessions);
    final territories = <String, _MutableGroupStatistics>{};
    final establishments = <String, _MutableGroupStatistics>{};
    for (final mission in missions) {
      final mobilizationId = mission.mobilizationId;
      final mobilization = mobilizationId == null
          ? null
          : mobilizationById[mobilizationId];
      final territoryId = mobilization?.territoryId;
      final territory = territoryId == null ? null : territoryById[territoryId];
      final territoryKey = territoryId ?? 'group:${mission.group.name}';
      final territoryLabel = territory == null
          ? mission.group.label
          : '${territory.name} · ${territory.code}';
      territories
          .putIfAbsent(
            territoryKey,
            () => _MutableGroupStatistics(territoryKey, territoryLabel),
          )
          .add(mission);

      final locationId = mission.locationId?.trim();
      final establishmentKey = locationId?.isNotEmpty == true
          ? locationId!
          : 'place:${mission.place.trim().toLowerCase()}';
      establishments
          .putIfAbsent(
            establishmentKey,
            () => _MutableGroupStatistics(establishmentKey, mission.place),
          )
          .add(mission);
    }
    final territoryValues =
        territories.values
            .map((value) => value.freeze())
            .toList(growable: false)
          ..sort(_compareGroups);
    final establishmentValues =
        establishments.values
            .map((value) => value.freeze())
            .toList(growable: false)
          ..sort(_compareGroups);
    return OperationalStatisticsBreakdown._(
      professions: List.unmodifiable(professions),
      territories: List.unmodifiable(territoryValues),
      establishments: List.unmodifiable(establishmentValues),
      remainingProfessionalCount: aggregate.values.fold(
        0,
        (total, quota) => total + quota.missing,
      ),
    );
  }

  final List<ProfessionStatistics> professions;
  final List<OperationalGroupStatistics> territories;
  final List<OperationalGroupStatistics> establishments;
  final int remainingProfessionalCount;

  List<ProfessionStatistics> get tenseProfessions => List.unmodifiable(
    professions.where((profession) => profession.missing > 0),
  );

  ProfessionStatistics? get mostTenseProfession {
    for (final profession in professions) {
      if (profession.missing > 0) return profession;
    }
    return null;
  }

  static int _compareProfessions(
    ProfessionStatistics left,
    ProfessionStatistics right,
  ) {
    final byMissing = right.missing.compareTo(left.missing);
    if (byMissing != 0) return byMissing;
    final byCoverage = left.coverage.compareTo(right.coverage);
    if (byCoverage != 0) return byCoverage;
    return left.label.compareTo(right.label);
  }

  static int _compareGroups(
    OperationalGroupStatistics left,
    OperationalGroupStatistics right,
  ) {
    final byMissing = right.missing.compareTo(left.missing);
    if (byMissing != 0) return byMissing;
    final byMissions = right.missionCount.compareTo(left.missionCount);
    if (byMissions != 0) return byMissions;
    return left.label.compareTo(right.label);
  }
}

class ProfessionStatistics {
  const ProfessionStatistics({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.required,
    required this.registered,
  });

  factory ProfessionStatistics.fromQuota(ProfessionQuota quota) {
    final definition = HealthProfessionRegistry.byId(quota.professionId);
    return ProfessionStatistics(
      id: quota.professionId,
      label: definition?.label ?? quota.professionId,
      shortLabel: definition?.shortLabel ?? quota.professionId,
      required: quota.required,
      registered: quota.registered,
    );
  }

  final String id;
  final String label;
  final String shortLabel;
  final int required;
  final int registered;

  int get missing => (required - registered).clamp(0, required);
  double get coverage =>
      required == 0 ? 1 : (registered / required).clamp(0, 1).toDouble();
}

class OperationalGroupStatistics {
  const OperationalGroupStatistics({
    required this.id,
    required this.label,
    required this.missionCount,
    required this.required,
    required this.registered,
  });

  final String id;
  final String label;
  final int missionCount;
  final int required;
  final int registered;

  int get missing => (required - registered).clamp(0, required);
  double get coverage =>
      required == 0 ? 1 : (registered / required).clamp(0, 1).toDouble();
}

class _MutableGroupStatistics {
  _MutableGroupStatistics(this.id, this.label);

  final String id;
  final String label;
  int missionCount = 0;
  int required = 0;
  int registered = 0;

  void add(CoordinationNeed mission) {
    missionCount++;
    required += mission.requiredPeople;
    registered += mission.registeredPeople;
  }

  OperationalGroupStatistics freeze() => OperationalGroupStatistics(
    id: id,
    label: label,
    missionCount: missionCount,
    required: required,
    registered: registered,
  );
}
