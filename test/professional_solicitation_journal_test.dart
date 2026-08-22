import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/professional_operational_history.dart';
import 'package:interface_incendies_gironde/models/professional_solicitation_journal.dart';
import 'package:interface_incendies_gironde/services/professional_solicitation_journal_aggregator.dart';

void main() {
  group('ProfessionalSolicitationJournalEntry', () {
    test('round-trips an immutable, additive canonical entry', () {
      final entry = ProfessionalSolicitationJournalEntry(
        entryId: 'entry-1',
        solicitationId: 'solicitation-1',
        recipientUid: _recipientUid,
        factType: ProfessionalSolicitationFactType('future_fact'),
        occurredAt: DateTime.utc(2026, 8, 1),
        quality: OperationalFactQuality.complete,
        sources: {
          ProfessionalSolicitationSource.canonicalJournal,
          ProfessionalSolicitationSource('future_source'),
        },
        sourceRecordIds: const {'source-1', 'source-2'},
        channel: ProfessionalSolicitationChannel('future_channel'),
        causeEventId: 'event-1',
        causeType: ProfessionalSolicitationCauseType('mission.future'),
        category: ProfessionalSolicitationCategory('future_category'),
        missionId: 'mission-1',
        mobilizationId: 'mobilization-1',
        operationId: 'operation-1',
        organizationId: 'organization-1',
        engagementId: 'engagement-1',
        source: 'notification_dispatch',
        limitations: const ['Limitation documentée.'],
        schemaVersion: 2,
      );
      final map = entry.toMap()..['futureField'] = true;

      final restored = ProfessionalSolicitationJournalEntry.fromMap(map);

      expect(restored, entry);
      expect(restored.hashCode, entry.hashCode);
      expect(restored.factType.serializedValue, 'future_fact');
      expect(restored.channel?.serializedValue, 'future_channel');
      expect(restored.toMap(), isNot(contains('futureField')));
      expect(
        () => restored.sources.add(
          ProfessionalSolicitationSource.notificationEvents,
        ),
        throwsUnsupportedError,
      );
      expect(
        () => restored.sourceRecordIds.add('source-3'),
        throwsUnsupportedError,
      );
      expect(
        () => restored.limitations.add('Modification interdite.'),
        throwsUnsupportedError,
      );
    });

    test('rejects unavailable journal entries and missing evidence', () {
      expect(
        () => ProfessionalSolicitationJournalEntry(
          entryId: 'entry-1',
          solicitationId: 'solicitation-1',
          recipientUid: _recipientUid,
          factType: ProfessionalSolicitationFactType.created,
          occurredAt: DateTime.utc(2026),
          quality: OperationalFactQuality.unavailable,
          sources: {ProfessionalSolicitationSource.canonicalJournal},
          sourceRecordIds: const {'source-1'},
        ),
        throwsFormatException,
      );
      expect(
        () => ProfessionalSolicitationJournalEntry(
          entryId: 'entry-1',
          solicitationId: 'solicitation-1',
          recipientUid: _recipientUid,
          factType: ProfessionalSolicitationFactType.created,
          occurredAt: DateTime.utc(2026),
          quality: OperationalFactQuality.complete,
          sources: const {},
          sourceRecordIds: const {},
        ),
        throwsFormatException,
      );
    });
  });

  group('Future server read contract', () {
    test('defines bounded, recipient-scoped stable pagination', () {
      final cursor = ProfessionalSolicitationJournalCursor(
        occurredAt: DateTime.utc(2026, 8, 1),
        entryId: 'entry-42',
      );
      final query = ProfessionalSolicitationJournalQuery(
        recipientUid: _recipientUid,
        limit: 100,
        after: cursor,
      );
      final page = ProfessionalSolicitationJournalPage(
        entries: [_canonicalCreated()],
        nextCursor: cursor,
        coverageQuality: OperationalFactQuality.complete,
        coveredSince: DateTime.utc(2026),
      );

      expect(query.recipientUid, _recipientUid);
      expect(query.limit, 100);
      expect(query.after, same(cursor));
      expect(page.entries, hasLength(1));
      expect(() => page.entries.clear(), throwsUnsupportedError);
    });

    test('rejects unbounded or invalid queries', () {
      expect(
        () => ProfessionalSolicitationJournalQuery(
          recipientUid: _recipientUid,
          limit: 101,
        ),
        throwsFormatException,
      );
      expect(
        () => ProfessionalSolicitationJournalQuery(recipientUid: '  '),
        throwsFormatException,
      );
    });
  });

  group('ProfessionalSolicitationJournalAggregator - RC3', () {
    test('keeps an empty legacy result partial rather than claiming zero', () {
      final journal = _aggregate(
        ProfessionalSolicitationJournalInput(recipientUid: _recipientUid),
      );

      expect(journal.entries, isEmpty);
      expect(journal.solicitations, isEmpty);
      expect(journal.coverageQuality, OperationalFactQuality.partial);
      expect(journal.coveredSince, isNull);
      expect(journal.limitations, isNotEmpty);
    });

    test(
      'does not turn a recipient-less notificationEvent into a solicitation',
      () {
        final journal = _aggregate(
          ProfessionalSolicitationJournalInput(
            recipientUid: _recipientUid,
            notificationEvents: [
              _event(
                id: 'event-1',
                eventType: 'mission.published',
                occurredAt: DateTime.utc(2026, 1, 1),
              ),
            ],
          ),
        );

        expect(journal.entries, isEmpty);
        expect(journal.solicitations, isEmpty);
      },
    );

    test('uses notification as proof of a created recipient solicitation', () {
      final occurredAt = DateTime.utc(2026, 2, 1);
      final coveredSince = DateTime.utc(2026, 1, 1);
      final journal = _aggregate(
        ProfessionalSolicitationJournalInput(
          recipientUid: _recipientUid,
          notifications: [
            _notification(
              id: 'notification-1',
              eventId: 'event-1',
              occurredAt: occurredAt,
            ),
          ],
          notificationEvents: [
            _event(
              id: 'event-1',
              eventType: 'mission.published',
              occurredAt: occurredAt,
              missionId: 'mission-1',
              mobilizationId: 'mobilization-1',
            ),
          ],
          notificationsCoveredSince: coveredSince,
        ),
      );

      expect(journal.coveredSince, coveredSince);
      expect(journal.coverageQuality, OperationalFactQuality.partial);
      expect(journal.solicitations, hasLength(1));
      final solicitation = journal.solicitations.single;
      expect(solicitation.id, 'notification-1');
      expect(solicitation.createdAt, occurredAt);
      expect(solicitation.isCreationProven, isTrue);
      expect(solicitation.quality, OperationalFactQuality.complete);
      expect(solicitation.causeEventId, 'event-1');
      expect(solicitation.causeType?.serializedValue, 'mission.published');
      expect(solicitation.category?.serializedValue, 'compatible');
      expect(solicitation.missionId, 'mission-1');
      expect(solicitation.mobilizationId, 'mobilization-1');
      expect(
        journal.entries.single.sources,
        contains(ProfessionalSolicitationSource.notificationEvents),
      );
    });

    test('keeps legacy readAt as a partial consulted fact', () {
      final createdAt = DateTime.utc(2026, 2, 1);
      final readAt = DateTime.utc(2026, 2, 2);
      final journal = _aggregate(
        ProfessionalSolicitationJournalInput(
          recipientUid: _recipientUid,
          notifications: [
            _notification(
              id: 'notification-1',
              occurredAt: createdAt,
              readAt: readAt,
            ),
          ],
        ),
      );

      final consulted = journal.entries.singleWhere(
        (entry) => entry.factType == ProfessionalSolicitationFactType.consulted,
      );
      expect(consulted.occurredAt, readAt);
      expect(consulted.quality, OperationalFactQuality.partial);
      expect(consulted.limitations, isNotEmpty);
      expect(journal.solicitations.single.lastConsultedAt, readAt);
    });

    test('maps RC3 delivered only to provider accepted for push', () {
      final acceptedAt = DateTime.utc(2026, 3, 1);
      final journal = _aggregate(
        ProfessionalSolicitationJournalInput(
          recipientUid: _recipientUid,
          notifications: [
            _notification(
              id: 'notification-1',
              occurredAt: DateTime.utc(2026, 2, 1),
            ),
          ],
          notificationDeliveries: [
            LegacySolicitationDeliveryRecord(
              id: 'delivery-1',
              notificationId: 'notification-1',
              recipientUid: _recipientUid,
              channel: 'push:installation-1',
              status: 'delivered',
              deliveredAt: acceptedAt,
            ),
            const LegacySolicitationDeliveryRecord(
              id: 'delivery-email',
              notificationId: 'notification-1',
              recipientUid: _recipientUid,
              channel: 'email',
              status: 'delivered',
            ),
            const LegacySolicitationDeliveryRecord(
              id: 'delivery-failed',
              notificationId: 'notification-1',
              recipientUid: _recipientUid,
              channel: 'push',
              status: 'failed',
            ),
          ],
        ),
      );

      final accepted = journal.entries.singleWhere(
        (entry) =>
            entry.factType == ProfessionalSolicitationFactType.providerAccepted,
      );
      expect(accepted.occurredAt, acceptedAt);
      expect(accepted.channel, ProfessionalSolicitationChannel.push);
      expect(
        accepted.limitations.single,
        contains('pas la réception terminal'),
      );
      expect(journal.solicitations.single.pushProviderAcceptedCount, 1);
      expect(
        journal.entries.any(
          (entry) => entry.factType.serializedValue == 'delivered',
        ),
        isFalse,
      );
    });

    test('retains an orphan provider proof without inventing createdAt', () {
      final journal = _aggregate(
        ProfessionalSolicitationJournalInput(
          recipientUid: _recipientUid,
          notificationDeliveries: [
            LegacySolicitationDeliveryRecord(
              id: 'delivery-orphan',
              notificationId: 'notification-missing',
              recipientUid: _recipientUid,
              channel: 'push',
              status: 'provider_accepted',
              providerAcceptedAt: DateTime.utc(2026, 4, 1),
            ),
          ],
        ),
      );

      expect(journal.entries, hasLength(1));
      expect(journal.solicitations, hasLength(1));
      expect(journal.solicitations.single.createdAt, isNull);
      expect(journal.solicitations.single.isCreationProven, isFalse);
      expect(
        journal.solicitations.single.quality,
        OperationalFactQuality.partial,
      );
      expect(
        journal.issues.map((issue) => issue.code),
        containsAll(['orphan_delivery', 'missing_created_fact']),
      );
    });

    test('uses createdAt fallback explicitly when occurredAt is absent', () {
      final createdAt = DateTime.utc(2026, 5, 1);
      final journal = _aggregate(
        ProfessionalSolicitationJournalInput(
          recipientUid: _recipientUid,
          notifications: [
            _notification(id: 'notification-1', createdAt: createdAt),
          ],
        ),
      );

      expect(journal.solicitations.single.createdAt, createdAt);
      expect(
        journal.solicitations.single.quality,
        OperationalFactQuality.partial,
      );
      expect(journal.entries.single.limitations, isNotEmpty);
    });

    test('keeps notification data and reports a conflicting event join', () {
      final journal = _aggregate(
        ProfessionalSolicitationJournalInput(
          recipientUid: _recipientUid,
          notifications: [
            _notification(
              id: 'notification-1',
              eventId: 'event-1',
              eventType: 'mission.updated',
              missionId: 'mission-from-notification',
              occurredAt: DateTime.utc(2026, 6, 1),
            ),
          ],
          notificationEvents: [
            _event(
              id: 'event-1',
              eventType: 'mission.cancelled',
              occurredAt: DateTime.utc(2026, 6, 1),
              missionId: 'mission-from-event',
            ),
          ],
        ),
      );

      expect(
        journal.solicitations.single.missionId,
        'mission-from-notification',
      );
      expect(
        journal.issues.map((issue) => issue.code),
        contains('legacy_metadata_conflict'),
      );
      expect(journal.entries.single.limitations, isNotEmpty);
    });

    test('filters another recipient and defensively copies source lists', () {
      final notifications = <LegacySolicitationNotificationRecord>[
        _notification(
          id: 'notification-1',
          occurredAt: DateTime.utc(2026, 7, 1),
        ),
        _notification(
          id: 'notification-other',
          recipientUid: 'professional-2',
          occurredAt: DateTime.utc(2026, 7, 1),
        ),
      ];
      final input = ProfessionalSolicitationJournalInput(
        recipientUid: _recipientUid,
        notifications: notifications,
      );
      notifications.clear();

      final journal = _aggregate(input);

      expect(input.notifications, hasLength(2));
      expect(() => input.notifications.clear(), throwsUnsupportedError);
      expect(journal.solicitations, hasLength(1));
      expect(journal.solicitations.single.id, 'notification-1');
    });
  });

  group('ProfessionalSolicitationJournalAggregator - canonical source', () {
    test(
      'uses only authoritative canonical entries with complete coverage',
      () {
        final coveredSince = DateTime.utc(2026, 1, 1);
        final canonical = _canonicalCreated();
        final journal = _aggregate(
          ProfessionalSolicitationJournalInput(
            recipientUid: _recipientUid,
            canonicalEntries: [canonical],
            notifications: [
              _notification(
                id: 'legacy-notification',
                occurredAt: DateTime.utc(2025),
              ),
            ],
            canonicalJournalIsAuthoritative: true,
            canonicalJournalCoveredSince: coveredSince,
          ),
        );

        expect(journal.coverageQuality, OperationalFactQuality.complete);
        expect(journal.coveredSince, coveredSince);
        expect(journal.entries, [canonical]);
        expect(journal.solicitations.single.id, canonical.solicitationId);
        expect(
          journal.entries.any(
            (entry) => entry.solicitationId == 'legacy-notification',
          ),
          isFalse,
        );
      },
    );

    test('keeps canonical coverage partial when coveredSince is unknown', () {
      final journal = _aggregate(
        ProfessionalSolicitationJournalInput(
          recipientUid: _recipientUid,
          canonicalEntries: [_canonicalCreated()],
          canonicalJournalIsAuthoritative: true,
        ),
      );

      expect(journal.coverageQuality, OperationalFactQuality.partial);
      expect(journal.coveredSince, isNull);
      expect(journal.limitations, isNotEmpty);
    });
  });
}

