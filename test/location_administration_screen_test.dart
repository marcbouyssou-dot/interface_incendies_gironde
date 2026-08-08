import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/admin_location.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/location_administration_repository.dart';
import 'package:interface_incendies_gironde/repositories/location_administration_repository_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_location_administration_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/location_administration_screen.dart';
import 'package:interface_incendies_gironde/widgets/v5_form_system.dart';

void main() {
  const active = AdminLocation(
    id: 'merignac',
    name: 'Mérignac',
    group: TerritorialGroup.bordeauxMetropole,
    type: ResponsePlaceType.sdisStation,
    addressLine1: '12 rue du Test',
    postalCode: '33700',
    city: 'Mérignac',
    active: true,
    isOperational: true,
    canDelete: true,
  );
  const inactive = AdminLocation(
    id: 'bazas',
    name: 'Bazas',
    group: TerritorialGroup.southGironde,
    type: ResponsePlaceType.interventionSector,
    active: false,
    isOperational: true,
    canDelete: false,
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    LocationAdministrationRepository? locationRepository,
    ResponsibleAccess? access = _coordinator,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      FireCoordinationApp(
        useLegacyCoordinatorShellForTesting: true,
        repository: MockCoordinationRepository(
          responsibleAccess: access,
          locationAdministrationRepository:
              locationRepository ??
              MockLocationAdministrationRepository(
                initialLocations: const [active, inactive],
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Déclarer').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('admin-locations-entry')));
    await tester.tap(find.byKey(const Key('admin-locations-entry')));
    await tester.pumpAndSettle();
  }

  Finder locationListScrollable() => find
      .descendant(
        of: find.byKey(const Key('admin-location-list')),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> scrollToLocation(WidgetTester tester, String id) async {
    final card = find.byKey(Key('admin-location-$id'));
    await tester.scrollUntilVisible(
      card,
      250,
      scrollable: locationListScrollable(),
    );
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
  }

  Future<void> tapLocationAction(WidgetTester tester, Key key) async {
    final action = find.byKey(key);
    await tester.scrollUntilVisible(
      action,
      200,
      scrollable: locationListScrollable(),
    );
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  Future<void> openCreateForm(WidgetTester tester) async {
    final createButton = find.byKey(const Key('admin-location-create'));
    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-location-form-list')), findsOneWidget);
  }

  testWidgets('coordinator sees active, inactive and legacy-safe values', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byType(LocationAdministrationScreen), findsOneWidget);
    await scrollToLocation(tester, 'merignac');
    expect(find.text('Mérignac'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
    await scrollToLocation(tester, 'bazas');
    expect(find.text('Bazas'), findsOneWidget);
    expect(find.text('Désactivé'), findsOneWidget);
    expect(find.text('Adresse à renseigner'), findsOneWidget);
    expect(
      find.text('Lieu utilisé : désactivation uniquement'),
      findsOneWidget,
    );
  });

  testWidgets('search ignores accents and status filter isolates inactive', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const Key('admin-location-search')),
      'merignac',
    );
    await tester.pump();
    expect(find.text('Mérignac'), findsOneWidget);
    expect(find.text('Bazas'), findsNothing);

    await tester.enterText(find.byKey(const Key('admin-location-search')), '');
    await tester.tap(find.byKey(const Key('admin-location-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Désactivés').last);
    await tester.pumpAndSettle();
    expect(find.text('Mérignac'), findsNothing);
    expect(find.text('Bazas'), findsOneWidget);
  });

  testWidgets('coordinator creates and modifies a location', (tester) async {
    final repository = MockLocationAdministrationRepository(
      initialLocations: const [active],
    );
    await pumpScreen(tester, locationRepository: repository);

    await openCreateForm(tester);
    await tester.enterText(
      find.byKey(const Key('admin-location-id-field')),
      'nouveau-centre',
    );
    await tester.enterText(
      find.byKey(const Key('admin-location-name-field')),
      'Nouveau centre',
    );
    await tester.tap(find.byKey(const Key('admin-location-submit')).last);
    await tester.pumpAndSettle();

    await scrollToLocation(tester, 'nouveau-centre');
    final createdCard = find.byKey(const Key('admin-location-nouveau-centre'));
    expect(
      find.descendant(of: createdCard, matching: find.text('Nouveau centre')),
      findsOneWidget,
    );
    final modifyButton = find.descendant(
      of: createdCard,
      matching: find.widgetWithText(OutlinedButton, 'Modifier'),
    );
    await tester.ensureVisible(modifyButton);
    await tester.pumpAndSettle();
    await tester.tap(modifyButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-location-form-list')), findsOneWidget);
    expect(
      tester
          .widget<V5TextField>(find.byKey(const Key('admin-location-id-field')))
          .enabled,
      isFalse,
    );
    await tester.enterText(
      find.byKey(const Key('admin-location-name-field')),
      'Centre renommé',
    );
    await tester.tap(find.byKey(const Key('admin-location-submit')).last);
    await tester.pumpAndSettle();
    await scrollToLocation(tester, 'nouveau-centre');
    expect(find.text('Centre renommé'), findsOneWidget);
  });

  testWidgets('deactivation, reactivation and deletion require confirmation', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      locationRepository: MockLocationAdministrationRepository(
        initialLocations: const [active],
      ),
    );

    await tapLocationAction(
      tester,
      const Key('admin-location-toggle-merignac'),
    );
    expect(find.text('Désactiver ce lieu ?'), findsOneWidget);
    await tester.tap(find.text('Désactiver').last);
    await tester.pumpAndSettle();
    expect(find.text('Désactivé'), findsOneWidget);

    await tapLocationAction(
      tester,
      const Key('admin-location-toggle-merignac'),
    );
    await tester.tap(find.text('Réactiver').last);
    await tester.pumpAndSettle();
    expect(find.text('Actif'), findsOneWidget);

    await tapLocationAction(
      tester,
      const Key('admin-location-delete-merignac'),
    );
    expect(find.text('Supprimer définitivement ce lieu ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    expect(find.text('Mérignac'), findsNothing);
  });

  testWidgets('server deletion refusal is displayed clearly', (tester) async {
    await pumpScreen(tester, locationRepository: _DeletionRefusalRepository());

    await tapLocationAction(
      tester,
      const Key('admin-location-delete-merignac'),
    );
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('encore utilisé'), findsOneWidget);
    expect(find.text('Mérignac'), findsOneWidget);
  });

  testWidgets('list error exposes retry and recovers without stale content', (
    tester,
  ) async {
    final repository = _RetryRepository();
    await pumpScreen(tester, locationRepository: repository);

    expect(find.text('Les lieux ne sont pas disponibles.'), findsOneWidget);
    expect(find.text('Mérignac'), findsNothing);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Mérignac'), findsOneWidget);
    expect(repository.listCalls, 2);
  });

  testWidgets('site manager never gets location administration', (
    tester,
  ) async {
    final repository = MockLocationAdministrationRepository(
      initialLocations: const [active],
    );
    final coordinationRepository = MockCoordinationRepository(
      responsibleAccess: ResponsibleAccess.v2(
        uid: 'manager',
        roles: const [ResponsibleRole.siteManager],
        locationIds: const {'merignac'},
        active: true,
      ),
      locationAdministrationRepository: repository,
    );
    await tester.pumpWidget(
      RepositoryScope(
        repository: coordinationRepository,
        child: LocationAdministrationRepositoryScope(
          repository: repository,
          child: const MaterialApp(home: LocationAdministrationScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accès coordinateur actif requis.'), findsOneWidget);
    expect(find.text('Mérignac'), findsNothing);
    expect(find.byKey(const Key('admin-location-create')), findsNothing);
  });

  testWidgets('double creation submission is blocked', (tester) async {
    final repository = _PendingCreateRepository();
    await pumpScreen(tester, locationRepository: repository);
    await openCreateForm(tester);
    await tester.enterText(
      find.byKey(const Key('admin-location-id-field')),
      'nouveau-centre',
    );
    await tester.enterText(
      find.byKey(const Key('admin-location-name-field')),
      'Nouveau centre',
    );
    await tester.tap(find.byKey(const Key('admin-location-submit')).last);
    await tester.pump();
    await tester.tap(find.byKey(const Key('admin-location-submit')).last);
    await tester.pump();

    expect(repository.createCalls, 1);
    repository.complete();
    await tester.pumpAndSettle();
  });
}

const _coordinator = ResponsibleAccess(
  uid: 'coordinator',
  role: 'coordinator',
  locationIds: {'*'},
  active: true,
);

const _singleLocation = AdminLocation(
  id: 'merignac',
  name: 'Mérignac',
  group: TerritorialGroup.bordeauxMetropole,
  type: ResponsePlaceType.sdisStation,
  active: true,
  isOperational: true,
  canDelete: true,
);

class _DeletionRefusalRepository extends MockLocationAdministrationRepository {
  _DeletionRefusalRepository()
    : super(initialLocations: const [_singleLocation]);

  @override
  Future<void> deleteLocation(String locationId) =>
      throw const LocationAdministrationException(
        'Ce lieu est encore utilisé et ne peut pas être supprimé. '
        'Vous pouvez le désactiver.',
      );
}

class _RetryRepository extends MockLocationAdministrationRepository {
  _RetryRepository() : super(initialLocations: const [_singleLocation]);

  int listCalls = 0;

  @override
  Future<List<AdminLocation>> listLocations() async {
    listCalls++;
    if (listCalls == 1) {
      throw const LocationAdministrationException('temporary');
    }
    return super.listLocations();
  }
}

class _PendingCreateRepository extends MockLocationAdministrationRepository {
  final _completion = Completer<AdminLocation>();
  int createCalls = 0;

  @override
  Future<AdminLocation> createLocation(AdminLocationDraft draft) {
    createCalls++;
    return _completion.future;
  }

  void complete() => _completion.complete(
    const AdminLocation(
      id: 'nouveau-centre',
      name: 'Nouveau centre',
      group: TerritorialGroup.bordeauxMetropole,
      type: ResponsePlaceType.sdisStation,
      active: true,
      isOperational: true,
      canDelete: true,
    ),
  );
}
