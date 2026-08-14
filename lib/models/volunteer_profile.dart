import 'need.dart';

enum ProfessionalIdType { rpps, ordinal, none }

extension ProfessionalIdTypeLabel on ProfessionalIdType {
  String get label => switch (this) {
    ProfessionalIdType.rpps => 'RPPS',
    ProfessionalIdType.ordinal => 'Numéro ordinal',
    ProfessionalIdType.none => 'Aucun identifiant',
  };
}

bool isValidProfessionalIdentifier(ProfessionalIdType type, String? value) {
  return (type == ProfessionalIdType.rpps ||
          type == ProfessionalIdType.ordinal) &&
      (value?.trim().isNotEmpty ?? false);
}

class ProfessionalAddress {
  const ProfessionalAddress({
    this.line1,
    this.line2,
    this.postalCode,
    this.city,
    this.countryCode = 'FR',
  });

  final String? line1;
  final String? line2;
  final String? postalCode;
  final String? city;
  final String countryCode;

  String? get normalizedLine1 => _trimmedOrNull(line1);
  String? get normalizedLine2 => _trimmedOrNull(line2);
  String? get normalizedPostalCode => _trimmedOrNull(postalCode);
  String? get normalizedCity => _trimmedOrNull(city);
  String get normalizedCountryCode {
    final value = countryCode.trim().toUpperCase();
    return value.isEmpty ? 'FR' : value;
  }

  bool get isEmpty =>
      normalizedLine1 == null &&
      normalizedLine2 == null &&
      normalizedPostalCode == null &&
      normalizedCity == null;

  bool get isComplete => isEmpty || validationMessage == null;

