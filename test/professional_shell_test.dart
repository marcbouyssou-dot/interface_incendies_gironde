import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/development_settings_screen.dart';
import 'package:interface_incendies_gironde/screens/coordinator_shell.dart';
import 'package:interface_incendies_gironde/screens/professional_shell.dart';
import 'package:interface_incendies_gironde/screens/responsible_home_screen.dart';
import 'package:interface_incendies_gironde/screens/responsible_shell.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';
import 'package:interface_incendies_gironde/utils/mission_timing.dart';
import 'package:interface_incendies_gironde/widgets/responsible_bottom_navigation.dart';
import 'package:interface_incendies_gironde/widgets/coordinator_bottom_navigation.dart';
import 'package:interface_incendies_gironde/widgets/v5_bottom_navigation.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';

void main() {
  Future<void> selectPreview(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('role-preview-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> closeSettings(WidgetTester tester) async {
    final context = tester.element(find.byType(DevelopmentSettingsScreen));
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
  }

  testWidgets('professional journey exposes exactly the three V5 tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(responsibleAccess: null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfessionalShell), findsOneWidget);
    expect(find.byType(V5BottomNavigation), findsOneWidget);
    expect(find.text('MobSanté'), findsOneWidget);
    expect(find.text('Professionnel'), findsOneWidget);
    expect(
      find.text('Trouvez rapidement où vous pouvez être utile.'),
      findsOneWidget,
    );
    expect(find.text('Bonjour'), findsNothing);
    expect(
      find.text('1 mission urgente nécessite votre attention.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('decision-header-secondary')), findsNothing);
    expect(find.byKey(const Key('professional-hero-where')), findsOneWidget);
    expect(find.byKey(const Key('professional-hero-when')), findsOneWidget);
    expect(find.byKey(const Key('slots-territorial-filter')), findsNothing);
    expect(
      find.byKey(const Key('professional-secondary-filters')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('professional-status-filters')), findsNothing);
    expect(find.byKey(const Key('mission-coverage-overview')), findsNothing);
    expect(find.text('Les missions qui ont besoin de vous'), findsNothing);
    expect(
      find.byKey(const Key('professional-missions-section-title')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('professional-missions-period')),
      findsOneWidget,
    );
    expect(find.text('À venir'), findsOneWidget);
    expect(find.text('Voir les détails'), findsWidgets);
    expect(find.text('Détails de la mission'), findsNothing);

    final firstMission = find.byKey(const ValueKey('mission-merignac'));
    final missionLocation = find.descendant(
      of: firstMission,
      matching: find.text('Mérignac'),
    );
    final missionDate = find.descendant(
      of: firstMission,
      matching: find.text('mardi 29 juillet'),
    );
    final missionProfession = find.descendant(
      of: firstMission,
      matching: find.text('Profession recherchée'),
    );
    final missionUrgency = find.byKey(
      const Key('mission-priority-mission-merignac'),
    );
    final missionAction = find.descendant(
      of: firstMission,
      matching: find.text('Je me mobilise'),
    );
    expect(
      tester.getTopLeft(missionLocation).dy,
      lessThan(tester.getTopLeft(missionDate).dy),
    );
    expect(
      tester.getTopLeft(missionDate).dy,
      lessThan(tester.getTopLeft(missionProfession).dy),
    );
    expect(
      tester.getTopLeft(missionProfession).dy,
      lessThan(tester.getTopLeft(missionUrgency).dy),
    );
    expect(
      tester.getTopLeft(missionUrgency).dy,
      lessThan(tester.getTopLeft(missionAction).dy),
    );

    final colors = Theme.of(
      tester.element(find.byType(ProfessionalShell)),
    ).extension<V5Colors>()!;
    expect(find.byKey(const Key('professional-page-title')), findsOneWidget);

    final mobilizeButton = find.ancestor(
      of: find.text('Je me mobilise').first,
      matching: find.byType(FilledButton),
    );
    expect(mobilizeButton, findsOneWidget);
    expect(
      find.descendant(of: mobilizeButton, matching: find.byType(Icon)),
      findsNothing,
    );
    final mobilize = tester.widget<FilledButton>(mobilizeButton);
    expect(mobilize.style?.backgroundColor?.resolve({}), colors.info);

    await tester.tap(find.byKey(const Key('professional-hero-where')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bordeaux Métropole').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('professional-hero-where')),
        matching: find.text('Bordeaux Métropole'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('professional-hero-when')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('mardi 29 juillet').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('professional-hero-when')),
        matching: find.text('mardi 29 juillet'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('professional-secondary-filters')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('professional-status-filters')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('professional-reset-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Bordeaux Métropole'), findsNothing);
    expect(find.text('mardi 29 juillet'), findsWidgets);

    final detailsDisclosure = find.text('Voir les détails').first;
    await tester.drag(
      find.byKey(const PageStorageKey('slots')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(detailsDisclosure);
    await tester.pumpAndSettle();
    expect(find.text('Détails de la mission'), findsOneWidget);

    final navigation = tester.widget<V5BottomBar>(
      find.byKey(const Key('v5-bottom-navigation')),
    );
    expect(navigation.destinations, hasLength(3));
    expect(navigation.selectedColor, colors.info);
    expect(find.text('Missions'), findsWidgets);
    expect(find.text('Engagements'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Déclarer'), findsNothing);
    expect(find.text('Statistiques'), findsNothing);
    expect(find.text('Plus'), findsNothing);

    await tester.tap(find.text('Engagements'));
    await tester.pumpAndSettle();
    expect(find.text('Mes engagements'), findsOneWidget);
    expect(find.text('Aucun engagement à venir.'), findsOneWidget);
    expect(find.text('Aujourd’hui'), findsOneWidget);
    expect(find.text('À venir'), findsOneWidget);
    expect(find.text('Passés'), findsOneWidget);
    expect(find.text('En cours'), findsNothing);
    expect(
      find.text('Vos engagements seront bientôt disponibles ici.'),
      findsNothing,
    );

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Identité professionnelle'), findsOneWidget);
    expect(
      find.text('Votre profil professionnel sera bientôt disponible ici.'),
      findsNothing,
    );
    await tester.drag(
      find.byKey(const PageStorageKey('professional-profile')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-responsible-access')), findsOneWidget);
  });

  testWidgets('professional mission empty state repeats its active period', (
    tester,
  ) async {
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(
          initialMissions: const [],
          responsibleAccess: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('À venir'), findsOneWidget);
    expect(find.text('Aucune mission à venir.'), findsNWidgets(2));
    expect(
      find.text('Les nouvelles missions de cette période apparaîtront ici.'),
      findsOneWidget,
    );
  });

  testWidgets('a real coordinator receives the territorial V5 journey', (
    tester,
  ) async {
    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();

    expect(find.byType(ProfessionalShell), findsNothing);
    expect(find.byType(V5BottomNavigation), findsNothing);
    expect(find.byType(CoordinatorShell), findsOneWidget);
    expect(find.byType(CoordinatorBottomNavigation), findsOneWidget);
    expect(find.byKey(const Key('mission-coverage-overview')), findsNothing);
    expect(find.byKey(const Key('slots-territorial-filter')), findsNothing);
    expect(
      find.byKey(const Key('professional-secondary-filters')),
      findsNothing,
    );
    expect(
      find.text('1 mission urgente nécessite votre attention.'),
      findsNothing,
    );
    final navigation = tester.widget<V5BottomBar>(find.byType(V5BottomBar));
    expect(navigation.destinations, hasLength(4));
    expect(find.text('Cockpit'), findsOneWidget);
    expect(find.text('Territoire'), findsOneWidget);
    expect(find.text('Acteurs'), findsOneWidget);
    expect(find.text('Déclarer'), findsNothing);
  });

  testWidgets('the active journey follows responsible access changes', (
    tester,
  ) async {
    final repository = _RoleAwareRepository();
    addTearDown(repository.disposeRoleStream);
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byType(ProfessionalShell), findsOneWidget);

    repository.setAccess(
      const ResponsibleAccess(
        uid: 'manager',
        role: ResponsibleRole.siteManager,
        locationIds: {'location-bazas'},
        active: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfessionalShell), findsNothing);
    expect(find.byType(ResponsibleShell), findsOneWidget);
    expect(find.byType(ResponsibleHomeScreen), findsOneWidget);
    expect(find.text('Responsable'), findsOneWidget);
    expect(
      find.text('Organisez la couverture de votre établissement.'),
      findsOneWidget,
    );
    expect(find.text('Mon planning est-il sécurisé ?'), findsNothing);
    expect(find.text('Tout est couvert pour demain.'), findsOneWidget);
    expect(find.text('Demain dans mon établissement'), findsOneWidget);
    expect(
      find.byKey(const Key('responsible-planning-context')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('responsible-create-need')), findsOneWidget);
    expect(find.text('À traiter'), findsOneWidget);
    expect(find.text('Sous contrôle'), findsOneWidget);
    expect(find.text('Équipe'), findsWidgets);
    expect(find.byType(ResponsibleBottomNavigation), findsOneWidget);
    final navigation = tester.widget<V5BottomBar>(find.byType(V5BottomBar));
    expect(navigation.destinations, hasLength(4));
  });

  testWidgets('responsible home answers the planning decision immediately', (
    tester,
  ) async {
    final merignac = places.firstWhere((place) => place.name == 'Mérignac');
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final repository = MockCoordinationRepository(
      initialMissions: [
        _responsibleMission(
          id: 'mission-merignac',
          location: merignac,
          day: tomorrow,
          startHour: 8,
          endHour: 12,
          requiredMk: 4,
          registeredMk: 1,
        ),
      ],
      responsibleAccess: ResponsibleAccess(
        uid: 'manager',
        role: ResponsibleRole.siteManager,
        locationIds: {merignac.id},
        active: true,
      ),
    );

    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byType(ResponsibleHomeScreen), findsOneWidget);
    expect(find.text('3 postes restent à couvrir demain.'), findsOneWidget);
    expect(find.textContaining('Demain  •  Centre : Mérignac'), findsOneWidget);
    expect(
      find.byKey(const Key('responsible-open-need-mission-merignac')),
      findsOneWidget,
    );
    expect(find.text('1 confirmé sur 4 attendus demain.'), findsOneWidget);
    expect(
      find.byKey(const Key('responsible-missing-professions')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('responsible-next-deadline')), findsOneWidget);
    final globalState = find.byKey(const Key('responsible-planning-verdict'));
    final missingProfessions = find.byKey(
      const Key('responsible-missing-professions'),
    );
    final deadline = find.byKey(const Key('responsible-next-deadline'));
    final action = find.byKey(const Key('responsible-create-need'));
    expect(
      tester.getTopLeft(globalState).dy,
      lessThan(tester.getTopLeft(missingProfessions).dy),
    );
    expect(
      tester.getTopLeft(missingProfessions).dy,
      lessThan(tester.getTopLeft(deadline).dy),
    );
    expect(
      tester.getTopLeft(deadline).dy,
      lessThan(tester.getTopLeft(action).dy),
    );
    expect(find.text('Statistiques'), findsNothing);
    expect(find.text('Tableau de bord'), findsNothing);
    final colors = Theme.of(
      tester.element(find.byType(ResponsibleShell)),
    ).extension<V5Colors>()!;
    final createButton = tester.widget<V5Button>(
      find.ancestor(
        of: find.text('Créer un besoin'),
        matching: find.byType(V5Button),
      ),
    );
    expect(createButton.backgroundColor, colors.accent);
    final responsibleNavigation = tester.widget<V5BottomBar>(
      find.byKey(const Key('responsible-bottom-navigation')),
    );
    expect(responsibleNavigation.selectedColor, colors.accent);

    await tester.tap(find.text('Besoins'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('responsible-needs-filter-attention')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('responsible-needs-filter-inProgress')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('responsible-needs-filter-covered')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('responsible-needs-filter-past')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('responsible-need-mission-merignac')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('responsible-need-mission-langon')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('responsible-edit-need-mission-merignac')),
      findsOneWidget,
    );
    expect(find.text('1 / 4'), findsOneWidget);
    expect(
      find.byKey(const Key('responsible-view-team-mission-merignac')),
      findsOneWidget,
    );

    await tester.tap(find.text('Équipe').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('responsible-team-mission-merignac')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('responsible-team-mission-langon')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('responsible-team-filter-confirmed')),
      findsOneWidget,
    );
    expect(find.text('Marc BOUYSSOU'), findsOneWidget);
    expect(find.textContaining('Pédicure-Podologue'), findsOneWidget);
    expect(find.text('mock-confirmed'), findsNothing);
    expect(
      find.byKey(const Key('engagement-menu-mission-merignac_mock-confirmed')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('responsible-team-filter-pending')));
    await tester.pumpAndSettle();
    expect(find.text('Camille Martin'), findsOneWidget);
    expect(find.text('mock-pending'), findsNothing);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Mérignac'), findsOneWidget);
    expect(find.text('Perspective'), findsNothing);
    expect(find.text('Centre géré'), findsOneWidget);
    expect(find.text('Identité'), findsNothing);
    expect(find.text('Identifiant du compte'), findsNothing);
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Gestion des responsables'), findsNothing);
    expect(find.byKey(const Key('admin-locations-entry')), findsNothing);
  });

  test('responsible tomorrow scope distinguishes local calendar days', () {
    final bassens = places.first;
    final now = DateTime(2026, 8, 25, 12);

    CoordinationNeed missionOn(int day, int startHour, int endHour) =>
        _responsibleMission(
          id: 'mission-$day',
          location: bassens,
          day: DateTime(2026, 8, day),
          startHour: startHour,
          endHour: endHour,
          requiredMk: 1,
        );

    expect(
      isMissionScheduledForTomorrow(missionOn(24, 8, 12), now: now),
      isFalse,
    );
    expect(
      isMissionScheduledForTomorrow(missionOn(25, 14, 18), now: now),
      isFalse,
    );
    expect(
      isMissionScheduledForTomorrow(missionOn(26, 8, 12), now: now),
      isTrue,
    );
    expect(
      isMissionScheduledForTomorrow(missionOn(27, 8, 12), now: now),
      isFalse,
    );
  });

  testWidgets(
    'responsible home aggregates only tomorrow missions and their deadline',
    (tester) async {
      final bassens = places.first;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final repository = MockCoordinationRepository(
        initialMissions: [
          _responsibleMission(
            id: 'past-need',
            location: bassens,
            day: DateTime(today.year, today.month, today.day - 2),
            startHour: 8,
            endHour: 10,
            requiredMk: 40,
          ),
          _responsibleMission(
            id: 'today-need',
            location: bassens,
            day: today,
            startHour: 0,
            endHour: 23,
            requiredMk: 50,
          ),
          _responsibleMission(
            id: 'tomorrow-early',
            location: bassens,
            day: tomorrow,
            startHour: 8,
            endHour: 10,
            requiredMk: 2,
            registeredMk: 1,
            requiredPp: 1,
            dateLabel: 'Demain tôt',
          ),
          _responsibleMission(
            id: 'tomorrow-late',
            location: bassens,
            day: tomorrow,
            startHour: 14,
            endHour: 18,
            requiredMk: 3,
            registeredMk: 1,
            requiredPp: 2,
            registeredPp: 1,
            dateLabel: 'Demain tard',
          ),
          _responsibleMission(
            id: 'after-tomorrow-need',
            location: bassens,
            day: DateTime(today.year, today.month, today.day + 2),
            startHour: 8,
            endHour: 10,
            requiredMk: 60,
          ),
        ],
        initialLocations: [bassens],
        responsibleAccess: ResponsibleAccess(
          uid: 'manager-tomorrow',
          role: ResponsibleRole.siteManager,
          locationIds: {bassens.id},
          active: true,
        ),
      );

      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('5 postes restent à couvrir demain.'), findsOneWidget);
      expect(
        find.text('Masseur-kinésithérapeute · 3 · Pédicure-podologue · 2'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('responsible-next-deadline')),
          matching: find.text('Demain tôt · 08:00–10:00'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('responsible-open-need-tomorrow-early')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('responsible-open-need-tomorrow-late')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('responsible-open-need-past-need')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('responsible-open-need-today-need')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('responsible-open-need-after-tomorrow-need')),
        findsNothing,
      );
    },
  );

  testWidgets('responsible home never falls back outside tomorrow', (
    tester,
  ) async {
    final bassens = places.first;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final repository = MockCoordinationRepository(
      initialMissions: [
        _responsibleMission(
          id: 'past-only',
          location: bassens,
          day: DateTime(today.year, today.month, today.day - 1),
          startHour: 8,
          endHour: 10,
          requiredMk: 20,
        ),
        _responsibleMission(
          id: 'future-only',
          location: bassens,
          day: DateTime(today.year, today.month, today.day + 2),
          startHour: 8,
          endHour: 10,
          requiredMk: 30,
        ),
      ],
      initialLocations: [bassens],
      responsibleAccess: ResponsibleAccess(
        uid: 'manager-no-tomorrow',
        role: ResponsibleRole.siteManager,
        locationIds: {bassens.id},
        active: true,
      ),
    );

    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Tout est couvert pour demain.'), findsOneWidget);
    expect(find.text('Aucune profession manquante.'), findsOneWidget);
    expect(find.text('Aucune échéance demain.'), findsOneWidget);
    expect(
      find.text('Rien ne nécessite votre intervention pour demain.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('responsible-open-need-past-only')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('responsible-open-need-future-only')),
      findsNothing,
    );
  });

  testWidgets('site manager never sees the technical perspective selector', (
    tester,
  ) async {
    final merignac = places.firstWhere((place) => place.name == 'Mérignac');
    final repository = MockCoordinationRepository(
      responsibleAccess: ResponsibleAccess(
        uid: 'manager',
        role: ResponsibleRole.siteManager,
        locationIds: {merignac.id},
        active: true,
      ),
    );

    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Perspective'), findsNothing);
    expect(find.byKey(const Key('perspective-professional')), findsNothing);
    expect(find.byType(ResponsibleShell), findsOneWidget);
    expect(find.byKey(const Key('cross-role-preview-banner')), findsNothing);
  });

  testWidgets('responsible team uses a neutral fallback without exposing UID', (
    tester,
  ) async {
    final merignac = places.firstWhere((place) => place.name == 'Mérignac');
    final mission = needs.firstWhere(
      (candidate) => candidate.id == 'mission-merignac',
    );
    final repository = MockCoordinationRepository(
      initialMissions: [mission],
      initialLocations: [merignac],
      initialEngagements: const [
        EngagementInfo(
          missionId: 'mission-merignac',
          volunteerId: 'raw-technical-uid',
          profession: VolunteerProfession.nurse,
        ),
      ],
      responsibleAccess: ResponsibleAccess(
        uid: 'manager',
        role: ResponsibleRole.siteManager,
        locationIds: {merignac.id},
        active: true,
      ),
    );

    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Équipe').last);
    await tester.pumpAndSettle();

    expect(find.text('Professionnel'), findsOneWidget);
    expect(find.textContaining('Infirmier'), findsOneWidget);
    expect(find.text('raw-technical-uid'), findsNothing);
  });

  testWidgets('responsible empty states communicate operational serenity', (
    tester,
  ) async {
    final bassens = places.first;
    final repository = MockCoordinationRepository(
      initialMissions: const [],
      initialLocations: [bassens],
      initialEngagements: const [],
      responsibleAccess: ResponsibleAccess(
        uid: 'manager-empty',
        role: ResponsibleRole.siteManager,
        locationIds: {bassens.id},
        active: true,
      ),
    );

    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Tout est couvert pour demain.'), findsOneWidget);
    expect(
      find.textContaining('Demain  •  Centre : ${bassens.name}'),
      findsOneWidget,
    );
    expect(
      find.text('Rien ne nécessite votre intervention pour demain.'),
      findsOneWidget,
    );
    expect(
      find.text('Tous les besoins de demain sont couverts.'),
      findsOneWidget,
    );
    expect(
      find.text('Aucun professionnel mobilisé pour demain.'),
      findsOneWidget,
    );
    expect(
      find.text('Les confirmations pour demain apparaîtront ici.'),
      findsNothing,
    );
    final colors = Theme.of(
      tester.element(find.byType(ResponsibleShell)),
    ).extension<V5Colors>()!;
    final calmCreateButton = tester.widget<V5Button>(
      find.ancestor(
        of: find.text('Créer un besoin'),
        matching: find.byType(V5Button),
      ),
    );
    expect(calmCreateButton.backgroundColor, colors.warningContainer);

    await tester.tap(find.text('Besoins'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('responsible-needs-period')), findsOneWidget);
    expect(find.text('Aujourd’hui et à venir'), findsOneWidget);
    expect(find.text('Aucun besoin aujourd’hui ou à venir'), findsOneWidget);
    expect(
      find.text('Votre planning est couvert pour cette période.'),
      findsOneWidget,
    );
    expect(find.text('En cours'), findsNothing);
    expect(
      find.byKey(const Key('responsible-needs-empty-create')),
      findsOneWidget,
    );

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun besoin passé'), findsOneWidget);
    expect(
      find.text('L’historique de votre établissement apparaîtra ici.'),
      findsOneWidget,
    );
  });

  testWidgets('debug settings switch the displayed shell instantly', (
    tester,
  ) async {
    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-development-settings')));
    await tester.pumpAndSettle();

    expect(find.text('Mode Développement'), findsOneWidget);
    expect(find.text('Automatique'), findsOneWidget);
    await selectPreview(tester, 'Professionnel');
    await closeSettings(tester);
    expect(find.byType(ProfessionalShell), findsOneWidget);
    expect(
      find.text('1 mission urgente nécessite votre attention.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mission-coverage-overview')), findsNothing);
    expect(find.text('Voir les détails'), findsWidgets);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const PageStorageKey('professional-profile')),
      const Offset(0, -1800),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const PageStorageKey('professional-profile')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-development-settings')));
    await tester.pumpAndSettle();
    await selectPreview(tester, 'Responsable');
    await closeSettings(tester);

    expect(find.byType(ProfessionalShell), findsNothing);
    expect(find.byType(ResponsibleShell), findsOneWidget);
    expect(find.byType(ResponsibleHomeScreen), findsOneWidget);
    expect(find.byType(ResponsibleBottomNavigation), findsOneWidget);
  });

  testWidgets('coordinator preview never elevates a real site manager', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      responsibleAccess: ResponsibleAccess(
        uid: 'manager',
        role: ResponsibleRole.siteManager,
        locationIds: {places.first.id},
        active: true,
      ),
    );
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    final developmentSettings = find.byKey(
      const Key('responsible-development-settings'),
    );
    await tester.drag(
      find.byKey(const PageStorageKey('responsible-profile')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    await tester.tap(developmentSettings);
    await tester.pumpAndSettle();
    await selectPreview(tester, 'Coordinateur');
    await closeSettings(tester);

    expect(find.byType(CoordinatorShell), findsOneWidget);
    expect(find.byKey(const Key('admin-invitations-entry')), findsNothing);
    expect(find.byKey(const Key('admin-locations-entry')), findsNothing);
  });
}

class _RoleAwareRepository extends MockCoordinationRepository {
  _RoleAwareRepository() : super(responsibleAccess: null);

  ResponsibleAccess? _access;
  final _accessUpdates = StreamController<ResponsibleAccess?>.broadcast();

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() =>
      Stream<ResponsibleAccess?>.multi((controller) {
        controller.add(_access);
        final subscription = _accessUpdates.stream.listen(controller.add);
        controller.onCancel = subscription.cancel;
      });

  void setAccess(ResponsibleAccess? access) {
    _access = access;
    _accessUpdates.add(access);
  }

  Future<void> disposeRoleStream() => _accessUpdates.close();
}

CoordinationNeed _responsibleMission({
  required String id,
  required ResponsePlace location,
  required DateTime day,
  required int startHour,
  required int endHour,
  int requiredMk = 0,
  int registeredMk = 0,
  int requiredPp = 0,
  int registeredPp = 0,
  String? dateLabel,
}) => CoordinationNeed(
  id: id,
  place: location.name,
  group: location.group,
  date: dateLabel ?? 'Jour du besoin',
  time:
      '${startHour.toString().padLeft(2, '0')}:00–'
      '${endHour.toString().padLeft(2, '0')}:00',
  requiredPhysiotherapists: requiredMk,
  registeredPhysiotherapists: registeredMk,
  requiredPodiatrists: requiredPp,
  registeredPodiatrists: registeredPp,
  equipment: const [],
  mobilizationId: 'mobilization-test',
  locationId: location.id,
  startAt: DateTime(day.year, day.month, day.day, startHour),
  endAt: DateTime(day.year, day.month, day.day, endHour),
);
