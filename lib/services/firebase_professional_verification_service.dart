import 'package:cloud_functions/cloud_functions.dart';

import 'professional_verification_service.dart';

typedef ProfessionalRppsCallable =
    Future<Object?> Function(String functionName, Map<String, Object?> data);

class FirebaseProfessionalVerificationService
    implements ProfessionalVerificationService {
  FirebaseProfessionalVerificationService({
    FirebaseFunctions? functions,
    ProfessionalRppsCallable? callable,
  }) : assert(functions == null || callable == null),
       _functions = functions,
       _callable = callable;

  static const functionName = 'verifyProfessionalRpps';
  static const region = 'europe-west1';

  static const _responseKeys = <String>{
    'status',
    'rpps',
    'firstName',
    'lastName',
    'professionCode',
    'professionLabel',
    'source',
  };

  final FirebaseFunctions? _functions;
  final ProfessionalRppsCallable? _callable;

  @override
  Future<ProfessionalVerificationResult> verifyRpps(String rpps) async {
    final normalizedRpps = rpps.trim();
    try {
      final response = await _invoke({'rpps': normalizedRpps});
      return _parseResponse(response) ?? _unavailable(normalizedRpps);
    } catch (_) {
      return _unavailable(normalizedRpps);
    }
  }

  Future<Object?> _invoke(Map<String, Object?> data) async {
    final callable = _callable;
    if (callable != null) return callable(functionName, data);

    final functions =
        _functions ?? FirebaseFunctions.instanceFor(region: region);
    final result = await functions
        .httpsCallable(functionName)
        .call<Object?>(data);
    return result.data;
  }

  ProfessionalVerificationResult? _parseResponse(Object? response) {
    if (response is! Map || response.length != _responseKeys.length) {
      return null;
    }
    final data = <String, Object?>{};
    for (final entry in response.entries) {
      if (entry.key is! String) return null;
      data[entry.key as String] = entry.value;
    }
    if (!_responseKeys.every(data.containsKey) ||
        data.values.any((value) => value is! String)) {
      return null;
    }

    final status = switch (data['status']) {
      'verified' => ProfessionalVerificationStatus.verified,
      'not_found' => ProfessionalVerificationStatus.notFound,
      'invalid' => ProfessionalVerificationStatus.invalid,
      'unavailable' => ProfessionalVerificationStatus.unavailable,
      _ => null,
    };
    final returnedRpps = data['rpps']! as String;
    final firstName = data['firstName']! as String;
    final lastName = data['lastName']! as String;
    final professionCode = data['professionCode']! as String;
    final professionLabel = data['professionLabel']! as String;
    final source = data['source']! as String;
    if (status == null || source != 'ans_rpps') return null;

    final hasValidRpps = RegExp(r'^\d{11}$').hasMatch(returnedRpps);
    final hasEmptyProfessionalDetails =
        firstName.isEmpty &&
        lastName.isEmpty &&
        professionCode.isEmpty &&
        professionLabel.isEmpty;
    final isCoherent = switch (status) {
      ProfessionalVerificationStatus.verified =>
        hasValidRpps &&
            firstName.trim().isNotEmpty &&
            lastName.trim().isNotEmpty &&
            professionCode.trim().isNotEmpty &&
            professionLabel.trim().isNotEmpty,
      ProfessionalVerificationStatus.notFound =>
        hasValidRpps && hasEmptyProfessionalDetails,
      ProfessionalVerificationStatus.invalid =>
        !hasValidRpps && hasEmptyProfessionalDetails,
      ProfessionalVerificationStatus.unavailable =>
        (returnedRpps.isEmpty || hasValidRpps) && hasEmptyProfessionalDetails,
    };
    if (!isCoherent) return null;

    return ProfessionalVerificationResult(
      status: status,
      rpps: returnedRpps,
      firstName: firstName,
      lastName: lastName,
      professionCode: professionCode,
      professionLabel: professionLabel,
      source: source,
    );
  }

  ProfessionalVerificationResult _unavailable(String rpps) =>
      ProfessionalVerificationResult.empty(
        status: ProfessionalVerificationStatus.unavailable,
        rpps: RegExp(r'^\d{11}$').hasMatch(rpps) ? rpps : '',
      );
}
