import 'need.dart';

class AdminLocation {
  const AdminLocation({
    required this.id,
    required this.name,
    required this.group,
    required this.type,
    required this.active,
    required this.isOperational,
    required this.canDelete,
    this.addressLine1,
    this.addressLine2,
    this.postalCode,
    this.city,
    this.country = 'France',
    this.contactName,
    this.contactPhone,
    this.latitude,
    this.longitude,
  });

  factory AdminLocation.fromMap(Map<String, Object?> data) {
    final id = data['id'];
    final name = data['name'];
    final groupName = data['group'];
    final typeName = data['type'];
    final active = data['active'];
    final isOperational = data['isOperational'];
    final canDelete = data['canDelete'];
    if (id is! String ||
        name is! String ||
        groupName is! String ||
        typeName is! String ||
        active is! bool ||
        isOperational is! bool ||
        canDelete is! bool) {
      throw const FormatException('Lieu administratif invalide.');
    }
    return AdminLocation(
      id: id,
      name: name,
      group: TerritorialGroup.values.byName(groupName),
      type: ResponsePlaceType.values.byName(typeName),
      addressLine1: _optionalString(data['addressLine1']),
      addressLine2: _optionalString(data['addressLine2']),
      postalCode: _optionalString(data['postalCode']),
      city: _optionalString(data['city']),
      country: _optionalString(data['country']) ?? 'France',
      contactName: _optionalString(data['contactName']),
      contactPhone: _optionalString(data['contactPhone']),
      latitude: _optionalDouble(data['latitude']),
      longitude: _optionalDouble(data['longitude']),
      active: active,
      isOperational: isOperational,
      canDelete: canDelete,
    );
  }

  final String id;
  final String name;
  final TerritorialGroup group;
  final ResponsePlaceType type;
  final String? addressLine1;
  final String? addressLine2;
  final String? postalCode;
  final String? city;
  final String country;
  final String? contactName;
  final String? contactPhone;
  final double? latitude;
  final double? longitude;
  final bool active;
  final bool isOperational;
  final bool canDelete;

  String get addressLabel {
    final value = [
      addressLine1,
      addressLine2,
      [
        postalCode,
        city,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' '),
      if (addressLine1 != null || city != null || postalCode != null) country,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
    return value.isEmpty ? 'Adresse à renseigner' : value;
  }

  AdminLocationDraft toDraft() => AdminLocationDraft(
    id: id,
    name: name,
    group: group,
    type: type,
    addressLine1: addressLine1,
    addressLine2: addressLine2,
    postalCode: postalCode,
    city: city,
    country: country,
    contactName: contactName,
    contactPhone: contactPhone,
    latitude: latitude,
    longitude: longitude,
  );

  AdminLocation copyWith({
    String? name,
    TerritorialGroup? group,
    ResponsePlaceType? type,
    String? addressLine1,
    String? addressLine2,
    String? postalCode,
    String? city,
    String? country,
    String? contactName,
    String? contactPhone,
    double? latitude,
    double? longitude,
    bool? active,
    bool? isOperational,
    bool? canDelete,
  }) => AdminLocation(
    id: id,
    name: name ?? this.name,
    group: group ?? this.group,
    type: type ?? this.type,
    addressLine1: addressLine1 ?? this.addressLine1,
    addressLine2: addressLine2 ?? this.addressLine2,
    postalCode: postalCode ?? this.postalCode,
    city: city ?? this.city,
    country: country ?? this.country,
    contactName: contactName ?? this.contactName,
    contactPhone: contactPhone ?? this.contactPhone,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    active: active ?? this.active,
    isOperational: isOperational ?? this.isOperational,
    canDelete: canDelete ?? this.canDelete,
  );
}

class AdminLocationDraft {
  const AdminLocationDraft({
    required this.id,
    required this.name,
    required this.group,
    required this.type,
    this.addressLine1,
    this.addressLine2,
    this.postalCode,
    this.city,
    this.country = 'France',
    this.contactName,
    this.contactPhone,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final TerritorialGroup group;
  final ResponsePlaceType type;
  final String? addressLine1;
  final String? addressLine2;
  final String? postalCode;
  final String? city;
  final String country;
  final String? contactName;
  final String? contactPhone;
  final double? latitude;
  final double? longitude;

  Map<String, Object?> toCallableData() => {
    'name': name.trim(),
    'group': group.name,
    'type': type.name,
    'addressLine1': _trimmedOrNull(addressLine1),
    'addressLine2': _trimmedOrNull(addressLine2),
    'postalCode': _trimmedOrNull(postalCode),
    'city': _trimmedOrNull(city),
    'country': country.trim(),
    'contactName': _trimmedOrNull(contactName),
    'contactPhone': _trimmedOrNull(contactPhone),
    'latitude': latitude,
    'longitude': longitude,
  };
}

String? _optionalString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

double? _optionalDouble(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
