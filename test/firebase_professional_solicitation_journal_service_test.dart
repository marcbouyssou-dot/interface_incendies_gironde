import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/professional_operational_history.dart';
import 'package:interface_incendies_gironde/models/professional_solicitation_journal.dart';
import 'package:interface_incendies_gironde/services/firebase_professional_solicitation_journal_service.dart';
import 'package:interface_incendies_gironde/services/professional_solicitation_journal_service.dart';

const _recipientUid = 'professional-1';
const _occurredAtMillis = 1785585600000;
const _recordedAtMillis = 1785585600500;

Map<String, Object?> entryResponse() => {
  'entryId': 'entry-1',
  'solicitationId': 'solicitation-1',
  'recipientUid': _recipientUid,
  'factType': 'created',
  'missionId': 'mission-1',
  'mobilizationId': 'mobilization-1',
  'operationId': 'operation-1',
  'organizationId': 'organization-1',
  'channel': 'in_app',
  'source': 'notification_dispatch',
  'sources': ['canonical_journal'],
  'sourceRecordIds': ['notification-1'],
  'quality': 'complete',
  'causeEventId': 'event-1',
  'causeType': 'mission.published',
  'category': 'compatible',
  'engagementId': 'engagement-1',
  'schemaVersion': 1,
  'occurredAtMillis': _occurredAtMillis,
  'recordedAtMillis': _recordedAtMillis,
};

