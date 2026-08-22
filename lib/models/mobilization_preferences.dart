import 'dart:collection';

/// Jour récurrent préféré, sans représenter une disponibilité datée.
enum ProfessionalWeekday {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
}

extension ProfessionalWeekdayValue on ProfessionalWeekday {
  String get serializedValue => name;
}

ProfessionalWeekday professionalWeekdayFromValue(Object? value) =>
    ProfessionalWeekday.values.firstWhere(
      (weekday) => weekday.serializedValue == value,
      orElse: () => throw const FormatException('Jour de préférence invalide.'),
    );

/// Préférences générales de mobilisation du professionnel.
///
/// Les types et bandes horaires sont des identifiants ouverts afin de ne pas
/// figer une taxonomie métier avant sa validation. Aucune valeur ne représente
/// un engagement ou une disponibilité datée.
class MobilizationPreferences {
  factory MobilizationPreferences({
    Iterable<String> preferredMobilizationTypes = const [],
    Iterable<String> territoryIds = const [],
    Iterable<String> locationIds = const [],
    Iterable<ProfessionalWeekday> preferredWeekdays = const [],
    Iterable<String> preferredTimeBands = const [],
    int schemaVersion = 1,
  }) {
    if (schemaVersion < 1) {
      throw const FormatException(
        'Version de préférences de mobilisation invalide.',
      );
    }
    return MobilizationPreferences._(
      preferredMobilizationTypes: _immutableIdentifiers(
        preferredMobilizationTypes,
      ),
      territoryIds: _immutableIdentifiers(territoryIds),
      locationIds: _immutableIdentifiers(locationIds),
      preferredWeekdays: _immutableWeekdays(preferredWeekdays),
      preferredTimeBands: _immutableIdentifiers(preferredTimeBands),
      schemaVersion: schemaVersion,
    );
  }

  MobilizationPreferences._({
    required Set<String> preferredMobilizationTypes,
    required Set<String> territoryIds,
    required Set<String> locationIds,
    required Set<ProfessionalWeekday> preferredWeekdays,
    required Set<String> preferredTimeBands,
    required this.schemaVersion,
  }) : preferredMobilizationTypes = UnmodifiableSetView(
         preferredMobilizationTypes,
       ),
       territoryIds = UnmodifiableSetView(territoryIds),
       locationIds = UnmodifiableSetView(locationIds),
       preferredWeekdays = UnmodifiableSetView(preferredWeekdays),
       preferredTimeBands = UnmodifiableSetView(preferredTimeBands);

  factory MobilizationPreferences.fromMap(Map<String, Object?> data) {
    final weekdays = _optionalObjectList(
      data,
      'preferredWeekdays',
    ).map(professionalWeekdayFromValue);
    return MobilizationPreferences(
      preferredMobilizationTypes: _optionalStringList(
        data,
        'preferredMobilizationTypes',
      ),
      territoryIds: _optionalStringList(data, 'territoryIds'),
      locationIds: _optionalStringList(data, 'locationIds'),
      preferredWeekdays: weekdays,
      preferredTimeBands: _optionalStringList(data, 'preferredTimeBands'),
      schemaVersion: _optionalPositiveInt(data, 'schemaVersion'),
    );
  }

  final Set<String> preferredMobilizationTypes;
  final Set<String> territoryIds;
  final Set<String> locationIds;
  final Set<ProfessionalWeekday> preferredWeekdays;
  final Set<String> preferredTimeBands;
  final int schemaVersion;

  Map<String, Object?> toMap() => {
    if (preferredMobilizationTypes.isNotEmpty)
      'preferredMobilizationTypes': _sortedStrings(preferredMobilizationTypes),
    if (territoryIds.isNotEmpty) 'territoryIds': _sortedStrings(territoryIds),
    if (locationIds.isNotEmpty) 'locationIds': _sortedStrings(locationIds),
    if (preferredWeekdays.isNotEmpty)
      'preferredWeekdays':
          preferredWeekdays
              .toList(growable: false)
              .map((weekday) => weekday.serializedValue)
              .toList(growable: false)
            ..sort(),
    if (preferredTimeBands.isNotEmpty)
      'preferredTimeBands': _sortedStrings(preferredTimeBands),
    'schemaVersion': schemaVersion,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MobilizationPreferences &&
          _sameSet(
            preferredMobilizationTypes,
            other.preferredMobilizationTypes,
          ) &&
          _sameSet(territoryIds, other.territoryIds) &&
          _sameSet(locationIds, other.locationIds) &&
          _sameSet(preferredWeekdays, other.preferredWeekdays) &&
          _sameSet(preferredTimeBands, other.preferredTimeBands) &&
          schemaVersion == other.schemaVersion;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(_sortedStrings(preferredMobilizationTypes)),
    Object.hashAll(_sortedStrings(territoryIds)),
    Object.hashAll(_sortedStrings(locationIds)),
    Object.hashAll(
      preferredWeekdays.map((weekday) => weekday.serializedValue).toList()
        ..sort(),
    ),
    Object.hashAll(_sortedStrings(preferredTimeBands)),
    schemaVersion,
  );
}

Set<String> _immutableIdentifiers(Iterable<String> values) {
  final items = values.toList(growable: false);
  final result = Set<String>.of(items);
  if (result.length != items.length) {
    throw const FormatException('Préférences dupliquées.');
  }
  for (final value in result) {
    if (value.trim().isEmpty || value.trim() != value) {
      throw const FormatException('Identifiant de préférence invalide.');
    }
  }
  return Set<String>.unmodifiable(result);
}

Set<ProfessionalWeekday> _immutableWeekdays(
  Iterable<ProfessionalWeekday> values,
) {
  final items = values.toList(growable: false);
  final result = Set<ProfessionalWeekday>.of(items);
  if (result.length != items.length) {
    throw const FormatException('Jours de préférence dupliqués.');
  }
  return Set<ProfessionalWeekday>.unmodifiable(result);
}

Iterable<String> _optionalStringList(Map<String, Object?> data, String key) {
  final values = _optionalObjectList(data, key);
  if (values.any((value) => value is! String)) {
    throw const FormatException('Préférences de mobilisation invalides.');
  }
  return values.cast<String>();
}

List<Object?> _optionalObjectList(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('Préférences de mobilisation invalides.');
  }
  return value.cast<Object?>();
}

int _optionalPositiveInt(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return 1;
  if (value is! int || value < 1) {
    throw const FormatException(
      'Version de préférences de mobilisation invalide.',
    );
  }
  return value;
}

List<String> _sortedStrings(Iterable<String> values) =>
    values.toList(growable: false)..sort();

bool _sameSet<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);
