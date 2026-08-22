import 'dart:collection';

/// Compétences déclarées par un professionnel pour les usages futurs du Vivier.
///
/// Les identifiants restent ouverts : la taxonomie métier sera fournie et
/// versionnée séparément. Ce contrat n'est pas relié au profil RC3.
class ProfessionalCompetencies {
  factory ProfessionalCompetencies({
    Iterable<String> skillIds = const [],
    String? otherSkillDetails,
    int taxonomyVersion = 1,
  }) {
    if (taxonomyVersion < 1) {
      throw const FormatException('Version de taxonomie invalide.');
    }
    return ProfessionalCompetencies._(
      skillIds: _immutableIdentifiers(skillIds),
      otherSkillDetails: _optionalCanonicalText(otherSkillDetails),
      taxonomyVersion: taxonomyVersion,
    );
  }

  ProfessionalCompetencies._({
    required Set<String> skillIds,
    required this.otherSkillDetails,
    required this.taxonomyVersion,
  }) : skillIds = UnmodifiableSetView(skillIds);

  factory ProfessionalCompetencies.fromMap(Map<String, Object?> data) =>
      ProfessionalCompetencies(
        skillIds: _optionalStringList(data, 'skillIds'),
        otherSkillDetails: _optionalTextValue(data, 'otherSkillDetails'),
        taxonomyVersion: _optionalPositiveInt(data, 'taxonomyVersion'),
      );

  final Set<String> skillIds;
  final String? otherSkillDetails;
  final int taxonomyVersion;

  Map<String, Object?> toMap() {
    final orderedSkillIds = skillIds.toList(growable: false)..sort();
    return {
      if (orderedSkillIds.isNotEmpty) 'skillIds': orderedSkillIds,
      if (otherSkillDetails != null) 'otherSkillDetails': otherSkillDetails,
      'taxonomyVersion': taxonomyVersion,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionalCompetencies &&
          _sameSet(skillIds, other.skillIds) &&
          otherSkillDetails == other.otherSkillDetails &&
          taxonomyVersion == other.taxonomyVersion;

  @override
  int get hashCode {
    final orderedSkillIds = skillIds.toList(growable: false)..sort();
    return Object.hash(
      Object.hashAll(orderedSkillIds),
      otherSkillDetails,
      taxonomyVersion,
    );
  }
}

Set<String> _immutableIdentifiers(Iterable<String> values) {
  final items = values.toList(growable: false);
  final result = Set<String>.of(items);
  if (result.length != items.length) {
    throw const FormatException('Identifiants de compétences dupliqués.');
  }
  for (final value in result) {
    if (value.trim().isEmpty || value.trim() != value) {
      throw const FormatException('Identifiant de compétence invalide.');
    }
  }
  return Set<String>.unmodifiable(result);
}

Iterable<String> _optionalStringList(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return const [];
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException('Compétences professionnelles invalides.');
  }
  return value.cast<String>();
}

String? _optionalTextValue(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Compétences professionnelles invalides.');
  }
  return value;
}

String? _optionalCanonicalText(String? value) {
  if (value == null) return null;
  if (value.trim().isEmpty || value.trim() != value) {
    throw const FormatException('Précision de compétence invalide.');
  }
  return value;
}

int _optionalPositiveInt(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return 1;
  if (value is! int || value < 1) {
    throw const FormatException('Version de taxonomie invalide.');
  }
  return value;
}

bool _sameSet<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);
