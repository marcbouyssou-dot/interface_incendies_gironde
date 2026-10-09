import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/models/public_mission_discovery.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/public_mission_discovery_repository.dart';
import 'package:interface_incendies_gironde/repositories/professional_admission_repository.dart';
import 'package:interface_incendies_gironde/screens/professional_engagements_screen.dart';
import 'package:interface_incendies_gironde/screens/create_need_screen.dart';
import 'package:interface_incendies_gironde/screens/slots_screen.dart';
import 'package:interface_incendies_gironde/widgets/brand_mark.dart';

import 'support/verified_professional_profile.dart';

class _UnavailableMissionsRepository extends MockCoordinationRepository
    implements VisitorOperationalReadGate {
  _UnavailableMissionsRepository() : super(responsibleAccess: null);

  int missionReads = 0;
  int locationReads = 0;

  @override
  Stream<List<CoordinationNeed>> watchMissions() {
    missionReads++;
    return Stream.error(StateError('Mission data unavailable'));
  }

  @override
  Stream<List<ResponsePlace>> watchLocations() {
    locationReads++;
    return Stream.error(StateError('Location data unavailable'));
  }
}

class _InvitationOnlyRepository extends MockCoordinationRepository
    implements ProfessionalAdmissionRepository, VisitorOperationalReadGate {
  _InvitationOnlyRepository({required bool verified})
    : super(
        responsibleAccess: null,
        initialProfiles: verified
            ? {'mock-volunteer': verifiedMkProfile()}
            : const {},
      );

  String? redeemedCode;
  int operationalReads = 0;
  bool anonymous = false;
  bool emailVerified = true;
  String? linkedEmail;
  int verificationEmails = 0;
  int passwordResetRequests = 0;
  String? passwordResetEmail;
  bool passwordResetFails = false;

  @override
  Stream<ProfessionalAdmissionState> watchProfessionalAdmission() =>
      Stream.value(
        const ProfessionalAdmissionState(
          mode: ProfessionalAdmissionMode.invitationOnly,
        ),
      );

  @override
  Future<void> redeemProfessionalInvitation(String code) async {
    redeemedCode = code;
  }

  @override
  Future<ProfessionalEmailIdentity> professionalEmailIdentity() async =>
      ProfessionalEmailIdentity(
        isAnonymous: anonymous,
        emailVerified: emailVerified,
        email: linkedEmail,
      );

  @override
  Future<void> linkProfessionalEmail(String email, String password) async {
    linkedEmail = email;
    anonymous = false;
    emailVerified = false;
    verificationEmails++;
  }

  @override
  Future<void> signInProfessionalEmail(String email, String password) async {
    linkedEmail = email;
    anonymous = false;
  }

  @override
  Future<void> sendAccountPasswordReset(String email) async {
    passwordResetRequests++;
    passwordResetEmail = email;
    if (passwordResetFails) {
      throw StateError('Synthetic network error with private account details');
    }
  }

  @override
  Future<void> sendProfessionalEmailVerification() async {
    verificationEmails++;
  }

  @override
  Future<void> signOutProfessionalEmail() async {
    anonymous = true;
    emailVerified = false;
  }

  @override
  Stream<List<CoordinationNeed>> watchMissions() {
    operationalReads++;
    return super.watchMissions();
  }
}

class _OpenAccountRepository extends _InvitationOnlyRepository {
  _OpenAccountRepository() : super(verified: false) {
    anonymous = true;
    emailVerified = false;
  }

  @override
  Stream<ProfessionalAdmissionState> watchProfessionalAdmission() =>
      Stream.value(
        const ProfessionalAdmissionState(mode: ProfessionalAdmissionMode.open),
      );
}

class _PublicDiscoveryFixture implements PublicMissionDiscoveryRepository {
  int reads = 0;

  @override
  Stream<List<PublicMissionDiscovery>> watchMissions() {
    reads++;
    return Stream.value(const [
      PublicMissionDiscovery(
        publicId: 'safe-public-id',
        day: '2026-10-08',
        sectorLabel: 'Bordeaux Métropole',
        professions: ['physiotherapist', 'nurse'],
      ),
    ]);
  }
}

CoordinationNeed _mission() => CoordinationNeed(
  id: 'professional-discovery-fixture',
  place: 'Site de test',
  group: TerritorialGroup.medoc,
  date: 'Demain',
  time: '08:00 — 12:00',
  startAt: DateTime.now().add(const Duration(days: 1)),
  endAt: DateTime.now().add(const Duration(days: 1, hours: 4)),
  requiredPhysiotherapists: 1,
  registeredPhysiotherapists: 0,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  professionQuotas: ProfessionQuotas.fromMaps(
    requiredByProfession: const {'physiotherapist': 1, 'physician': 1},
    registeredByProfession: const {},
  ),
  equipment: const ['Crèmes / huiles de massage', 'Stéthoscope'],
  equipmentByProfession: const {
    'physiotherapist': ['massage_cream_oil'],
    'physician': ['stethoscope'],
  },
  availableEquipmentOnSite: const ['massage_table'],
);

