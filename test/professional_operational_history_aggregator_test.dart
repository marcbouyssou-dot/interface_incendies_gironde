import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/professional_operational_history.dart';
import 'package:interface_incendies_gironde/services/professional_operational_history_aggregator.dart';

void main() {
  group('OperationalFact', () {
    test('keeps unavailable distinct from a known zero', () {
      final unavailable = OperationalFact<int>(
        value: null,
        quality: OperationalFactQuality.unavailable,
        sources: const {OperationalFactSource.presenceRecords},
        reasonUnavailable: 'Aucune preuve de présence.',
      );
      final zero = OperationalFact<int>(
        value: 0,
        quality: OperationalFactQuality.complete,
        sources: const {OperationalFactSource.engagements},
      );

      expect(unavailable.value, isNull);
      expect(unavailable.isAvailable, isFalse);
      expect(zero.value, 0);
      expect(zero.isAvailable, isTrue);
      expect(
        () => OperationalFact<int>(
          value: 0,
          quality: OperationalFactQuality.unavailable,
          sources: const {OperationalFactSource.presenceRecords},
          reasonUnavailable: 'Aucune preuve.',
        ),
        throwsArgumentError,
      );
    });

    test('defensively copies sources and limitations', () {
      final sources = <OperationalFactSource>{
        OperationalFactSource.engagements,
      };
      final limitations = <String>['Couverture partielle.'];
      final fact = OperationalFact<int>(
        value: 1,
        quality: OperationalFactQuality.partial,
        sources: sources,
        limitations: limitations,
      );

      sources.add(OperationalFactSource.notifications);
      limitations.add('Ajout tardif.');

      expect(fact.sources, {OperationalFactSource.engagements});
      expect(fact.limitations, ['Couverture partielle.']);
      expect(
        () => fact.sources.add(OperationalFactSource.notifications),
        throwsUnsupportedError,
      );
      expect(() => fact.limitations.add('Interdit.'), throwsUnsupportedError);
    });
  });

  group('ProfessionalOperationalHistoryAggregator - engagements', () {
    test('returns known zeroes for an empty, valid engagement source', () {
      final history = _aggregate(
        ProfessionalOperationalHistoryInput(professionalUid: _professionalUid),
      );

      expect(history.distinctEngagementCount.value, 0);
      expect(
        history.distinctEngagementCount.quality,
        OperationalFactQuality.complete,
      );
      expect(history.firstEngagementAt.value, isNull);
      expect(
        history.firstEngagementAt.quality,
        OperationalFactQuality.complete,
      );
      expect(history.currentConfirmedEngagementCount.value, 0);
      expect(history.currentStandbyEngagementCount.value, 0);
      expect(history.currentCancelledEngagementCount.value, 0);
      expect(history.linkedOperations.value, isEmpty);
      expect(history.linkedMobilizationTypes.value, isEmpty);
    });

    test('counts distinct current statuses and finds the first engagement', () {
      final firstAt = DateTime.utc(2025, 1, 2);
      final history = _aggregate(
        ProfessionalOperationalHistoryInput(
          professionalUid: _professionalUid,
          engagements: [
            _engagement(
              id: 'eng-confirmed',
              missionId: 'mission-1',
              status: OperationalHistoryEngagementStatus.confirmed,
              createdAt: DateTime.utc(2025, 2, 1),
            ),
            _engagement(
              id: 'eng-standby',
              missionId: 'mission-2',
              status: OperationalHistoryEngagementStatus.standby,
              createdAt: firstAt,
            ),
            _engagement(
              id: 'eng-cancelled',
              missionId: 'mission-3',
              status: OperationalHistoryEngagementStatus.cancelled,
              createdAt: DateTime.utc(2025, 3, 1),
            ),
            _engagement(
              id: 'eng-confirmed',
              missionId: 'duplicate-is-ignored',
              status: OperationalHistoryEngagementStatus.confirmed,
              createdAt: DateTime.utc(2025, 2, 1),
            ),
            _engagement(
              id: 'other-professional',
              missionId: 'mission-4',
              status: OperationalHistoryEngagementStatus.confirmed,
              professionalUid: 'pro-2',
              createdAt: DateTime.utc(2024),
            ),
          ],
        ),
      );

      expect(history.distinctEngagementCount.value, 3);
      expect(history.currentConfirmedEngagementCount.value, 1);
      expect(history.currentStandbyEngagementCount.value, 1);
      expect(history.currentCancelledEngagementCount.value, 1);
      expect(history.firstEngagementAt.value, firstAt);
    });

    test('does not claim a complete first date when createdAt is missing', () {
      final history = _aggregate(
        ProfessionalOperationalHistoryInput(
          professionalUid: _professionalUid,
          engagements: [
            _engagement(
              id: 'eng-1',
              missionId: 'mission-1',
              status: OperationalHistoryEngagementStatus.confirmed,
            ),
          ],
        ),
      );

      expect(history.firstEngagementAt.value, isNull);
      expect(history.firstEngagementAt.quality, OperationalFactQuality.partial);
      expect(history.firstEngagementAt.limitations, isNotEmpty);
    });

    test(
      'derives complete reengagement and cancellation facts with coverage',
      () {
        final coveredSince = DateTime.utc(2025);
        final first = DateTime.utc(2025, 2, 1);
        final cancelled = DateTime.utc(2025, 3, 1);
        final history = _aggregate(
          ProfessionalOperationalHistoryInput(
            professionalUid: _professionalUid,
            engagements: [
              _engagement(
                id: 'eng-1',
                missionId: 'mission-1',
                status: OperationalHistoryEngagementStatus.confirmed,
                createdAt: first,
              ),
            ],
            notificationEvents: [
              _event(
                id: 'event-created',
                engagementId: 'eng-1',
                kind: OperationalHistoryEventKind.engagementCreated,
                occurredAt: first,
              ),
              _event(
                id: 'event-cancelled',
                engagementId: 'eng-1',
                kind: OperationalHistoryEventKind.engagementCancelled,
                occurredAt: cancelled,
              ),
              _event(
                id: 'event-reengaged',
                engagementId: 'eng-1',
                kind: OperationalHistoryEventKind.engagementCreated,
                occurredAt: DateTime.utc(2025, 3, 2),
              ),
            ],
            engagementEventsCoveredSince: coveredSince,
          ),
        );

        expect(history.reengagementCount.value, 1);
        expect(history.cancellationCount.value, 1);
        expect(history.lastCancellationAt.value, cancelled);
        expect(history.reengagementCount.coveredSince, coveredSince);
        expect(
          history.reengagementCount.quality,
          OperationalFactQuality.complete,
        );
        expect(
          history.cancellationCount.quality,
          OperationalFactQuality.complete,
        );
      },
    );

    test('keeps event-derived counts partial when coverage is unknown', () {
      final history = _aggregate(
        ProfessionalOperationalHistoryInput(
          professionalUid: _professionalUid,
          engagements: [
            _engagement(
              id: 'eng-1',
              missionId: 'mission-1',
              status: OperationalHistoryEngagementStatus.cancelled,
              createdAt: DateTime.utc(2024),
            ),
          ],
          notificationEvents: [
            _event(
              id: 'event-cancelled',
              engagementId: 'eng-1',
              kind: OperationalHistoryEventKind.engagementCancelled,
              occurredAt: DateTime.utc(2025),
            ),
          ],
        ),
      );

      expect(history.cancellationCount.value, 1);
      expect(history.cancellationCount.quality, OperationalFactQuality.partial);
      expect(history.cancellationCount.coveredSince, isNull);
      expect(history.reengagementCount.value, 0);
      expect(history.reengagementCount.quality, OperationalFactQuality.partial);
    });
  });

  group('ProfessionalOperationalHistoryAggregator - sollicitations', () {
    test('keeps notification facts partial and carries known coverage', () {
      final notificationsCoveredSince = DateTime.utc(2025, 4, 1);
      final deliveriesCoveredSince = DateTime.utc(2025, 5, 1);
      final firstCreated = DateTime.utc(2025, 6, 1);
      final lastCreated = DateTime.utc(2025, 7, 1);
      final consultedAt = DateTime.utc(2025, 7, 2);
      final history = _aggregate(
        ProfessionalOperationalHistoryInput(
          professionalUid: _professionalUid,
          compatibleNotifications: [
            OperationalHistorySolicitationRecord(
              id: 'notification-1',
              recipientUid: _professionalUid,
              occurredAt: firstCreated,
            ),
            OperationalHistorySolicitationRecord(
              id: 'notification-2',
              recipientUid: _professionalUid,
              occurredAt: lastCreated,
              readAt: consultedAt,
            ),
          ],
          notificationDeliveries: [
            OperationalHistoryNotificationDeliveryRecord(
              id: 'delivery-accepted',
              notificationId: 'notification-1',
              recipientUid: _professionalUid,
              channel: 'push:fcm',
              status: OperationalHistoryDeliveryStatus.providerAccepted,
              providerAcceptedAt: DateTime.utc(2025, 6, 1, 0, 1),
            ),
            const OperationalHistoryNotificationDeliveryRecord(
              id: 'delivery-failed',
              notificationId: 'notification-2',
              recipientUid: _professionalUid,
              channel: 'push',
              status: OperationalHistoryDeliveryStatus.failed,
            ),
            const OperationalHistoryNotificationDeliveryRecord(
              id: 'delivery-email',
              notificationId: 'notification-2',
              recipientUid: _professionalUid,
              channel: 'email',
              status: OperationalHistoryDeliveryStatus.providerAccepted,
            ),
          ],
          notificationsCoveredSince: notificationsCoveredSince,
          notificationDeliveriesCoveredSince: deliveriesCoveredSince,
        ),
      );

      expect(history.createdSolicitationCount.value, 2);
      expect(history.lastCreatedSolicitationAt.value, lastCreated);
      expect(history.consultedSolicitationCount.value, 1);
      expect(history.lastConsultedSolicitationAt.value, consultedAt);
      expect(history.pushProviderAcceptedCount.value, 1);
      expect(
        history.createdSolicitationCount.quality,
        OperationalFactQuality.partial,
      );
      expect(
        history.pushProviderAcceptedCount.quality,
        OperationalFactQuality.partial,
      );
      expect(
        history.createdSolicitationCount.coveredSince,
        notificationsCoveredSince,
      );
      expect(
        history.pushProviderAcceptedCount.coveredSince,
        deliveriesCoveredSince,
      );
    });

    test('reports an orphan accepted push delivery without counting it', () {
      final history = _aggregate(
        ProfessionalOperationalHistoryInput(
          professionalUid: _professionalUid,
          notificationDeliveries: const [
            OperationalHistoryNotificationDeliveryRecord(
              id: 'orphan',
              notificationId: 'missing-notification',
              recipientUid: _professionalUid,
              channel: 'push',
              status: OperationalHistoryDeliveryStatus.providerAccepted,
            ),
          ],
        ),
      );

      expect(history.pushProviderAcceptedCount.value, 0);
      expect(
        history.pushProviderAcceptedCount.limitations,
        contains(
          'Une livraison ne peut pas être reliée à une sollicitation compatible.',
        ),
      );
    });
  });

  group('ProfessionalOperationalHistoryAggregator - rattachements legacy', () {
    test('derives complete linked operations and mobilization types', () {
      final history = _aggregate(
        ProfessionalOperationalHistoryInput(
          professionalUid: _professionalUid,
          engagements: [
            _engagement(
              id: 'eng-1',
              missionId: 'mission-1',
              status: OperationalHistoryEngagementStatus.confirmed,
              mobilizationId: 'mobilization-1',
              createdAt: DateTime.utc(2025),
            ),
          ],
          missions: const [
            OperationalHistoryMissionRecord(
              id: 'mission-1',
              mobilizationId: 'mobilization-1',
            ),
          ],
          mobilizations: const [
            OperationalHistoryMobilizationRecord(
              id: 'mobilization-1',
              operationId: 'operation-1',
              contextType: 'fire',
            ),
          ],
          operations: const [
            OperationalHistoryOperationRecord(
              id: 'operation-1',
              label: 'Feux de Gironde',
              type: 'wildfire',
            ),
          ],
        ),
      );

      expect(history.linkedOperations.value, {
        const OperationalHistoryOperationRef(
          id: 'operation-1',
          label: 'Feux de Gironde',
          type: 'wildfire',
        ),
      });
      expect(history.linkedMobilizationTypes.value, {'fire'});
      expect(history.linkedOperations.quality, OperationalFactQuality.complete);
      expect(
        history.linkedMobilizationTypes.quality,
        OperationalFactQuality.complete,
      );
      expect(
        history.linkedOperations.sources,
        contains(OperationalFactSource.operations),
      );
      expect(
        history.linkedMobilizationTypes.sources,
        isNot(contains(OperationalFactSource.operations)),
      );
    });

    test('retains known links when legacy and incomplete joins coexist', () {
      final history = _aggregate(
        ProfessionalOperationalHistoryInput(
          professionalUid: _professionalUid,
          engagements: [
            _engagement(
              id: 'eng-complete',
              missionId: 'mission-complete',
              status: OperationalHistoryEngagementStatus.confirmed,
              mobilizationId: 'mobilization-complete',
              createdAt: DateTime.utc(2025),
            ),
            _engagement(
              id: 'eng-no-operation',
              missionId: 'mission-no-operation',
              status: OperationalHistoryEngagementStatus.standby,
              mobilizationId: 'mobilization-no-operation',
              createdAt: DateTime.utc(2025, 2),
            ),
            _engagement(
              id: 'eng-no-context',
              missionId: 'mission-no-context',
              status: OperationalHistoryEngagementStatus.cancelled,
              mobilizationId: 'mobilization-no-context',
              createdAt: DateTime.utc(2025, 3),
            ),
            _engagement(
              id: 'eng-missing-join',
              missionId: 'missing-mission',
              status: OperationalHistoryEngagementStatus.confirmed,
              createdAt: DateTime.utc(2025, 4),
            ),
          ],
          missions: const [
            OperationalHistoryMissionRecord(
              id: 'mission-complete',
              mobilizationId: 'mobilization-complete',
            ),
            OperationalHistoryMissionRecord(
              id: 'mission-no-operation',
              mobilizationId: 'mobilization-no-operation',
            ),
            OperationalHistoryMissionRecord(
              id: 'mission-no-context',
              mobilizationId: 'mobilization-no-context',
            ),
          ],
          mobilizations: const [
            OperationalHistoryMobilizationRecord(
              id: 'mobilization-complete',
              operationId: 'operation-known',
              contextType: 'fire',
            ),
            OperationalHistoryMobilizationRecord(
              id: 'mobilization-no-operation',
              contextType: 'heatwave',
            ),
            OperationalHistoryMobilizationRecord(
              id: 'mobilization-no-context',
              operationId: 'operation-unloaded',
            ),
          ],
          operations: const [
            OperationalHistoryOperationRecord(
              id: 'operation-known',
              label: 'Opération connue',
            ),
          ],
        ),
      );

      expect(
        history.linkedOperations.value,
        contains(
          const OperationalHistoryOperationRef(
            id: 'operation-known',
            label: 'Opération connue',
          ),
        ),
      );
      expect(
        history.linkedOperations.value,
        contains(
          const OperationalHistoryOperationRef(id: 'operation-unloaded'),
        ),
      );
      expect(history.linkedMobilizationTypes.value, {'fire', 'heatwave'});
      expect(history.linkedOperations.quality, OperationalFactQuality.partial);
      expect(
        history.linkedMobilizationTypes.quality,
        OperationalFactQuality.partial,
      );
      expect(
        history.linkedOperations.limitations,
        contains(
          'Au moins une mobilisation legacy ne possède pas de operationId.',
        ),
      );
      expect(
        history.linkedMobilizationTypes.limitations,
        contains(
          'Au moins une mobilisation legacy ne possède pas de contextType.',
        ),
      );
    });

    test('degrades only the link affected by one legacy missing field', () {
      final baseEngagement = _engagement(
        id: 'eng-1',
        missionId: 'mission-1',
        status: OperationalHistoryEngagementStatus.confirmed,
        mobilizationId: 'mobilization-1',
        createdAt: DateTime.utc(2025),
      );
      final withoutOperation = _aggregate(
        ProfessionalOperationalHistoryInput(
          professionalUid: _professionalUid,
          engagements: [baseEngagement],
          missions: const [
            OperationalHistoryMissionRecord(
              id: 'mission-1',
              mobilizationId: 'mobilization-1',
            ),
          ],
          mobilizations: const [
            OperationalHistoryMobilizationRecord(
              id: 'mobilization-1',
              contextType: 'fire',
            ),
          ],
        ),
      );
      final withoutContext = _aggregate(
        ProfessionalOperationalHistoryInput(
          professionalUid: _professionalUid,
          engagements: [baseEngagement],
          missions: const [
            OperationalHistoryMissionRecord(
              id: 'mission-1',
              mobilizationId: 'mobilization-1',
            ),
          ],
          mobilizations: const [
            OperationalHistoryMobilizationRecord(
              id: 'mobilization-1',
              operationId: 'operation-1',
            ),
          ],
          operations: const [
            OperationalHistoryOperationRecord(id: 'operation-1'),
          ],
        ),
      );

      expect(
        withoutOperation.linkedOperations.quality,
        OperationalFactQuality.partial,
      );
      expect(
        withoutOperation.linkedMobilizationTypes.quality,
        OperationalFactQuality.complete,
      );
      expect(
        withoutContext.linkedOperations.quality,
        OperationalFactQuality.complete,
      );
      expect(
        withoutContext.linkedMobilizationTypes.quality,
        OperationalFactQuality.partial,
      );
    });
  });

  test('never invents participation, mission completion or presence facts', () {
    final history = _aggregate(
      ProfessionalOperationalHistoryInput(
        professionalUid: _professionalUid,
        engagements: [
          _engagement(
            id: 'eng-confirmed',
            missionId: 'mission-1',
            status: OperationalHistoryEngagementStatus.confirmed,
            createdAt: DateTime.utc(2025),
          ),
        ],
      ),
    );
    final unavailableFacts = <OperationalFact<Object>>[
      history.effectiveParticipationCount,
      history.completedMissionCount,
      history.lastParticipationAt,
      history.lastPresenceAt,
      history.experiencedOperations,
      history.experiencedMobilizationTypes,
      history.partialPresenceCount,
      history.validatedAbsenceCount,
      history.totalValidatedPresenceDuration,
    ];

    for (final fact in unavailableFacts) {
      expect(fact.quality, OperationalFactQuality.unavailable);
      expect(fact.value, isNull);
      expect(fact.reasonUnavailable, isNotEmpty);
    }
  });
}

const _professionalUid = 'pro-1';

ProfessionalOperationalHistory _aggregate(
  ProfessionalOperationalHistoryInput input,
) => const ProfessionalOperationalHistoryAggregator().aggregate(
  input: input,
  derivedAt: DateTime.utc(2026, 8, 22),
);

OperationalHistoryEngagementRecord _engagement({
  required String id,
  required String missionId,
  required OperationalHistoryEngagementStatus status,
  String professionalUid = _professionalUid,
  String? mobilizationId,
  DateTime? createdAt,
}) => OperationalHistoryEngagementRecord(
  id: id,
  professionalUid: professionalUid,
  missionId: missionId,
  mobilizationId: mobilizationId,
  status: status,
  createdAt: createdAt,
);

OperationalHistoryEngagementEventRecord _event({
  required String id,
  required String engagementId,
  required OperationalHistoryEventKind kind,
  required DateTime occurredAt,
}) => OperationalHistoryEngagementEventRecord(
  id: id,
  engagementId: engagementId,
  professionalUid: _professionalUid,
  kind: kind,
  occurredAt: occurredAt,
);
