import 'need.dart';
import 'professional_equipment.dart';
import 'volunteer_profile.dart';

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

  static bool isComplete(VolunteerProfile? profile) {
    if (profile == null || !profile.hasValidProfessionalIdentifier) {
      return false;
    }
    final hasIdentity =
        profile.firstName.trim().isNotEmpty &&
        profile.lastName.trim().isNotEmpty &&
        profile.phone.trim().isNotEmpty &&
        isValidEmail(profile.email);
    final hasEquipmentDetails =
        !ProfessionalEquipmentRegistry.requiresDetails(profile.equipment) ||
        (profile.otherEquipmentDetails?.trim().isNotEmpty ?? false);
    return hasIdentity && hasEquipmentDetails;
  }

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
