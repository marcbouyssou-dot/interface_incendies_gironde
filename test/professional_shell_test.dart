import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/development_settings_screen.dart';
import 'package:interface_incendies_gironde/screens/professional_shell.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';
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
    final verdict = tester.widget<Text>(
      find.byKey(const Key('decision-header-verdict')),
    );
    expect(verdict.style?.color, colors.info);

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
    expect(
      find.text('Vos engagements seront bientôt disponibles ici.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(
      find.text('Votre profil professionnel sera bientôt disponible ici.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('open-responsible-access')), findsOneWidget);
  });

  testWidgets('a real privileged role keeps the historical journey', (
    tester,
  ) async {
    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();

    expect(find.byType(ProfessionalShell), findsNothing);
    expect(find.byType(V5BottomNavigation), findsNothing);
    expect(find.byKey(const Key('mission-coverage-overview')), findsOneWidget);
    expect(find.byKey(const Key('slots-territorial-filter')), findsOneWidget);
    expect(
      find.byKey(const Key('professional-secondary-filters')),
      findsNothing,
    );
    expect(
      find.text('1 mission urgente nécessite votre attention.'),
      findsNothing,
    );
    expect(find.text('Détails de la mission'), findsWidgets);
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations, hasLength(4));
    expect(find.text('Déclarer'), findsOneWidget);
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
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations, hasLength(4));
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
    await tester.tap(find.byKey(const Key('open-development-settings')));
    await tester.pumpAndSettle();
    await selectPreview(tester, 'Responsable');
    await closeSettings(tester);

    expect(find.byType(ProfessionalShell), findsNothing);
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations, hasLength(4));
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

    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-development-settings')));
    await tester.pumpAndSettle();
    await selectPreview(tester, 'Coordinateur');
    await closeSettings(tester);
    await tester.tap(find.text('Déclarer'));
    await tester.pumpAndSettle();

    expect(find.text('Votre accès responsable'), findsOneWidget);
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