const _recipientUid = 'professional-1';

ProfessionalSolicitationJournal _aggregate(
  ProfessionalSolicitationJournalInput input,
) => const ProfessionalSolicitationJournalAggregator().aggregate(
  input: input,
  generatedAt: DateTime.utc(2026, 8, 22),
);

ProfessionalSolicitationJournalEntry _canonicalCreated() =>
    ProfessionalSolicitationJournalEntry(
      entryId: 'canonical-entry-1',
      solicitationId: 'canonical-solicitation-1',
      recipientUid: _recipientUid,
      factType: ProfessionalSolicitationFactType.created,
      occurredAt: DateTime.utc(2026, 8, 1),
      quality: OperationalFactQuality.complete,
      sources: {ProfessionalSolicitationSource.canonicalJournal},
      sourceRecordIds: const {'canonical-entry-1'},
      channel: ProfessionalSolicitationChannel.inApp,
      causeEventId: 'event-canonical',
      causeType: ProfessionalSolicitationCauseType('mission.published'),
      category: ProfessionalSolicitationCategory('compatible'),
      missionId: 'mission-canonical',
      mobilizationId: 'mobilization-canonical',
      operationId: 'operation-canonical',
      organizationId: 'organization-canonical',
      source: 'notification_dispatch',
    );

LegacySolicitationNotificationRecord _notification({
  required String id,
  String recipientUid = _recipientUid,
  String? eventId,
  String? eventType,
  String? category,
  DateTime? occurredAt,
  DateTime? createdAt,
  DateTime? readAt,
  String? missionId,
  String? mobilizationId,
  String? engagementId,
}) => LegacySolicitationNotificationRecord(
  id: id,
  recipientUid: recipientUid,
  eventId: eventId,
  eventType: eventType,
  category: category,
  occurredAt: occurredAt,
  createdAt: createdAt,
  readAt: readAt,
  missionId: missionId,
  mobilizationId: mobilizationId,
  engagementId: engagementId,
);

LegacySolicitationCauseEventRecord _event({
  required String id,
  required String eventType,
  required DateTime occurredAt,
  String? missionId,
  String? mobilizationId,
  String? engagementId,
}) => LegacySolicitationCauseEventRecord(
  id: id,
  eventType: eventType,
  occurredAt: occurredAt,
  missionId: missionId,
  mobilizationId: mobilizationId,
  engagementId: engagementId,
);