void _expectIdentity(WidgetTester tester) {
  expect(find.byType(BrandMark), findsOneWidget);
  expect(find.text('MobSanté'), findsOneWidget);
  expect(
    find.text('Le bon professionnel, au bon endroit, au bon moment.'),
    findsOneWidget,
  );
  expect(find.text('Professionnel de santé'), findsOneWidget);
}

void main() {
  testWidgets(
    'open mode exposes existing professional email login without invitation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _OpenAccountRepository();
      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('open-professional-account')),
        300,
      );
      await tester.tap(find.byKey(const Key('open-professional-account')));
      await tester.pumpAndSettle();

      expect(find.text('Compte MobSanté'), findsWidgets);
      expect(find.byKey(const Key('open-responsible-access')), findsNothing);
      expect(
        find.byKey(const Key('professional-invitation-code')),
        findsNothing,
      );
      expect(find.text('Associer mon compte'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('professional-invitation-email')),
        'existing@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('professional-invitation-password')),
        'synthetic-password',
      );
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(repository.linkedEmail, 'existing@example.test');
      expect(repository.anonymous, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('professional password recovery is neutral on compact iPhone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _OpenAccountRepository();
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-professional-account')),
      300,
    );
    await tester.ensureVisible(
      find.byKey(const Key('open-professional-account')),
    );
    await tester.tap(find.byKey(const Key('open-professional-account')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('professional-forgot-password')),
    );
    await tester.tap(find.byKey(const Key('professional-forgot-password')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('professional-invitation-password')),
      findsNothing,
    );
    expect(find.text('Retour à la connexion'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('professional-invitation-email')),
      'adresse-invalide',
    );
    await tester.tap(
      find.byKey(const Key('professional-password-reset-submit')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);
    expect(repository.passwordResetRequests, 0);

    await tester.enterText(
      find.byKey(const Key('professional-invitation-email')),
      'synthetic@example.test',
    );
    await tester.tap(
      find.byKey(const Key('professional-password-reset-submit')),
    );
    await tester.pumpAndSettle();
    expect(repository.passwordResetRequests, 1);
    expect(repository.passwordResetEmail, 'synthetic@example.test');
    expect(
      find.text(
        'Si un compte correspond à cette adresse, un e-mail de récupération a été envoyé.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('professional-password-reset-submit')),
      findsNothing,
    );
    expect(find.text('Pensez à vérifier aussi vos spams.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('professional password recovery hides network details', (
    tester,
  ) async {
    final repository = _OpenAccountRepository()..passwordResetFails = true;
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-professional-account')),
      300,
    );
    await tester.tap(find.byKey(const Key('open-professional-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('professional-forgot-password')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('professional-invitation-email')),
      'synthetic@example.test',
    );
    await tester.tap(
      find.byKey(const Key('professional-password-reset-submit')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Récupération temporairement indisponible. Réessayez.'),
      findsOneWidget,
    );
    expect(find.textContaining('Synthetic network error'), findsNothing);
    expect(
      find.byKey(const Key('professional-password-reset-submit')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('common MobSanté login shares password recovery and sign-in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _OpenAccountRepository();
    var signedIn = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsibleLogin(
            repository: repository,
            onSignedIn: () => signedIn = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('COMPTE MOBSANTÉ'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('manager-email')), 'invalid');
    await tester.tap(find.byKey(const Key('account-forgot-password')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manager-password')), findsNothing);
    await tester.tap(find.byKey(const Key('account-password-reset-submit')));
    await tester.pumpAndSettle();
    expect(repository.passwordResetRequests, 0);
    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('manager-email')),
      'synthetic@example.test',
    );
    await tester.tap(find.byKey(const Key('account-password-reset-submit')));
    await tester.pumpAndSettle();
    expect(repository.passwordResetRequests, 1);
    expect(
      find.text(
        'Si un compte correspond à cette adresse, un e-mail de récupération a été envoyé.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Retour à la connexion'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('manager-password')),
      'synthetic-password',
    );
    await tester.tap(find.byKey(const Key('manager-sign-in')));
    await tester.pumpAndSettle();
    expect(repository.linkedEmail, 'synthetic@example.test');
    expect(signedIn, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password recovery hides invitation controls on compact iPhone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _InvitationOnlyRepository(verified: true)
      ..anonymous = true;
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('professional-use-invitation')),
      300,
    );
    await tester.tap(find.byKey(const Key('professional-use-invitation')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('professional-forgot-password')),
    );
    await tester.tap(find.byKey(const Key('professional-forgot-password')));
    await tester.pumpAndSettle();

    expect(
      find.text('Saisissez l’adresse de votre compte professionnel.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('professional-invitation-code')), findsNothing);
    expect(find.text('Valider'), findsNothing);
    expect(
      find.byKey(const Key('professional-password-reset-submit')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('invitation waits for verified email on compact iPhone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _InvitationOnlyRepository(verified: true)
      ..anonymous = true
      ..emailVerified = false;
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('professional-use-invitation')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('professional-invitation-code')),
      'opaque-test-code',
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Valider'))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('professional-invitation-email')),
      'a@example.test',
    );
    await tester.enterText(
      find.byKey(const Key('professional-invitation-password')),
      'test-password-42',
    );
    await tester.ensureVisible(find.text('Associer mon compte'));
    await tester.tap(find.text('Associer mon compte'));
    await tester.pumpAndSettle();
    expect(repository.redeemedCode, isNull);
    expect(repository.verificationEmails, 1);
    repository.emailVerified = true;
    await tester.tap(find.text('J’ai vérifié mon e-mail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(repository.redeemedCode, 'opaque-test-code');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'invitation-only visitor can enter code without operational reads',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _InvitationOnlyRepository(verified: true);
      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();

      expect(
        find.text('MobSanté est actuellement accessible sur invitation.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('professional-use-invitation')),
        findsOneWidget,
      );
      expect(find.byType(SlotsScreen), findsNothing);
      expect(repository.operationalReads, 0);
      await tester.tap(find.byKey(const Key('professional-use-invitation')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('professional-invitation-code')),
        'local-test-code',
      );
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(repository.redeemedCode, 'local-test-code');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unverified Missions and Engagements explain value without data',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _UnavailableMissionsRepository();
      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();

      _expectIdentity(tester);
      expect(
        find.byKey(const Key('professional-missions-discovery')),
        findsOneWidget,
      );
      expect(
        find.text('Des missions ont besoin de professionnels comme vous'),
        findsOneWidget,
      );
      expect(find.text('Comment ça marche'), findsOneWidget);
      expect(find.textContaining('selon votre profession'), findsOneWidget);
      expect(
        find.byKey(const Key('professional-verification-cta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('professional-verification-cta')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(SlotsScreen), findsNothing);
      expect(find.text('Voir les détails'), findsNothing);
      expect(find.text('Site de test'), findsNothing);
      final startupMissionReads = repository.missionReads;
      final startupLocationReads = repository.locationReads;

      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      _expectIdentity(tester);
      expect(
        find.byKey(const Key('professional-engagements-discovery')),
        findsOneWidget,
      );
      expect(find.text('Vos engagements apparaîtront ici'), findsOneWidget);
      expect(
        find.textContaining('retrouver ici toutes les informations'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('professional-verification-cta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('professional-verification-cta')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(ProfessionalEngagementsScreen), findsNothing);
      expect(repository.missionReads, startupMissionReads);
      expect(repository.locationReads, startupLocationReads);

      await tester.tap(find.byKey(const Key('professional-verification-cta')));
      await tester.pumpAndSettle();
      _expectIdentity(tester);
      expect(find.text('Mon profil'), findsOneWidget);
      expect(find.text('Identité professionnelle'), findsOneWidget);
      expect(find.text('Vérification professionnelle'), findsOneWidget);
      expect(
        find.byKey(const Key('edit-professional-profile')),
        findsOneWidget,
      );
    },
  );

  testWidgets('unverified visitor sees only safe projected mission fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _UnavailableMissionsRepository();
    final publicRepository = _PublicDiscoveryFixture();
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: repository,
        publicMissionDiscoveryRepository: publicRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('public-mission-list')), findsOneWidget);
    expect(find.text('Secteur Bordeaux Métropole'), findsOneWidget);
    expect(find.textContaining('Masseur-kinésithérapeute'), findsOneWidget);
    expect(find.textContaining('Infirmier'), findsOneWidget);
    expect(find.text('Compléter mon profil'), findsOneWidget);
    expect(find.text('Site de test'), findsNothing);
    expect(repository.missionReads, 0);
    expect(repository.locationReads, 0);
    expect(publicRepository.reads, 1);
  });

  testWidgets('verified screens retain mission, equipment and engagement UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final mission = _mission();
    final repository = MockCoordinationRepository(
      responsibleAccess: null,
      initialMissions: [mission],
      initialLocations: const [],
      initialProfiles: {'mock-volunteer': verifiedMkProfile()},
    );
    repository.engagements[mission.id] = const EngagementInfo(
      missionId: 'professional-discovery-fixture',
      volunteerId: 'mock-volunteer',
      profession: VolunteerProfession.mk,
      status: EngagementStatus.confirmed,
    );
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();

    _expectIdentity(tester);
    expect(find.byType(SlotsScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Voir les détails'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir les détails'));
    await tester.pumpAndSettle();
    expect(find.text('Crèmes / huiles de massage'), findsOneWidget);
    expect(find.text('Stéthoscope'), findsNothing);

    await tester.tap(find.text('Engagements'));
    await tester.pumpAndSettle();
    _expectIdentity(tester);
    expect(find.byType(ProfessionalEngagementsScreen), findsOneWidget);
    await tester.tap(find.text('Informations pratiques'));
    await tester.pumpAndSettle();
    expect(find.text('Table de massage'), findsOneWidget);
    expect(find.text('Crèmes / huiles de massage'), findsOneWidget);
    expect(find.text('Stéthoscope'), findsNothing);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    _expectIdentity(tester);
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Identité professionnelle'), findsOneWidget);
    expect(find.text('Vérification professionnelle'), findsOneWidget);
  });
}
