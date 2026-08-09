enum ProfessionalVerificationStatus {
  verified('verified'),
  notFound('not_found'),
  invalid('invalid'),
  unavailable('unavailable');

  const ProfessionalVerificationStatus(this.wireValue);

  final String wireValue;
}

class ProfessionalVerificationResult {
  const ProfessionalVerificationResult({
    required this.status,
    required this.rpps,
    required this.firstName,
    required this.lastName,
    required this.professionCode,
    required this.professionLabel,
    this.source = 'ans_rpps',
  });

  final ProfessionalVerificationStatus status;
  final String rpps;
  final String firstName;
  final String lastName;
  final String professionCode;
  final String professionLabel;
  final String source;

  factory ProfessionalVerificationResult.empty({
    required ProfessionalVerificationStatus status,
    required String rpps,
  }) => ProfessionalVerificationResult(
    status: status,
    rpps: rpps,
    firstName: '',
    lastName: '',
    professionCode: '',
    professionLabel: '',
  );
}

abstract interface class ProfessionalVerificationService {
  Future<ProfessionalVerificationResult> verifyRpps(String rpps);
}

/// Implémentation locale injectable. Elle ne contacte jamais Firebase ni l'ANS.
class FakeProfessionalVerificationService
    implements ProfessionalVerificationService {
  const FakeProfessionalVerificationService({
    this.responses = const {},
    this.latency = Duration.zero,
  });

  final Map<String, ProfessionalVerificationResult> responses;
  final Duration latency;

  @override
  Future<ProfessionalVerificationResult> verifyRpps(String rpps) async {
    final normalized = rpps.trim();
    if (!RegExp(r'^\d{11}$').hasMatch(normalized)) {
      return ProfessionalVerificationResult.empty(
        status: ProfessionalVerificationStatus.invalid,
        rpps: normalized,
      );
    }
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return responses[normalized] ??
        ProfessionalVerificationResult.empty(
          status: ProfessionalVerificationStatus.notFound,
          rpps: normalized,
        );
  }
}
