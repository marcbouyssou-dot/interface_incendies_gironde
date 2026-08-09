class Territory {
  const Territory({
    required this.id,
    required this.name,
    required this.code,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Territory.fromMap(Map<String, Object?> data) {
    return Territory(
      id: _requiredText(data, 'id'),
      name: _requiredText(data, 'name'),
      code: _requiredText(data, 'code'),
      active: _requiredValue<bool>(data, 'active'),
      createdAt: _requiredValue<DateTime>(data, 'createdAt'),
      updatedAt: _requiredValue<DateTime>(data, 'updatedAt'),
    );
  }

  final String id;
  final String name;
  final String code;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'code': code,
    'active': active,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

T _requiredValue<T>(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! T) throw const FormatException('Territoire invalide.');
  return value;
}

String _requiredText(Map<String, Object?> data, String key) {
  final value = _requiredValue<String>(data, key);
  if (value.trim().isEmpty) {
    throw const FormatException('Territoire invalide.');
  }
  return value;
}
