import 'operational_scope.dart';
import 'organization_visibility.dart';

enum OperationType {
  emergency,
  healthCrisis,
  naturalDisaster,
  event,
  prevention,
  exercise,
  humanitarian,
  other,
}

extension OperationTypeValue on OperationType {
  String get serializedValue => switch (this) {
    OperationType.emergency => 'emergency',
    OperationType.healthCrisis => 'health_crisis',
    OperationType.naturalDisaster => 'natural_disaster',
    OperationType.event => 'event',
    OperationType.prevention => 'prevention',
    OperationType.exercise => 'exercise',
    OperationType.humanitarian => 'humanitarian',
    OperationType.other => 'other',
  };
}

OperationType operationTypeFromValue(Object? value) {
  return OperationType.values.firstWhere(
    (type) => type.serializedValue == value,
    orElse: () => throw const FormatException('Type d’opération invalide.'),
  );
}

enum OperationStatus { draft, planned, active, suspended, completed, archived }

extension OperationStatusValue on OperationStatus {
  String get serializedValue => name;

  bool canTransitionTo(OperationStatus target) => switch ((this, target)) {
    (OperationStatus.draft, OperationStatus.planned) => true,
    (OperationStatus.draft, OperationStatus.archived) => true,
    (OperationStatus.planned, OperationStatus.active) => true,
    (OperationStatus.planned, OperationStatus.archived) => true,
    (OperationStatus.active, OperationStatus.suspended) => true,
    (OperationStatus.active, OperationStatus.completed) => true,
    (OperationStatus.suspended, OperationStatus.active) => true,
    (OperationStatus.suspended, OperationStatus.completed) => true,
    (OperationStatus.completed, OperationStatus.archived) => true,
    _ => false,
  };
}

OperationStatus operationStatusFromValue(Object? value) {
  return OperationStatus.values.firstWhere(
    (status) => status.serializedValue == value,
    orElse: () => throw const FormatException('Statut d’opération invalide.'),
  );
}

enum OperationPurpose { operational, demonstration }

OperationPurpose operationPurposeFromValue(Object? value) =>
    OperationPurpose.values.firstWhere(
      (purpose) => purpose.name == value,
      orElse: () =>
          throw const FormatException('Finalité d’opération invalide.'),
    );

/// Provenance technique d'une importation, sans identité de personne source.
class OperationProvenance {
  const OperationProvenance({
    required this.sourceDataset,
    required this.sourceObjectType,
    required this.migrationLot,
    required this.migrationDate,
  });

  factory OperationProvenance.fromMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Provenance d’opération invalide.');
    }
    final data = Map<String, Object?>.from(value);
    final rawDate = _requiredOperationText(data, 'migrationDate');
    final parsedDate = DateTime.tryParse(rawDate);
    if (parsedDate == null || !parsedDate.isUtc || !rawDate.endsWith('Z')) {
      throw const FormatException('Date de migration invalide.');
    }
    return OperationProvenance(
      sourceDataset: _requiredOperationText(data, 'sourceDataset'),
      sourceObjectType: _requiredOperationText(data, 'sourceObjectType'),
      migrationLot: _requiredOperationText(data, 'migrationLot'),
      migrationDate: parsedDate,
    );
  }

  final String sourceDataset;
  final String sourceObjectType;
  final String migrationLot;
  final DateTime migrationDate;

  Map<String, Object?> toMap() => {
    'sourceDataset': sourceDataset,
    'sourceObjectType': sourceObjectType,
    'migrationLot': migrationLot,
    'migrationDate': migrationDate.toUtc().toIso8601String(),
  };
}

class Operation {
  const Operation({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.startAt,
    required this.scopeRefs,
    required this.createdBy,
    required this.createdAt,
    required this.updatedBy,
    required this.updatedAt,
    required this.schemaVersion,
    this.context,
    this.endAt,
    this.coordinatorUid,
    this.ownerOrganizationId,
    this.visibility,
    this.purpose = OperationPurpose.operational,
    this.themeKey,
    this.organizerDisplayName,
    this.demoSafetyLabel,
    this.provenance,
  });

