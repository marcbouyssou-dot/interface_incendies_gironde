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
    required this.profession,
  });

  final String firstName;
  final String lastName;
  final String phone;
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
  });

  final String id;
  final String name;
  final ResponsePlaceType type;
  final TerritorialGroup group;
  final String? address;
  final int activeNeeds;

  bool get isActive => activeNeeds > 0;
}
