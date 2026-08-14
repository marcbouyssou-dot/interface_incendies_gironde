import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/responsible_access.dart';
import 'package:interface_incendies_gironde/models/responsible_account.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/responsible_access_administration_repository.dart';
import 'package:interface_incendies_gironde/widgets/v5_secondary_navigation.dart';

void main() {
  testWidgets(
    'deactivation survives a repository read and a coordinator shell rebuild',
    (tester) async {
      final accessRepository = _PersistentAccessRepository();
      final repository = _coordinatorRepository(accessRepository);

      await _pumpCoordinator(tester, repository);
      await tester.tap(find.text('Acteurs'));
      await tester.pumpAndSettle();
      expect(find.text('Actif'), findsOneWidget);

      await _openAdministrationFromActors(tester);
      await _openManagerAccessForm(tester);
      await _setAccountActive(tester, active: false);

      final managerCard = find.byKey(const Key('responsible-account-manager'));
      expect(
        find.descendant(of: managerCard, matching: find.text('Inactif')),
        findsOneWidget,
      );
      expect(find.text('Accès responsable désactivé.'), findsOneWidget);

      final reread = await accessRepository.listAccounts();
      expect(
        reread.singleWhere((account) => account.uid == 'manager').access.active,
        isFalse,
      );

      await tester.tap(find.byType(V5BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Inactif'), findsOneWidget);
      expect(
        find.byKey(const Key('coordinator-preview-manager')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acteurs'));
      await tester.pumpAndSettle();

      expect(find.text('Inactif'), findsOneWidget);
      expect(
        find.byKey(const Key('coordinator-preview-manager')),
        findsNothing,
      );
    },
  );

  testWidgets('a failed server update leaves the persisted UI state active', (
    tester,
  ) async {
    final accessRepository = _PersistentAccessRepository(failUpdates: true);
    final repository = _coordinatorRepository(accessRepository);

    await _pumpCoordinator(tester, repository);
    await _openAdministrationFromOverview(tester);
    await _openManagerAccessForm(tester);
    await _setAccountActive(tester, active: false, expectSuccess: false);

    expect(find.text('Échec serveur contrôlé.'), findsOneWidget);
    expect(find.byKey(const Key('responsible-access-form')), findsOneWidget);
    expect(accessRepository.updateCalls, 1);
    expect(
      (await accessRepository.listAccounts())
          .singleWhere((account) => account.uid == 'manager')
          .access
          .active,
      isTrue,
    );

    await tester.tap(find.byType(V5BackButton));
    await tester.pumpAndSettle();
    final managerCard = find.byKey(const Key('responsible-account-manager'));
    expect(
      find.descendant(of: managerCard, matching: find.text('Actif')),
      findsOneWidget,
    );
    expect(find.text('Accès responsable désactivé.'), findsNothing);
  });

  testWidgets('the existing reactivation flow remains persistent', (
    tester,
  ) async {
    final accessRepository = _PersistentAccessRepository(managerActive: false);
    final repository = _coordinatorRepository(accessRepository);

    await _pumpCoordinator(tester, repository);
    await _openAdministrationFromOverview(tester);
    await _openManagerAccessForm(tester);
    expect(find.text('Accès désactivé'), findsOneWidget);
    await _setAccountActive(tester, active: true);

    final managerCard = find.byKey(const Key('responsible-account-manager'));
    expect(
      find.descendant(of: managerCard, matching: find.text('Actif')),
      findsOneWidget,
    );
    expect(
      (await accessRepository.listAccounts())
          .singleWhere((account) => account.uid == 'manager')
          .access
          .active,
      isTrue,
    );
  });
}

MockCoordinationRepository _coordinatorRepository(
  ResponsibleAccessAdministrationRepository accessRepository,
) => MockCoordinationRepository(
  responsibleAccess: const ResponsibleAccess(
    uid: 'coordinator',
    role: ResponsibleRole.coordinator,
    locationIds: {'*'},
    active: true,
  ),
  responsibleAccessAdministrationRepository: accessRepository,
);

Future<void> _pumpCoordinator(
  WidgetTester tester,
  MockCoordinationRepository repository,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FireCoordinationApp(repository: repository));
  await tester.pumpAndSettle();
}

Future<void> _openAdministrationFromActors(WidgetTester tester) async {
  final manage = find.widgetWithText(TextButton, 'Gérer').first;
  await tester.ensureVisible(manage);
  await tester.tap(manage);
  await tester.pumpAndSettle();
  await _expandAccounts(tester);
}

Future<void> _openAdministrationFromOverview(WidgetTester tester) async {
  final manage = find.byKey(const Key('admin-invitations-entry'));
  await tester.ensureVisible(manage);
  await tester.pumpAndSettle();
  await tester.tap(manage);
  await tester.pumpAndSettle();
  await _expandAccounts(tester);
}

Future<void> _expandAccounts(WidgetTester tester) async {
  final section = find.byKey(const Key('responsible-accounts-section'));
  await tester.ensureVisible(section);
  await tester.tap(section);
  await tester.pumpAndSettle();
}

Future<void> _openManagerAccessForm(WidgetTester tester) async {
  final manage = find.byKey(const Key('manage-responsible-manager'));
  await tester.ensureVisible(manage);
  await tester.pumpAndSettle();
  await tester.tap(manage);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('responsible-access-form')), findsOneWidget);
}

Future<void> _setAccountActive(
  WidgetTester tester, {
  required bool active,
  bool expectSuccess = true,
}) async {
  final activeSwitch = find.byKey(const Key('responsible-active-switch'));
  await tester.ensureVisible(activeSwitch);
  await tester.tap(activeSwitch);
  await tester.tap(find.byKey(const Key('save-responsible-access')));
  await tester.pumpAndSettle();
  if (!active) {
    expect(find.text('Désactiver ce responsable ?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-responsible-deactivation')));
    await tester.pumpAndSettle();
  }
  if (expectSuccess) {
    expect(find.byKey(const Key('responsible-access-form')), findsNothing);
  }
}

