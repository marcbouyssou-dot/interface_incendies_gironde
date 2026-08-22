import 'professional_operational_history.dart';

/// Type ouvert d'un fait du journal de sollicitations.
final class ProfessionalSolicitationFactType {
  factory ProfessionalSolicitationFactType(String value) {
    _validateWireValue(value, label: 'Type de fait de sollicitation');
    return switch (value) {
      'created' => created,
      'consulted' => consulted,
      'provider_accepted' => providerAccepted,
      _ => ProfessionalSolicitationFactType._(value),
    };
  }

  const ProfessionalSolicitationFactType._(this.serializedValue);

  static const created = ProfessionalSolicitationFactType._('created');
  static const consulted = ProfessionalSolicitationFactType._('consulted');
  static const providerAccepted = ProfessionalSolicitationFactType._(
    'provider_accepted',
  );

  final String serializedValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionalSolicitationFactType &&
          serializedValue == other.serializedValue;

  @override
  int get hashCode => serializedValue.hashCode;

  @override
  String toString() => serializedValue;
}

/// Collection ayant fourni la preuve. Les valeurs restent additives.
final class ProfessionalSolicitationSource {
  factory ProfessionalSolicitationSource(String value) {
    _validateWireValue(value, label: 'Source de sollicitation');
    return switch (value) {
      'canonical_journal' => canonicalJournal,
      'notifications' => notifications,
      'notification_events' => notificationEvents,
      'notification_deliveries' => notificationDeliveries,
      _ => ProfessionalSolicitationSource._(value),
    };
  }

  const ProfessionalSolicitationSource._(this.serializedValue);

  static const canonicalJournal = ProfessionalSolicitationSource._(
    'canonical_journal',
  );
  static const notifications = ProfessionalSolicitationSource._(
    'notifications',
  );
  static const notificationEvents = ProfessionalSolicitationSource._(
    'notification_events',
  );
  static const notificationDeliveries = ProfessionalSolicitationSource._(
    'notification_deliveries',
  );

  final String serializedValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionalSolicitationSource &&
          serializedValue == other.serializedValue;

  @override
  int get hashCode => serializedValue.hashCode;

  @override
  String toString() => serializedValue;
}

/// Canal ouvert. Un identifiant d'installation push n'appartient pas au
/// contrat métier et n'est jamais exposé ici.
final class ProfessionalSolicitationChannel {
  factory ProfessionalSolicitationChannel(String value) {
    _validateWireValue(value, label: 'Canal de sollicitation');
    return switch (value) {
      'in_app' => inApp,
      'push' => push,
      'email' => email,
      'sms' => sms,
      _ => ProfessionalSolicitationChannel._(value),
    };
  }

  const ProfessionalSolicitationChannel._(this.serializedValue);

  static const inApp = ProfessionalSolicitationChannel._('in_app');
  static const push = ProfessionalSolicitationChannel._('push');
  static const email = ProfessionalSolicitationChannel._('email');
  static const sms = ProfessionalSolicitationChannel._('sms');

  final String serializedValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionalSolicitationChannel &&
          serializedValue == other.serializedValue;

  @override
  int get hashCode => serializedValue.hashCode;

  @override
  String toString() => serializedValue;
}

/// Cause métier ouverte, actuellement alignée sur les eventType RC3.
final class ProfessionalSolicitationCauseType {
  factory ProfessionalSolicitationCauseType(String value) {
    _validateWireValue(value, label: 'Cause de sollicitation');
    return ProfessionalSolicitationCauseType._(value);
  }

  const ProfessionalSolicitationCauseType._(this.serializedValue);

  final String serializedValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionalSolicitationCauseType &&
          serializedValue == other.serializedValue;

  @override
  int get hashCode => serializedValue.hashCode;

  @override
  String toString() => serializedValue;
}

/// Catégorie métier ouverte, distincte du canal de transport.
final class ProfessionalSolicitationCategory {
  factory ProfessionalSolicitationCategory(String value) {
    _validateWireValue(value, label: 'Catégorie de sollicitation');
    return ProfessionalSolicitationCategory._(value);
  }

