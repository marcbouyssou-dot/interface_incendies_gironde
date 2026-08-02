import 'health_profession.dart';

class ProfessionQuota {
  const ProfessionQuota({
    required this.professionId,
    required this.required,
    required this.registered,
  }) : assert(required >= 0),
       assert(registered >= 0);

  final String professionId;
  final int required;
  final int registered;

  int get missing => (required - registered).clamp(0, required);
  bool get hasActivity => required > 0 || registered > 0;
  bool get isCovered => registered >= required;
  double get coverage =>
      required == 0 ? 1 : (registered / required).clamp(0, 1).toDouble();

  ProfessionQuota copyWith({int? required, int? registered}) {
    return ProfessionQuota(
      professionId: professionId,
      required: required ?? this.required,
      registered: registered ?? this.registered,
    );
  }
}

class ProfessionQuotas {
  ProfessionQuotas(Iterable<ProfessionQuota> quotas)
    : _byProfession = Map.unmodifiable({
        for (final quota in quotas) quota.professionId: quota,
      });

  factory ProfessionQuotas.fromMaps({
    required Map<String, int> requiredByProfession,
    required Map<String, int> registeredByProfession,
  }) {
    final normalizedRequired = _normalizeMap(requiredByProfession);
    final normalizedRegistered = _normalizeMap(registeredByProfession);
    final ids = HealthProfessionId.canonical;
    return ProfessionQuotas(
      ids.map(
        (id) => ProfessionQuota(
          professionId: id,
          required: normalizedRequired[id] ?? 0,
          registered: normalizedRegistered[id] ?? 0,
        ),
      ),
    );
  }

  factory ProfessionQuotas.fromLegacyMkPp({
    required int requiredMk,
    required int registeredMk,
    required int requiredPp,
    required int registeredPp,
  }) {
    return ProfessionQuotas.fromMaps(
      requiredByProfession: {
        HealthProfessionId.physiotherapist: requiredMk,
        HealthProfessionId.podiatrist: requiredPp,
      },
      registeredByProfession: {
        HealthProfessionId.physiotherapist: registeredMk,
        HealthProfessionId.podiatrist: registeredPp,
      },
    );
  }

  factory ProfessionQuotas.aggregate(Iterable<ProfessionQuotas> sources) {
    final quotas = sources.toList(growable: false);
    return ProfessionQuotas.fromMaps(
      requiredByProfession: {
        for (final id in HealthProfessionId.canonical)
          id: quotas.fold(
            0,
            (total, source) => total + source.quotaFor(id).required,
          ),
      },
      registeredByProfession: {
        for (final id in HealthProfessionId.canonical)
          id: quotas.fold(
            0,
            (total, source) => total + source.quotaFor(id).registered,
          ),
      },
    );
  }

  final Map<String, ProfessionQuota> _byProfession;

  static Map<String, int> _normalizeMap(Map<String, int> source) {
    final result = <String, int>{};
    for (final entry in source.entries) {
      final id = HealthProfessionId.normalize(entry.key);
      if (entry.value < 0) {
        throw FormatException('Quota négatif pour $id');
      }
      if (result.containsKey(id)) {
        throw FormatException('Quota dupliqué pour $id');
      }
      result[id] = entry.value;
    }
    return result;
  }

  static Map<String, int> parseMap(Object? value, {required String field}) {
    if (value is! Map) {
      throw FormatException('$field doit être une map');
    }
    final result = <String, int>{};
    for (final entry in value.entries) {
      if (entry.key is! String ||
          entry.value is! num ||
          (entry.value as num).toInt() != entry.value) {
        throw FormatException('Quota invalide dans $field');
      }
      result[entry.key as String] = (entry.value as num).toInt();
    }
    return result;
  }

  factory ProfessionQuotas.fromMissionData(Map<String, dynamic> data) {
    final hasRequiredMap = data.containsKey('requiredByProfession');
    final hasRegisteredMap = data.containsKey('registeredByProfession');
    if (hasRequiredMap || hasRegisteredMap) {
      return ProfessionQuotas.fromMaps(
        requiredByProfession: hasRequiredMap
            ? parseMap(
                data['requiredByProfession'],
                field: 'requiredByProfession',
              )
            : const {},
        registeredByProfession: hasRegisteredMap
            ? parseMap(
                data['registeredByProfession'],
                field: 'registeredByProfession',
              )
            : const {},
      );
    }
    return ProfessionQuotas.fromLegacyMkPp(
      requiredMk: _legacyInt(data['requiredMk']),
      registeredMk: _legacyInt(data['registeredMk']),
      requiredPp: _legacyInt(data['requiredPp']),
      registeredPp: _legacyInt(data['registeredPp']),
    );
  }

  static int _legacyInt(Object? value) =>
      value is num && value >= 0 && value.toInt() == value ? value.toInt() : 0;

  List<ProfessionQuota> get values => List.unmodifiable(_byProfession.values);

  ProfessionQuota quotaFor(String professionId) {
    return _byProfession[professionId] ??
        ProfessionQuota(professionId: professionId, required: 0, registered: 0);
  }

  Map<String, int> get requiredByProfession => Map.unmodifiable({
    for (final entry in _byProfession.entries) entry.key: entry.value.required,
  });

  Map<String, int> get registeredByProfession => Map.unmodifiable({
    for (final entry in _byProfession.entries)
      entry.key: entry.value.registered,
  });

  ProfessionQuotas updateRegistered(String professionId, int delta) {
    final id = HealthProfessionId.normalize(professionId);
    final current = quotaFor(id);
    final next = current.registered + delta;
    if (next < 0) throw StateError('Un compteur ne peut pas être négatif.');
    return ProfessionQuotas([
      for (final quota in values)
        quota.professionId == id ? quota.copyWith(registered: next) : quota,
    ]);
  }

  Map<String, dynamic> toMissionUpdate() => {
    'requiredByProfession': requiredByProfession,
    'registeredByProfession': registeredByProfession,
    'requiredMk': quotaFor(HealthProfessionId.physiotherapist).required,
    'registeredMk': quotaFor(HealthProfessionId.physiotherapist).registered,
    'requiredPp': quotaFor(HealthProfessionId.podiatrist).required,
    'registeredPp': quotaFor(HealthProfessionId.podiatrist).registered,
  };

  int get requiredTotal =>
      _byProfession.values.fold(0, (total, quota) => total + quota.required);

  int get registeredTotal =>
      _byProfession.values.fold(0, (total, quota) => total + quota.registered);

  bool get isCovered => _byProfession.values.every((quota) => quota.isCovered);

  double get coverage => requiredTotal == 0
      ? 1
      : (registeredTotal / requiredTotal).clamp(0, 1).toDouble();
}
