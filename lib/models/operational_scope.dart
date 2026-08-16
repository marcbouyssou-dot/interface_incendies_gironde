enum OperationalScopeKind { territory, location }

extension OperationalScopeKindValue on OperationalScopeKind {
  String get collection => switch (this) {
    OperationalScopeKind.territory => 'territories',
    OperationalScopeKind.location => 'locations',
  };
}

class OperationalScopeRef {
  const OperationalScopeRef({required this.kind, required this.id});

  factory OperationalScopeRef.fromValue(Object? value) {
    if (value is! String) {
      throw const FormatException('Périmètre opérationnel invalide.');
    }
    final parts = value.split('/');
    if (parts.length != 2 || !_validId(parts[1])) {
      throw const FormatException('Périmètre opérationnel invalide.');
    }
    final kind = OperationalScopeKind.values.firstWhere(
      (candidate) => candidate.collection == parts[0],
      orElse: () =>
          throw const FormatException('Périmètre opérationnel invalide.'),
    );
    return OperationalScopeRef(kind: kind, id: parts[1]);
  }

  final OperationalScopeKind kind;
  final String id;

  String get serializedValue => '${kind.collection}/$id';

  static bool _validId(String value) =>
      value.isNotEmpty &&
      value.length <= 160 &&
      value.trim() == value &&
      !value.contains('/');
}
