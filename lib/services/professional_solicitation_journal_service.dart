import '../models/professional_operational_history.dart';
import '../models/professional_solicitation_journal.dart';

abstract interface class ProfessionalSolicitationJournalService {
  Future<({bool created, String entryId})> recordConsulted({
    required String recipientUid,
    required String solicitationId,
  });

  Future<ProfessionalSolicitationJournalPage> listEntries(
    ProfessionalSolicitationJournalQuery query,
  );
}

/// Erreur stable du service, indépendante du SDK Firebase.
class ProfessionalSolicitationJournalException implements Exception {
  const ProfessionalSolicitationJournalException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Implémentation locale injectable. Elle ne contacte jamais Firebase.
class FakeProfessionalSolicitationJournalService
    implements ProfessionalSolicitationJournalService {
  const FakeProfessionalSolicitationJournalService({
    this.entries = const [],
    this.nextCursor,
    this.coverageQuality = OperationalFactQuality.partial,
    this.coveredSince,
    this.recordConsultedResult = const (created: true, entryId: 'fake-entry'),
    this.latency = Duration.zero,
  });

  final List<ProfessionalSolicitationJournalEntry> entries;
  final ProfessionalSolicitationJournalCursor? nextCursor;
  final OperationalFactQuality coverageQuality;
  final DateTime? coveredSince;
  final ({bool created, String entryId}) recordConsultedResult;
  final Duration latency;

  @override
  Future<({bool created, String entryId})> recordConsulted({
    required String recipientUid,
    required String solicitationId,
  }) async {
    await _wait();
    return recordConsultedResult;
  }

  @override
  Future<ProfessionalSolicitationJournalPage> listEntries(
    ProfessionalSolicitationJournalQuery query,
  ) async {
    await _wait();
    final matchingEntries = entries
        .where((entry) => entry.recipientUid == query.recipientUid)
        .take(query.limit);
    return ProfessionalSolicitationJournalPage(
      entries: matchingEntries,
      nextCursor: nextCursor,
      coverageQuality: coverageQuality,
      coveredSince: coveredSince,
    );
  }

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }
}
