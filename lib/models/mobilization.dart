enum MobilizationContextType { fire, flood, heatwave, event, whitePlan, other }

extension MobilizationContextTypeValue on MobilizationContextType {
  String get serializedValue => switch (this) {
    MobilizationContextType.fire => 'fire',
    MobilizationContextType.flood => 'flood',
    MobilizationContextType.heatwave => 'heatwave',
    MobilizationContextType.event => 'event',
    MobilizationContextType.whitePlan => 'white_plan',
    MobilizationContextType.other => 'other',
  };
}

MobilizationContextType mobilizationContextTypeFromValue(Object? value) {
  return MobilizationContextType.values.firstWhere(
    (type) => type.serializedValue == value,
    orElse: () =>
        throw const FormatException('Contexte de mobilisation invalide.'),
  );
}

enum MobilizationStatus { draft, active, inactive, archived }

extension MobilizationStatusValue on MobilizationStatus {
  String get serializedValue => name;

  bool canTransitionTo(
    MobilizationStatus target, {
    bool allowActiveArchiving = false,
  }) {
    return switch ((this, target)) {
      (MobilizationStatus.draft, MobilizationStatus.active) => true,
      (MobilizationStatus.draft, MobilizationStatus.archived) => true,
      (MobilizationStatus.active, MobilizationStatus.inactive) => true,
      (MobilizationStatus.active, MobilizationStatus.archived) =>
        allowActiveArchiving,
      (MobilizationStatus.inactive, MobilizationStatus.active) => true,
      (MobilizationStatus.inactive, MobilizationStatus.archived) => true,
      _ => false,
    };
  }
}

MobilizationStatus mobilizationStatusFromValue(Object? value) {
  return MobilizationStatus.values.firstWhere(
    (status) => status.serializedValue == value,
    orElse: () =>
        throw const FormatException('Statut de mobilisation invalide.'),
  );
}

class Mobilization {
  const Mobilization({
    required this.id,
    required this.territoryId,
    required this.name,
    required this.subtitle,
    required this.contextType,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    this.activatedBy,
    this.activatedAt,
    this.deactivatedBy,
    this.deactivatedAt,
    this.archivedBy,
    this.archivedAt,
  });

  factory Mobilization.fromMap(Map<String, Object?> data) {
    final schemaVersion = _requiredValue<int>(data, 'schemaVersion');
    if (schemaVersion < 1) {
      throw const FormatException('Mobilisation invalide.');
    }
    return Mobilization(
      id: _requiredText(data, 'id'),
      territoryId: _requiredText(data, 'territoryId'),
      name: _requiredText(data, 'name'),
      subtitle: _requiredText(data, 'subtitle'),
      contextType: mobilizationContextTypeFromValue(data['contextType']),
      status: mobilizationStatusFromValue(data['status']),
      createdBy: _requiredText(data, 'createdBy'),
      createdAt: _requiredValue<DateTime>(data, 'createdAt'),
      updatedAt: _requiredValue<DateTime>(data, 'updatedAt'),
      activatedBy: _optionalText(data, 'activatedBy'),
      activatedAt: _optionalDateTime(data, 'activatedAt'),
      deactivatedBy: _optionalText(data, 'deactivatedBy'),
      deactivatedAt: _optionalDateTime(data, 'deactivatedAt'),
      archivedBy: _optionalText(data, 'archivedBy'),
      archivedAt: _optionalDateTime(data, 'archivedAt'),
      schemaVersion: schemaVersion,
    );
  }

  final String id;
  final String territoryId;
  final String name;
  final String subtitle;
  final MobilizationContextType contextType;
  final MobilizationStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? activatedBy;
  final DateTime? activatedAt;
  final String? deactivatedBy;
  final DateTime? deactivatedAt;
  final String? archivedBy;
  final DateTime? archivedAt;
  final int schemaVersion;

  Map<String, Object?> toMap() => {
    'id': id,
    'territoryId': territoryId,
    'name': name,
    'subtitle': subtitle,
    'contextType': contextType.serializedValue,
    'status': status.serializedValue,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'activatedBy': activatedBy,
    'activatedAt': activatedAt,
    'deactivatedBy': deactivatedBy,
    'deactivatedAt': deactivatedAt,
    'archivedBy': archivedBy,
    'archivedAt': archivedAt,
    'schemaVersion': schemaVersion,
  };
}

T _requiredValue<T>(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! T) throw const FormatException('Mobilisation invalide.');
  return value;
}

String _requiredText(Map<String, Object?> data, String key) {
  final value = _requiredValue<String>(data, key);
  if (value.trim().isEmpty) {
    throw const FormatException('Mobilisation invalide.');
  }
  return value;
}

String? _optionalText(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Mobilisation invalide.');
  }
  return value;
}

DateTime? _optionalDateTime(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! DateTime) {
    throw const FormatException('Mobilisation invalide.');
  }
  return value;
}
