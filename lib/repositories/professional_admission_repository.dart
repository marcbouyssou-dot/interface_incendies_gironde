enum ProfessionalAdmissionMode { open, invitationOnly, unavailable }

class ProfessionalAdmissionState {
  const ProfessionalAdmissionState({
    required this.mode,
    this.operationIds = const {},
    this.termsAccepted = true,
  });

  final ProfessionalAdmissionMode mode;
  final Set<String> operationIds;
  final bool termsAccepted;

  bool get canReadOperationalData =>
      mode == ProfessionalAdmissionMode.open ||
      (termsAccepted && operationIds.isNotEmpty);
}

/// Terms acceptance is separate from optional notification and location consent.
abstract interface class BetaTermsAcceptanceRepository {
  Future<void> acceptCurrentBetaTerms();
}

class ProfessionalEmailIdentity {
  const ProfessionalEmailIdentity({
    required this.isAnonymous,
    required this.emailVerified,
    this.email,
  });

  final bool isAnonymous;
  final bool emailVerified;
  final String? email;
}

/// This read model drives UX only. Firestore rules and callable transactions
/// remain the authorization boundary.
abstract interface class ProfessionalAdmissionRepository {
  Stream<ProfessionalAdmissionState> watchProfessionalAdmission();

  Future<void> redeemProfessionalInvitation(String code);

  Future<void> prepareProfessionalRegistration(String code);

  Future<ProfessionalEmailIdentity> professionalEmailIdentity();

  Future<void> linkProfessionalEmail(String email, String password);

  Future<void> signInProfessionalEmail(String email, String password);

  Future<void> sendAccountPasswordReset(String email);

  Future<void> sendProfessionalEmailVerification();

  Future<void> signOutProfessionalEmail();
}
