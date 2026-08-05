import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/professional_shell.dart';
import 'package:interface_incendies_gironde/widgets/v5_bottom_navigation.dart';

void main() {
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
    final navigation = tester.widget<NavigationBar>(
      find.byKey(const Key('v5-bottom-navigation')),
    );
    expect(navigation.destinations, hasLength(3));
    expect(find.text('Missions'), findsOneWidget);
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
