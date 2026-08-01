import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/responsible_access.dart';
import 'package:interface_incendies_gironde/models/responsible_account.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_responsible_access_administration_repository.dart';
import 'package:interface_incendies_gironde/repositories/responsible_access_administration_repository.dart';
import 'package:interface_incendies_gironde/screens/responsible_access_form_screen.dart';

void main() {
  const coordinatorAccess = ResponsibleAccess(
    uid: 'coordinator',
    role: ResponsibleRole.coordinator,
    locationIds: {'*'},
    active: true,
  );

  testWidgets('coordinator sees accounts and cannot manage their own access', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final accessRepository = MockResponsibleAccessAdministrationRepository(
      currentUid: 'coordinator',
      initialAccounts: [
        _coordinatorAccount(),
        _managerAccount(),
        _cumulativeAccount(active: false),
      ],
    );
    final repository = MockCoordinationRepository(
      responsibleAccess: coordinatorAccess,
      responsibleAccessAdministrationRepository: accessRepository,
    );

    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Déclarer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-invitations-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('responsible-accounts-section')));
    await tester.pumpAndSettle();

    expect(find.text('Coordinateur Test'), findsOneWidget);
    expect(find.text('Responsable Test'), findsOneWidget);
    expect(find.text('Responsable Cumulatif'), findsOneWidget);
    expect(find.text('Coordinateur départemental'), findsOneWidget);
    expect(find.text('Responsable de centre'), findsOneWidget);
    expect(find.text('Coordinateur et responsable'), findsOneWidget);
    expect(find.text('Actif'), findsNWidgets(2));
    expect(find.text('Inactif'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('manage-responsible-coordinator')),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.text('Votre propre accès doit être géré par un autre coordinateur.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('manage-responsible-manager')),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.textContaining('Supprimer'), findsNothing);
    final manageManager = find.byKey(const Key('manage-responsible-manager'));
    await tester.ensureVisible(manageManager);
    await tester.pumpAndSettle();
    await tester.tap(manageManager);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('responsible-access-form')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coordinator role clears locations and saves a strict update', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    await _openForm(tester, repository: repository);

    await tester.tap(find.byKey(const Key('responsible-role-choice')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coordinateur départemental').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-responsible-access')));
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(repository.lastUpdate!.roles, [ResponsibleRole.coordinator]);
    expect(repository.lastUpdate!.locationIds, isEmpty);
  });

  testWidgets('deactivation is explicit and preserves the account', (
    tester,
  ) async {
    final repository = MockResponsibleAccessAdministrationRepository(
      currentUid: 'coordinator',
      initialAccounts: [_managerAccount()],
    );
    await _openForm(tester, repository: repository);

    await tester.tap(find.byKey(const Key('responsible-active-switch')));
    await tester.tap(find.byKey(const Key('save-responsible-access')));
    await tester.pumpAndSettle();
    expect(find.text('Désactiver ce responsable ?'), findsOneWidget);
    expect(
      find.textContaining('Le compte et son historique sont conservés'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirm-responsible-deactivation')));
    await tester.pumpAndSettle();

    final account = (await repository.listAccounts()).single;
    expect(account.access.active, isFalse);
    expect(account.uid, 'manager');
  });

  testWidgets('site manager and cumulative roles require a centre locally', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    await _openForm(tester, repository: repository);

    await _chooseRole(tester, 'Coordinateur départemental');
    await _chooseRole(tester, 'Responsable de centre');
    await tester.tap(find.byKey(const Key('save-responsible-access')));
    await tester.pump();
    expect(find.text('Sélectionnez au moins un centre.'), findsOneWidget);
    expect(repository.calls, 0);

    await _chooseRole(tester, 'Coordinateur et responsable');
    await tester.tap(find.byKey(const Key('save-responsible-access')));
    await tester.pump();
    expect(repository.calls, 0);
  });

  testWidgets(
    'an inactive account can be reactivated without being recreated',
    (tester) async {
      final repository = _RecordingRepository();
      await _openForm(
        tester,
        repository: repository,
        account: _managerAccount(active: false),
      );

      expect(find.text('Accès désactivé'), findsOneWidget);
      await tester.tap(find.byKey(const Key('responsible-active-switch')));
      await tester.tap(find.byKey(const Key('save-responsible-access')));
      await tester.pumpAndSettle();

      expect(repository.calls, 1);
      expect(repository.lastUpdate!.active, isTrue);
      expect(repository.lastUpdate!.targetUid, 'manager');
    },
  );

  testWidgets('failure keeps the form editable with an explicit message', (
    tester,
  ) async {
    final repository = _RecordingRepository(fail: true);
    await _openForm(tester, repository: repository);

    await tester.tap(find.byKey(const Key('save-responsible-access')));
    await tester.pumpAndSettle();

    expect(find.text('Échec serveur contrôlé.'), findsOneWidget);
    expect(find.byKey(const Key('responsible-access-form')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('save-responsible-access')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('double submission is blocked while an update is pending', (
    tester,
  ) async {
    final completer = Completer<ResponsibleAccount>();
    final repository = _RecordingRepository(completer: completer);
    await _openForm(tester, repository: repository);

    await tester.tap(find.byKey(const Key('save-responsible-access')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-responsible-access')));
    expect(repository.calls, 1);

    completer.complete(_managerAccount());
    await tester.pumpAndSettle();
  });
}

Future<void> _openForm(
  WidgetTester tester, {
  required ResponsibleAccessAdministrationRepository repository,
  ResponsibleAccount? account,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ResponsibleAccessFormScreen(
                  account: account ?? _managerAccount(),
                  currentUid: 'coordinator',
                  locations: places,
                  repository: repository,
                ),
              ),
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

Future<void> _chooseRole(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('responsible-role-choice')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

ResponsibleAccount _coordinatorAccount() => ResponsibleAccount(
  access: ResponsibleAccess.v2(
    uid: 'coordinator',
    roles: const [ResponsibleRole.coordinator],
    locationIds: const {},
    active: true,
  ),
  displayName: 'Coordinateur Test',
  email: 'coordinateur@example.test',
);

ResponsibleAccount _managerAccount({bool active = true}) => ResponsibleAccount(
  access: ResponsibleAccess.v2(
    uid: 'manager',
    roles: const [ResponsibleRole.siteManager],
    locationIds: {places.firstWhere((place) => place.isOperational).id},
    active: active,
  ),
  displayName: 'Responsable Test',
  email: 'responsable@example.test',
);

ResponsibleAccount _cumulativeAccount({bool active = true}) =>
    ResponsibleAccount(
      access: ResponsibleAccess.v2(
        uid: 'cumulative',
        roles: const [ResponsibleRole.coordinator, ResponsibleRole.siteManager],
        locationIds: {places.firstWhere((place) => place.isOperational).id},
        active: active,
      ),
      displayName: 'Responsable Cumulatif',
      email: 'cumulatif@example.test',
    );

class _RecordingRepository
    implements ResponsibleAccessAdministrationRepository {
  _RecordingRepository({this.fail = false, this.completer});

  final bool fail;
  final Completer<ResponsibleAccount>? completer;
  int calls = 0;
  ResponsibleAccessUpdate? lastUpdate;

  @override
  Future<List<ResponsibleAccount>> listAccounts() async => [_managerAccount()];

  @override
  Future<ResponsibleAccount> updateAccess(
    ResponsibleAccessUpdate update,
  ) async {
    calls += 1;
    lastUpdate = update;
    if (fail) {
      throw const ResponsibleAccessAdministrationException(
        'Échec serveur contrôlé.',
      );
    }
    if (completer != null) return completer!.future;
    return _managerAccount().copyWith(
      access: ResponsibleAccess.v2(
        uid: update.targetUid,
        roles: update.roles,
        locationIds: update.locationIds,
        active: update.active,
      ),
    );
  }
}