  factory Operation.fromMap(Map<String, Object?> data) {
    final scopeValues = _requiredOperationValue<List<Object?>>(
      data,
      'scopeRefs',
    );
    final scopeRefs = scopeValues
        .map(OperationalScopeRef.fromValue)
        .toList(growable: false);
    if (scopeRefs.map((ref) => ref.serializedValue).toSet().length !=
        scopeRefs.length) {
      throw const FormatException('Opération invalide.');
    }
    final startAt = _requiredOperationValue<DateTime>(data, 'startAt');
    final endAt = _optionalOperationDateTime(data, 'endAt');
    if (endAt != null && !endAt.isAfter(startAt)) {
      throw const FormatException('Opération invalide.');
    }
    final schemaVersion = _requiredOperationValue<int>(data, 'schemaVersion');
    if (schemaVersion < 1) throw const FormatException('Opération invalide.');
    final purpose = data['purpose'] == null
        ? OperationPurpose.operational
        : operationPurposeFromValue(data['purpose']);
    final demoSafetyLabel = _optionalOperationText(data, 'demoSafetyLabel');
    if (purpose == OperationPurpose.demonstration && demoSafetyLabel == null) {
      throw const FormatException('Label de démonstration requis.');
    }
    return Operation(
      id: _requiredOperationText(data, 'id'),
      name: _requiredOperationText(data, 'name'),
      type: operationTypeFromValue(data['type']),
      status: operationStatusFromValue(data['status']),
      context: _optionalOperationText(data, 'context'),
      startAt: startAt,
      endAt: endAt,
      coordinatorUid: _optionalOperationUid(data, 'coordinatorUid'),
      ownerOrganizationId: _optionalOrganizationId(data, 'ownerOrganizationId'),
      visibility: _optionalOperationVisibility(data, 'visibility'),
      scopeRefs: scopeRefs,
      createdBy: _requiredOperationText(data, 'createdBy'),
      createdAt: _requiredOperationValue<DateTime>(data, 'createdAt'),
      updatedBy: _requiredOperationText(data, 'updatedBy'),
      updatedAt: _requiredOperationValue<DateTime>(data, 'updatedAt'),
      schemaVersion: schemaVersion,
      purpose: purpose,
      themeKey: _optionalOperationText(data, 'themeKey'),
      organizerDisplayName: _optionalOperationText(
        data,
        'organizerDisplayName',
      ),
      demoSafetyLabel: demoSafetyLabel,
      provenance: data['provenance'] == null
          ? null
          : OperationProvenance.fromMap(data['provenance']),
    );
  }

  final String id;
  final String name;
  final OperationType type;
  final OperationStatus status;
  final String? context;
  final DateTime startAt;
  final DateTime? endAt;
  final String? coordinatorUid;
  final String? ownerOrganizationId;

  /// Visibilité effective choisie pour cette opération.
  ///
  /// Une valeur absente est réservée à la compatibilité additive RC3 et doit
  /// être résolue par le service de visibilité central. Le défaut porté par
  /// l'organisation sert à initialiser une nouvelle opération ; il ne modifie
  /// jamais rétroactivement une valeur explicite déjà enregistrée.
  final OrganizationVisibility? visibility;
  final List<OperationalScopeRef> scopeRefs;
  final String createdBy;
  final DateTime createdAt;
  final String updatedBy;
  final DateTime updatedAt;
  final int schemaVersion;
  final OperationPurpose purpose;
  final String? themeKey;
  final String? organizerDisplayName;
  final String? demoSafetyLabel;
  final OperationProvenance? provenance;

  bool get isEngageable =>
      purpose == OperationPurpose.operational &&
      status == OperationStatus.active;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'type': type.serializedValue,
    'status': status.serializedValue,
    'context': context,
    'startAt': startAt,
    'endAt': endAt,
    if (coordinatorUid != null) 'coordinatorUid': coordinatorUid,
    if (ownerOrganizationId != null) 'ownerOrganizationId': ownerOrganizationId,
    if (visibility != null) 'visibility': visibility!.serializedValue,
    'scopeRefs': scopeRefs.map((ref) => ref.serializedValue).toList(),
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedBy': updatedBy,
    'updatedAt': updatedAt,
    'schemaVersion': schemaVersion,
    if (purpose != OperationPurpose.operational) 'purpose': purpose.name,
    if (themeKey != null) 'themeKey': themeKey,
    if (organizerDisplayName != null)
      'organizerDisplayName': organizerDisplayName,
    if (demoSafetyLabel != null) 'demoSafetyLabel': demoSafetyLabel,
    if (provenance != null) 'provenance': provenance!.toMap(),
  };
}

T _requiredOperationValue<T>(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! T) throw const FormatException('Opération invalide.');
  return value;
}

String _requiredOperationText(Map<String, Object?> data, String key) {
  final value = _requiredOperationValue<String>(data, key);
  if (value.trim().isEmpty || value.trim() != value) {
    throw const FormatException('Opération invalide.');
  }
  return value;
}

String? _optionalOperationText(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty || value.trim() != value) {
    throw const FormatException('Opération invalide.');
  }
  return value;
}

DateTime? _optionalOperationDateTime(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! DateTime) throw const FormatException('Opération invalide.');
  return value;
}

String? _optionalOperationUid(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      value.trim() != value ||
      value.contains('/')) {
    throw const FormatException('Opération invalide.');
  }
  return value;
}

String? _optionalOrganizationId(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! String ||
      value.isEmpty ||
      value.length > 160 ||
      value.trim() != value ||
      value.contains('/')) {
    throw const FormatException('Opération invalide.');
  }
  return value;
}

OrganizationVisibility? _optionalOperationVisibility(
  Map<String, Object?> data,
  String key,
) {
  final value = data[key];
  return value == null ? null : organizationVisibilityFromValue(value);
}
