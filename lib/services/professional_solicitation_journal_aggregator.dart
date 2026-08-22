import '../models/professional_operational_history.dart';
import '../models/professional_solicitation_journal.dart';

/// Projection minimale d'un document RC3 `notifications` déjà chargé.
final class LegacySolicitationNotificationRecord {
  const LegacySolicitationNotificationRecord({
    required this.id,
    required this.recipientUid,
    this.eventId,
    this.eventType,
    this.category,
    this.occurredAt,
    this.createdAt,
    this.readAt,
    this.missionId,
    this.mobilizationId,
    this.engagementId,
  });

  final String id;
  final String recipientUid;
  final String? eventId;
  final String? eventType;
  final String? category;
  final DateTime? occurredAt;
  final DateTime? createdAt;
  final DateTime? readAt;
  final String? missionId;
  final String? mobilizationId;
  final String? engagementId;
}

/// Projection minimale d'un document serveur RC3 `notificationEvents`.
///
/// Un événement n'est pas une sollicitation : il ne porte aucun destinataire.
final class LegacySolicitationCauseEventRecord {
  const LegacySolicitationCauseEventRecord({
    required this.id,
    required this.eventType,
    required this.occurredAt,
    this.missionId,
    this.mobilizationId,
    this.engagementId,
  });

  final String id;
  final String eventType;
  final DateTime occurredAt;
  final String? missionId;
  final String? mobilizationId;
  final String? engagementId;
}

/// Projection minimale d'un document RC3 `notificationDeliveries`.
final class LegacySolicitationDeliveryRecord {
  const LegacySolicitationDeliveryRecord({
    required this.id,
    required this.notificationId,
    required this.recipientUid,
    required this.channel,
    required this.status,
    this.providerAcceptedAt,
    this.deliveredAt,
    this.updatedAt,
  });

  final String id;
  final String notificationId;
  final String recipientUid;
  final String channel;
  final String status;
  final DateTime? providerAcceptedAt;
  final DateTime? deliveredAt;
  final DateTime? updatedAt;
}

/// Entrées déjà chargées. Aucun accès réseau n'est réalisé par l'agrégateur.
final class ProfessionalSolicitationJournalInput {
  factory ProfessionalSolicitationJournalInput({
    required String recipientUid,
    Iterable<ProfessionalSolicitationJournalEntry> canonicalEntries = const [],
    Iterable<LegacySolicitationNotificationRecord> notifications = const [],
    Iterable<LegacySolicitationCauseEventRecord> notificationEvents = const [],
    Iterable<LegacySolicitationDeliveryRecord> notificationDeliveries =
        const [],
    bool canonicalJournalIsAuthoritative = false,
    DateTime? canonicalJournalCoveredSince,
    DateTime? notificationsCoveredSince,
    DateTime? notificationDeliveriesCoveredSince,
  }) {
    if (_textOrNull(recipientUid) != recipientUid) {
      throw ArgumentError.value(
        recipientUid,
        'recipientUid',
        'Destinataire invalide.',
      );
    }
    return ProfessionalSolicitationJournalInput._(
      recipientUid: recipientUid,
      canonicalEntries: List.unmodifiable(canonicalEntries),
      notifications: List.unmodifiable(notifications),
      notificationEvents: List.unmodifiable(notificationEvents),
      notificationDeliveries: List.unmodifiable(notificationDeliveries),
      canonicalJournalIsAuthoritative: canonicalJournalIsAuthoritative,
      canonicalJournalCoveredSince: canonicalJournalCoveredSince,
      notificationsCoveredSince: notificationsCoveredSince,
      notificationDeliveriesCoveredSince: notificationDeliveriesCoveredSince,
    );
  }

  const ProfessionalSolicitationJournalInput._({
    required this.recipientUid,
    required this.canonicalEntries,
    required this.notifications,
    required this.notificationEvents,
    required this.notificationDeliveries,
    required this.canonicalJournalIsAuthoritative,
    required this.canonicalJournalCoveredSince,
    required this.notificationsCoveredSince,
    required this.notificationDeliveriesCoveredSince,
  });

  final String recipientUid;
  final List<ProfessionalSolicitationJournalEntry> canonicalEntries;
  final List<LegacySolicitationNotificationRecord> notifications;
  final List<LegacySolicitationCauseEventRecord> notificationEvents;
  final List<LegacySolicitationDeliveryRecord> notificationDeliveries;
  final bool canonicalJournalIsAuthoritative;
  final DateTime? canonicalJournalCoveredSince;
  final DateTime? notificationsCoveredSince;
  final DateTime? notificationDeliveriesCoveredSince;
}

