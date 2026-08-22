import 'dart:collection';

enum OperationalFactQuality { complete, partial, unavailable }

enum OperationalFactSource {
  engagements,
  missions,
  mobilizations,
  operations,
  notifications,
  notificationEvents,
  notificationDeliveries,
  presenceRecords,
}

/// Fait dérivé accompagné de la qualité et de la couverture de ses sources.
///
/// Une valeur nulle avec une qualité [OperationalFactQuality.complete] peut
/// signifier qu'aucune occurrence n'existe (par exemple aucune dernière date).
/// Elle ne doit pas être confondue avec [OperationalFactQuality.unavailable],
/// qui exige toujours une raison explicite.
final class OperationalFact<T> {
  factory OperationalFact({
    required T? value,
    required OperationalFactQuality quality,
    required Iterable<OperationalFactSource> sources,
    DateTime? coveredSince,
    String? reasonUnavailable,
    Iterable<String> limitations = const [],
  }) {
    final immutableSources = Set<OperationalFactSource>.unmodifiable(sources);
    final immutableLimitations = List<String>.unmodifiable(limitations);
    if (immutableSources.isEmpty) {
      throw ArgumentError.value(sources, 'sources', 'Une source est requise.');
    }
    final reason = reasonUnavailable?.trim();
    if (quality == OperationalFactQuality.unavailable) {
      if (value != null) {
        throw ArgumentError.value(
          value,
          'value',
          'Un fait indisponible ne peut pas porter de valeur.',
        );
      }
      if (reason == null || reason.isEmpty) {
        throw ArgumentError.value(
          reasonUnavailable,
          'reasonUnavailable',
          'Une raison est requise pour un fait indisponible.',
        );
      }
    } else if (reason != null && reason.isNotEmpty) {
      throw ArgumentError.value(
        reasonUnavailable,
        'reasonUnavailable',
        'La raison est réservée aux faits indisponibles.',
      );
    }
    return OperationalFact._(
      value: value,
      quality: quality,
      coveredSince: coveredSince,
      sources: immutableSources,
      reasonUnavailable: reason,
      limitations: immutableLimitations,
    );
  }

  const OperationalFact._({
    required this.value,
    required this.quality,
    required this.coveredSince,
    required this.sources,
    required this.reasonUnavailable,
    required this.limitations,
  });

  final T? value;
  final OperationalFactQuality quality;
  final DateTime? coveredSince;
  final Set<OperationalFactSource> sources;
  final String? reasonUnavailable;
  final List<String> limitations;

  bool get isAvailable => quality != OperationalFactQuality.unavailable;
}

/// Référence transitoire vers une opération reliée aux engagements.
///
/// Elle n'affirme aucune présence. Le libellé et le type restent optionnels
/// afin de conserver un identifiant connu lorsque la jointure est partielle.
final class OperationalHistoryOperationRef {
  const OperationalHistoryOperationRef({
    required this.id,
    this.label,
    this.type,
  });

  final String id;
  final String? label;
  final String? type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OperationalHistoryOperationRef &&
          id == other.id &&
          label == other.label &&
          type == other.type;

  @override
  int get hashCode => Object.hash(id, label, type);
}

/// Projection pure de faits opérationnels ; elle n'est jamais persistée.
final class ProfessionalOperationalHistory {
  const ProfessionalOperationalHistory({
    required this.professionalUid,
    required this.derivedAt,
    required this.distinctEngagementCount,
    required this.firstEngagementAt,
    required this.currentConfirmedEngagementCount,
    required this.currentStandbyEngagementCount,
    required this.currentCancelledEngagementCount,
    required this.reengagementCount,
    required this.cancellationCount,
    required this.lastCancellationAt,
    required this.createdSolicitationCount,
    required this.lastCreatedSolicitationAt,
    required this.pushProviderAcceptedCount,
    required this.consultedSolicitationCount,
    required this.lastConsultedSolicitationAt,
    required this.linkedOperations,
    required this.linkedMobilizationTypes,
    required this.effectiveParticipationCount,
    required this.completedMissionCount,
    required this.lastParticipationAt,
    required this.lastPresenceAt,
    required this.experiencedOperations,
    required this.experiencedMobilizationTypes,
    required this.partialPresenceCount,
    required this.validatedAbsenceCount,
    required this.totalValidatedPresenceDuration,
  });

  final String professionalUid;
  final DateTime derivedAt;

  final OperationalFact<int> distinctEngagementCount;
  final OperationalFact<DateTime> firstEngagementAt;
  final OperationalFact<int> currentConfirmedEngagementCount;
  final OperationalFact<int> currentStandbyEngagementCount;
  final OperationalFact<int> currentCancelledEngagementCount;
  final OperationalFact<int> reengagementCount;
  final OperationalFact<int> cancellationCount;
  final OperationalFact<DateTime> lastCancellationAt;

  final OperationalFact<int> createdSolicitationCount;
  final OperationalFact<DateTime> lastCreatedSolicitationAt;
  final OperationalFact<int> pushProviderAcceptedCount;
  final OperationalFact<int> consultedSolicitationCount;
  final OperationalFact<DateTime> lastConsultedSolicitationAt;

  final OperationalFact<Set<OperationalHistoryOperationRef>> linkedOperations;
  final OperationalFact<Set<String>> linkedMobilizationTypes;

  final OperationalFact<int> effectiveParticipationCount;
  final OperationalFact<int> completedMissionCount;
  final OperationalFact<DateTime> lastParticipationAt;
  final OperationalFact<DateTime> lastPresenceAt;
  final OperationalFact<Set<OperationalHistoryOperationRef>>
  experiencedOperations;
  final OperationalFact<Set<String>> experiencedMobilizationTypes;
  final OperationalFact<int> partialPresenceCount;
  final OperationalFact<int> validatedAbsenceCount;
  final OperationalFact<Duration> totalValidatedPresenceDuration;
}

Set<T> immutableOperationalFactSet<T>(Iterable<T> values) =>
    UnmodifiableSetView<T>(Set<T>.of(values));
