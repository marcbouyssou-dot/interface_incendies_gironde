import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/volunteer_profile.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/services/professional_verification_service.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/professional_rpps_verification.dart';

const rpps = '00000000000';

ProfessionalVerificationResult result(
  ProfessionalVerificationStatus status, {
  String professionCode = '70',
  String professionLabel = 'Masseur-Kinésithérapeute',
}) => ProfessionalVerificationResult(
  status: status,
  rpps: rpps,
  firstName: status == ProfessionalVerificationStatus.verified ? 'Alice' : '',
  lastName: status == ProfessionalVerificationStatus.verified ? 'EXEMPLE' : '',
  professionCode: status == ProfessionalVerificationStatus.verified
      ? professionCode
      : '',
  professionLabel: status == ProfessionalVerificationStatus.verified
      ? professionLabel
      : '',
);

class StubProfessionalVerificationService
    implements ProfessionalVerificationService {
  StubProfessionalVerificationService(this.handler);

  final Future<ProfessionalVerificationResult> Function(String) handler;
  final calls = <String>[];

  @override
  Future<ProfessionalVerificationResult> verifyRpps(String value) {
    calls.add(value);
    return handler(value);
  }
}

Future<void> pumpVerification(
  WidgetTester tester, {
  required ProfessionalVerificationService service,
  VolunteerProfession profession = VolunteerProfession.mk,
  ValueChanged<ProfessionalVerificationResult>? onConfirmed,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 390,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ProfessionalRppsVerification(
              profession: profession,
              service: service,
              onIdentityConfirmed: onConfirmed,
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> enterAndVerify(WidgetTester tester, String value) async {
  await tester.enterText(
    find.byKey(const Key('professional-rpps-field')),
    value,
  );
  await tester.tap(find.byKey(const Key('verify-professional-rpps')));
  await tester.pump();
}

void main() {
  test('prend en charge exactement les quatre professions RPPS du lot', () {
    final supported = VolunteerProfession.values
        .where(ProfessionalRppsVerification.supportsProfession)
        .toSet();
    expect(supported, {
      VolunteerProfession.mk,
      VolunteerProfession.nurse,
      VolunteerProfession.doctor,
      VolunteerProfession.pp,
    });
  });

  testWidgets('un RPPS invalide est refusé sans appeler le service', (
    tester,
  ) async {
    final service = StubProfessionalVerificationService(
      (_) async => result(ProfessionalVerificationStatus.verified),
    );
    await pumpVerification(tester, service: service);
    await enterAndVerify(tester, '123');

    expect(
      find.text('Le numéro RPPS doit contenir 11 chiffres'),
      findsOneWidget,
    );
    expect(service.calls, isEmpty);
  });

  testWidgets('affiche le chargement pendant la vérification', (tester) async {
    final completer = Completer<ProfessionalVerificationResult>();
    final service = StubProfessionalVerificationService(
      (_) => completer.future,
    );
    await pumpVerification(tester, service: service);
    await enterAndVerify(tester, rpps);

    expect(find.text('Vérification en cours…'), findsOneWidget);
    completer.complete(result(ProfessionalVerificationStatus.verified));
    await tester.pumpAndSettle();
  });

  testWidgets('affiche identité, profession et badge vérifié', (tester) async {
    final service = StubProfessionalVerificationService(
      (_) async => result(ProfessionalVerificationStatus.verified),
    );
    await pumpVerification(tester, service: service);
    await enterAndVerify(tester, rpps);
    await tester.pumpAndSettle();

    expect(find.text('Alice EXEMPLE'), findsOneWidget);
    expect(find.text('Masseur-Kinésithérapeute'), findsOneWidget);
    expect(find.text('Profil vérifié'), findsOneWidget);
    expect(find.text('Confirmer mon identité'), findsOneWidget);
  });

  testWidgets('affiche RPPS non reconnu', (tester) async {
    final service = StubProfessionalVerificationService(
      (_) async => result(ProfessionalVerificationStatus.notFound),
    );
    await pumpVerification(tester, service: service);
    await enterAndVerify(tester, rpps);
    await tester.pumpAndSettle();

    expect(find.text('RPPS non reconnu'), findsOneWidget);
  });

  testWidgets('affiche le service momentanément indisponible', (tester) async {
    final service = StubProfessionalVerificationService(
      (_) async => result(ProfessionalVerificationStatus.unavailable),
    );
    await pumpVerification(tester, service: service);
    await enterAndVerify(tester, rpps);
    await tester.pumpAndSettle();

    expect(
      find.text('Le service de vérification est momentanément indisponible'),
      findsOneWidget,
    );
  });

  testWidgets('distingue une profession incompatible', (tester) async {
    final service = StubProfessionalVerificationService(
      (_) async => result(
        ProfessionalVerificationStatus.verified,
        professionCode: '10',
        professionLabel: 'Médecin',
      ),
    );
    await pumpVerification(tester, service: service);
    await enterAndVerify(tester, rpps);
    await tester.pumpAndSettle();

    expect(
      find.text('Ce RPPS correspond à une autre profession'),
      findsOneWidget,
    );
    expect(find.text('Profil vérifié'), findsNothing);
    expect(find.text('Confirmer mon identité'), findsNothing);
  });

  testWidgets('la confirmation masque le bouton et affiche le bloc compact', (
    tester,
  ) async {
    ProfessionalVerificationResult? confirmed;
    final service = StubProfessionalVerificationService(
      (_) async => result(ProfessionalVerificationStatus.verified),
    );
    await pumpVerification(
      tester,
      service: service,
      onConfirmed: (value) => confirmed = value,
    );
    await enterAndVerify(tester, rpps);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-professional-identity')));
    await tester.pumpAndSettle();

    expect(confirmed?.rpps, rpps);
    expect(
      find.byKey(const Key('professional-rpps-persisted-verified')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('verify-professional-rpps')), findsNothing);
    expect(find.text('RPPS •••••••0000'), findsOneWidget);
  });

  testWidgets('changer le RPPS remet la vérification à zéro', (tester) async {
    final service = StubProfessionalVerificationService(
      (_) async => result(ProfessionalVerificationStatus.verified),
    );
    await pumpVerification(tester, service: service);
    await enterAndVerify(tester, rpps);
    await tester.pumpAndSettle();
    expect(find.text('Profil vérifié'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('professional-rpps-field')),
      '00000000001',
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil vérifié'), findsNothing);
    expect(find.text('Alice EXEMPLE'), findsNothing);
  });

  testWidgets('le profil professionnel injecte le service RPPS', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      responsibleAccess: null,
      initialProfiles: const {
        'mock-volunteer': VolunteerProfile(
          uid: 'mock-volunteer',
          firstName: 'Alice',
          lastName: 'EXEMPLE',
          phone: '0600000000',
          profession: VolunteerProfession.mk,
          professionalIdType: ProfessionalIdType.rpps,
          professionalIdValue: rpps,
        ),
      },
    );
    final service = StubProfessionalVerificationService(
      (_) async => result(ProfessionalVerificationStatus.verified),
    );
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: repository,
        initialTab: 1,
        professionalVerificationService: service,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('professional-rpps-field')), findsOneWidget);
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, rpps);
  });

  testWidgets('la confirmation persiste et reste visible après redémarrage', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      responsibleAccess: null,
      initialProfiles: const {
        'mock-volunteer': VolunteerProfile(
          uid: 'mock-volunteer',
          firstName: 'Alice',
          lastName: 'EXEMPLE',
          phone: '0600000000',
          email: 'alice@example.fr',
          profession: VolunteerProfession.mk,
          professionalIdType: ProfessionalIdType.rpps,
          professionalIdValue: rpps,
        ),
      },
    );
    final service = StubProfessionalVerificationService(
      (_) async => result(ProfessionalVerificationStatus.verified),
    );

    Future<void> pumpApp() => tester.pumpWidget(
      FireCoordinationApp(
        repository: repository,
        initialTab: 1,
        professionalVerificationService: service,
      ),
    );

    await pumpApp();
    await tester.pumpAndSettle();
    final verify = find.byKey(const Key('verify-professional-rpps'));
    await Scrollable.ensureVisible(
      tester.element(verify),
      alignment: 0.4,
      duration: const Duration(milliseconds: 100),
    );
    await tester.pumpAndSettle();
    await tester.tap(verify);
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('confirm-professional-identity'));
    await Scrollable.ensureVisible(
      tester.element(confirm),
      alignment: 0.4,
      duration: const Duration(milliseconds: 100),
    );
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    final stored = await repository.getVolunteerProfile();
    expect(stored?.verificationStatus, 'verified');
    expect(stored?.verificationSource, 'ans_rpps');
    expect(stored?.verifiedFirstName, 'Alice');
    expect(stored?.verifiedLastName, 'EXEMPLE');
    expect(stored?.verifiedProfessionCode, '70');
    expect(stored?.verifiedProfessionLabel, 'Masseur-Kinésithérapeute');
    expect(stored?.verifiedAt, isNotNull);
    expect(find.byKey(const Key('verify-professional-rpps')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('professional-rpps-persisted-verified')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('verify-professional-rpps')), findsNothing);
  });
}