final class ProfessionalSolicitationSummaryAggregation {
  ProfessionalSolicitationSummaryAggregation({
    required Iterable<ProfessionalSolicitation> solicitations,
    required Iterable<ProfessionalSolicitationJournalIssue> issues,
  }) : solicitations = List.unmodifiable(solicitations),
       issues = List.unmodifiable(issues);

  final List<ProfessionalSolicitation> solicitations;
  final List<ProfessionalSolicitationJournalIssue> issues;
}

/// Regroupe des entrées déjà normalisées sans supprimer leurs preuves.
final class ProfessionalSolicitationSummaryAggregator {
  const ProfessionalSolicitationSummaryAggregator();

  ProfessionalSolicitationSummaryAggregation aggregate({
    required String recipientUid,
    required Iterable<ProfessionalSolicitationJournalEntry> entries,
  }) {
    final issues = <ProfessionalSolicitationJournalIssue>[];
    final groups = <String, List<ProfessionalSolicitationJournalEntry>>{};
    for (final entry in _uniqueEntries(entries)) {
      if (entry.recipientUid != recipientUid) continue;
      groups.putIfAbsent(entry.solicitationId, () => []).add(entry);
    }

    final solicitations = <ProfessionalSolicitation>[];
    for (final group in groups.entries) {
      final ordered = group.value.toList()..sort(_ascendingEntryComparison);
      final createdEntries = ordered
          .where(
            (entry) =>
                entry.factType == ProfessionalSolicitationFactType.created,
          )
          .toList(growable: false);
      final createdAt = _minimum(
        createdEntries.map((entry) => entry.occurredAt),
      );
      final limitations = <String>{
        for (final entry in ordered) ...entry.limitations,
      };
      if (createdEntries.isEmpty) {
        limitations.add(
          'La preuve de création de cette sollicitation est absente.',
        );
        issues.add(
          ProfessionalSolicitationJournalIssue(
            code: 'missing_created_fact',
            sourceRecordId: group.key,
            description:
                'Des faits existent sans preuve de création de sollicitation.',
          ),
        );
      }

      T? metadata<T>(
        String field,
        T? Function(ProfessionalSolicitationJournalEntry) select,
      ) {
        final values = ordered.map(select).whereType<T>().toSet();
        if (values.length > 1) {
          limitations.add('Métadonnée $field incohérente entre les preuves.');
          issues.add(
            ProfessionalSolicitationJournalIssue(
              code: 'conflicting_metadata',
              sourceRecordId: group.key,
              description: 'Plusieurs valeurs existent pour $field.',
            ),
          );
        }
        if (values.isEmpty) return null;
        return values.first;
      }

      final consultedAt = _maximum(
        ordered
            .where(
              (entry) =>
                  entry.factType == ProfessionalSolicitationFactType.consulted,
            )
            .map((entry) => entry.occurredAt),
      );
      final pushProviderAcceptedCount = ordered.where((entry) {
        return entry.factType ==
                ProfessionalSolicitationFactType.providerAccepted &&
            entry.channel == ProfessionalSolicitationChannel.push;
      }).length;
      final hasCompleteCreation = createdEntries.any(
        (entry) => entry.quality == OperationalFactQuality.complete,
      );

      solicitations.add(
        ProfessionalSolicitation(
          id: group.key,
          recipientUid: recipientUid,
          createdAt: createdAt,
          lastConsultedAt: consultedAt,
          pushProviderAcceptedCount: pushProviderAcceptedCount,
          quality: hasCompleteCreation
              ? OperationalFactQuality.complete
              : OperationalFactQuality.partial,
          causeEventId: metadata('causeEventId', (entry) => entry.causeEventId),
          causeType: metadata('causeType', (entry) => entry.causeType),
          category: metadata('category', (entry) => entry.category),
          missionId: metadata('missionId', (entry) => entry.missionId),
          mobilizationId: metadata(
            'mobilizationId',
            (entry) => entry.mobilizationId,
          ),
          operationId: metadata('operationId', (entry) => entry.operationId),
          organizationId: metadata(
            'organizationId',
            (entry) => entry.organizationId,
          ),
          engagementId: metadata('engagementId', (entry) => entry.engagementId),
          entries: ordered,
          limitations: limitations,
        ),
      );
    }
    solicitations.sort((left, right) {
      final leftAt = left.createdAt;
      final rightAt = right.createdAt;
      if (leftAt == null && rightAt == null) return left.id.compareTo(right.id);
      if (leftAt == null) return 1;
      if (rightAt == null) return -1;
      final byDate = rightAt.compareTo(leftAt);
      return byDate != 0 ? byDate : left.id.compareTo(right.id);
    });
    return ProfessionalSolicitationSummaryAggregation(
      solicitations: solicitations,
      issues: issues,
    );
  }
}

