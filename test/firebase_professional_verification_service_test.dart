import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/services/firebase_professional_verification_service.dart';
import 'package:interface_incendies_gironde/services/professional_verification_service.dart';

const _rpps = '00000000000';

Map<String, Object?> response(
  String status, {
  String rpps = _rpps,
  String firstName = '',
  String lastName = '',
  String professionCode = '',
  String professionLabel = '',
  String source = 'ans_rpps',
}) => {
  'status': status,
  'rpps': rpps,
  'firstName': firstName,
  'lastName': lastName,
  'professionCode': professionCode,
  'professionLabel': professionLabel,
  'source': source,
};

void main() {
  test('appelle la callable régionale et mappe verified exactement', () async {
    String? calledFunction;
    Map<String, Object?>? sentData;
    final service = FirebaseProfessionalVerificationService(
      callable: (functionName, data) async {
        calledFunction = functionName;
        sentData = data;
        return response(
          'verified',
          firstName: 'Alice',
          lastName: 'EXEMPLE',
          professionCode: '70',
          professionLabel: 'Masseur-Kinésithérapeute',
        );
      },
    );

    final result = await service.verifyRpps('  $_rpps  ');

    expect(FirebaseProfessionalVerificationService.region, 'europe-west1');
    expect(calledFunction, 'verifyProfessionalRpps');
    expect(sentData, {'rpps': _rpps});
    expect(result.status, ProfessionalVerificationStatus.verified);
    expect(result.rpps, _rpps);
    expect(result.firstName, 'Alice');
    expect(result.lastName, 'EXEMPLE');
    expect(result.professionCode, '70');
    expect(result.professionLabel, 'Masseur-Kinésithérapeute');
    expect(result.source, 'ans_rpps');
  });

  test('mappe not_found sans données professionnelles', () async {
    final service = FirebaseProfessionalVerificationService(
      callable: (_, _) async => response('not_found'),
    );

    final result = await service.verifyRpps(_rpps);

    expect(result.status, ProfessionalVerificationStatus.notFound);
    expect(result.rpps, _rpps);
    expect(result.firstName, isEmpty);
    expect(result.lastName, isEmpty);
    expect(result.professionCode, isEmpty);
    expect(result.professionLabel, isEmpty);
    expect(result.source, 'ans_rpps');
  });

  test('mappe invalid sans le convertir en indisponibilité', () async {
    final service = FirebaseProfessionalVerificationService(
      callable: (_, _) async => response('invalid', rpps: '123'),
    );

    final result = await service.verifyRpps('123');

    expect(result.status, ProfessionalVerificationStatus.invalid);
    expect(result.rpps, '123');
    expect(result.source, 'ans_rpps');
  });

  test('mappe unavailable sans le convertir en not_found', () async {
    final service = FirebaseProfessionalVerificationService(
      callable: (_, _) async => response('unavailable'),
    );

    final result = await service.verifyRpps(_rpps);

    expect(result.status, ProfessionalVerificationStatus.unavailable);
    expect(result.rpps, _rpps);
    expect(result.source, 'ans_rpps');
  });

  test('convertit une exception callable en unavailable', () async {
    final service = FirebaseProfessionalVerificationService(
      callable: (_, _) => throw StateError('network unavailable'),
    );

    final result = await service.verifyRpps(_rpps);

    expect(result.status, ProfessionalVerificationStatus.unavailable);
    expect(result.rpps, _rpps);
    expect(result.status, isNot(ProfessionalVerificationStatus.notFound));
  });

  test('convertit toute réponse malformée en unavailable', () async {
    final malformedResponses = <Object?>[
      null,
      'verified',
      {'status': 'verified'},
      response('unknown'),
      response('verified'),
      response('not_found', firstName: 'Donnée inattendue'),
      {...response('not_found'), 'apiKey': 'secret'},
    ];

    for (final malformed in malformedResponses) {
      final service = FirebaseProfessionalVerificationService(
        callable: (_, _) async => malformed,
      );

      final result = await service.verifyRpps(_rpps);

      expect(
        result.status,
        ProfessionalVerificationStatus.unavailable,
        reason: 'Réponse acceptée à tort : $malformed',
      );
      expect(result.status, isNot(ProfessionalVerificationStatus.notFound));
      expect(result.source, 'ans_rpps');
    }
  });
}
