/// Type de preuve versionnée associée au profil professionnel.
///
/// Ce value object est volontairement ouvert : une valeur future valide est
/// conservée lors d'une désérialisation au lieu d'être rejetée.
final class ProfessionalConsentType {
  factory ProfessionalConsentType(String value) {
    _validateWireValue(value, label: 'Type de consentement');
    return switch (value) {
      'terms_of_use' => termsOfUse,
      'privacy_notice' => privacyNotice,
      _ => ProfessionalConsentType._(value),
    };
  }

  const ProfessionalConsentType._(this.serializedValue);

  static const termsOfUse = ProfessionalConsentType._('terms_of_use');
  static const privacyNotice = ProfessionalConsentType._('privacy_notice');

  final String serializedValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionalConsentType &&
          serializedValue == other.serializedValue;

  @override
  int get hashCode => serializedValue.hashCode;

  @override
  String toString() => serializedValue;
}

/// État enregistré dans une preuve de consentement.
///
/// Les constantes ne définissent aucune base légale. Le type reste ouvert pour
/// préserver les états additifs futurs.
final class ProfessionalConsentState {
  factory ProfessionalConsentState(String value) {
    _validateWireValue(value, label: 'État de consentement');
    return switch (value) {
      'granted' => granted,
      'denied' => denied,
      'withdrawn' => withdrawn,
      _ => ProfessionalConsentState._(value),
    };
  }

  const ProfessionalConsentState._(this.serializedValue);

  static const granted = ProfessionalConsentState._('granted');
  static const denied = ProfessionalConsentState._('denied');
  static const withdrawn = ProfessionalConsentState._('withdrawn');

  final String serializedValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionalConsentState &&
          serializedValue == other.serializedValue;

  @override
  int get hashCode => serializedValue.hashCode;

  @override
  String toString() => serializedValue;
}

/// Preuve immuable et versionnée d'un état de consentement.
///
/// Plusieurs instances de même [type] peuvent coexister avec des [version]
/// différentes. Le contrat ne contient ni texte juridique ni base légale.
class ProfessionalConsentRecord {
  factory ProfessionalConsentRecord({
    required ProfessionalConsentType type,
    required String version,
    required ProfessionalConsentState state,
    required DateTime recordedAt,
    required String source,
  }) {
    _validateCanonicalText(version, label: 'Version de consentement');
    _validateWireValue(source, label: 'Source de consentement');
    return ProfessionalConsentRecord._(
      type: type,
      version: version,
      state: state,
      recordedAt: recordedAt,
      source: source,
    );
  }

  const ProfessionalConsentRecord._({
    required this.type,
    required this.version,
    required this.state,
    required this.recordedAt,
    required this.source,
  });

  factory ProfessionalConsentRecord.fromMap(Map<String, Object?> data) {
    final type = data['type'];
    final version = data['version'];
    final state = data['state'];
    final recordedAt = data['recordedAt'];
    final source = data['source'];
    if (type is! String ||
        version is! String ||
        state is! String ||
        recordedAt is! DateTime ||
        source is! String) {
      throw const FormatException('Preuve de consentement invalide.');
    }
    return ProfessionalConsentRecord(
      type: ProfessionalConsentType(type),
      version: version,
      state: ProfessionalConsentState(state),
      recordedAt: recordedAt,
      source: source,
    );
  }

  final ProfessionalConsentType type;
  final String version;
  final ProfessionalConsentState state;
  final DateTime recordedAt;
  final String source;

  Map<String, Object?> toMap() => {
    'type': type.serializedValue,
    'version': version,
    'state': state.serializedValue,
    'recordedAt': recordedAt,
    'source': source,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionalConsentRecord &&
          type == other.type &&
          version == other.version &&
          state == other.state &&
          recordedAt == other.recordedAt &&
          source == other.source;

  @override
  int get hashCode => Object.hash(type, version, state, recordedAt, source);
}

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
