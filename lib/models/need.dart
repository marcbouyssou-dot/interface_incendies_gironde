enum NeedStatus { critical, toComplete, complete }

enum VolunteerProfession { mk, pp }

enum TerritorialGroup {
  bordeauxMetropole,
  northBasin,
  southBasin,
  medoc,
  southGironde,
  libournais,
  hauteGironde,
  partnerSites,
}

extension TerritorialGroupLabel on TerritorialGroup {
  String get label => switch (this) {
    TerritorialGroup.bordeauxMetropole => 'Bordeaux Métropole',
    TerritorialGroup.northBasin => 'Nord Bassin',
    TerritorialGroup.southBasin => 'Sud Bassin',
    TerritorialGroup.medoc => 'Médoc',
    TerritorialGroup.southGironde => 'Sud Gironde',
    TerritorialGroup.libournais => 'Libournais',
    TerritorialGroup.hauteGironde => 'Haute Gironde',
    TerritorialGroup.partnerSites => 'Sites partenaires',
  };
}

enum ResponsePlaceType {
  sdisStation,
  civilianReceptionSite,
  redCross,
  otherPartnerSite,
}

extension ResponsePlaceTypeLabel on ResponsePlaceType {
  String get label => switch (this) {
    ResponsePlaceType.sdisStation => 'Caserne SDIS',
    ResponsePlaceType.civilianReceptionSite => 'Site d’accueil des civils',
    ResponsePlaceType.redCross => 'Croix-Rouge',
    ResponsePlaceType.otherPartnerSite => 'Autre site partenaire',
  };
}

class Volunteer {
  const Volunteer({
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    required this.profession,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final VolunteerProfession profession;
}

class CoordinationNeed {
  const CoordinationNeed({
    required this.id,
    required this.place,
    required this.group,
    required this.date,
    required this.time,
    required this.requiredPhysiotherapists,
    required this.registeredPhysiotherapists,
    required this.requiredPodiatrists,
    required this.registeredPodiatrists,
    required this.equipment,
    this.locationId,
    this.startAt,
    this.endAt,
    this.details,
    this.isActive = true,
    this.isCancelled = false,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
  });

  final String id;
  final String place;
  final TerritorialGroup group;
  final String date;
  final String time;
  final int requiredPhysiotherapists;
  final int registeredPhysiotherapists;
  final int requiredPodiatrists;
  final int registeredPodiatrists;
  final List<String> equipment;
  final String? locationId;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? details;
  final bool isActive;
  final bool isCancelled;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancellationReason;

  String get area => group.label;

  int get requiredPeople => requiredPhysiotherapists + requiredPodiatrists;
  int get registeredPeople =>
      registeredPhysiotherapists + registeredPodiatrists;

  double get coverage => requiredPeople == 0
      ? 1
      : (registeredPeople / requiredPeople).clamp(0, 1).toDouble();

  NeedStatus get status {
    final physiotherapistsCovered =
        registeredPhysiotherapists >= requiredPhysiotherapists;
    final podiatristsCovered = registeredPodiatrists >= requiredPodiatrists;
    if (physiotherapistsCovered && podiatristsCovered) {
      return NeedStatus.complete;
    }
    if (coverage < .5) return NeedStatus.critical;
    return NeedStatus.toComplete;
  }

  CoordinationNeed copyWith({
    int? registeredPhysiotherapists,
    int? registeredPodiatrists,
  }) {
    return CoordinationNeed(
      id: id,
      place: place,
      group: group,
      date: date,
      time: time,
      requiredPhysiotherapists: requiredPhysiotherapists,
      registeredPhysiotherapists:
          registeredPhysiotherapists ?? this.registeredPhysiotherapists,
      requiredPodiatrists: requiredPodiatrists,
      registeredPodiatrists:
          registeredPodiatrists ?? this.registeredPodiatrists,
      equipment: equipment,
      locationId: locationId,
      startAt: startAt,
      endAt: endAt,
      details: details,
      isActive: isActive,
      isCancelled: isCancelled,
      cancelledAt: cancelledAt,
      cancelledBy: cancelledBy,
      cancellationReason: cancellationReason,
    );
  }
}

class ResponsePlace {
  const ResponsePlace({
    required this.id,
    required this.name,
    required this.type,
    required this.group,
    required this.activeNeeds,
    this.address,
    this.structuredAddress,
  });

  final String id;
  final String name;
  final ResponsePlaceType type;
  final TerritorialGroup group;
  final String? address;
  final LocationAddress? structuredAddress;
  final int activeNeeds;

  bool get isActive => activeNeeds > 0;

  String? get verifiedAddress {
    final value = structuredAddress;
    if (value != null && value.isVerified) return value.fullAddress;
    if (value == null && address != null && address!.trim().isNotEmpty) {
      return address;
    }
    return null;
  }

  String get publicAddressLabel {
    if (verifiedAddress != null) return verifiedAddress!;
    if (structuredAddress?.status == AddressStatus.needsConfirmation) {
      return 'Adresse à confirmer';
    }
    return 'Adresse à renseigner';
  }
}

enum AddressStatus {
  verifiedOfficial('verified_official'),
  verifiedCrossSource('verified_cross_source'),
  needsConfirmation('needs_confirmation'),
  notFound('not_found');

  const AddressStatus(this.firestoreValue);
  final String firestoreValue;

  static AddressStatus fromFirestore(Object? value) {
    return values.firstWhere(
      (status) => status.firestoreValue == value,
      orElse: () => AddressStatus.notFound,
    );
  }
}

class LocationAddress {
  const LocationAddress({
    this.addressLine1,
    this.addressLine2,
    this.postalCode,
    this.city,
    this.country = 'France',
    this.storedFullAddress,
    this.latitude,
    this.longitude,
    this.status = AddressStatus.notFound,
    this.sourceUrl,
    this.sourceLabel,
    this.verifiedAt,
    this.notes,
  });

  final String? addressLine1;
  final String? addressLine2;
  final String? postalCode;
  final String? city;
  final String country;
  final String? storedFullAddress;
  final double? latitude;
  final double? longitude;
  final AddressStatus status;
  final String? sourceUrl;
  final String? sourceLabel;
  final DateTime? verifiedAt;
  final String? notes;

  bool get isVerified =>
      status == AddressStatus.verifiedOfficial ||
      status == AddressStatus.verifiedCrossSource;

  String get fullAddress {
    final stored = storedFullAddress?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return [
      addressLine1,
      addressLine2,
      [
        postalCode,
        city,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' '),
      country,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
  }
}
