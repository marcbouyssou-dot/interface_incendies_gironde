import 'package:cloud_functions/cloud_functions.dart';

import '../models/professional_operational_history.dart';
import '../models/professional_solicitation_journal.dart';
import 'professional_solicitation_journal_service.dart';

typedef ProfessionalSolicitationJournalCallable =
    Future<Object?> Function(String functionName, Map<String, Object?> data);

class FirebaseProfessionalSolicitationJournalService
    implements ProfessionalSolicitationJournalService {
  FirebaseProfessionalSolicitationJournalService({
    FirebaseFunctions? functions,
    ProfessionalSolicitationJournalCallable? callable,
  }) : assert(functions == null || callable == null),
       _functions = functions,
       _callable = callable;

  static const region = 'europe-west1';
  static const recordConsultedFunctionName =
      'recordProfessionalSolicitationConsulted';
  static const listEntriesFunctionName = 'listProfessionalSolicitationJournal';

  static const _recordResponseKeys = <String>{'created', 'entryId'};
  static const _pageResponseKeys = <String>{'entries', 'nextCursor'};
  static const _cursorKeys = <String>{'occurredAtMillis', 'entryId'};

  final FirebaseFunctions? _functions;
  final ProfessionalSolicitationJournalCallable? _callable;

  @override
  Future<({bool created, String entryId})> recordConsulted({
    required String recipientUid,
    required String solicitationId,
  }) => _guard(() async {
    final response = await _invoke(recordConsultedFunctionName, {
      'recipientUid': recipientUid,
      'solicitationId': solicitationId,
    });
    final data = _strictMap(response, _recordResponseKeys);
    final created = data['created'];
    final entryId = data['entryId'];
    if (created is! bool ||
        entryId is! String ||
        entryId.trim().isEmpty ||
        entryId.trim() != entryId) {
      throw const FormatException('Réponse de consultation invalide.');
    }
    return (created: created, entryId: entryId);
  });

  @override
  Future<ProfessionalSolicitationJournalPage> listEntries(
    ProfessionalSolicitationJournalQuery query,
  ) => _guard(() async {
    final cursor = query.after;
    final response = await _invoke(listEntriesFunctionName, {
      'recipientUid': query.recipientUid,
      'limit': query.limit,
      if (cursor != null)
        'cursor': {
          'occurredAtMillis': cursor.occurredAt.millisecondsSinceEpoch,
          'entryId': cursor.entryId,
        },
    });
    final data = _strictMap(response, _pageResponseKeys);
    final rawEntries = data['entries'];
    if (rawEntries is! List) {
      throw const FormatException('Page de journal invalide.');
    }
    final entries = rawEntries.map(_parseEntry).toList(growable: false);
    return ProfessionalSolicitationJournalPage(
      entries: entries,
      nextCursor: _parseCursor(data['nextCursor']),
      coverageQuality: OperationalFactQuality.partial,
      coveredSince: null,
    );
  });

  Future<Object?> _invoke(
    String functionName,
    Map<String, Object?> data,
  ) async {
    final callable = _callable;
    if (callable != null) return callable(functionName, data);

    final functions =
        _functions ?? FirebaseFunctions.instanceFor(region: region);
    final result = await functions
        .httpsCallable(functionName)
        .call<Object?>(data);
    return result.data;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ProfessionalSolicitationJournalException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw ProfessionalSolicitationJournalException(
        code: _serviceCode(error.code),
        message:
            error.message ?? 'Le journal des sollicitations est indisponible.',
      );
    } on FormatException {
      throw const ProfessionalSolicitationJournalException(
        code: 'internal',
        message: 'La réponse du journal des sollicitations est invalide.',
      );
    } catch (_) {
      throw const ProfessionalSolicitationJournalException(
        code: 'unavailable',
        message: 'Le journal des sollicitations est indisponible.',
      );
    }
  }

  ProfessionalSolicitationJournalEntry _parseEntry(Object? value) {
    final data = _stringKeyedMap(value);
    final occurredAtMillis = data.remove('occurredAtMillis');
    final recordedAtMillis = data.remove('recordedAtMillis');
    if (occurredAtMillis is! int ||
        occurredAtMillis < 0 ||
        recordedAtMillis is! int ||
        recordedAtMillis < 0 ||
        data.containsKey('occurredAt') ||
        data.containsKey('recordedAt')) {
      throw const FormatException('Entrée de journal invalide.');
    }
    data['occurredAt'] = DateTime.fromMillisecondsSinceEpoch(
      occurredAtMillis,
      isUtc: true,
    );
    return ProfessionalSolicitationJournalEntry.fromMap(data);
  }

  ProfessionalSolicitationJournalCursor? _parseCursor(Object? value) {
    if (value == null) return null;
    final data = _strictMap(value, _cursorKeys);
    final occurredAtMillis = data['occurredAtMillis'];
    final entryId = data['entryId'];
    if (occurredAtMillis is! int ||
        occurredAtMillis < 0 ||
        entryId is! String ||
        entryId.trim().isEmpty ||
        entryId.trim() != entryId) {
      throw const FormatException('Curseur de journal invalide.');
    }
    return ProfessionalSolicitationJournalCursor(
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        occurredAtMillis,
        isUtc: true,
      ),
      entryId: entryId,
    );
  }

  Map<String, Object?> _strictMap(Object? value, Set<String> expectedKeys) {
    final data = _stringKeyedMap(value);
    if (data.length != expectedKeys.length ||
        !expectedKeys.every(data.containsKey)) {
      throw const FormatException('Réponse callable invalide.');
    }
    return data;
  }

  Map<String, Object?> _stringKeyedMap(Object? value) {
    if (value is! Map) throw const FormatException('Objet callable invalide.');
    final data = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException('Clé callable invalide.');
      }
      data[entry.key as String] = entry.value;
    }
    return data;
  }

  String _serviceCode(String code) => switch (code) {
    'unauthenticated' ||
    'invalid-argument' ||
    'permission-denied' ||
    'not-found' ||
    'failed-precondition' ||
    'already-exists' ||
    'internal' => code,
    'unavailable' || 'deadline-exceeded' => 'unavailable',
    _ => 'internal',
  };
}