class _PersistentAccessRepository
    implements ResponsibleAccessAdministrationRepository {
  _PersistentAccessRepository({
    bool managerActive = true,
    this.failUpdates = false,
  }) : _accounts = {
         'coordinator': _account(
           uid: 'coordinator',
           displayName: 'Coordinateur Test',
           roles: const [ResponsibleRole.coordinator],
           locationIds: const {},
           active: true,
         ),
         'manager': _account(
           uid: 'manager',
           displayName: 'Responsable Test',
           roles: const [ResponsibleRole.siteManager],
           locationIds: {places.firstWhere((place) => place.isOperational).id},
           active: managerActive,
         ),
       };

  final bool failUpdates;
  final Map<String, ResponsibleAccount> _accounts;
  int updateCalls = 0;

  @override
  Future<List<ResponsibleAccount>> listAccounts() async =>
      _accounts.values.toList(growable: false);

  @override
  Future<ResponsibleAccount> updateAccess(
    ResponsibleAccessUpdate update,
  ) async {
    updateCalls++;
    if (failUpdates) {
      throw const ResponsibleAccessAdministrationException(
        'Échec serveur contrôlé.',
      );
    }
    final existing = _accounts[update.targetUid]!;
    final updated = existing.copyWith(
      access: ResponsibleAccess.v2(
        uid: update.targetUid,
        roles: update.roles,
        locationIds: update.locationIds,
        active: update.active,
      ),
    );
    _accounts[updated.uid] = updated;
    return updated;
  }
}

ResponsibleAccount _account({
  required String uid,
  required String displayName,
  required List<String> roles,
  required Set<String> locationIds,
  required bool active,
}) => ResponsibleAccount(
  access: ResponsibleAccess.v2(
    uid: uid,
    roles: roles,
    locationIds: locationIds,
    active: active,
  ),
  displayName: displayName,
  email: '$uid@example.test',
);
