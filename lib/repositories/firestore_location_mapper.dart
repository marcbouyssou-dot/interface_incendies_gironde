import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/need.dart';

abstract final class FirestoreLocationMapper {
  static ResponsePlace fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ResponsePlace(
      id: id,
      name: data['name'] as String? ?? 'À renseigner',
      type: _enumByName(
        ResponsePlaceType.values,
        data['type'] as String?,
        ResponsePlaceType.otherPartnerSite,
      ),
      group: _enumByName(
        TerritorialGroup.values,
        data['group'] as String? ?? data['territorialGroup'] as String?,
        TerritorialGroup.partnerSites,
      ),
      activeNeeds: _int(data['activeNeeds']),
      address: data['address'] as String?,
      structuredAddress: _structuredAddress(data),
      contactName: data['contactName'] as String?,
      contactPhone: data['contactPhone'] as String?,
      isOperational: data['isOperational'] as bool? ?? true,
    );
  }

  static LocationAddress? _structuredAddress(Map<String, dynamic> data) {
    final statusValue = data['addressStatus'];
    if (statusValue == null &&
        data['addressLine1'] == null &&
        data['fullAddress'] == null) {
      return null;
    }
    return LocationAddress(
      addressLine1: data['addressLine1'] as String?,
      addressLine2: data['addressLine2'] as String?,
      postalCode: data['postalCode'] as String?,
      city: data['city'] as String?,
      country: data['country'] as String? ?? 'France',
      storedFullAddress: data['fullAddress'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      status: AddressStatus.fromFirestore(statusValue),
      sourceUrl: data['addressSourceUrl'] as String?,
      sourceLabel: data['addressSourceLabel'] as String?,
      secondSourceUrl: data['addressSecondSourceUrl'] as String?,
      secondSourceLabel: data['addressSecondSourceLabel'] as String?,
      verifiedAt: (data['addressVerifiedAt'] as Timestamp?)?.toDate(),
      notes: data['addressNotes'] as String?,
    );
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;
}
