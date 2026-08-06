import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/development_settings_screen.dart';
import 'package:interface_incendies_gironde/screens/coordinator_shell.dart';
import 'package:interface_incendies_gironde/screens/professional_shell.dart';
import 'package:interface_incendies_gironde/screens/responsible_home_screen.dart';
import 'package:interface_incendies_gironde/screens/responsible_shell.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';
import 'package:interface_incendies_gironde/widgets/responsible_bottom_navigation.dart';
import 'package:interface_incendies_gironde/widgets/coordinator_bottom_navigation.dart';
import 'package:interface_incendies_gironde/widgets/v5_bottom_navigation.dart';

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
      findsOneWidget,
    );
    expect(find.text('Voir les détails'), findsWidgets);
    expect(find.text('Détails de la mission'), findsNothing);

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

    final navigation = tester.widget<NavigationBar>(
      find.byKey(const Key('v5-bottom-navigation')),
    );
    expect(navigation.destinations, hasLength(3));
    final navigationTheme = NavigationBarTheme.of(
      tester.element(find.byType(NavigationBar)),
    );
    expect(navigationTheme.indicatorColor, Colors.transparent);
    expect(
      navigationTheme.iconTheme?.resolve({WidgetState.selected})?.color,
      colors.info,
    );
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
    expect(find.byKey(const Key('open-responsible-access')), findsOneWidget);
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
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations, hasLength(4));
    expect(find.text('Vue d’ensemble'), findsOneWidget);
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
    expect(find.text('Mon planning est-il sécurisé ?'), findsNothing);
    expect(find.text('Tout est couvert pour demain.'), findsOneWidget);
    expect(
      find.byKey(const Key('responsible-planning-context')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('responsible-create-need')), findsOneWidget);
    expect(find.text('À traiter'), findsOneWidget);
    expect(find.text('Sous contrôle'), findsOneWidget);
    expect(find.text('Équipe'), findsWidgets);
    expect(find.byType(ResponsibleBottomNavigation), findsOneWidget);
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations, hasLength(4));
  });

  testWidgets('responsible home answers the planning decision immediately', (
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

    expect(find.byType(ResponsibleHomeScreen), findsOneWidget);
    expect(find.text('3 postes restent à couvrir demain.'), findsOneWidget);
    expect(find.textContaining('Demain  •  Centre : Mérignac'), findsOneWidget);
    expect(
      find.byKey(const Key('responsible-open-need-mission-merignac')),
      findsOneWidget,
    );
    expect(find.text('1 confirmé sur 4 attendus demain.'), findsOneWidget);
    expect(find.text('Statistiques'), findsNothing);
    expect(find.text('Tableau de bord'), findsNothing);
    final colors = Theme.of(
      tester.element(find.byType(ResponsibleShell)),
    ).extension<V5Colors>()!;
    final createButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Créer un besoin'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(createButton.style?.backgroundColor?.resolve({}), colors.accent);
    final responsibleNavigationTheme = NavigationBarTheme.of(
      tester.element(find.byKey(const Key('responsible-bottom-navigation'))),
    );
    expect(
      responsibleNavigationTheme.iconTheme?.resolve({
        WidgetState.selected,
      })?.color,
      colors.accent,
    );

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
    expect(find.text('mock-confirmed'), findsOneWidget);
    expect(
      find.byKey(const Key('engagement-menu-mission-merignac_mock-confirmed')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('responsible-team-filter-pending')));
    await tester.pumpAndSettle();
    expect(find.text('mock-pending'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Mérignac'), findsOneWidget);
    expect(find.text('Perspective'), findsOneWidget);
    expect(find.text('Centre géré'), findsOneWidget);
    expect(find.text('Identité'), findsNothing);
    expect(find.text('Identifiant du compte'), findsNothing);
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Gestion des responsables'), findsNothing);
    expect(find.byKey(const Key('admin-locations-entry')), findsNothing);
  });

  testWidgets('site manager can view and immediately leave professional UI', (
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

    expect(find.text('Perspective'), findsOneWidget);
    final professionalPerspective = find.byKey(
      const Key('perspective-professional'),
    );
    await tester.ensureVisible(professionalPerspective);
    await tester.tap(professionalPerspective);
    await tester.pumpAndSettle();

    expect(find.byType(ProfessionalShell), findsOneWidget);
    expect(find.byKey(const Key('cross-role-preview-banner')), findsOneWidget);
    expect(find.text('Perspective Professionnel'), findsOneWidget);
    expect(find.text('Rôle réel : Responsable de centre'), findsOneWidget);

    await tester.tap(find.byKey(const Key('exit-cross-role-preview')));
    await tester.pumpAndSettle();

    expect(find.byType(ResponsibleShell), findsOneWidget);
    expect(find.byKey(const Key('cross-role-preview-banner')), findsNothing);
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
      find.text('Tous les besoins prévus sont sécurisés.'),
      findsOneWidget,
    );
    expect(
      find.text('Aucun professionnel mobilisé actuellement.'),
      findsOneWidget,
    );
    expect(find.text('Les confirmations apparaîtront ici.'), findsOneWidget);
    final colors = Theme.of(
      tester.element(find.byType(ResponsibleShell)),
    ).extension<V5Colors>()!;
    final calmCreateButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Créer un besoin'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      calmCreateButton.style?.backgroundColor?.resolve({}),
      colors.warningContainer,
    );

    await tester.tap(find.text('Besoins'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun besoin ouvert'), findsOneWidget);
    expect(
      find.text('Votre planning est actuellement couvert.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('responsible-needs-empty-create')),
      findsOneWidget,
    );
  });

  testWidgets(
    'coordinator selects an authorized center before responsible preview',
    (tester) async {
      final selectedCenter = places.first;

      await tester.pumpWidget(const FireCoordinationApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plus'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-development-settings')));
      await tester.pumpAndSettle();

      expect(find.text('Changer de perspective'), findsOneWidget);
      await tester.tap(find.byKey(const Key('perspective-responsible')));
      await tester.pumpAndSettle();

      expect(find.text('Choisir un centre'), findsOneWidget);
      final center = find.byKey(Key('preview-center-${selectedCenter.id}'));
      await tester.tap(center);
      await tester.pumpAndSettle();

      expect(find.byType(ResponsibleShell), findsOneWidget);
      expect(
        find.text('Vue Responsable de centre · ${selectedCenter.name}'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('responsible-open-need-mission-merignac')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('responsible-open-need-mission-langon')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('change-preview-center')));
      await tester.pumpAndSettle();
      expect(find.text('Choisir un centre'), findsOneWidget);
      Navigator.of(tester.element(find.text('Choisir un centre'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('exit-cross-role-preview')));
      await tester.pumpAndSettle();
      expect(find.byType(ResponsibleShell), findsNothing);
      await tester.tap(find.text('Plus'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-development-settings')));
      await tester.pumpAndSettle();
      expect(find.text('Changer de perspective'), findsOneWidget);

      await tester.tap(find.byKey(const Key('perspective-professional')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfessionalShell), findsOneWidget);
      expect(find.text('Perspective Professionnel'), findsOneWidget);
      expect(find.text('Rôle réel : Coordinateur'), findsOneWidget);
    },
  );

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
