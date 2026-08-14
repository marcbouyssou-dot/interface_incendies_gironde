import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/professional_equipment.dart';
import 'package:interface_incendies_gironde/models/responsible_access.dart';
import 'package:interface_incendies_gironde/models/volunteer_profile.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/professional_shell.dart';
import 'package:interface_incendies_gironde/widgets/v5_form_system.dart';

void main() {
  testWidgets(
    'an incomplete professional profile can be completed and survives reload',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final profiles = <String, VolunteerProfile>{};
      final repository = MockCoordinationRepository(
        responsibleAccess: null,
        initialProfiles: profiles,
      );

      await _pumpApp(tester, repository);
      await _openProfessionalProfile(tester);

      expect(find.text('Profil à compléter'), findsOneWidget);
      expect(find.text('Compléter mon profil'), findsWidgets);
      await tester.tap(find.byKey(const Key('edit-professional-profile')));
      await tester.pumpAndSettle();

      expect(find.text('Compléter mon profil'), findsWidgets);
      await _scrollTo(
        tester,
        find.byKey(const Key('save-professional-profile')),
      );
      await tester.tap(find.byKey(const Key('save-professional-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Champ requis'), findsNWidgets(3));
      expect(find.text('Email invalide'), findsOneWidget);
      expect(
        find.text('Le numéro RPPS doit contenir exactement 11 chiffres.'),
        findsOneWidget,
      );
      final firstNameEditable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('professional-profile-first-name')),
          matching: find.byType(EditableText),
        ),
      );
      expect(firstNameEditable.focusNode.hasFocus, isTrue);
      final firstNameSemantics = tester.getSemantics(
        find.bySemanticsLabel(
          RegExp(r'Prénom, obligatoire, Erreur : Champ requis'),
        ),
      );
      expect(firstNameSemantics.flagsCollection.isTextField, isTrue);

      await tester.enterText(
        find.byKey(const Key('professional-profile-first-name')),
        'Alice',
      );
      await tester.enterText(
        find.byKey(const Key('professional-profile-last-name')),
        'Martin',
      );
      await tester.enterText(
        find.byKey(const Key('professional-profile-phone')),
        '0600000000',
      );
      await tester.enterText(
        find.byKey(const Key('professional-profile-email')),
        'alice@example.fr',
      );

      expect(
        find.byKey(const Key('professional-profile-id-type-mk')),
        findsNothing,
      );
      expect(find.text('Identifiant : RPPS'), findsOneWidget);
      expect(find.text('Numéro ordinal'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('professional-profile-id-value')),
        '10123456789',
      );
      await tester.enterText(
        find.byKey(const Key('professional-profile-cpts-id')),
        'cpts-medoc',
      );
      await tester.enterText(
        find.byKey(const Key('professional-profile-cpts-label')),
        'CPTS Médoc',
      );

      final equipment = find.byKey(
        const Key(
          'professional-profile-equipment-${ProfessionalEquipmentId.massageTable}',
        ),
      );
      await _scrollTo(tester, equipment);
      await tester.tap(equipment);
      await _scrollTo(
        tester,
        find.byKey(const Key('save-professional-profile')),
      );
      await tester.tap(find.byKey(const Key('save-professional-profile')));
      await tester.pumpAndSettle();

      expect(find.text('Profil enregistré.'), findsOneWidget);
      expect(find.text('Profil complet'), findsOneWidget);
      expect(find.text('Alice Martin'), findsOneWidget);
      expect(find.text('alice@example.fr'), findsOneWidget);
      expect(find.text('10123456789'), findsOneWidget);
      expect(find.text('CPTS Médoc'), findsWidgets);
      await tester.drag(
        find.byKey(const PageStorageKey('professional-profile')),
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();
      expect(find.text('Table de massage'), findsOneWidget);

      final saved = await repository.getVolunteerProfile();
      expect(saved?.uid, 'mock-volunteer');
      expect(saved?.profession, VolunteerProfession.mk);
      expect(saved?.effectiveProfessionalIdType, ProfessionalIdType.rpps);
      expect(saved?.equipment, [ProfessionalEquipmentId.massageTable]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();
      await _openProfessionalProfile(tester);

      expect(find.text('Profil complet'), findsOneWidget);
      expect(find.text('alice@example.fr'), findsOneWidget);
      expect(find.text('CPTS Médoc'), findsWidgets);
      semantics.dispose();
    },
  );

  testWidgets('an existing professional profile remains editable', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      responsibleAccess: null,
      initialProfiles: const {
        'mock-volunteer': VolunteerProfile(
          uid: 'mock-volunteer',
          firstName: 'Nina',
          lastName: 'Bernard',
          phone: '0611111111',
          email: 'nina@example.fr',
          profession: VolunteerProfession.nurse,
          professionalIdType: ProfessionalIdType.ordinal,
          professionalIdValue: 'ORD-123',
        ),
      },
    );

    await _pumpApp(tester, repository);
    await _openProfessionalProfile(tester);
    expect(find.text('Profil complet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('edit-professional-profile')));
    await tester.pumpAndSettle();

    expect(find.text('Modifier mon profil'), findsOneWidget);
    expect(
      find.text('Identifiant historique : Numéro ordinal'),
      findsOneWidget,
    );
    expect(
      _fieldText(tester, const Key('professional-profile-email')),
      'nina@example.fr',
    );
    await tester.enterText(
      find.byKey(const Key('professional-profile-email')),
      'nina.modifiee@example.fr',
    );
    await tester.enterText(
      find.byKey(const Key('professional-profile-phone')),
      '0622222222',
    );
    await _scrollTo(tester, find.byKey(const Key('save-professional-profile')));
    await tester.tap(find.byKey(const Key('save-professional-profile')));
    await tester.pumpAndSettle();

    expect(find.text('nina.modifiee@example.fr'), findsOneWidget);
    final saved = await repository.getVolunteerProfile();
    expect(saved?.email, 'nina.modifiee@example.fr');
    expect(saved?.phone, '0622222222');
    expect(saved?.createdAt, isNotNull);
  });

  testWidgets('changing a verified RPPS restores verification action', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      responsibleAccess: null,
      initialProfiles: {'mock-volunteer': _verifiedProfile()},
    );
    await _pumpApp(tester, repository);
    await _openProfessionalProfile(tester);
    expect(find.byKey(const Key('verify-professional-rpps')), findsNothing);

    await tester.tap(find.byKey(const Key('edit-professional-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('professional-profile-id-value')),
      '10987654321',
    );
    await _scrollTo(tester, find.byKey(const Key('save-professional-profile')));
    await tester.tap(find.byKey(const Key('save-professional-profile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('verify-professional-rpps')), findsOneWidget);
    expect(
      (await repository.getVolunteerProfile())?.verificationStatus,
      'unverified',
    );
  });

  testWidgets('changing a verified profession restores verification action', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      responsibleAccess: null,
      initialProfiles: {'mock-volunteer': _verifiedProfile()},
    );
    await _pumpApp(tester, repository);
    await _openProfessionalProfile(tester);
    expect(find.byKey(const Key('verify-professional-rpps')), findsNothing);

    await tester.tap(find.byKey(const Key('edit-professional-profile')));
    await tester.pumpAndSettle();
    final profession = find.byKey(const Key('professional-profile-profession'));
    await tester.tap(profession);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Médecin').last);
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('save-professional-profile')));
    await tester.tap(find.byKey(const Key('save-professional-profile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('verify-professional-rpps')), findsOneWidget);
    final saved = await repository.getVolunteerProfile();
    expect(saved?.profession, VolunteerProfession.doctor);
    expect(saved?.verificationStatus, 'unverified');
  });

  for (final access in <ResponsibleAccess>[
    ResponsibleAccess(
      uid: 'manager',
      role: ResponsibleRole.siteManager,
      locationIds: {places.first.id},
      active: true,
    ),
    const ResponsibleAccess(
      uid: 'coordinator',
      role: ResponsibleRole.coordinator,
      locationIds: {'*'},
      active: true,
    ),
  ]) {
    testWidgets(
      '${access.role} debug shell preview only edits the volunteer profile',
      (tester) async {
        final repository = MockCoordinationRepository(
          responsibleAccess: access,
          initialProfiles: const {
            'mock-volunteer': VolunteerProfile(
              uid: 'mock-volunteer',
              firstName: 'Sam',
              lastName: 'Durand',
              phone: '0633333333',
              email: 'sam@example.fr',
              profession: VolunteerProfession.doctor,
              professionalIdType: ProfessionalIdType.rpps,
              professionalIdValue: '10987654321',
            ),
          },
        );

        await _pumpApp(tester, repository);
        await _enterProfessionalPerspective(tester, access);
        expect(find.byType(ProfessionalShell), findsOneWidget);
        await _openProfessionalProfile(tester);
        await tester.tap(find.byKey(const Key('edit-professional-profile')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('professional-profile-email')),
          '${access.role}@example.fr',
        );
        await _scrollTo(
          tester,
          find.byKey(const Key('save-professional-profile')),
        );
        await tester.tap(find.byKey(const Key('save-professional-profile')));
        await tester.pumpAndSettle();

        final saved = await repository.getVolunteerProfile();
        expect(saved?.uid, 'mock-volunteer');
        expect(saved?.email, '${access.role}@example.fr');
        final unchangedAccess = await repository.watchResponsibleAccess().first;
        expect(unchangedAccess?.uid, access.uid);
        expect(unchangedAccess?.role, access.role);
        expect(unchangedAccess?.active, isTrue);
      },
    );
  }
}

VolunteerProfile _verifiedProfile() => VolunteerProfile(
  uid: 'mock-volunteer',
  firstName: 'Alice',
  lastName: 'MARTIN',
  phone: '0600000000',
  email: 'alice@example.fr',
  profession: VolunteerProfession.mk,
  professionalIdType: ProfessionalIdType.rpps,
  professionalIdValue: '10123456789',
  verificationStatus: 'verified',
  verificationSource: 'ans_rpps',
  verifiedFirstName: 'Alice',
  verifiedLastName: 'MARTIN',
  verifiedProfessionCode: '70',
  verifiedProfessionLabel: 'Masseur-Kinésithérapeute',
  verifiedAt: DateTime(2026, 8, 9),
);

Future<void> _pumpApp(
  WidgetTester tester,
  MockCoordinationRepository repository,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FireCoordinationApp(repository: repository));
  await tester.pumpAndSettle();
}

Future<void> _openProfessionalProfile(WidgetTester tester) async {
  if (find.text('Mon profil').evaluate().isNotEmpty) return;
  await tester.tap(find.text('Profil'));
  await tester.pumpAndSettle();
  expect(find.text('Mon profil'), findsOneWidget);
}

Future<void> _enterProfessionalPerspective(
  WidgetTester tester,
  ResponsibleAccess access,
) async {
  if (access.roles.contains(ResponsibleRole.coordinator)) {
    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();
  } else {
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
  }
  final settings = access.roles.contains(ResponsibleRole.coordinator)
      ? find.byKey(const Key('open-development-settings'))
      : find.byKey(const Key('responsible-development-settings'));
  await tester.ensureVisible(settings);
  await tester.tap(settings);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('role-preview-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Professionnel').last);
  await tester.pumpAndSettle();
  Navigator.of(tester.element(find.text('Mode Développement'))).pop();
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  final editor = find.byKey(const Key('professional-profile-editor-scroll'));
  for (var attempt = 0; attempt < 8; attempt++) {
    if (tester.getCenter(target).dy < 760) break;
    await tester.drag(editor, const Offset(0, -360));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, Key key) =>
    tester.widget<V5TextField>(find.byKey(key)).controller?.text ?? '';