/// Adapte le legacy RC3 ou consomme le futur journal canonique. Cette classe
/// n'effectue aucune lecture, écriture ou mutation de ses entrées.
final class ProfessionalSolicitationJournalAggregator {
  const ProfessionalSolicitationJournalAggregator({
    this.summaryAggregator = const ProfessionalSolicitationSummaryAggregator(),
  });

  final ProfessionalSolicitationSummaryAggregator summaryAggregator;

  ProfessionalSolicitationJournal aggregate({
    required ProfessionalSolicitationJournalInput input,
    required DateTime generatedAt,
  }) {
    final issues = <ProfessionalSolicitationJournalIssue>[];
    final limitations = <String>{};
    final entries = <String, ProfessionalSolicitationJournalEntry>{};

    void addEntry(ProfessionalSolicitationJournalEntry entry) {
      if (entry.recipientUid != input.recipientUid) return;
      final existing = entries[entry.entryId];
      if (existing != null && existing != entry) {
        issues.add(
          ProfessionalSolicitationJournalIssue(
            code: 'duplicate_entry_id',
            sourceRecordId: entry.entryId,
            description: 'Deux preuves différentes partagent le même entryId.',
          ),
        );
        return;
      }
      entries[entry.entryId] = entry;
    }

    for (final entry in input.canonicalEntries) {
      addEntry(entry);
    }

    if (!input.canonicalJournalIsAuthoritative) {
      _adaptLegacy(input, addEntry, issues);
      limitations.add(
        'La reconstruction RC3 n’est pas un journal append-only exhaustif.',
      );
      limitations.add(
        'Le readAt RC3 est mutable et ne constitue qu’une preuve partielle de consultation.',
      );
      if (input.notificationsCoveredSince == null) {
        limitations.add('Début de couverture des notifications inconnu.');
      }
      if (input.notificationDeliveriesCoveredSince == null) {
        limitations.add('Début de couverture des livraisons push inconnu.');
      }
    } else if (input.canonicalJournalCoveredSince == null) {
      limitations.add('Début de couverture du journal canonique inconnu.');
    }

    final orderedEntries = entries.values.toList()
      ..sort(_descendingEntryComparison);
    final summary = summaryAggregator.aggregate(
      recipientUid: input.recipientUid,
      entries: orderedEntries,
    );
    issues.addAll(summary.issues);

    final canonicalCoverageComplete =
        input.canonicalJournalIsAuthoritative &&
        input.canonicalJournalCoveredSince != null;
    return ProfessionalSolicitationJournal(
      recipientUid: input.recipientUid,
      generatedAt: generatedAt,
      coverageQuality: canonicalCoverageComplete
          ? OperationalFactQuality.complete
          : OperationalFactQuality.partial,
      coveredSince: input.canonicalJournalIsAuthoritative
          ? input.canonicalJournalCoveredSince
          : input.notificationsCoveredSince,
      entries: orderedEntries,
      solicitations: summary.solicitations,
      issues: issues,
      limitations: limitations,
    );
  }

