import '../models/operation.dart';
import '../platform_admin/platform_admin_statistics_view_data.dart';
import '../utils/operation_presentation.dart';

enum PlatformHistoryPeriod { all, last30Days, last90Days, currentYear }

extension PlatformHistoryPeriodLabel on PlatformHistoryPeriod {
  String get label => switch (this) {
    PlatformHistoryPeriod.all => 'Toutes les périodes',
    PlatformHistoryPeriod.last30Days => '30 derniers jours',
    PlatformHistoryPeriod.last90Days => '90 derniers jours',
    PlatformHistoryPeriod.currentYear => 'Année en cours',
  };
}

class PlatformAdminHistoryFilter {
  const PlatformAdminHistoryFilter({
    this.search = '',
    this.period = PlatformHistoryPeriod.all,
    this.territoryId,
    this.type,
    this.status,
  });

  final String search;
  final PlatformHistoryPeriod period;
  final String? territoryId;
  final OperationType? type;
  final OperationStatus? status;

  int get activeCount =>
      (period == PlatformHistoryPeriod.all ? 0 : 1) +
      (territoryId == null ? 0 : 1) +
      (type == null ? 0 : 1) +
      (status == null ? 0 : 1);

  PlatformAdminHistoryFilter copyWith({
    String? search,
    PlatformHistoryPeriod? period,
    String? territoryId,
    bool clearTerritory = false,
    OperationType? type,
    bool clearType = false,
    OperationStatus? status,
    bool clearStatus = false,
  }) => PlatformAdminHistoryFilter(
    search: search ?? this.search,
    period: period ?? this.period,
    territoryId: clearTerritory ? null : territoryId ?? this.territoryId,
    type: clearType ? null : type ?? this.type,
    status: clearStatus ? null : status ?? this.status,
  );
}

class PlatformAdminHistoryViewData {
  PlatformAdminHistoryViewData._({
    required this.operations,
    required this.territories,
    required this.types,
  });

  factory PlatformAdminHistoryViewData.fromStatistics(
    PlatformAdminStatisticsViewData statistics,
  ) {
    final operations =
        statistics.operations
            .where(
              (entry) => {
                OperationStatus.completed,
                OperationStatus.archived,
              }.contains(entry.operation.status),
            )
            .map(PlatformHistoryOperation.new)
            .toList(growable: false)
          ..sort(_compareHistoryOperations);
    final territoryById = <String, String>{};
    final types = <OperationType>{};
    for (final operation in operations) {
      types.add(operation.operation.type);
      for (final territory in operation.territories) {
        territoryById.putIfAbsent(territory.id, () => territory.label);
      }
    }
    final territories =
        territoryById.entries
            .map(
              (entry) =>
                  PlatformHistoryTerritory(id: entry.key, label: entry.value),
            )
            .toList(growable: false)
          ..sort((left, right) => left.label.compareTo(right.label));
    final sortedTypes = types.toList(growable: false)
      ..sort(
        (left, right) =>
            operationTypeLabel(left).compareTo(operationTypeLabel(right)),
      );
    return PlatformAdminHistoryViewData._(
      operations: List.unmodifiable(operations),
      territories: List.unmodifiable(territories),
      types: List.unmodifiable(sortedTypes),
    );
  }

  final List<PlatformHistoryOperation> operations;
  final List<PlatformHistoryTerritory> territories;
  final List<OperationType> types;

  List<PlatformHistoryOperation> filtered(
    PlatformAdminHistoryFilter filter, {
    required DateTime now,
  }) {
    final query = filter.search.trim().toLowerCase();
    return List.unmodifiable(
      operations.where((entry) {
        if (filter.status != null && entry.operation.status != filter.status) {
          return false;
        }
        if (filter.type != null && entry.operation.type != filter.type) {
          return false;
        }
        if (filter.territoryId != null &&
            !entry.territoryIds.contains(filter.territoryId)) {
          return false;
        }
        if (!_matchesPeriod(entry.referenceDate, filter.period, now)) {
          return false;
        }
        if (query.isEmpty) return true;
        final searchable = [
          entry.operation.name,
          operationTypeLabel(entry.operation.type),
          entry.operation.type.serializedValue,
          ...entry.territories.map((territory) => territory.label),
        ].join(' ').toLowerCase();
        return searchable.contains(query);
      }),
    );
  }

  static bool _matchesPeriod(
    DateTime value,
    PlatformHistoryPeriod period,
    DateTime now,
  ) => switch (period) {
    PlatformHistoryPeriod.all => true,
    PlatformHistoryPeriod.last30Days => !value.isBefore(
      now.subtract(const Duration(days: 30)),
    ),
    PlatformHistoryPeriod.last90Days => !value.isBefore(
      now.subtract(const Duration(days: 90)),
    ),
    PlatformHistoryPeriod.currentYear => value.year == now.year,
  };

  static int _compareHistoryOperations(
    PlatformHistoryOperation left,
    PlatformHistoryOperation right,
  ) {
    final byDate = right.referenceDate.compareTo(left.referenceDate);
    if (byDate != 0) return byDate;
    return left.operation.name.compareTo(right.operation.name);
  }
}

class PlatformHistoryOperation {
  PlatformHistoryOperation(this.statistics)
    : territories = _territories(statistics);

  final OperationAdminStatistics statistics;
  final List<PlatformHistoryTerritory> territories;

  Operation get operation => statistics.operation;
  DateTime get referenceDate => operation.status == OperationStatus.archived
      ? operation.updatedAt
      : operation.endAt ?? operation.updatedAt;
  Set<String> get territoryIds =>
      territories.map((territory) => territory.id).toSet();

  int get mobilizationCount => statistics.snapshot.mobilizations.length;
  int get missionCount => statistics.snapshot.missionCount;
  int get remainingProfessionalCount => statistics.remainingProfessionalCount;
  int get mobilizedProfessionalCount =>
      statistics.snapshot.mobilizedProfessionalCount;
  int get criticalMissionCount => statistics.snapshot.criticalMissionCount;
  double? get coverage => statistics.snapshot.coverage;
  String? get coordinatorUid => statistics.coordinatorUid;

  static List<PlatformHistoryTerritory> _territories(
    OperationAdminStatistics statistics,
  ) {
    final labelsById = {
      for (final territory in statistics.territories)
        territory.id: territory.label,
    };
    for (final territory in statistics.breakdown.territories) {
      labelsById.putIfAbsent(territory.id, () => territory.label);
    }
    final result =
        labelsById.entries
            .map(
              (entry) =>
                  PlatformHistoryTerritory(id: entry.key, label: entry.value),
            )
            .toList(growable: false)
          ..sort((left, right) => left.label.compareTo(right.label));
    return List.unmodifiable(result);
  }
}

class PlatformHistoryTerritory {
  const PlatformHistoryTerritory({required this.id, required this.label});

  final String id;
  final String label;
}
