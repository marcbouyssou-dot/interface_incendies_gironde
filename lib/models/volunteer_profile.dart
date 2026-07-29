import 'need.dart';

enum ProfessionalIdType { rpps, ordinal, none }

extension ProfessionalIdTypeLabel on ProfessionalIdType {
  String get label => switch (this) {
    ProfessionalIdType.rpps => 'RPPS',
    ProfessionalIdType.ordinal => 'Numéro ordinal',
    ProfessionalIdType.none => 'Aucun identifiant',
  };
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