  void _adaptLegacy(
    ProfessionalSolicitationJournalInput input,
    void Function(ProfessionalSolicitationJournalEntry) addEntry,
    List<ProfessionalSolicitationJournalIssue> issues,
  ) {
    final events = <String, LegacySolicitationCauseEventRecord>{
      for (final event in input.notificationEvents) event.id: event,
    };
    final notifications = <String, LegacySolicitationNotificationRecord>{};
    for (final notification in input.notifications) {
      if (notification.recipientUid != input.recipientUid) continue;
      notifications[notification.id] = notification;
      final eventId = _textOrNull(notification.eventId);
      final event = eventId == null ? null : events[eventId];
      final entryLimitations = <String>{};
      if (eventId != null && event == null) {
        entryLimitations.add('Événement cause RC3 non chargé ou absent.');
      }
      _recordLegacyInconsistencies(
        notification: notification,
        event: event,
        limitations: entryLimitations,
        issues: issues,
      );
      final occurredAt = notification.occurredAt ?? notification.createdAt;
      if (occurredAt == null) {
        issues.add(
          ProfessionalSolicitationJournalIssue(
            code: 'missing_notification_timestamp',
            sourceRecordId: notification.id,
            description:
                'La notification ne possède ni occurredAt ni createdAt.',
          ),
        );
      } else {
        if (notification.occurredAt == null) {
          entryLimitations.add(
            'occurredAt absent : createdAt est utilisé comme preuve temporelle.',
          );
        }
        addEntry(
          _legacyEntry(
            entryId: 'notifications:${notification.id}:created',
            notification: notification,
            event: event,
            factType: ProfessionalSolicitationFactType.created,
            occurredAt: occurredAt,
            quality: notification.occurredAt == null
                ? OperationalFactQuality.partial
                : OperationalFactQuality.complete,
            channel: ProfessionalSolicitationChannel.inApp,
            sources: {
              ProfessionalSolicitationSource.notifications,
              if (event != null)
                ProfessionalSolicitationSource.notificationEvents,
            },
            sourceRecordIds: {notification.id, if (event != null) event.id},
            limitations: entryLimitations,
          ),
        );
      }
      final readAt = notification.readAt;
      if (readAt != null) {
        final readLimitations = <String>{
          ...entryLimitations,
          'readAt est réversible en RC3 et ne prouve pas un historique exhaustif.',
        };
        if (occurredAt != null && readAt.isBefore(occurredAt)) {
          readLimitations.add('readAt précède la création de la notification.');
          issues.add(
            ProfessionalSolicitationJournalIssue(
              code: 'consulted_before_created',
              sourceRecordId: notification.id,
              description: 'La date de lecture RC3 est incohérente.',
            ),
          );
        }
        addEntry(
          _legacyEntry(
            entryId: 'notifications:${notification.id}:consulted',
            notification: notification,
            event: event,
            factType: ProfessionalSolicitationFactType.consulted,
            occurredAt: readAt,
            quality: OperationalFactQuality.partial,
            channel: ProfessionalSolicitationChannel.inApp,
            sources: {ProfessionalSolicitationSource.notifications},
            sourceRecordIds: {notification.id},
            limitations: readLimitations,
          ),
        );
      }
    }

    for (final delivery in input.notificationDeliveries) {
      if (delivery.recipientUid != input.recipientUid ||
          !_isProviderAccepted(delivery.status) ||
          !_isPush(delivery.channel)) {
        continue;
      }
      final notification = notifications[delivery.notificationId];
      final eventId = _textOrNull(notification?.eventId);
      final event = eventId == null ? null : events[eventId];
      final occurredAt =
          delivery.providerAcceptedAt ??
          delivery.deliveredAt ??
          delivery.updatedAt;
      if (occurredAt == null) {
        issues.add(
          ProfessionalSolicitationJournalIssue(
            code: 'missing_delivery_timestamp',
            sourceRecordId: delivery.id,
            description:
                'La livraison acceptée ne possède aucun horodatage exploitable.',
          ),
        );
        continue;
      }
      final deliveryLimitations = <String>{
        'Le statut RC3 delivered prouve l’acceptation fournisseur, pas la réception terminal.',
      };
      if (delivery.providerAcceptedAt == null && delivery.deliveredAt == null) {
        deliveryLimitations.add(
          'updatedAt est utilisé faute d’horodatage d’acceptation dédié.',
        );
      }
      if (notification == null) {
        deliveryLimitations.add('Notification RC3 reliée absente.');
        issues.add(
          ProfessionalSolicitationJournalIssue(
            code: 'orphan_delivery',
            sourceRecordId: delivery.id,
            description:
                'La preuve fournisseur est conservée sans notification reliée.',
          ),
        );
      }
      addEntry(
        ProfessionalSolicitationJournalEntry(
          entryId: 'notificationDeliveries:${delivery.id}:providerAccepted',
          solicitationId: delivery.notificationId,
          recipientUid: input.recipientUid,
          factType: ProfessionalSolicitationFactType.providerAccepted,
          occurredAt: occurredAt,
          quality:
              delivery.providerAcceptedAt == null &&
                  delivery.deliveredAt == null
              ? OperationalFactQuality.partial
              : OperationalFactQuality.complete,
          channel: ProfessionalSolicitationChannel.push,
          sources: {
            ProfessionalSolicitationSource.notificationDeliveries,
            if (notification != null)
              ProfessionalSolicitationSource.notifications,
            if (event != null)
              ProfessionalSolicitationSource.notificationEvents,
          },
          sourceRecordIds: {
            delivery.id,
            if (notification != null) notification.id,
            if (event != null) event.id,
          },
          causeEventId: eventId,
          causeType: _causeType(notification?.eventType, event?.eventType),
          category: _category(notification?.category, event?.eventType),
          missionId: _firstText(notification?.missionId, event?.missionId),
          mobilizationId: _firstText(
            notification?.mobilizationId,
            event?.mobilizationId,
          ),
          engagementId: _firstText(
            notification?.engagementId,
            event?.engagementId,
          ),
          limitations: deliveryLimitations,
        ),
      );
    }
  }
}