  String? get validationMessage {
    if (isEmpty) return null;
    if ((normalizedLine1?.length ?? 0) > 240 ||
        (normalizedLine2?.length ?? 0) > 240 ||
        (normalizedPostalCode?.length ?? 0) > 16 ||
        (normalizedCity?.length ?? 0) > 120) {
      return 'L’adresse professionnelle est trop longue.';
    }
    if (normalizedLine1 == null) {
      return 'Renseignez l’adresse professionnelle.';
    }
    if (normalizedPostalCode == null) {
      return 'Renseignez le code postal professionnel.';
    }
    if (normalizedCity == null) {
      return 'Renseignez la ville professionnelle.';
    }
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalizedCountryCode)) {
      return 'Le code pays doit contenir deux lettres.';
    }
    final postalCode = normalizedPostalCode!;
    if (normalizedCountryCode == 'FR') {
      if (!RegExp(r'^\d{5}$').hasMatch(postalCode)) {
        return 'Le code postal doit contenir exactement 5 chiffres.';
      }
    } else if (!RegExp(
      r'^[A-Za-z0-9][A-Za-z0-9 -]{1,15}$',
    ).hasMatch(postalCode)) {
      return 'Le code postal est invalide.';
    }
    return null;
  }

  String get addressLineLabel =>
      [normalizedLine1, normalizedLine2].whereType<String>().join(', ');

  String get localityLabel =>
      [normalizedPostalCode, normalizedCity].whereType<String>().join(' · ');
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class VolunteerProfile {
  const VolunteerProfile({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.profession,
    this.email,
    this.rpps,
    this.professionalIdType,
    this.professionalIdValue,
    this.cptsId,
    this.cptsLabel,
    this.professionalAddressLine1,
    this.professionalAddressLine2,
    this.professionalPostalCode,
    this.professionalCity,
    this.professionalCountryCode = 'FR',
    this.equipment = const [],
    this.otherEquipmentDetails,
    this.verificationStatus,
    this.verificationSource,
    this.verifiedFirstName,
    this.verifiedLastName,
    this.verifiedProfessionCode,
    this.verifiedProfessionLabel,
    this.verifiedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String? rpps;
  final ProfessionalIdType? professionalIdType;
  final String? professionalIdValue;
  final String? cptsId;
  final String? cptsLabel;
  final String? professionalAddressLine1;
  final String? professionalAddressLine2;
  final String? professionalPostalCode;
  final String? professionalCity;
  final String professionalCountryCode;
  final VolunteerProfession profession;
  final List<String> equipment;
  final String? otherEquipmentDetails;
  final String? verificationStatus;
  final String? verificationSource;
  final String? verifiedFirstName;
  final String? verifiedLastName;
  final String? verifiedProfessionCode;
  final String? verifiedProfessionLabel;
  final DateTime? verifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName => '$firstName $lastName'.trim();
  ProfessionalIdType get effectiveProfessionalIdType =>
      professionalIdType ??
      ((rpps?.trim().isNotEmpty ?? false)
          ? ProfessionalIdType.rpps
          : ProfessionalIdType.none);
  String get effectiveProfessionalIdValue =>
      (professionalIdValue ??
              (effectiveProfessionalIdType == ProfessionalIdType.rpps
                  ? rpps
                  : null) ??
              '')
          .trim();

  bool get hasValidProfessionalIdentifier => isValidProfessionalIdentifier(
    effectiveProfessionalIdType,
    effectiveProfessionalIdValue,
  );

  ProfessionalAddress get professionalAddress => ProfessionalAddress(
    line1: professionalAddressLine1,
    line2: professionalAddressLine2,
    postalCode: professionalPostalCode,
    city: professionalCity,
    countryCode: professionalCountryCode,
  );

  bool get hasProfessionalAddress => !professionalAddress.isEmpty;
  bool get hasCompleteProfessionalAddress => professionalAddress.isComplete;

  bool get hasVerifiedProfessionalIdentity =>
      verificationStatus == 'verified' &&
      verificationSource == 'ans_rpps' &&
      effectiveProfessionalIdType == ProfessionalIdType.rpps &&
      RegExp(r'^\d{11}$').hasMatch(effectiveProfessionalIdValue) &&
      (rpps == null || rpps!.trim() == effectiveProfessionalIdValue) &&
      (verifiedFirstName?.trim().isNotEmpty ?? false) &&
      (verifiedLastName?.trim().isNotEmpty ?? false) &&
      verifiedProfessionCode?.trim() == _expectedRppsProfessionCode &&
      (verifiedProfessionLabel?.trim().isNotEmpty ?? false) &&
      verifiedAt != null;

  String? get _expectedRppsProfessionCode => switch (profession) {
    VolunteerProfession.doctor => '10',
    VolunteerProfession.nurse => '60',
    VolunteerProfession.mk => '70',
    VolunteerProfession.pp => '80',
    VolunteerProfession.veterinarian ||
    VolunteerProfession.otherHealthProfessional => null,
  };

  VolunteerProfile copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? rpps,
    ProfessionalIdType? professionalIdType,
    String? professionalIdValue,
    String? cptsId,
    String? cptsLabel,
    String? professionalAddressLine1,
    String? professionalAddressLine2,
    String? professionalPostalCode,
    String? professionalCity,
    String? professionalCountryCode,
    VolunteerProfession? profession,
    List<String>? equipment,
    String? otherEquipmentDetails,
    String? verificationStatus,
    String? verificationSource,
    String? verifiedFirstName,
    String? verifiedLastName,
    String? verifiedProfessionCode,
    String? verifiedProfessionLabel,
    DateTime? verifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VolunteerProfile(
      uid: uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      rpps: rpps ?? this.rpps,
      professionalIdType: professionalIdType ?? this.professionalIdType,
      professionalIdValue: professionalIdValue ?? this.professionalIdValue,
      cptsId: cptsId ?? this.cptsId,
      cptsLabel: cptsLabel ?? this.cptsLabel,
      professionalAddressLine1:
          professionalAddressLine1 ?? this.professionalAddressLine1,
      professionalAddressLine2:
          professionalAddressLine2 ?? this.professionalAddressLine2,
      professionalPostalCode:
          professionalPostalCode ?? this.professionalPostalCode,
      professionalCity: professionalCity ?? this.professionalCity,
      professionalCountryCode:
          professionalCountryCode ?? this.professionalCountryCode,
      profession: profession ?? this.profession,
      equipment: equipment ?? this.equipment,
      otherEquipmentDetails:
          otherEquipmentDetails ?? this.otherEquipmentDetails,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationSource: verificationSource ?? this.verificationSource,
      verifiedFirstName: verifiedFirstName ?? this.verifiedFirstName,
      verifiedLastName: verifiedLastName ?? this.verifiedLastName,
      verifiedProfessionCode:
          verifiedProfessionCode ?? this.verifiedProfessionCode,
      verifiedProfessionLabel:
          verifiedProfessionLabel ?? this.verifiedProfessionLabel,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
