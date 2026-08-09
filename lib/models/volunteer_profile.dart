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