ProfessionalSolicitationJournalEntry _legacyEntry({
  required String entryId,
  required LegacySolicitationNotificationRecord notification,
  required LegacySolicitationCauseEventRecord? event,
  required ProfessionalSolicitationFactType factType,
  required DateTime occurredAt,
  required OperationalFactQuality quality,
  required ProfessionalSolicitationChannel channel,
  required Iterable<ProfessionalSolicitationSource> sources,
  required Iterable<String> sourceRecordIds,
  required Iterable<String> limitations,
}) => ProfessionalSolicitationJournalEntry(
  entryId: entryId,
  solicitationId: notification.id,
  recipientUid: notification.recipientUid,
  factType: factType,
  occurredAt: occurredAt,
  quality: quality,
  channel: channel,
  sources: sources,
  sourceRecordIds: sourceRecordIds,
  causeEventId: _textOrNull(notification.eventId),
  causeType: _causeType(notification.eventType, event?.eventType),
  category: _category(notification.category, event?.eventType),
  missionId: _firstText(notification.missionId, event?.missionId),
  mobilizationId: _firstText(
    notification.mobilizationId,
    event?.mobilizationId,
  ),
  engagementId: _firstText(notification.engagementId, event?.engagementId),
  limitations: limitations,
);

void _recordLegacyInconsistencies({
  required LegacySolicitationNotificationRecord notification,
  required LegacySolicitationCauseEventRecord? event,
  required Set<String> limitations,
  required List<ProfessionalSolicitationJournalIssue> issues,
}) {
  if (event == null) return;
  final conflicts = <String>[
    if (_differentKnown(notification.eventType, event.eventType)) 'eventType',
    if (_differentKnown(notification.missionId, event.missionId)) 'missionId',
    if (_differentKnown(notification.mobilizationId, event.mobilizationId))
      'mobilizationId',
    if (_differentKnown(notification.engagementId, event.engagementId))
      'engagementId',
  ];
  if (conflicts.isEmpty) return;
  limitations.add('Métadonnées RC3 incohérentes : ${conflicts.join(', ')}.');
  issues.add(
    ProfessionalSolicitationJournalIssue(
      code: 'legacy_metadata_conflict',
      sourceRecordId: notification.id,
      description:
          'La notification et son événement cause divergent sur ${conflicts.join(', ')}.',
    ),
  );
}

ProfessionalSolicitationCauseType? _causeType(
  String? notificationType,
  String? eventType,
) {
  final value = _firstText(notificationType, eventType);
  return value == null ? null : ProfessionalSolicitationCauseType(value);
}

ProfessionalSolicitationCategory? _category(
  String? notificationCategory,
  String? eventType,
) {
  final value =
      _textOrNull(notificationCategory) ??
      switch (_textOrNull(eventType)) {
        'mission.published' => 'compatible',
        'mission.updated' || 'mission.cancelled' => 'engagement',
        null => null,
        _ => 'operational',
      };
  return value == null ? null : ProfessionalSolicitationCategory(value);
}

List<ProfessionalSolicitationJournalEntry> _uniqueEntries(
  Iterable<ProfessionalSolicitationJournalEntry> entries,
) => List.unmodifiable(
  {for (final entry in entries) entry.entryId: entry}.values,
);

int _ascendingEntryComparison(
  ProfessionalSolicitationJournalEntry left,
  ProfessionalSolicitationJournalEntry right,
) {
  final byDate = left.occurredAt.compareTo(right.occurredAt);
  return byDate != 0 ? byDate : left.entryId.compareTo(right.entryId);
}

int _descendingEntryComparison(
  ProfessionalSolicitationJournalEntry left,
  ProfessionalSolicitationJournalEntry right,
) {
  final byDate = right.occurredAt.compareTo(left.occurredAt);
  return byDate != 0 ? byDate : right.entryId.compareTo(left.entryId);
}

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

String? _firstText(String? preferred, String? fallback) =>
    _textOrNull(preferred) ?? _textOrNull(fallback);

String? _textOrNull(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

bool _differentKnown(String? left, String? right) {
  final normalizedLeft = _textOrNull(left);
  final normalizedRight = _textOrNull(right);
  return normalizedLeft != null &&
      normalizedRight != null &&
      normalizedLeft != normalizedRight;
}

bool _isProviderAccepted(String status) =>
    status == 'delivered' || status == 'provider_accepted';

bool _isPush(String channel) =>
    channel == 'push' || channel.startsWith('push:');
