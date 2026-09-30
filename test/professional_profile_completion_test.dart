import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/mobilization_preferences.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/professional_equipment.dart';
import 'package:interface_incendies_gironde/models/responsible_access.dart';
import 'package:interface_incendies_gironde/models/volunteer_profile.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/professional_shell.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';
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

      expect(find.text('MobSanté'), findsOneWidget);
      expect(find.text('Professionnel'), findsNothing);
      expect(find.text('de santé'), findsNothing);
      expect(
        find.text('Le bon professionnel · au bon endroit · au bon moment'),
        findsOneWidget,
      );
      expect(find.text('Profil à compléter'), findsOneWidget);
      final missingName = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('professional-profile-value-name')),
          matching: find.text('Non renseigné'),
        ),
      );
      final colors = Theme.of(
        tester.element(find.byType(ProfessionalShell)),
      ).extension<V5Colors>()!;
      expect(missingName.style?.color, colors.danger);
      expect(
        find.byKey(const Key('professional-profile-missing-information')),
        findsOneWidget,
      );
      expect(find.text('Compléter mon profil'), findsWidgets);
      await tester.tap(find.byKey(const Key('edit-professional-profile')));
      await tester.pumpAndSettle();

      expect(find.text('Compléter mon profil'), findsWidgets);
      expect(
        find.byKey(const Key('professional-profile-editor-mode-completion')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('professional-profile-editor-title')),
        findsOneWidget,
      );
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
      await tester.enterText(
        find.byKey(const Key('professional-profile-address-line-1')),
        '10 rue de la Santé',
      );
      await tester.enterText(
        find.byKey(const Key('professional-profile-postal-code')),
        '33000',
      );
      await tester.enterText(
        find.byKey(const Key('professional-profile-city')),
        'Bordeaux',
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
      expect(
        find.byKey(const Key('professional-profile-cpts-id')),
        findsNothing,
      );
      expect(find.textContaining('Identifiant CPTS'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('professional-profile-address-line-1')),
        '10 rue de la Santé',
      );
      await tester.enterText(
        find.byKey(const Key('professional-profile-address-line-2')),
        'Cabinet 2',
      );
      await tester.enterText(
        find.byKey(const Key('professional-profile-postal-code')),
        '33000',
      );
      await tester.enterText(
        find.byKey(const Key('professional-profile-city')),
        'Bordeaux',
      );
      await _scrollTo(
        tester,
        find.byKey(const Key('professional-profile-cpts-label')),
      );
      await tester.enterText(
        find.byKey(const Key('professional-profile-cpts-label')),
        'CPTS Médoc',
      );
      expect(
        _fieldText(tester, const Key('professional-profile-cpts-label')),
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

      expect(find.text('Profil complet'), findsOneWidget);
      expect(find.text('Alice Martin'), findsOneWidget);
      expect(find.text('alice@example.fr'), findsOneWidget);
      await _scrollProfileTo(
        tester,
        find.text('10 rue de la Santé, Cabinet 2'),
      );
      expect(find.text('10 rue de la Santé, Cabinet 2'), findsOneWidget);
      expect(find.text('33000 · Bordeaux'), findsOneWidget);
      await _scrollProfileTo(tester, find.text('10123456789'));
      expect(find.text('10123456789'), findsOneWidget);
      await _scrollProfileTo(tester, find.text('CPTS Médoc').first);
      expect(find.text('CPTS Médoc'), findsWidgets);
      await _scrollProfileTo(tester, find.text('Table de massage'));
      expect(find.text('Table de massage'), findsOneWidget);

      final saved = await repository.getVolunteerProfile();
      expect(saved?.uid, 'mock-volunteer');
      expect(saved?.profession, VolunteerProfession.mk);
      expect(saved?.effectiveProfessionalIdType, ProfessionalIdType.rpps);
      expect(saved?.equipment, [ProfessionalEquipmentId.massageTable]);
      expect(saved?.professionalAddressLine1, '10 rue de la Santé');
      expect(saved?.professionalAddressLine2, 'Cabinet 2');
      expect(saved?.professionalPostalCode, '33000');
      expect(saved?.professionalCity, 'Bordeaux');
      expect(saved?.professionalCountryCode, 'FR');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();
      await _openProfessionalProfile(tester);

      expect(find.text('Profil complet'), findsOneWidget);
      expect(find.text('alice@example.fr'), findsOneWidget);
      await _scrollProfileTo(tester, find.text('33000 · Bordeaux'));
      expect(find.text('33000 · Bordeaux'), findsOneWidget);
      await _scrollProfileTo(tester, find.text('CPTS Médoc').first);
      expect(find.text('CPTS Médoc'), findsWidgets);
      semantics.dispose();
    },
  );

  testWidgets(
    'a profession requiring no identifier can select "Aucun identifiant" '
    'and save',
    (tester) async {
      final profiles = <String, VolunteerProfile>{};
      final repository = MockCoordinationRepository(
        responsibleAccess: null,
        initialProfiles: profiles,
      );

      await _pumpApp(tester, repository);
      await _openProfessionalProfile(tester);
      await tester.tap(find.byKey(const Key('edit-professional-profile')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('professional-profile-profession')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Autre professionnel de santé').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('professional-profile-id-value')),
        findsNothing,
      );

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
      await tester.enterText(
        find.byKey(const Key('professional-profile-address-line-1')),
        '10 rue de la Santé',
      );
      await tester.enterText(
        find.byKey(const Key('professional-profile-postal-code')),
        '33000',
      );
      await tester.enterText(
        find.byKey(const Key('professional-profile-city')),
        'Bordeaux',
      );

      await _scrollTo(
        tester,
        find.byKey(const Key('save-professional-profile')),
      );
      await tester.tap(find.byKey(const Key('save-professional-profile')));
      await tester.pumpAndSettle();

      expect(find.text('Profil enregistré.'), findsOneWidget);
      expect(find.text('Profil complet'), findsOneWidget);

      final saved = await repository.getVolunteerProfile();
      expect(saved?.profession, VolunteerProfession.otherHealthProfessional);
      expect(saved?.effectiveProfessionalIdType, ProfessionalIdType.none);
      expect(saved?.effectiveProfessionalIdValue, isEmpty);
      expect(saved?.hasValidProfessionalIdentifier, isTrue);
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
          cptsId: 'legacy-cpts-id',
          cptsLabel: 'CPTS Historique',
          professionalAddressLine1: '10 rue de la Santé',
          professionalPostalCode: '33000',
          professionalCity: 'Bordeaux',
        ),
      },
    );

    await _pumpApp(tester, repository);
    await _openProfessionalProfile(tester);
    expect(find.text('Profil à compléter'), findsOneWidget);
    expect(
      find.textContaining('Informations manquantes : Numéro RPPS'),
      findsOneWidget,
    );
    expect(find.text('10 rue de la Santé'), findsOneWidget);
    await tester.tap(find.byKey(const Key('edit-professional-profile')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('professional-profile-editor-title')),
      findsOneWidget,
    );
    expect(
      find.text('Identifiant : RPPS'),
      findsOneWidget,
    );
    expect(
      _fieldText(tester, const Key('professional-profile-id-value')),
      isEmpty,
    );
    expect(
      _fieldText(tester, const Key('professional-profile-email')),
      'nina@example.fr',
    );
    expect(find.textContaining('Identifiant CPTS'), findsNothing);
    expect(
      _fieldText(tester, const Key('professional-profile-cpts-label')),
      'CPTS Historique',
    );
    await tester.enterText(
      find.byKey(const Key('professional-profile-email')),
      'nina.modifiee@example.fr',
    );
    await tester.enterText(
      find.byKey(const Key('professional-profile-phone')),
      '0622222222',
    );
    await tester.enterText(
      find.byKey(const Key('professional-profile-id-value')),
      '10123456789',
    );
    await _scrollTo(tester, find.byKey(const Key('save-professional-profile')));
    await tester.tap(find.byKey(const Key('save-professional-profile')));
    await tester.pumpAndSettle();

    expect(find.text('nina.modifiee@example.fr'), findsOneWidget);
    final saved = await repository.getVolunteerProfile();
    expect(saved?.email, 'nina.modifiee@example.fr');
    expect(saved?.phone, '0622222222');
    expect(saved?.effectiveProfessionalIdType, ProfessionalIdType.rpps);
    expect(saved?.effectiveProfessionalIdValue, '10123456789');
    expect(saved?.cptsId, 'legacy-cpts-id');
    expect(saved?.cptsLabel, 'CPTS Historique');
    expect(saved?.createdAt, isNotNull);
  });

  testWidgets('general V2 preferences are visible, editable and persisted', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      responsibleAccess: null,
      initialProfiles: {
        'mock-volunteer': _verifiedProfile().copyWith(
          mobilizationPreferences: MobilizationPreferences(
            territoryIds: const {'medoc'},
            locationIds: const {'merignac'},
            preferredWeekdays: const {
              ProfessionalWeekday.monday,
              ProfessionalWeekday.saturday,
            },
            preferredTimeBands: const {'morning', 'evening'},
          ),
        ),
      },
    );

    await _pumpApp(tester, repository);
    await _openProfessionalProfile(tester);
    await _scrollProfileTo(
      tester,
      find.byKey(const Key('edit-professional-preferences')),
    );
    expect(
      find.text('Secteurs : medoc · Établissements : merignac'),
      findsOneWidget,
    );
    expect(find.text('Lundi, Samedi'), findsOneWidget);
    expect(find.text('Matin, Soir'), findsOneWidget);
    expect(find.text('COMPTE'), findsOneWidget);
    expect(find.byKey(const Key('open-responsible-access')), findsNothing);

    await tester.tap(find.byKey(const Key('edit-professional-preferences')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('professional-profile-editor-mode-preferences')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('professional-profile-first-name')),
      findsNothing,
    );
    expect(find.text('Où souhaitez-vous intervenir ?'), findsOneWidget);
    expect(find.text('Secteurs d’intervention'), findsOneWidget);
    expect(
      find.text('Établissements précis (facultatif)'),
      findsOneWidget,
    );
    await _scrollTo(
      tester,
      find.byKey(const Key('professional-profile-territories')),
    );
    await tester.tap(
      find.byKey(const Key('professional-profile-territories')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('professional-profile-territory-southBasin')),
    );
    await tester.tap(
      find.byKey(const Key('professional-profile-territory-apply')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('professional-profile-weekdays')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('professional-profile-weekday-tuesday')),
    );
    await tester.tap(
      find.byKey(const Key('professional-profile-weekday-apply')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('professional-profile-time-bands')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('professional-profile-time-band-afternoon')),
    );
    await tester.tap(
      find.byKey(const Key('professional-profile-time-band-evening')),
    );
    await tester.tap(
      find.byKey(const Key('professional-profile-time-band-apply')),
    );
    await _scrollTo(tester, find.byKey(const Key('save-professional-profile')));
    await tester.tap(find.byKey(const Key('save-professional-profile')));
    await tester.pumpAndSettle();

    final saved = await repository.getVolunteerProfile();
    expect(saved?.mobilizationPreferences?.territoryIds, {
      'medoc',
      'southBasin',
    });
    expect(saved?.mobilizationPreferences?.locationIds, {'merignac'});
    expect(saved?.mobilizationPreferences?.preferredWeekdays, {
      ProfessionalWeekday.monday,
      ProfessionalWeekday.tuesday,
      ProfessionalWeekday.saturday,
    });
    expect(saved?.mobilizationPreferences?.preferredTimeBands, {
      'morning',
      'afternoon',
    });
  });

  for (final width in const [390.0, 430.0]) {
    testWidgets('postal code and city stay aligned at ${width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        FireCoordinationApp(
          repository: MockCoordinationRepository(responsibleAccess: null),
        ),
      );
      await tester.pumpAndSettle();
      await _openProfessionalProfile(tester);
      await tester.tap(find.byKey(const Key('edit-professional-profile')));
      await tester.pumpAndSettle();
      final postal = find.byKey(const Key('professional-profile-postal-code'));
      final city = find.byKey(const Key('professional-profile-city'));
      await _scrollTo(tester, postal);

      final postalLabel = find.descendant(
        of: postal,
        matching: find.text('Code postal'),
      );
      final cityLabel = find.descendant(of: city, matching: find.text('Ville'));
      final postalField = find.descendant(
        of: postal,
        matching: find.byType(TextFormField),
      );
      final cityField = find.descendant(
        of: city,
        matching: find.byType(TextFormField),
      );
      expect(
        tester.getTopLeft(postalLabel).dy,
        closeTo(tester.getTopLeft(cityLabel).dy, 0.5),
      );
      expect(
        tester.getTopLeft(postalField).dy,
        closeTo(tester.getTopLeft(cityField).dy, 0.5),
      );
      expect(
        tester.getBottomLeft(postalField).dy,
        closeTo(tester.getBottomLeft(cityField).dy, 0.5),
      );
      expect(
        tester.getTopRight(postalField).dx,
        lessThan(tester.getTopLeft(cityField).dx),
      );
      final postalWidth = tester.getSize(postal).width;
      final cityWidth = tester.getSize(city).width;
      expect(cityWidth, greaterThan(postalWidth));
      expect(cityWidth / postalWidth, closeTo(1.5, 0.05));
      expect(tester.takeException(), isNull);
    });
  }

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

    await _scrollProfileTo(
      tester,
      find.byKey(const Key('verify-professional-rpps')),
    );
    expect(find.byKey(const Key('verify-professional-rpps')), findsOneWidget);
    expect(
      (await repository.getVolunteerProfile())?.verificationStatus,
      'unverified',
    );
  });

  testWidgets('profile summary opens CPTS and equipment in targeted editors', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      responsibleAccess: null,
      initialProfiles: {'mock-volunteer': _verifiedProfile()},
    );
    await _pumpApp(tester, repository);
    await _openProfessionalProfile(tester);

    await _scrollProfileTo(
      tester,
      find.byKey(const Key('edit-professional-cpts')),
    );
    await tester.tap(find.byKey(const Key('edit-professional-cpts')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('professional-profile-editor-mode-cpts')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('professional-profile-cpts-label')), findsOneWidget);
    expect(find.byKey(const Key('professional-profile-first-name')), findsNothing);
    Navigator.of(
      tester.element(find.byKey(const Key('professional-profile-cpts-label'))),
    ).pop();
    await tester.pumpAndSettle();

    await _scrollProfileTo(
      tester,
      find.byKey(const Key('edit-professional-equipment')),
    );
    await tester.tap(find.byKey(const Key('edit-professional-equipment')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('professional-profile-editor-mode-equipment')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('professional-profile-first-name')),
      findsNothing,
    );
    expect(find.text('Matériel disponible'), findsWidgets);
  });

  testWidgets(
    'profile summary danger state follows canonical engagement gaps',
    (tester) async {
      final repository = MockCoordinationRepository(
        responsibleAccess: null,
        initialProfiles: {
          'mock-volunteer': _verifiedProfile().copyWith(
            email: 'email-invalide',
            cptsId: null,
            cptsLabel: null,
          ),
        },
      );
      await _pumpApp(tester, repository);
      await _openProfessionalProfile(tester);

      final colors = Theme.of(
        tester.element(find.byType(ProfessionalShell)),
      ).extension<V5Colors>()!;
      final emailValue = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('professional-profile-value-email')),
          matching: find.text('email-invalide'),
        ),
      );
      expect(emailValue.style?.color, colors.danger);
      expect(find.textContaining('Informations manquantes : Email valide'), findsOneWidget);

      await _scrollProfileTo(tester, find.text('Aucune CPTS renseignée'));
      final optionalCpts = tester.widget<Text>(
        find.text('Aucune CPTS renseignée'),
      );
      expect(optionalCpts.style?.color, colors.textPrimary);
      await _scrollProfileTo(tester, find.text('Aucun renseigné'));
      final optionalEquipment = tester.widget<Text>(find.text('Aucun renseigné'));
      expect(optionalEquipment.style?.color, colors.textPrimary);
    },
  );

  testWidgets(
    'missing profile marks required values only and keeps optional values neutral',
    (tester) async {
      final repository = MockCoordinationRepository(
        responsibleAccess: null,
        initialProfiles: const {},
      );
      await _pumpApp(tester, repository);
      await _openProfessionalProfile(tester);

      final colors = Theme.of(
        tester.element(find.byType(ProfessionalShell)),
      ).extension<V5Colors>()!;
      final missingName = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('professional-profile-value-name')),
          matching: find.text('Non renseigné'),
        ),
      );
      expect(missingName.style?.color, colors.danger);

      await _scrollProfileTo(tester, find.text('Aucune CPTS renseignée'));
      expect(
        tester.widget<Text>(find.text('Aucune CPTS renseignée')).style?.color,
        colors.textPrimary,
      );
      await _scrollProfileTo(tester, find.text('Aucun renseigné'));
      expect(
        tester.widget<Text>(find.text('Aucun renseigné')).style?.color,
        colors.textPrimary,
      );
    },
  );

  testWidgets('valid profile summary has no false danger value', (tester) async {
    final repository = MockCoordinationRepository(
      responsibleAccess: null,
      initialProfiles: {'mock-volunteer': _verifiedProfile()},
    );
    await _pumpApp(tester, repository);
    await _openProfessionalProfile(tester);

    final colors = Theme.of(
      tester.element(find.byType(ProfessionalShell)),
    ).extension<V5Colors>()!;
    for (final key in const [
      Key('professional-profile-value-name'),
      Key('professional-profile-value-phone'),
      Key('professional-profile-value-email'),
      Key('professional-profile-value-profession'),
      Key('professional-profile-value-address'),
      Key('professional-profile-value-locality'),
      Key('professional-profile-value-cpts'),
      Key('professional-profile-value-equipment'),
    ]) {
      await _scrollProfileTo(tester, find.byKey(key));
      final values = tester.widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      );
      expect(values.last.style?.color, isNot(colors.danger), reason: '$key');
    }
  });

  testWidgets(
    'targeted equipment validation focuses only its visible invalid field '
    'and preserves an invalid global profile',
    (tester) async {
      final repository = MockCoordinationRepository(
        responsibleAccess: null,
        initialProfiles: {
          'mock-volunteer': _verifiedProfile().copyWith(
            email: 'email-invalide',
            professionalIdType: ProfessionalIdType.ordinal,
            professionalIdValue: 'ORD-123',
            equipment: const [ProfessionalEquipmentId.otherEquipment],
            otherEquipmentDetails: '',
          ),
        },
      );
      await _pumpApp(tester, repository);
      await _openProfessionalProfile(tester);
      await _scrollProfileTo(
        tester,
        find.byKey(const Key('edit-professional-equipment')),
      );
      await tester.tap(find.byKey(const Key('edit-professional-equipment')));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const Key('save-professional-profile')));
      await tester.tap(find.byKey(const Key('save-professional-profile')));
      await tester.pumpAndSettle();

      expect(find.text('Champ requis'), findsOneWidget);
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        'profile-equipment-details',
      );
      expect(find.byKey(const Key('professional-profile-email')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('professional-profile-equipment-details')),
        'Kit de test',
      );
      await _scrollTo(
        tester,
        find.byKey(const Key('save-professional-profile')),
      );
      await tester.tap(find.byKey(const Key('save-professional-profile')));
      await tester.pumpAndSettle();

      final saved = await repository.getVolunteerProfile();
      expect(saved?.email, 'email-invalide');
      expect(saved?.professionalIdType, ProfessionalIdType.ordinal);
      expect(saved?.professionalIdValue, 'ORD-123');
      expect(saved?.otherEquipmentDetails, isEmpty);
      expect(
        find.byKey(const Key('professional-profile-editor-mode-equipment')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Votre profil doit être complété'),
        findsOneWidget,
      );
      expect(find.text('Compléter mon profil'), findsOneWidget);
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        isNot('profile-email'),
      );
      await tester.tap(find.text('Compléter mon profil'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('professional-profile-editor-mode-completion')),
        findsOneWidget,
      );
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        'profile-email',
      );
    },
  );

  testWidgets('unknown targeted save failure keeps the generic error', (
    tester,
  ) async {
    final repository = _FailingSaveRepository(
      initialProfiles: {'mock-volunteer': _verifiedProfile()},
    );
    await _pumpApp(tester, repository);
    await _openProfessionalProfile(tester);
    await _scrollProfileTo(tester, find.byKey(const Key('edit-professional-cpts')));
    await tester.tap(find.byKey(const Key('edit-professional-cpts')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('save-professional-profile')));
    await tester.tap(find.byKey(const Key('save-professional-profile')));
    await tester.pumpAndSettle();

    expect(
      find.text('Le profil n’a pas pu être enregistré. Réessayez.'),
      findsOneWidget,
    );
    expect(find.text('Compléter mon profil'), findsNothing);
    expect(
      find.byKey(const Key('professional-profile-editor-mode-cpts')),
      findsOneWidget,
    );
  });

  testWidgets('completion mode focuses its first correctable gap', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      responsibleAccess: null,
      initialProfiles: {
        'mock-volunteer': _verifiedProfile().copyWith(firstName: ''),
      },
    );
    await _pumpApp(tester, repository);
    await _openProfessionalProfile(tester);
    await tester.tap(find.byKey(const Key('edit-professional-profile')));
    await tester.pumpAndSettle();

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'profile-first-name',
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

    await _scrollProfileTo(
      tester,
      find.byKey(const Key('verify-professional-rpps')),
    );
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
              professionalAddressLine1: '10 rue de la Santé',
              professionalPostalCode: '33000',
              professionalCity: 'Bordeaux',
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
  professionalAddressLine1: '10 rue de la Santé',
  professionalPostalCode: '33000',
  professionalCity: 'Bordeaux',
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
  if (find
      .byKey(const Key('professional-profile-completion-actions'))
      .evaluate()
      .isNotEmpty) {
    return;
  }
  await tester.tap(find.text('Profil'));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const Key('professional-profile-completion-actions')),
    findsOneWidget,
  );
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

Future<void> _scrollProfileTo(WidgetTester tester, Finder target) async {
  final profile = find.byKey(const PageStorageKey('professional-profile'));
  for (var attempt = 0; attempt < 10; attempt++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(profile, const Offset(0, -320));
    await tester.pumpAndSettle();
  }
  expect(target, findsWidgets);
}

String _fieldText(WidgetTester tester, Key key) =>
    tester.widget<V5TextField>(find.byKey(key)).controller?.text ?? '';

class _FailingSaveRepository extends MockCoordinationRepository {
  _FailingSaveRepository({required Map<String, VolunteerProfile> initialProfiles})
    : super(responsibleAccess: null, initialProfiles: initialProfiles);

  @override
  Future<void> saveVolunteerProfile(VolunteerProfile profile) async {
    throw StateError('technical test failure');
  }
}