  const ProfessionalSolicitationCategory._(this.serializedValue);

  final String serializedValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionalSolicitationCategory &&
          serializedValue == other.serializedValue;

  @override
  int get hashCode => serializedValue.hashCode;

  @override
  String toString() => serializedValue;
}

/// Entrée append-only du futur journal canonique, ou adaptation explicite
/// d'une preuve RC3. Une entrée indisponible n'existe pas : l'absence reste
/// portée par la couverture du journal et non transformée en événement.
final class ProfessionalSolicitationJournalEntry {
  factory ProfessionalSolicitationJournalEntry({
    required String entryId,
    required String solicitationId,
    required String recipientUid,
    required ProfessionalSolicitationFactType factType,
    required DateTime occurredAt,
    required OperationalFactQuality quality,
    required Iterable<ProfessionalSolicitationSource> sources,
    required Iterable<String> sourceRecordIds,
    ProfessionalSolicitationChannel? channel,
    String? causeEventId,
    ProfessionalSolicitationCauseType? causeType,
    ProfessionalSolicitationCategory? category,
    String? missionId,
    String? mobilizationId,
    String? operationId,
    String? organizationId,
    String? engagementId,
    String? source,
    Iterable<String> limitations = const [],
    int schemaVersion = 1,
  }) {
    _validateIdentifier(entryId, label: 'Identifiant d’entrée');
    _validateIdentifier(solicitationId, label: 'Identifiant de sollicitation');
    _validateIdentifier(recipientUid, label: 'Destinataire');
    if (quality == OperationalFactQuality.unavailable) {
      throw const FormatException(
        'Une entrée de journal ne peut pas être indisponible.',
      );
    }
    if (schemaVersion < 1) {
      throw const FormatException('Version de journal invalide.');
    }
    final immutableSources = Set<ProfessionalSolicitationSource>.unmodifiable(
      sources,
    );
    final immutableSourceIds = _immutableIdentifiers(
      sourceRecordIds,
      label: 'Identifiant de preuve',
    );
    if (immutableSources.isEmpty || immutableSourceIds.isEmpty) {
      throw const FormatException('Une preuve de sollicitation est requise.');
    }
    final normalizedOrganizationId = _optionalIdentifier(
      organizationId,
      label: 'Organisation',
    );
    final normalizedSource = _optionalWireValue(source, label: 'Source');
    if (immutableSources.contains(
          ProfessionalSolicitationSource.canonicalJournal,
        ) &&
        (normalizedOrganizationId == null || normalizedSource == null)) {
      throw const FormatException(
        'Le contexte serveur canonique est incomplet.',
      );
    }
    return ProfessionalSolicitationJournalEntry._(
      entryId: entryId,
      solicitationId: solicitationId,
      recipientUid: recipientUid,
      factType: factType,
      occurredAt: occurredAt,
      quality: quality,
      sources: immutableSources,
      sourceRecordIds: immutableSourceIds,
      channel: channel,
      causeEventId: _optionalIdentifier(causeEventId, label: 'Événement cause'),
      causeType: causeType,
      category: category,
      missionId: _optionalIdentifier(missionId, label: 'Mission'),
      mobilizationId: _optionalIdentifier(
        mobilizationId,
        label: 'Mobilisation',
      ),
      operationId: _optionalIdentifier(operationId, label: 'Opération'),
      organizationId: normalizedOrganizationId,
      engagementId: _optionalIdentifier(engagementId, label: 'Engagement'),
      source: normalizedSource,
      limitations: _immutableLimitations(limitations),
      schemaVersion: schemaVersion,
    );
  }

