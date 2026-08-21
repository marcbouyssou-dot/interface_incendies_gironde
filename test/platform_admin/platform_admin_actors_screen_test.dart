import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/platform_admin/platform_actor_view_data.dart';
import 'package:interface_incendies_gironde/repositories/platform_actor_read_repository.dart';
import 'package:interface_incendies_gironde/screens/platform_admin_actors_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';

void main() {
  testWidgets('affiche et distingue les trois familles d’acteurs', (
    tester,
  ) async {
    final repository = _FakeActorRepository(_directory());
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Alice Martin'), findsOneWidget);
    await tester.tap(find.byKey(const Key('platform-actor-kind-coordinator')));
    await tester.pumpAndSettle();
    expect(find.text('Camille Martin'), findsOneWidget);
    await tester.tap(find.byKey(const Key('platform-actor-kind-manager')));
    await tester.pumpAndSettle();
    expect(find.text('Morgan Dupont'), findsOneWidget);
    expect(repository.loadCount, 1);
  });

  testWidgets('recherche rapidement sans nouvelle lecture', (tester) async {
    final repository = _FakeActorRepository(_directory());
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('platform-actor-search')),
      'introuvable',
    );
    await tester.pump();
    expect(
      find.text('Aucun acteur ne correspond à ces filtres.'),
      findsOneWidget,
    );
    expect(repository.loadCount, 1);
  });

  testWidgets('fiche professionnelle conserve l’historique existant', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeActorRepository(_directory())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('professional-professional-a')));
    await tester.pumpAndSettle();
    expect(find.text('Historique des participations'), findsOneWidget);
    expect(find.text('Mission A'), findsOneWidget);
    expect(
      find.text(
        'Les coordonnées personnelles ne sont pas exposées dans ce périmètre.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reste utilisable à 320 px avec Dynamic Type et thème sombre', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 760),
          textScaler: TextScaler.linear(1.6),
          platformBrightness: Brightness.dark,
        ),
        child: _app(
          _FakeActorRepository(_directory()),
          themeMode: ThemeMode.dark,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('platform-admin-actors-title')),
      findsOneWidget,
    );
    expect(find.byType(PlatformAdminActorsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  PlatformActorReadRepository repository, {
  ThemeMode themeMode = ThemeMode.light,
}) => MaterialApp(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: themeMode,
  home: Scaffold(body: PlatformAdminActorsScreen(repository: repository)),
);

class _FakeActorRepository implements PlatformActorReadRepository {
  _FakeActorRepository(this.directory);

  final PlatformActorDirectoryViewData directory;
  int loadCount = 0;

  @override
  Future<PlatformActorDirectoryViewData> loadDirectory() async {
    loadCount += 1;
    return directory;
  }
}

PlatformActorDirectoryViewData _directory() =>
    const PlatformActorDirectoryViewData(
      professionals: [
        PlatformProfessionalViewData(
          uid: 'professional-a',
          displayName: 'Alice Martin',
          professionLabel: 'Infirmier',
          cptsId: 'cpts-a',
          cptsLabel: 'CPTS A',
          departmentLabel: 'Gironde',
          regionLabel: 'Nouvelle-Aquitaine',
          participations: [
            PlatformParticipationViewData(
              missionId: 'mission-a',
              missionLabel: 'Mission A',
              professionLabel: 'Infirmier',
              status: 'confirmed',
              operationId: 'operation-a',
              operationLabel: 'Opération A',
              locationId: 'location-a',
              locationLabel: 'Centre A',
            ),
          ],
        ),
      ],
      coordinators: [
        PlatformCoordinatorViewData(
          uid: 'coordinator-a',
          displayName: 'Camille Martin',
          active: true,
          operations: [
            PlatformActorReference(id: 'operation-a', label: 'Opération A'),
          ],
          mobilizations: [
            PlatformCoordinatorMobilizationViewData(
              id: 'mobilization-a',
              label: 'Mobilisation A',
              active: true,
            ),
          ],
        ),
      ],
      managers: [
        PlatformManagerViewData(
          uid: 'manager-a',
          displayName: 'Morgan Dupont',
          active: true,
          locations: [
            PlatformActorReference(id: 'location-a', label: 'Centre A'),
          ],
          operations: [
            PlatformActorReference(id: 'operation-a', label: 'Opération A'),
          ],
          territories: [
            PlatformActorReference(id: 'territory-a', label: 'Gironde'),
          ],
        ),
      ],
    );
