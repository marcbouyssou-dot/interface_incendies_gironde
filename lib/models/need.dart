import 'health_profession.dart';
import 'profession_quotas.dart';

enum NeedStatus { critical, toComplete, complete }

enum VolunteerProfession { mk, pp, doctor, nurse, otherHealthProfessional }

extension VolunteerProfessionLabel on VolunteerProfession {
  String? get canonicalId => switch (this) {
    VolunteerProfession.mk => HealthProfessionId.physiotherapist,
    VolunteerProfession.pp => HealthProfessionId.podiatrist,
    VolunteerProfession.doctor => HealthProfessionId.physician,
    VolunteerProfession.nurse => HealthProfessionId.nurse,
    VolunteerProfession.otherHealthProfessional =>
      HealthProfessionId.otherHealthProfessional,
  };

  String get label => HealthProfessionRegistry.byId(canonicalId!)!.label;

  bool get isSupportedByCurrentMission =>
      this == VolunteerProfession.mk || this == VolunteerProfession.pp;
}

VolunteerProfession volunteerProfessionFromId(String value) {
  return switch (HealthProfessionId.normalize(value)) {
    HealthProfessionId.physiotherapist => VolunteerProfession.mk,
    HealthProfessionId.podiatrist => VolunteerProfession.pp,
    HealthProfessionId.physician => VolunteerProfession.doctor,
    HealthProfessionId.nurse => VolunteerProfession.nurse,
    HealthProfessionId.otherHealthProfessional =>
      VolunteerProfession.otherHealthProfessional,
    _ => throw FormatException('Profession inconnue : $value'),
  };
}

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
  interventionSector,
  civilianReceptionSite,
  redCross,
  otherPartnerSite,
}

extension ResponsePlaceTypeLabel on ResponsePlaceType {
  String get label => switch (this) {
    ResponsePlaceType.sdisStation => 'Caserne SDIS',
    ResponsePlaceType.interventionSector => 'Secteur sans CIS autonome',
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
    this.createdBy,
    ProfessionQuotas? professionQuotas,
  }) : _professionQuotas = professionQuotas;

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
  final String? createdBy;
  final ProfessionQuotas? _professionQuotas;

  String get area => group.label;

  ProfessionQuotas get professionQuotas =>
      _professionQuotas ??
      ProfessionQuotas.fromLegacyMkPp(
        requiredMk: requiredPhysiotherapists,
        registeredMk: registeredPhysiotherapists,
        requiredPp: requiredPodiatrists,
        registeredPp: registeredPodiatrists,
      );

  int get requiredPeople => professionQuotas.requiredTotal;
  int get registeredPeople => professionQuotas.registeredTotal;

  double get coverage => professionQuotas.coverage;

  NeedStatus get status {
    if (professionQuotas.isCovered) {
      return NeedStatus.complete;
    }
    if (coverage < .5) return NeedStatus.critical;
    return NeedStatus.toComplete;
  }

  CoordinationNeed copyWith({
    int? registeredPhysiotherapists,
    int? registeredPodiatrists,
    String? createdBy,
    ProfessionQuotas? professionQuotas,
  }) {
    final quotas = professionQuotas ?? _professionQuotas;
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
      createdBy: createdBy ?? this.createdBy,
      professionQuotas: quotas,
    );
  }

  CoordinationNeed withProfessionQuotas(ProfessionQuotas quotas) {
    final mk = quotas.quotaFor(HealthProfessionId.physiotherapist);
    final pp = quotas.quotaFor(HealthProfessionId.podiatrist);
    return copyWith(
      registeredPhysiotherapists: mk.registered,
      registeredPodiatrists: pp.registered,
      professionQuotas: quotas,
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
    this.isOperational = true,
  });

  final String id;
  final String name;
  final ResponsePlaceType type;
  final TerritorialGroup group;
  final String? address;
  final LocationAddress? structuredAddress;
  final bool isOperational;
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
    this.secondSourceUrl,
    this.secondSourceLabel,
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
  final String? secondSourceUrl;
  final String? secondSourceLabel;
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
