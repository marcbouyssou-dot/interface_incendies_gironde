import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
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
import 'package:interface_incendies_gironde/screens/responsible_needs_screen.dart';
import 'package:interface_incendies_gironde/screens/responsible_team_screen.dart';
import 'package:interface_incendies_gironde/screens/responsible_profile_screen.dart';
import 'package:interface_incendies_gironde/screens/responsible_shell.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';
import 'package:interface_incendies_gironde/utils/mission_timing.dart';
import 'package:interface_incendies_gironde/widgets/brand_mark.dart';
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
    expect(find.text('de santé'), findsOneWidget);
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
    final identityMark = tester.widget<BrandMark>(
      find.descendant(
        of: find.byKey(const Key('mobsante-product-identity')),
        matching: find.byType(BrandMark),
      ),
    );
    expect(identityMark.size, 48);
    expect(find.text('Voir les détails'), findsWidgets);
    expect(find.text('Détails de la mission'), findsNothing);

    final firstMission = find.byKey(const ValueKey('mission-merignac'));
    final missionLocation = find.descendant(
      of: firstMission,
      matching: find.text('Mérignac'),
    );
    final missionDate = find.descendant(
      of: firstMission,
      matching: find.textContaining('MARDI 29 JUILLET'),
    );
    final missionProfession = find.descendant(
      of: firstMission,
      matching: find.text('Professions recherchées'),
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
    expect(find.text('Où intervenir ?'), findsOneWidget);
    expect(find.text('Partout'), findsNWidgets(2));
    await tester.tap(find.text('Bordeaux Métropole').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('professional-where-apply')));
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
    for (final shortcut in [
      'Aujourd’hui',
      'Demain',
      'Cette semaine',
      'Plus tard',
      'Choisir une date',
    ]) {
      expect(find.text(shortcut), findsOneWidget);
    }
    await tester.tap(find.text('Choisir une date'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.byKey(const Key('professional-when-date-apply')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('professional-hero-when')),
        matching: find.textContaining(RegExp(r'\d{1,2}')),
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
    expect(find.textContaining('MARDI 29 JUILLET'), findsWidgets);

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
    expect(find.text('Professionnel'), findsNothing);
    expect(find.text('Aucun engagement à venir.'), findsOneWidget);
    expect(find.text('AUJOURD’HUI'), findsOneWidget);
    expect(find.text('À VENIR'), findsOneWidget);
    expect(find.text('PASSÉS (0)'), findsOneWidget);
    expect(find.text('En cours'), findsNothing);
    expect(
      find.text('Vos engagements seront bientôt disponibles ici.'),
      findsNothing,
    );

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('professional-profile-completion-actions')),
      findsOneWidget,
    );
    expect(find.text('Identité et coordonnées'), findsOneWidget);
    expect(
      find.text('Votre profil professionnel sera bientôt disponible ici.'),
      findsNothing,
    );
    await tester.drag(
      find.byKey(const PageStorageKey('professional-profile')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-responsible-access')), findsNothing);
  });

  testWidgets('Où combines sectors with OR and Partout clears selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(responsibleAccess: null),
      ),
    );
    await tester.pumpAndSettle();

    final where = find.byKey(const Key('professional-hero-where'));
    expect(
      find.descendant(of: where, matching: find.text('Partout')),
      findsOneWidget,
    );
    await tester.tap(where);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bordeaux Métropole').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('professional-where-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mission-merignac')), findsOneWidget);
    expect(find.byKey(const ValueKey('mission-langon')), findsNothing);

    await tester.tap(where);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sud Gironde').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sud Gironde').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('professional-where-apply')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: where, matching: find.text('2 secteurs')),
      findsOneWidget,
    );
    expect(find.text('2 missions'), findsOneWidget);
    expect(find.byKey(const ValueKey('mission-merignac')), findsOneWidget);

    await tester.tap(where);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Partout').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('professional-where-apply')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: where, matching: find.text('Partout')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mission-merignac')), findsOneWidget);
    expect(find.text('2 missions'), findsNothing);
  });

  testWidgets('professional profile has no logout and keeps its three tabs', (
    tester,
  ) async {
    final repository = _TrackingSignOutRepository();
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    final profileScroll = find.byKey(
      const PageStorageKey('professional-profile'),
    );
    final notifications = find.byKey(const Key('open-notification-center'));
    for (
      var attempt = 0;
      attempt < 10 && notifications.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(profileScroll, const Offset(0, -350));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(notifications);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('professional-sign-out')), findsNothing);
    expect(find.text('Déconnexion'), findsNothing);
    expect(notifications, findsOneWidget);

    await tester.tap(find.text('Engagements'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun engagement à venir.'), findsOneWidget);
    await tester.tap(find.text('Missions'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('professional-hero-where')), findsOneWidget);
    expect(repository.signOutCalls, 0);
  });

  testWidgets(
    'mobilization with an incomplete profile opens completion and keeps a mission return',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        FireCoordinationApp(
          repository: MockCoordinationRepository(responsibleAccess: null),
        ),
      );
      await tester.pumpAndSettle();

      final action = find.text('Je me mobilise').first;
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('professional-profile-editor-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('professional-profile-address-line-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('return-to-engagement-mission')),
        findsOneWidget,
      );

      Navigator.of(
        tester.element(
          find.byKey(const Key('professional-profile-editor-title')),
        ),
      ).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('return-to-engagement-mission')));
      await tester.pumpAndSettle();
      expect(find.byKey(const PageStorageKey('slots')), findsOneWidget);
    },
  );

  testWidgets(
    'professional engagement card uses the shared V5Card/V5StatusPill',
    (tester) async {
      const engagement = EngagementInfo(
        missionId: 'engagement-card-mission',
        volunteerId: 'mock-volunteer',
        profession: VolunteerProfession.mk,
        status: EngagementStatus.confirmed,
      );
      final repository = MockCoordinationRepository(
        initialMissions: const [
          CoordinationNeed(
            id: 'engagement-card-mission',
            locationId: 'site-a',
            place: 'Site A',
            group: TerritorialGroup.medoc,
            date: 'Aujourd’hui',
            time: '08:00 — 12:00',
            requiredPhysiotherapists: 1,
            registeredPhysiotherapists: 0,
            requiredPodiatrists: 0,
            registeredPodiatrists: 0,
            equipment: [],
            createdBy: 'mock-coordinator',
          ),
        ],
        initialLocations: const [],
        responsibleAccess: null,
      );
      repository.engagements['engagement-card-mission'] = engagement;

      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();

      expect(find.byType(V5Card), findsOneWidget);
      final pill = tester.widget<V5StatusPill>(find.byType(V5StatusPill));
      expect(pill.tone, V5StatusTone.success);
      expect(pill.label, EngagementStatus.confirmed.label);
      expect(find.text(EngagementStatus.confirmed.label), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets('professional date filters use the whole mission interval', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayAfterSunday = today.add(
      Duration(days: DateTime.sunday - today.weekday + 1),
    );
    final location = places.first;
    final repository = MockCoordinationRepository(
      initialMissions: [
        CoordinationNeed(
          id: 'mission-spanning-filter-periods',
          locationId: location.id,
          place: location.name,
          group: location.group,
          date: 'Période traversante',
          time: '18:00–12:00',
          requiredPhysiotherapists: 1,
          registeredPhysiotherapists: 0,
          requiredPodiatrists: 0,
          registeredPodiatrists: 0,
          equipment: const [],
          startAt: today.subtract(const Duration(hours: 6)),
          endAt: dayAfterSunday.add(const Duration(hours: 12)),
        ),
        CoordinationNeed(
          id: 'mission-ended-before-today',
          locationId: location.id,
          place: location.name,
          group: location.group,
          date: 'Mission terminée',
          time: '08:00–12:00',
          requiredPhysiotherapists: 1,
          registeredPhysiotherapists: 0,
          requiredPodiatrists: 0,
          registeredPodiatrists: 0,
          equipment: const [],
          startAt: today.subtract(const Duration(days: 2)),
          endAt: today.subtract(const Duration(hours: 1)),
        ),
        CoordinationNeed(
          id: 'mission-legacy-today-label',
          locationId: location.id,
          place: location.name,
          group: location.group,
          date: 'Aujourd’hui',
          time: 'Sans horaire structuré',
          requiredPhysiotherapists: 1,
          registeredPhysiotherapists: 0,
          requiredPodiatrists: 0,
          registeredPodiatrists: 0,
          equipment: const [],
        ),
      ],
      initialLocations: [location],
      responsibleAccess: null,
    );

    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();

    Future<void> selectWhen(String label) async {
      await tester.tap(find.byKey(const Key('professional-hero-when')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    for (final period in [
      'Aujourd’hui',
      'Demain',
      'Cette semaine',
      'Plus tard',
    ]) {
      await selectWhen(period);
      expect(
        find.byKey(const ValueKey('mission-spanning-filter-periods')),
        findsOneWidget,
        reason: 'The spanning mission must intersect $period',
      );
      expect(
        find.byKey(const ValueKey('mission-ended-before-today')),
        findsNothing,
      );
    }

    await tester.tap(find.byKey(const Key('professional-hero-when')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir une date').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('professional-when-date-apply')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mission-spanning-filter-periods')),
      findsOneWidget,
    );

    await selectWhen('Aujourd’hui');
    expect(
      find.byKey(const ValueKey('mission-legacy-today-label')),
      findsOneWidget,
      reason: 'Unstructured legacy timing must keep its conservative label',
    );
    await selectWhen('Toutes les dates');
  });

  test('professional date filters build local civil-day boundaries', () {
    final source = File('lib/screens/slots_screen.dart').readAsStringSync();
    final matcherStart = source.indexOf('bool _matchesMissionWhen(');
    final matcherEnd = source.indexOf(
      '\nString _encodeMissionDate',
      matcherStart,
    );
    final matcherSource = source.substring(matcherStart, matcherEnd);

    expect(matcherSource, contains('_localCivilDay('));
    expect(
      matcherSource,
      isNot(contains('.add(const Duration(days:')),
      reason: 'A local calendar boundary must not be derived by adding 24h.',
    );
    expect(
      matcherSource,
      isNot(contains('.add(Duration(days:')),
      reason: 'Week boundaries must also be rebuilt from date components.',
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
    expect(find.text('Responsable de site'), findsOneWidget);
    expect(
      find.text('Organisez la couverture de votre établissement.'),
      findsOneWidget,
    );
    expect(find.text('Mon planning est-il sécurisé ?'), findsNothing);
    expect(find.text('Aucun besoin aujourd’hui.'), findsOneWidget);
    expect(find.text('Situation de mon établissement'), findsOneWidget);
    expect(
      find.byKey(const Key('responsible-planning-context')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('responsible-create-need')), findsOneWidget);
    expect(find.text('À traiter'), findsNothing);
    expect(find.text('Sous contrôle'), findsNothing);
    expect(find.text('Équipe'), findsOneWidget);
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
    await tester.tap(find.text('Demain').first);
    await tester.pumpAndSettle();
    expect(find.text('3 postes restent à couvrir.'), findsOneWidget);
    expect(find.textContaining('Demain  •  Centre : Mérignac'), findsOneWidget);
    expect(
      find.byKey(const Key('responsible-open-need-mission-merignac')),
      findsOneWidget,
    );
    expect(find.text('1 confirmé sur 4 attendus.'), findsOneWidget);
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
    expect(find.text('Mérignac'), findsNWidgets(2));
    expect(find.text('Perspective'), findsNothing);
    expect(find.text('Centre géré'), findsOneWidget);
    expect(find.text('Identité'), findsNothing);
    expect(find.text('Identifiant du compte'), findsNothing);
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Gestion des responsables'), findsNothing);
    expect(find.byKey(const Key('admin-locations-entry')), findsNothing);
  });

  testWidgets('all responsible tabs share the MobSanté journey header', (
    tester,
  ) async {
    final site = places.first;
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(
          initialMissions: const [],
          initialLocations: [site],
          responsibleAccess: ResponsibleAccess(
            uid: 'manager-headers',
            role: ResponsibleRole.siteManager,
            locationIds: {site.id},
            active: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final tab in ['Accueil', 'Besoins', 'Équipe', 'Profil']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mobsante-journey-header')), findsOneWidget);
      expect(find.text('MobSanté'), findsOneWidget);
      expect(find.text('Responsable de site'), findsOneWidget);
    }
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

      expect(
        find.byKey(const Key('responsible-open-need-today-need')),
        findsOneWidget,
      );
      await tester.tap(find.text('Demain').first);
      await tester.pumpAndSettle();
      expect(find.text('5 postes restent à couvrir.'), findsOneWidget);
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
      await tester.tap(find.text('À venir').first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('responsible-open-need-after-tomorrow-need')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('responsible-open-need-tomorrow-early')),
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

    await tester.tap(find.text('Demain').first);
    await tester.pumpAndSettle();
    expect(find.text('Aucun besoin demain.'), findsOneWidget);
    expect(
      find.byKey(const Key('responsible-decision-priorities')),
      findsNothing,
    );
    expect(
      find.text('Rien ne nécessite votre intervention pour cette période.'),
      findsNothing,
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

  testWidgets('responsible today label stays on one line at iPhone widths', (
    tester,
  ) async {
    final site = places.first;
    final repository = MockCoordinationRepository(
      initialMissions: const [],
      initialLocations: [site],
      responsibleAccess: ResponsibleAccess(
        uid: 'manager-horizon-layout',
        role: ResponsibleRole.siteManager,
        locationIds: {site.id},
        active: true,
      ),
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final size in const [
      Size(320, 844),
      Size(375, 844),
      Size(390, 844),
      Size(430, 932),
      Size(776, 420),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();

      final label = tester.widget<Text>(find.text('Aujourd’hui'));
      expect(label.maxLines, 1, reason: '$size');
      expect(label.softWrap, isFalse, reason: '$size');
      expect(
        find.ancestor(
          of: find.text('Aujourd’hui'),
          matching: find.byType(FittedBox),
        ),
        findsOneWidget,
        reason: '$size',
      );
      expect(tester.takeException(), isNull, reason: '$size');
    }
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

    expect(find.text('Aucun besoin aujourd’hui.'), findsOneWidget);
    expect(find.textContaining('Centre : ${bassens.name}'), findsOneWidget);
    expect(
      find.text('Rien ne nécessite votre intervention pour cette période.'),
      findsNothing,
    );
    expect(find.text('Aucun autre besoin pour cette période.'), findsNothing);
    expect(
      find.text('Aucun professionnel mobilisé pour cette période.'),
      findsNothing,
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
    expect(calmCreateButton.backgroundColor, colors.accent);

    await tester.tap(find.text('À venir').first);
    await tester.pumpAndSettle();
    expect(find.text('Aucun besoin à venir.'), findsOneWidget);

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
    expect(find.byKey(const Key('responsible-needs-create')), findsOneWidget);
    expect(
      find.byKey(const Key('responsible-needs-empty-create')),
      findsNothing,
    );

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun besoin passé'), findsOneWidget);
    expect(
      find.text('L’historique de votre établissement apparaîtra ici.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'responsible bottom navigation receives portrait and landscape taps',
    (tester) async {
      final site = places.first;
      final repository = MockCoordinationRepository(
        initialMissions: const [],
        initialLocations: [site],
        responsibleAccess: ResponsibleAccess(
          uid: 'manager-navigation',
          role: ResponsibleRole.siteManager,
          locationIds: {site.id},
          active: true,
        ),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Besoins').last);
      await tester.pumpAndSettle();
      expect(find.byType(ResponsibleNeedsScreen), findsOneWidget);

      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Équipe').last);
      await tester.pumpAndSettle();
      expect(find.byType(ResponsibleTeamScreen), findsOneWidget);
      await tester.tap(find.text('Profil').last);
      await tester.pumpAndSettle();
      expect(find.byType(ResponsibleProfileScreen), findsOneWidget);
    },
  );

  testWidgets(
    'compact RECETTE control switches the displayed shell instantly',
    (tester) async {
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

      await tester.tap(find.byKey(const Key('role-preview-banner')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('role-preview-banner-option-responsible')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProfessionalShell), findsNothing);
      expect(find.byType(ResponsibleShell), findsOneWidget);
      expect(find.byType(ResponsibleHomeScreen), findsOneWidget);
      expect(find.byType(ResponsibleBottomNavigation), findsOneWidget);
    },
  );

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
    await tester.scrollUntilVisible(
      developmentSettings,
      350,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey('responsible-profile')),
        matching: find.byType(Scrollable),
      ),
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

class _TrackingSignOutRepository extends MockCoordinationRepository {
  _TrackingSignOutRepository() : super(responsibleAccess: null);

  int signOutCalls = 0;

  @override
  Future<void> signOutResponsible() async {
    signOutCalls++;
  }
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