  const ProfessionalSolicitationJournalEntry._({
    required this.entryId,
    required this.solicitationId,
    required this.recipientUid,
    required this.factType,
    required this.occurredAt,
    required this.quality,
    required this.sources,
    required this.sourceRecordIds,
    required this.channel,
    required this.causeEventId,
    required this.causeType,
    required this.category,
    required this.missionId,
    required this.mobilizationId,
    required this.operationId,
    required this.organizationId,
    required this.engagementId,
    required this.source,
    required this.limitations,
    required this.schemaVersion,
  });

  factory ProfessionalSolicitationJournalEntry.fromMap(
    Map<String, Object?> data,
  ) {
    final entryId = data['entryId'];
    final solicitationId = data['solicitationId'];
    final recipientUid = data['recipientUid'];
    final factType = data['factType'];
    final occurredAt = data['occurredAt'];
    final quality = data['quality'];
    final schemaVersion = data['schemaVersion'];
    if (entryId is! String ||
        solicitationId is! String ||
        recipientUid is! String ||
        factType is! String ||
        occurredAt is! DateTime ||
        quality is! String ||
        (schemaVersion != null && schemaVersion is! int)) {
      throw const FormatException('Entrée de sollicitation invalide.');
    }
    return ProfessionalSolicitationJournalEntry(
      entryId: entryId,
      solicitationId: solicitationId,
      recipientUid: recipientUid,
      factType: ProfessionalSolicitationFactType(factType),
      occurredAt: occurredAt,
      quality: switch (quality) {
        'complete' => OperationalFactQuality.complete,
        'partial' => OperationalFactQuality.partial,
        _ => throw const FormatException('Qualité de sollicitation invalide.'),
      },
      sources: _requiredStringList(
        data,
        'sources',
      ).map(ProfessionalSolicitationSource.new),
      sourceRecordIds: _requiredStringList(data, 'sourceRecordIds'),
      channel: _optionalOpenValue(
        data,
        'channel',
        ProfessionalSolicitationChannel.new,
      ),
      causeEventId: _optionalString(data, 'causeEventId'),
      causeType: _optionalOpenValue(
        data,
        'causeType',
        ProfessionalSolicitationCauseType.new,
      ),
      category: _optionalOpenValue(
        data,
        'category',
        ProfessionalSolicitationCategory.new,
      ),
      missionId: _optionalString(data, 'missionId'),
      mobilizationId: _optionalString(data, 'mobilizationId'),
      operationId: _optionalString(data, 'operationId'),
      organizationId: _optionalString(data, 'organizationId'),
      engagementId: _optionalString(data, 'engagementId'),
      source: _optionalString(data, 'source'),
      limitations: _optionalStringList(data, 'limitations'),
      schemaVersion: schemaVersion as int? ?? 1,
    );
  }

  final String entryId;
  final String solicitationId;
  final String recipientUid;
  final ProfessionalSolicitationFactType factType;
  final DateTime occurredAt;
  final OperationalFactQuality quality;
  final Set<ProfessionalSolicitationSource> sources;
  final Set<String> sourceRecordIds;
  final ProfessionalSolicitationChannel? channel;
  final String? causeEventId;
  final ProfessionalSolicitationCauseType? causeType;
  final ProfessionalSolicitationCategory? category;
  final String? missionId;
  final String? mobilizationId;
  final String? operationId;
  final String? organizationId;
  final String? engagementId;
  final String? source;
  final List<String> limitations;
  final int schemaVersion;

