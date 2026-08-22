import '../models/professional_operational_history.dart';

enum OperationalHistoryEngagementStatus {
  pending,
  confirmed,
  standby,
  cancelled,
}

enum OperationalHistoryEventKind { engagementCreated, engagementCancelled }

enum OperationalHistoryDeliveryStatus {
  pending,
  processing,
  providerAccepted,
  failed,
}

final class OperationalHistoryEngagementRecord {
  const OperationalHistoryEngagementRecord({
    required this.id,
    required this.professionalUid,
    required this.missionId,
    required this.status,
    this.mobilizationId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String professionalUid;
  final String missionId;
  final String? mobilizationId;
  final OperationalHistoryEngagementStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

final class OperationalHistoryMissionRecord {
  const OperationalHistoryMissionRecord({
    required this.id,
    this.mobilizationId,
  });

  final String id;
  final String? mobilizationId;
}

final class OperationalHistoryMobilizationRecord {
  const OperationalHistoryMobilizationRecord({
    required this.id,
    this.operationId,
    this.contextType,
  });

  final String id;
  final String? operationId;
  final String? contextType;
}

final class OperationalHistoryOperationRecord {
  const OperationalHistoryOperationRecord({
    required this.id,
    this.label,
    this.type,
  });

  final String id;
  final String? label;
  final String? type;
}

/// Notification compatible effectivement créée pour un destinataire.
final class OperationalHistorySolicitationRecord {
  const OperationalHistorySolicitationRecord({
    required this.id,
    required this.recipientUid,
    this.occurredAt,
    this.readAt,
  });

  final String id;
  final String recipientUid;
  final DateTime? occurredAt;
  final DateTime? readAt;
}

/// Événement serveur concernant le professionnel sujet de l'engagement.
///
/// [professionalUid] n'est pas l'auteur de la transition. Les événements
/// actuels ne permettent pas de prouver l'identité de cet auteur.
final class OperationalHistoryEngagementEventRecord {
  const OperationalHistoryEngagementEventRecord({
    required this.id,
    required this.engagementId,
    required this.professionalUid,
    required this.kind,
    required this.occurredAt,
  });

  final String id;
  final String engagementId;
  final String professionalUid;
  final OperationalHistoryEventKind kind;
  final DateTime occurredAt;
}

/// Preuve de transport push. `providerAccepted` ne prouve pas la réception
/// sur le terminal ni la consultation par le professionnel.
final class OperationalHistoryNotificationDeliveryRecord {
  const OperationalHistoryNotificationDeliveryRecord({
    required this.id,
    required this.notificationId,
    required this.recipientUid,
    required this.channel,
    required this.status,
    this.providerAcceptedAt,
  });

  final String id;
  final String notificationId;
  final String recipientUid;
  final String channel;
  final OperationalHistoryDeliveryStatus status;
  final DateTime? providerAcceptedAt;

  bool get isPush => channel == 'push' || channel.startsWith('push:');
}

final class ProfessionalOperationalHistoryInput {
  factory ProfessionalOperationalHistoryInput({
    required String professionalUid,
    Iterable<OperationalHistoryEngagementRecord> engagements = const [],
    Iterable<OperationalHistoryMissionRecord> missions = const [],
    Iterable<OperationalHistoryMobilizationRecord> mobilizations = const [],
    Iterable<OperationalHistoryOperationRecord> operations = const [],
    Iterable<OperationalHistorySolicitationRecord> compatibleNotifications =
        const [],
    Iterable<OperationalHistoryEngagementEventRecord> notificationEvents =
        const [],
    Iterable<OperationalHistoryNotificationDeliveryRecord>
        notificationDeliveries =
        const [],
    DateTime? notificationsCoveredSince,
    DateTime? engagementEventsCoveredSince,
    DateTime? notificationDeliveriesCoveredSince,
  }) {
    if (professionalUid.trim().isEmpty ||
        professionalUid.trim() != professionalUid) {
      throw ArgumentError.value(
        professionalUid,
        'professionalUid',
        'Identifiant professionnel invalide.',
      );
    }
    return ProfessionalOperationalHistoryInput._(
      professionalUid: professionalUid,
      engagements: List.unmodifiable(engagements),
      missions: List.unmodifiable(missions),
      mobilizations: List.unmodifiable(mobilizations),
      operations: List.unmodifiable(operations),
      compatibleNotifications: List.unmodifiable(compatibleNotifications),
      notificationEvents: List.unmodifiable(notificationEvents),
      notificationDeliveries: List.unmodifiable(notificationDeliveries),
      notificationsCoveredSince: notificationsCoveredSince,
      engagementEventsCoveredSince: engagementEventsCoveredSince,
      notificationDeliveriesCoveredSince: notificationDeliveriesCoveredSince,
    );
  }

  const ProfessionalOperationalHistoryInput._({
    required this.professionalUid,
    required this.engagements,
    required this.missions,
    required this.mobilizations,
    required this.operations,
    required this.compatibleNotifications,
    required this.notificationEvents,
    required this.notificationDeliveries,
    required this.notificationsCoveredSince,
    required this.engagementEventsCoveredSince,
    required this.notificationDeliveriesCoveredSince,
  });

  final String professionalUid;
  final List<OperationalHistoryEngagementRecord> engagements;
  final List<OperationalHistoryMissionRecord> missions;
  final List<OperationalHistoryMobilizationRecord> mobilizations;
  final List<OperationalHistoryOperationRecord> operations;
  final List<OperationalHistorySolicitationRecord> compatibleNotifications;
  final List<OperationalHistoryEngagementEventRecord> notificationEvents;
  final List<OperationalHistoryNotificationDeliveryRecord>
  notificationDeliveries;
  final DateTime? notificationsCoveredSince;
  final DateTime? engagementEventsCoveredSince;
  final DateTime? notificationDeliveriesCoveredSince;
}

/// Agrège exclusivement des données déjà chargées, sans lecture ni écriture.
final class ProfessionalOperationalHistoryAggregator {
  const ProfessionalOperationalHistoryAggregator();

  ProfessionalOperationalHistory aggregate({
    required ProfessionalOperationalHistoryInput input,
    required DateTime derivedAt,
  }) {
    final engagements = _recordsForProfessional(
      input.engagements,
      input.professionalUid,
    );
    final engagementFacts = _engagementFacts(
      engagements,
      input.notificationEvents,
      input.professionalUid,
      input.engagementEventsCoveredSince,
    );
    final solicitationFacts = _solicitationFacts(input);
    final links = _linkedFacts(input, engagements);

    return ProfessionalOperationalHistory(
      professionalUid: input.professionalUid,
      derivedAt: derivedAt,
      distinctEngagementCount: engagementFacts.distinctCount,
      firstEngagementAt: engagementFacts.firstAt,
      currentConfirmedEngagementCount: engagementFacts.confirmedCount,
      currentStandbyEngagementCount: engagementFacts.standbyCount,
      currentCancelledEngagementCount: engagementFacts.cancelledCurrentCount,
      reengagementCount: engagementFacts.reengagementCount,
      cancellationCount: engagementFacts.cancellationCount,
      lastCancellationAt: engagementFacts.lastCancellationAt,
      createdSolicitationCount: solicitationFacts.createdCount,
      lastCreatedSolicitationAt: solicitationFacts.lastCreatedAt,
      pushProviderAcceptedCount: solicitationFacts.pushAcceptedCount,
      consultedSolicitationCount: solicitationFacts.consultedCount,
      lastConsultedSolicitationAt: solicitationFacts.lastConsultedAt,
      linkedOperations: links.operations,
      linkedMobilizationTypes: links.mobilizationTypes,
      effectiveParticipationCount: _presenceUnavailable(
        'Aucune présence effective validée n’est disponible.',
      ),
      completedMissionCount: _presenceUnavailable(
        'Une mission terminée ou un engagement confirmé ne prouve pas sa réalisation.',
      ),
      lastParticipationAt: _presenceUnavailable(
        'Aucune participation effective validée n’est disponible.',
      ),
      lastPresenceAt: _presenceUnavailable(
        'Aucun fait canonique de présence n’est disponible.',
      ),
      experiencedOperations: _presenceUnavailable(
        'Les opérations reliées ne prouvent pas qu’elles ont été vécues.',
      ),
      experiencedMobilizationTypes: _presenceUnavailable(
        'Les types reliés ne prouvent pas une participation effective.',
      ),
      partialPresenceCount: _presenceUnavailable(
        'Aucune présence partielle validée n’est disponible.',
      ),
      validatedAbsenceCount: _presenceUnavailable(
        'Aucune absence validée n’est disponible.',
      ),
      totalValidatedPresenceDuration: _presenceUnavailable(
        'Aucun intervalle de présence validé n’est disponible.',
      ),
    );
  }

  List<OperationalHistoryEngagementRecord> _recordsForProfessional(
    Iterable<OperationalHistoryEngagementRecord> records,
    String professionalUid,
  ) => _uniqueById(
    records.where((record) => record.professionalUid == professionalUid),
    (record) => record.id,
  );

  _EngagementFacts _engagementFacts(
    List<OperationalHistoryEngagementRecord> engagements,
    Iterable<OperationalHistoryEngagementEventRecord> rawEvents,
    String professionalUid,
    DateTime? coveredSince,
  ) {
    const engagementSource = {OperationalFactSource.engagements};
    final createdDates = engagements
        .map((record) => record.createdAt)
        .whereType<DateTime>()
        .toList(growable: false);
    final allCreationDatesKnown = createdDates.length == engagements.length;
    final firstAt = _minimum(createdDates);
    final firstQuality = allCreationDatesKnown
        ? OperationalFactQuality.complete
        : OperationalFactQuality.partial;
    final firstLimitations = allCreationDatesKnown
        ? const <String>[]
        : const ['Au moins un engagement ne possède pas de createdAt.'];

    final engagementIds = engagements.map((item) => item.id).toSet();
    final events = _uniqueById(
      rawEvents.where(
        (event) =>
            event.professionalUid == professionalUid &&
            engagementIds.contains(event.engagementId),
      ),
      (event) => event.id,
    );
    final createdEventsByEngagement = <String, List<DateTime>>{};
    final cancellations = <OperationalHistoryEngagementEventRecord>[];
    for (final event in events) {
      switch (event.kind) {
        case OperationalHistoryEventKind.engagementCreated:
          createdEventsByEngagement
              .putIfAbsent(event.engagementId, () => [])
              .add(event.occurredAt);
        case OperationalHistoryEventKind.engagementCancelled:
          cancellations.add(event);
      }
    }
    final hasInitialEventForEveryEngagement = engagements.every(
      (engagement) =>
          createdEventsByEngagement[engagement.id]?.isNotEmpty ?? false,
    );
    final eventCoverageIsComplete =
        coveredSince != null &&
        allCreationDatesKnown &&
        createdDates.every((date) => !date.isBefore(coveredSince)) &&
        hasInitialEventForEveryEngagement;
    final eventQuality = eventCoverageIsComplete
        ? OperationalFactQuality.complete
        : OperationalFactQuality.partial;
    final eventLimitations = eventCoverageIsComplete
        ? const <String>[]
        : [
            if (coveredSince == null)
              'Début de couverture des événements inconnu.',
            if (!allCreationDatesKnown)
              'La couverture ne peut pas être comparée à tous les engagements.',
            if (!hasInitialEventForEveryEngagement && engagements.isNotEmpty)
              'Au moins un événement initial d’engagement est absent.',
          ];
    final reengagements = createdEventsByEngagement.values.fold<int>(
      0,
      (total, values) => total + (values.length > 1 ? values.length - 1 : 0),
    );

    return (
      distinctCount: _completeFact(engagements.length, engagementSource),
      firstAt: OperationalFact(
        value: firstAt,
        quality: firstQuality,
        sources: engagementSource,
        limitations: firstLimitations,
      ),
      confirmedCount: _completeFact(
        engagements
            .where(
              (item) =>
                  item.status == OperationalHistoryEngagementStatus.confirmed,
            )
            .length,
        engagementSource,
      ),
      standbyCount: _completeFact(
        engagements
            .where(
              (item) =>
                  item.status == OperationalHistoryEngagementStatus.standby,
            )
            .length,
        engagementSource,
      ),
      cancelledCurrentCount: _completeFact(
        engagements
            .where(
              (item) =>
                  item.status == OperationalHistoryEngagementStatus.cancelled,
            )
            .length,
        engagementSource,
      ),
      reengagementCount: OperationalFact(
        value: reengagements,
        quality: eventQuality,
        coveredSince: coveredSince,
        sources: const {
          OperationalFactSource.engagements,
          OperationalFactSource.notificationEvents,
        },
        limitations: eventLimitations,
      ),
      cancellationCount: OperationalFact(
        value: cancellations.length,
        quality: eventQuality,
        coveredSince: coveredSince,
        sources: const {OperationalFactSource.notificationEvents},
        limitations: eventLimitations,
      ),
      lastCancellationAt: OperationalFact(
        value: _maximum(cancellations.map((event) => event.occurredAt)),
        quality: eventQuality,
        coveredSince: coveredSince,
        sources: const {OperationalFactSource.notificationEvents},
        limitations: eventLimitations,
      ),
    );
  }

  _SolicitationFacts _solicitationFacts(
    ProfessionalOperationalHistoryInput input,
  ) {
    final notifications = _uniqueById(
      input.compatibleNotifications.where(
        (item) => item.recipientUid == input.professionalUid,
      ),
      (item) => item.id,
    );
    final notificationIds = notifications.map((item) => item.id).toSet();
    final acceptedDeliveries = _uniqueById(
      input.notificationDeliveries.where(
        (item) =>
            item.recipientUid == input.professionalUid &&
            item.isPush &&
            item.status == OperationalHistoryDeliveryStatus.providerAccepted &&
            notificationIds.contains(item.notificationId),
      ),
      (item) => item.id,
    );
    final unknownNotificationTimestamps = notifications.any(
      (item) => item.occurredAt == null,
    );
    final orphanAcceptedDelivery = input.notificationDeliveries.any(
      (item) =>
          item.recipientUid == input.professionalUid &&
          item.isPush &&
          item.status == OperationalHistoryDeliveryStatus.providerAccepted &&
          !notificationIds.contains(item.notificationId),
    );
    final notificationLimitations = <String>[
      if (input.notificationsCoveredSince == null)
        'Début de couverture des sollicitations inconnu.',
      if (unknownNotificationTimestamps)
        'Au moins une sollicitation ne possède pas de occurredAt.',
    ];
    final deliveryCoveredSince = _intersectionCoverageStart(
      input.notificationsCoveredSince,
      input.notificationDeliveriesCoveredSince,
    );
    final deliveryLimitations = <String>[
      if (deliveryCoveredSince == null)
        'Couverture conjointe notifications/livraisons inconnue.',
      if (orphanAcceptedDelivery)
        'Une livraison ne peut pas être reliée à une sollicitation compatible.',
      'L’acceptation fournisseur ne prouve pas la livraison au terminal.',
    ];

    return (
      createdCount: _partialFact(
        notifications.length,
        const {OperationalFactSource.notifications},
        coveredSince: input.notificationsCoveredSince,
        limitations: notificationLimitations,
      ),
      lastCreatedAt: _partialFact(
        _maximum(notifications.map((item) => item.occurredAt).whereType()),
        const {OperationalFactSource.notifications},
        coveredSince: input.notificationsCoveredSince,
        limitations: notificationLimitations,
      ),
      pushAcceptedCount: _partialFact(
        acceptedDeliveries.length,
        const {
          OperationalFactSource.notifications,
          OperationalFactSource.notificationDeliveries,
        },
        coveredSince: deliveryCoveredSince,
        limitations: deliveryLimitations,
      ),
      consultedCount: _partialFact(
        notifications.where((item) => item.readAt != null).length,
        const {OperationalFactSource.notifications},
        coveredSince: input.notificationsCoveredSince,
        limitations: notificationLimitations,
      ),
      lastConsultedAt: _partialFact(
        _maximum(notifications.map((item) => item.readAt).whereType()),
        const {OperationalFactSource.notifications},
        coveredSince: input.notificationsCoveredSince,
        limitations: notificationLimitations,
      ),
    );
  }

  _LinkedFacts _linkedFacts(
    ProfessionalOperationalHistoryInput input,
    List<OperationalHistoryEngagementRecord> engagements,
  ) {
    final missions = {for (final item in input.missions) item.id: item};
    final mobilizations = {
      for (final item in input.mobilizations) item.id: item,
    };
    final operations = {for (final item in input.operations) item.id: item};
    final linkedOperations = <OperationalHistoryOperationRef>{};
    final linkedTypes = <String>{};
    final operationLimitations = <String>{};
    final typeLimitations = <String>{};

    void addSharedLimitation(String limitation) {
      operationLimitations.add(limitation);
      typeLimitations.add(limitation);
    }

    for (final engagement in engagements) {
      final mission = missions[engagement.missionId];
      if (mission == null) {
        addSharedLimitation('Au moins une mission référencée est absente.');
      }
      final engagementMobilizationId = _textOrNull(engagement.mobilizationId);
      final missionMobilizationId = _textOrNull(mission?.mobilizationId);
      if (engagementMobilizationId != null &&
          missionMobilizationId != null &&
          engagementMobilizationId != missionMobilizationId) {
        addSharedLimitation(
          'Au moins un rattachement mission/mobilisation est incohérent.',
        );
      }
      final mobilizationId = engagementMobilizationId ?? missionMobilizationId;
      if (mobilizationId == null) {
        addSharedLimitation(
          'Au moins un engagement ne peut pas être relié à une mobilisation.',
        );
        continue;
      }
      final mobilization = mobilizations[mobilizationId];
      if (mobilization == null) {
        addSharedLimitation(
          'Au moins une mobilisation référencée est absente.',
        );
        continue;
      }
      final contextType = _textOrNull(mobilization.contextType);
      if (contextType == null) {
        typeLimitations.add(
          'Au moins une mobilisation legacy ne possède pas de contextType.',
        );
      } else {
        linkedTypes.add(contextType);
      }
      final operationId = _textOrNull(mobilization.operationId);
      if (operationId == null) {
        operationLimitations.add(
          'Au moins une mobilisation legacy ne possède pas de operationId.',
        );
        continue;
      }
      final operation = operations[operationId];
      if (operation == null) {
        operationLimitations.add(
          'Au moins une opération référencée est absente.',
        );
        linkedOperations.add(OperationalHistoryOperationRef(id: operationId));
      } else {
        linkedOperations.add(
          OperationalHistoryOperationRef(
            id: operation.id,
            label: _textOrNull(operation.label),
            type: _textOrNull(operation.type),
          ),
        );
      }
    }

    final operationSources = const {
      OperationalFactSource.engagements,
      OperationalFactSource.missions,
      OperationalFactSource.mobilizations,
      OperationalFactSource.operations,
    };
    final mobilizationTypeSources = const {
      OperationalFactSource.engagements,
      OperationalFactSource.missions,
      OperationalFactSource.mobilizations,
    };
    return (
      operations: OperationalFact(
        value: immutableOperationalFactSet(linkedOperations),
        quality: operationLimitations.isEmpty
            ? OperationalFactQuality.complete
            : OperationalFactQuality.partial,
        sources: operationSources,
        limitations: operationLimitations,
      ),
      mobilizationTypes: OperationalFact(
        value: immutableOperationalFactSet(linkedTypes),
        quality: typeLimitations.isEmpty
            ? OperationalFactQuality.complete
            : OperationalFactQuality.partial,
        sources: mobilizationTypeSources,
        limitations: typeLimitations,
      ),
    );
  }
}

OperationalFact<T> _completeFact<T>(
  T? value,
  Iterable<OperationalFactSource> sources,
) => OperationalFact(
  value: value,
  quality: OperationalFactQuality.complete,
  sources: sources,
);

OperationalFact<T> _partialFact<T>(
  T? value,
  Iterable<OperationalFactSource> sources, {
  DateTime? coveredSince,
  Iterable<String> limitations = const [],
}) => OperationalFact(
  value: value,
  quality: OperationalFactQuality.partial,
  coveredSince: coveredSince,
  sources: sources,
  limitations: limitations,
);

OperationalFact<T> _presenceUnavailable<T>(String reason) => OperationalFact(
  value: null,
  quality: OperationalFactQuality.unavailable,
  sources: const {OperationalFactSource.presenceRecords},
  reasonUnavailable: reason,
);

List<T> _uniqueById<T>(Iterable<T> records, String Function(T) idOf) =>
    List.unmodifiable(
      {for (final record in records) idOf(record): record}.values,
    );

DateTime? _minimum(Iterable<DateTime> values) {
  DateTime? result;
  for (final value in values) {
    if (result == null || value.isBefore(result)) result = value;
  }
  return result;
}

DateTime? _maximum(Iterable<DateTime> values) {
  DateTime? result;
  for (final value in values) {
    if (result == null || value.isAfter(result)) result = value;
  }
  return result;
}

DateTime? _intersectionCoverageStart(DateTime? left, DateTime? right) {
  if (left == null || right == null) return null;
  return left.isAfter(right) ? left : right;
}

String? _textOrNull(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

typedef _EngagementFacts = ({
  OperationalFact<int> distinctCount,
  OperationalFact<DateTime> firstAt,
  OperationalFact<int> confirmedCount,
  OperationalFact<int> standbyCount,
  OperationalFact<int> cancelledCurrentCount,
  OperationalFact<int> reengagementCount,
  OperationalFact<int> cancellationCount,
  OperationalFact<DateTime> lastCancellationAt,
});

typedef _SolicitationFacts = ({
  OperationalFact<int> createdCount,
  OperationalFact<DateTime> lastCreatedAt,
  OperationalFact<int> pushAcceptedCount,
  OperationalFact<int> consultedCount,
  OperationalFact<DateTime> lastConsultedAt,
});

typedef _LinkedFacts = ({
  OperationalFact<Set<OperationalHistoryOperationRef>> operations,
  OperationalFact<Set<String>> mobilizationTypes,
});