void main() {
  test('recordConsulted envoie le payload exact et parse la réponse', () async {
    String? calledFunction;
    Map<String, Object?>? sentData;
    final service = FirebaseProfessionalSolicitationJournalService(
      callable: (functionName, data) async {
        calledFunction = functionName;
        sentData = data;
        return {'created': true, 'entryId': 'entry-consulted'};
      },
    );

    final result = await service.recordConsulted(
      recipientUid: _recipientUid,
      solicitationId: 'solicitation-1',
    );

    expect(
      FirebaseProfessionalSolicitationJournalService.region,
      'europe-west1',
    );
    expect(calledFunction, 'recordProfessionalSolicitationConsulted');
    expect(sentData, {
      'recipientUid': _recipientUid,
      'solicitationId': 'solicitation-1',
    });
    expect(result, (created: true, entryId: 'entry-consulted'));
  });

  test('listEntries sans curseur parse la page et occurredAtMillis', () async {
    String? calledFunction;
    Map<String, Object?>? sentData;
    final service = FirebaseProfessionalSolicitationJournalService(
      callable: (functionName, data) async {
        calledFunction = functionName;
        sentData = data;
        return {
          'entries': [entryResponse()],
          'nextCursor': null,
        };
      },
    );
    final query = ProfessionalSolicitationJournalQuery(
      recipientUid: _recipientUid,
      limit: 25,
    );

    final page = await service.listEntries(query);

    expect(calledFunction, 'listProfessionalSolicitationJournal');
    expect(sentData, {'recipientUid': _recipientUid, 'limit': 25});
    expect(sentData, isNot(contains('cursor')));
    expect(page.entries, hasLength(1));
    expect(page.nextCursor, isNull);
    expect(page.coverageQuality, OperationalFactQuality.partial);
    expect(page.coveredSince, isNull);
    expect(
      page.entries.single,
      ProfessionalSolicitationJournalEntry.fromMap({
        ...entryResponse()
          ..remove('occurredAtMillis')
          ..remove('recordedAtMillis'),
        'occurredAt': DateTime.fromMillisecondsSinceEpoch(
          _occurredAtMillis,
          isUtc: true,
        ),
      }),
    );
  });

  test('listEntries sérialise et parse un curseur stable', () async {
    Map<String, Object?>? sentData;
    final service = FirebaseProfessionalSolicitationJournalService(
      callable: (_, data) async {
        sentData = data;
        return {
          'entries': <Object?>[],
          'nextCursor': {
            'occurredAtMillis': _occurredAtMillis,
            'entryId': 'entry-next',
          },
        };
      },
    );
    final after = ProfessionalSolicitationJournalCursor(
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        _recordedAtMillis,
        isUtc: true,
      ),
      entryId: 'entry-after',
    );

    final page = await service.listEntries(
      ProfessionalSolicitationJournalQuery(
        recipientUid: _recipientUid,
        after: after,
      ),
    );

    expect(sentData, {
      'recipientUid': _recipientUid,
      'limit': 50,
      'cursor': {
        'occurredAtMillis': _recordedAtMillis,
        'entryId': 'entry-after',
      },
    });
    expect(page.nextCursor?.entryId, 'entry-next');
    expect(
      page.nextCursor?.occurredAt,
      DateTime.fromMillisecondsSinceEpoch(_occurredAtMillis, isUtc: true),
    );
  });

  test('mappe les codes d’erreur callable sans exposer le SDK', () async {
    const mappings = {
      'unauthenticated': 'unauthenticated',
      'invalid-argument': 'invalid-argument',
      'permission-denied': 'permission-denied',
      'not-found': 'not-found',
      'failed-precondition': 'failed-precondition',
      'internal': 'internal',
      'unavailable': 'unavailable',
      'deadline-exceeded': 'unavailable',
      'unknown-code': 'internal',
    };

    for (final mapping in mappings.entries) {
      final service = FirebaseProfessionalSolicitationJournalService(
        callable: (_, _) => throw FirebaseFunctionsException(
          code: mapping.key,
          message: 'backend message',
        ),
      );

      await expectLater(
        service.recordConsulted(
          recipientUid: _recipientUid,
          solicitationId: 'solicitation-1',
        ),
        throwsA(
          isA<ProfessionalSolicitationJournalException>()
              .having((error) => error.code, 'code', mapping.value)
              .having((error) => error.message, 'message', 'backend message'),
        ),
        reason: 'Code callable mal mappé : ${mapping.key}',
      );
    }
  });

  test('convertit une panne technique en unavailable', () async {
    final service = FirebaseProfessionalSolicitationJournalService(
      callable: (_, _) => throw StateError('network unavailable'),
    );

    await expectLater(
      service.listEntries(
        ProfessionalSolicitationJournalQuery(recipientUid: _recipientUid),
      ),
      throwsA(
        isA<ProfessionalSolicitationJournalException>().having(
          (error) => error.code,
          'code',
          'unavailable',
        ),
      ),
    );
  });

  test('refuse les réponses invalides ou mal formées', () async {
    final malformedRecordResponses = <Object?>[
      null,
      {'created': true},
      {'created': 'true', 'entryId': 'entry-1'},
      {'created': true, 'entryId': ''},
      {'created': true, 'entryId': 'entry-1', 'extra': true},
    ];
    for (final response in malformedRecordResponses) {
      final service = FirebaseProfessionalSolicitationJournalService(
        callable: (_, _) async => response,
      );
      await expectLater(
        service.recordConsulted(
          recipientUid: _recipientUid,
          solicitationId: 'solicitation-1',
        ),
        throwsA(
          isA<ProfessionalSolicitationJournalException>().having(
            (error) => error.code,
            'code',
            'internal',
          ),
        ),
      );
    }

    final malformedPageResponses = <Object?>[
      null,
      {'entries': <Object?>[]},
      {'entries': 'invalid', 'nextCursor': null},
      {
        'entries': [entryResponse()..remove('occurredAtMillis')],
        'nextCursor': null,
      },
      {
        'entries': <Object?>[],
        'nextCursor': {'occurredAtMillis': -1, 'entryId': 'entry-1'},
      },
    ];
    for (final response in malformedPageResponses) {
      final service = FirebaseProfessionalSolicitationJournalService(
        callable: (_, _) async => response,
      );
      await expectLater(
        service.listEntries(
          ProfessionalSolicitationJournalQuery(recipientUid: _recipientUid),
        ),
        throwsA(
          isA<ProfessionalSolicitationJournalException>().having(
            (error) => error.code,
            'code',
            'internal',
          ),
        ),
      );
    }
  });
}
