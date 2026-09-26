import 'need.dart';
import 'professional_equipment.dart';
import 'volunteer_profile.dart';

/// Information a profile must hold before an engagement can be attempted.
enum EngagementProfileGap {
  firstName,
  lastName,
  phone,
  email,
  professionalIdentifier,
  cptsLabel,
  equipmentDetails,
}

extension EngagementProfileGapLabel on EngagementProfileGap {
  String label(VolunteerProfession profession) => switch (this) {
    EngagementProfileGap.firstName => 'Prénom',
    EngagementProfileGap.lastName => 'Nom',
    EngagementProfileGap.phone => 'Téléphone',
    EngagementProfileGap.email => 'Email valide',
    EngagementProfileGap.professionalIdentifier =>
      profession == VolunteerProfession.veterinarian
          ? 'Numéro ordinal'
          : 'Identifiant professionnel (RPPS ou numéro ordinal)',
    EngagementProfileGap.cptsLabel => 'Nom de la CPTS (160 caractères maximum)',
    EngagementProfileGap.equipmentDetails => 'Précision sur le matériel',
  };
}

abstract final class ProfessionalProfileValidation {
  static bool isValidEmail(String? value) {
    final normalized = value?.trim() ?? '';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized);
  }

  static String? persistenceError({
    required String? email,
    required ProfessionalIdType professionalIdType,
    required String professionalIdValue,
    required String? cptsId,
    required String? cptsLabel,
    String? professionalAddressLine1,
    String? professionalAddressLine2,
    String? professionalPostalCode,
    String? professionalCity,
    String professionalCountryCode = 'FR',
    List<String> equipment = const [],
    String? otherEquipmentDetails,
  }) {
    if (!isValidEmail(email)) {
      return 'Saisissez une adresse email valide.';
    }
    final identifierError = professionalIdentifierValidationMessage(
      professionalIdType,
      professionalIdValue,
    );
    if (identifierError != null) return identifierError;
    if ((_trimmedOrNull(cptsId)?.length ?? 0) > 160 ||
        (_trimmedOrNull(cptsLabel)?.length ?? 0) > 160) {
      return 'Le nom de la CPTS est trop long.';
    }
    final addressError = ProfessionalAddress(
      line1: professionalAddressLine1,
      line2: professionalAddressLine2,
      postalCode: professionalPostalCode,
      city: professionalCity,
      countryCode: professionalCountryCode,
    ).validationMessage;
    if (addressError != null) return addressError;
    if (ProfessionalEquipmentRegistry.requiresDetails(equipment) &&
        _trimmedOrNull(otherEquipmentDetails) == null) {
      return 'Précisez le matériel que vous pouvez apporter.';
    }
    return null;
  }

  /// Single definition of "this profile can attempt an engagement".
  ///
  /// It is a superset of what `createEngagement()` and the Firestore rules
  /// refuse (valid email, complete identifier, CPTS length, equipment
  /// details), plus the identity fields every profile form already requires
  /// (first name, last name, phone). An empty result therefore guarantees the
  /// engagement is not refused for a missing profile field.
  static List<EngagementProfileGap> engagementGaps({
    required String? firstName,
    required String? lastName,
    required String? phone,
    required String? email,
    required VolunteerProfession profession,
    required ProfessionalIdType professionalIdType,
    required String? professionalIdValue,
    String? cptsId,
    String? cptsLabel,
    List<String> equipment = const [],
    String? otherEquipmentDetails,
  }) {
    bool blank(String? value) => value == null || value.trim().isEmpty;
    return [
      if (blank(firstName)) EngagementProfileGap.firstName,
      if (blank(lastName)) EngagementProfileGap.lastName,
      if (blank(phone)) EngagementProfileGap.phone,
      if (!isValidEmail(email)) EngagementProfileGap.email,
      if (!hasCompleteProfessionalIdentifier(
        profession,
        professionalIdType,
        professionalIdValue,
      ))
        EngagementProfileGap.professionalIdentifier,
      if ((_trimmedOrNull(cptsId)?.length ?? 0) > 160 ||
          (_trimmedOrNull(cptsLabel)?.length ?? 0) > 160)
        EngagementProfileGap.cptsLabel,
      if (ProfessionalEquipmentRegistry.requiresDetails(equipment) &&
          blank(otherEquipmentDetails))
        EngagementProfileGap.equipmentDetails,
    ];
  }

  static List<EngagementProfileGap> engagementGapsForProfile(
    VolunteerProfile profile,
  ) => engagementGaps(
    firstName: profile.firstName,
    lastName: profile.lastName,
    phone: profile.phone,
    email: profile.email,
    profession: profile.profession,
    professionalIdType: profile.effectiveProfessionalIdType,
    professionalIdValue: profile.effectiveProfessionalIdValue,
    cptsId: profile.cptsId,
    cptsLabel: profile.cptsLabel,
    equipment: profile.equipment,
    otherEquipmentDetails: profile.otherEquipmentDetails,
  );

  static bool isComplete(VolunteerProfile? profile) =>
      profile != null && engagementGapsForProfile(profile).isEmpty;

  static bool preservesVerification({
    required VolunteerProfile? existing,
    required VolunteerProfession profession,
    required ProfessionalIdType professionalIdType,
    required String professionalIdValue,
  }) {
    return existing?.hasVerifiedProfessionalIdentity == true &&
        existing!.profession == profession &&
        professionalIdType == ProfessionalIdType.rpps &&
        existing.effectiveProfessionalIdValue ==
            normalizeProfessionalIdentifier(
              professionalIdType,
              professionalIdValue,
            );
  }

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