  Map<String, Object?> toMap() {
    final orderedSources = sources.map((item) => item.serializedValue).toList()
      ..sort();
    final orderedSourceIds = sourceRecordIds.toList()..sort();
    return {
      'entryId': entryId,
      'solicitationId': solicitationId,
      'recipientUid': recipientUid,
      'factType': factType.serializedValue,
      'occurredAt': occurredAt,
      'quality': quality.name,
      'sources': orderedSources,
      'sourceRecordIds': orderedSourceIds,
      if (channel != null) 'channel': channel!.serializedValue,
      if (causeEventId != null) 'causeEventId': causeEventId,
      if (causeType != null) 'causeType': causeType!.serializedValue,
      if (category != null) 'category': category!.serializedValue,
      if (missionId != null) 'missionId': missionId,
      if (mobilizationId != null) 'mobilizationId': mobilizationId,
      if (operationId != null) 'operationId': operationId,
      if (organizationId != null) 'organizationId': organizationId,
      if (engagementId != null) 'engagementId': engagementId,
      if (source != null) 'source': source,
      if (limitations.isNotEmpty) 'limitations': limitations,
      'schemaVersion': schemaVersion,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionalSolicitationJournalEntry &&
          entryId == other.entryId &&
          solicitationId == other.solicitationId &&
          recipientUid == other.recipientUid &&
          factType == other.factType &&
          occurredAt == other.occurredAt &&
          quality == other.quality &&
          _sameSet(sources, other.sources) &&
          _sameSet(sourceRecordIds, other.sourceRecordIds) &&
          channel == other.channel &&
          causeEventId == other.causeEventId &&
          causeType == other.causeType &&
          category == other.category &&
          missionId == other.missionId &&
          mobilizationId == other.mobilizationId &&
          operationId == other.operationId &&
          organizationId == other.organizationId &&
          engagementId == other.engagementId &&
          source == other.source &&
          _sameList(limitations, other.limitations) &&
          schemaVersion == other.schemaVersion;

  @override
  int get hashCode => Object.hashAll([
    entryId,
    solicitationId,
    recipientUid,
    factType,
    occurredAt,
    quality,
    Object.hashAll(
      sources.map((item) => item.serializedValue).toList()..sort(),
    ),
    Object.hashAll(sourceRecordIds.toList()..sort()),
    channel,
    causeEventId,
    causeType,
    category,
    missionId,
    mobilizationId,
    operationId,
    organizationId,
    engagementId,
    source,
    Object.hashAll(limitations),
    schemaVersion,
  ]);
}

/// Vue regroupée d'une sollicitation. Les faits restent disponibles dans
/// [entries] et ne sont jamais écrasés par ce résumé.
final class ProfessionalSolicitation {
  factory ProfessionalSolicitation({
    required String id,
    required String recipientUid,
    required DateTime? createdAt,
    required DateTime? lastConsultedAt,
    required int pushProviderAcceptedCount,
    required OperationalFactQuality quality,
    required String? causeEventId,
    required ProfessionalSolicitationCauseType? causeType,
    required ProfessionalSolicitationCategory? category,
    required String? missionId,
    required String? mobilizationId,
    required String? operationId,
    required String? organizationId,
    required String? engagementId,
    required Iterable<ProfessionalSolicitationJournalEntry> entries,
    required Iterable<String> limitations,
  }) {
    _validateIdentifier(id, label: 'Identifiant de sollicitation');
    _validateIdentifier(recipientUid, label: 'Destinataire');
    if (pushProviderAcceptedCount < 0 ||
        quality == OperationalFactQuality.unavailable) {
      throw const FormatException('Résumé de sollicitation invalide.');
    }
    final immutableEntries =
        List<ProfessionalSolicitationJournalEntry>.unmodifiable(entries);
    if (immutableEntries.any(
      (entry) =>
          entry.solicitationId != id || entry.recipientUid != recipientUid,
    )) {
      throw const FormatException('Preuves de sollicitation incohérentes.');
    }
    return ProfessionalSolicitation._(
      id: id,
      recipientUid: recipientUid,
      createdAt: createdAt,
      lastConsultedAt: lastConsultedAt,
      pushProviderAcceptedCount: pushProviderAcceptedCount,
      quality: quality,
      causeEventId: _optionalIdentifier(causeEventId, label: 'Événement cause'),
      causeType: causeType,
      category: category,
      missionId: _optionalIdentifier(missionId, label: 'Mission'),
      mobilizationId: _optionalIdentifier(
        mobilizationId,
        label: 'Mobilisation',
      ),
      operationId: _optionalIdentifier(operationId, label: 'Opération'),
      organizationId: _optionalIdentifier(
        organizationId,
        label: 'Organisation',
      ),
      engagementId: _optionalIdentifier(engagementId, label: 'Engagement'),
      entries: immutableEntries,
      limitations: _immutableLimitations(limitations),
    );
  }

  const ProfessionalSolicitation._({
    required this.id,
    required this.recipientUid,
    required this.createdAt,
    required this.lastConsultedAt,
    required this.pushProviderAcceptedCount,
    required this.quality,
    required this.causeEventId,
    required this.causeType,
    required this.category,
    required this.missionId,
    required this.mobilizationId,
    required this.operationId,
    required this.organizationId,
    required this.engagementId,
    required this.entries,
    required this.limitations,
  });

  final String id;
  final String recipientUid;
  final DateTime? createdAt;
  final DateTime? lastConsultedAt;
  final int pushProviderAcceptedCount;
  final OperationalFactQuality quality;
  final String? causeEventId;
  final ProfessionalSolicitationCauseType? causeType;
  final ProfessionalSolicitationCategory? category;
  final String? missionId;
  final String? mobilizationId;
  final String? operationId;
  final String? organizationId;
  final String? engagementId;
  final List<ProfessionalSolicitationJournalEntry> entries;
  final List<String> limitations;

  bool get isCreationProven => createdAt != null;
}

final class ProfessionalSolicitationJournalIssue {
  const ProfessionalSolicitationJournalIssue({
    required this.code,
    required this.sourceRecordId,
    required this.description,
  });

  final String code;
  final String sourceRecordId;
  final String description;
}

/// Résultat dérivé. Une liste vide avec qualité partielle ne signifie jamais
/// qu'aucune sollicitation historique n'a existé.
final class ProfessionalSolicitationJournal {
  factory ProfessionalSolicitationJournal({
    required String recipientUid,
    required DateTime generatedAt,
    required OperationalFactQuality coverageQuality,
    required DateTime? coveredSince,
    required Iterable<ProfessionalSolicitationJournalEntry> entries,
    required Iterable<ProfessionalSolicitation> solicitations,
    required Iterable<ProfessionalSolicitationJournalIssue> issues,
    required Iterable<String> limitations,
  }) {
    _validateIdentifier(recipientUid, label: 'Destinataire');
    if (coverageQuality == OperationalFactQuality.unavailable) {
      throw const FormatException('Couverture de journal invalide.');
    }
    final immutableEntries =
        List<ProfessionalSolicitationJournalEntry>.unmodifiable(entries);
    final immutableSolicitations = List<ProfessionalSolicitation>.unmodifiable(
      solicitations,
    );
    if (immutableEntries.any((entry) => entry.recipientUid != recipientUid) ||
        immutableSolicitations.any(
          (solicitation) => solicitation.recipientUid != recipientUid,
        )) {
      throw const FormatException('Journal destinataire incohérent.');
    }
    return ProfessionalSolicitationJournal._(
      recipientUid: recipientUid,
      generatedAt: generatedAt,
      coverageQuality: coverageQuality,
      coveredSince: coveredSince,
      entries: immutableEntries,
      solicitations: immutableSolicitations,
      issues: List.unmodifiable(issues),
      limitations: _immutableLimitations(limitations),
    );
  }

  const ProfessionalSolicitationJournal._({
    required this.recipientUid,
    required this.generatedAt,
    required this.coverageQuality,
    required this.coveredSince,
    required this.entries,
    required this.solicitations,
    required this.issues,
    required this.limitations,
  });

  final String recipientUid;
  final DateTime generatedAt;
  final OperationalFactQuality coverageQuality;
  final DateTime? coveredSince;
  final List<ProfessionalSolicitationJournalEntry> entries;
  final List<ProfessionalSolicitation> solicitations;
  final List<ProfessionalSolicitationJournalIssue> issues;
  final List<String> limitations;
}

/// Curseur stable pour une future lecture serveur ordonnée par occurredAt puis
/// entryId, tous deux décroissants.
final class ProfessionalSolicitationJournalCursor {
  factory ProfessionalSolicitationJournalCursor({
    required DateTime occurredAt,
    required String entryId,
  }) {
    _validateIdentifier(entryId, label: 'Curseur d’entrée');
    return ProfessionalSolicitationJournalCursor._(
      occurredAt: occurredAt,
      entryId: entryId,
    );
  }

  const ProfessionalSolicitationJournalCursor._({
    required this.occurredAt,
    required this.entryId,
  });

  final DateTime occurredAt;
  final String entryId;
}

/// Contrat de lecture serveur future. Il ne dépend d'aucun SDK Firestore.
final class ProfessionalSolicitationJournalQuery {
  factory ProfessionalSolicitationJournalQuery({
    required String recipientUid,
    int limit = 50,
    ProfessionalSolicitationJournalCursor? after,
  }) {
    _validateIdentifier(recipientUid, label: 'Destinataire');
    if (limit < 1 || limit > 100) {
      throw const FormatException('Limite de journal invalide.');
    }
    return ProfessionalSolicitationJournalQuery._(
      recipientUid: recipientUid,
      limit: limit,
      after: after,
    );
  }

  const ProfessionalSolicitationJournalQuery._({
    required this.recipientUid,
    required this.limit,
    required this.after,
  });

  final String recipientUid;
  final int limit;
  final ProfessionalSolicitationJournalCursor? after;
}

final class ProfessionalSolicitationJournalPage {
  ProfessionalSolicitationJournalPage({
    required Iterable<ProfessionalSolicitationJournalEntry> entries,
    required this.nextCursor,
    required this.coverageQuality,
    required this.coveredSince,
  }) : entries = List.unmodifiable(entries);

  final List<ProfessionalSolicitationJournalEntry> entries;
  final ProfessionalSolicitationJournalCursor? nextCursor;
  final OperationalFactQuality coverageQuality;
  final DateTime? coveredSince;
}

Set<String> _immutableIdentifiers(
  Iterable<String> values, {
  required String label,
}) {
  final result = <String>{};
  for (final value in values) {
    _validateIdentifier(value, label: label);
    if (!result.add(value)) throw FormatException('$label dupliqué.');
  }
  return Set.unmodifiable(result);
}

List<String> _immutableLimitations(Iterable<String> values) {
  final result = <String>[];
  for (final value in values) {
    _validateCanonicalText(value, label: 'Limitation');
    result.add(value);
  }
  return List.unmodifiable(result);
}

String? _optionalIdentifier(String? value, {required String label}) {
  if (value == null) return null;
  _validateIdentifier(value, label: label);
  return value;
}

String? _optionalWireValue(String? value, {required String label}) {
  if (value == null) return null;
  _validateWireValue(value, label: label);
  return value;
}

void _validateIdentifier(String value, {required String label}) =>
    _validateCanonicalText(value, label: label);

void _validateCanonicalText(String value, {required String label}) {
  if (value.trim().isEmpty || value.trim() != value) {
    throw FormatException('$label invalide.');
  }
}

void _validateWireValue(String value, {required String label}) {
  _validateCanonicalText(value, label: label);
  if (!RegExp(r'^[a-z0-9][a-z0-9._-]*$').hasMatch(value)) {
    throw FormatException('$label invalide.');
  }
}

List<String> _requiredStringList(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! List || value.isEmpty || value.any((item) => item is! String)) {
    throw const FormatException('Liste de sollicitation invalide.');
  }
  return value.cast<String>();
}

List<String> _optionalStringList(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return const [];
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException('Liste de sollicitation invalide.');
  }
  return value.cast<String>();
}

String? _optionalString(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Champ de sollicitation invalide.');
  }
  return value;
}

T? _optionalOpenValue<T>(
  Map<String, Object?> data,
  String key,
  T Function(String) factory,
) {
  final value = _optionalString(data, key);
  return value == null ? null : factory(value);
}

bool _sameSet<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

bool _sameList<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
