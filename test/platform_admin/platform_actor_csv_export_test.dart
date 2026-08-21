import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/platform_admin/platform_actor_csv_export.dart';
import 'package:interface_incendies_gironde/platform_admin/platform_actor_view_data.dart';

void main() {
  const builder = PlatformActorCsvExportBuilder();

  test('sérialise un CSV Excel FR sans coordonnées sensibles', () {
    final export = builder.build(
      directory: _directory(),
      kind: PlatformActorKind.professional,
      filter: const PlatformActorFilter(search: 'Élodie'),
      generatedAt: DateTime(2026, 8, 21),
    );

    expect(export.rowCount, 1);
    expect(
      export.fileName,
      'MobSante_professionnels_recherche-elodie_2026-08-21.csv',
    );
    expect(export.contents, startsWith('\ufeff"Identité";"Profession";'));
    expect(export.contents, contains('\r\n'));
    expect(export.contents, contains('"Élodie ""Martin"",\nTest"'));
    expect(export.contents, contains('"Centre, Sud\nNiveau 2"'));
    expect(export.contents, contains('"Opération Orage"'));
    expect(export.contents.toLowerCase(), isNot(contains('téléphone')));
    expect(export.contents.toLowerCase(), isNot(contains('email')));
    expect(export.contents.toLowerCase(), isNot(contains('rpps')));
    expect(
      export.contents.toLowerCase(),
      isNot(contains('adresse personnelle')),
    );
  });

  test('reprend exactement tous les filtres professionnels affichés', () {
    const filter = PlatformActorFilter(
      search: 'élodie',
      profession: 'Médecin urgentiste',
      operationId: 'operation-a',
      department: 'Gironde',
      region: 'Nouvelle-Aquitaine',
      cptsId: 'cpts-a',
      locationId: 'location-a',
      participationStatus: 'confirmed',
    );
    final directory = _directory();
    final visible = directory.filteredProfessionals(filter);
    final export = builder.build(
      directory: directory,
      kind: PlatformActorKind.professional,
      filter: filter,
      generatedAt: DateTime(2026, 8, 21),
    );

    expect(visible.map((actor) => actor.displayName), [
      'Élodie "Martin",\nTest',
    ]);
    expect(export.rowCount, visible.length);
    expect(export.contents, contains('Élodie'));
    expect(export.contents, isNot(contains('Bruno')));
    expect(export.fileName, startsWith('MobSante_professionnels_'));
    expect(export.fileName, contains('profession-medecin-urgentist'));
    expect(export.fileName, contains('operation-operation-orage'));
    expect(export.fileName, endsWith('_2026-08-21.csv'));
  });

  test('exporte les colonnes opérationnelles des coordinateurs', () {
    final export = builder.build(
      directory: _directory(),
      kind: PlatformActorKind.coordinator,
      filter: const PlatformActorFilter(operationId: 'operation-a'),
      generatedAt: DateTime(2026, 8, 21),
    );

    expect(export.rowCount, 1);
    expect(export.fileName, startsWith('MobSante_coordinateurs_operation-'));
    expect(
      export.contents,
      contains('"Identité";"Opérations pilotées";"Mobilisations";"État"'),
    );
    expect(export.contents, contains('"Mobilisation Orage · Active"'));
    expect(export.contents, contains('"Actif"'));
  });

  test('exporte les colonnes opérationnelles des responsables', () {
    final export = builder.build(
      directory: _directory(),
      kind: PlatformActorKind.manager,
      filter: const PlatformActorFilter(locationId: 'location-a'),
      generatedAt: DateTime(2026, 8, 21),
    );

    expect(export.rowCount, 1);
    expect(export.fileName, startsWith('MobSante_responsables_site-'));
    expect(
      export.contents,
      contains(
        '"Identité";"Établissements / sites";"Territoires";"Opérations concernées";"État"',
      ),
    );
    expect(export.contents, contains('"Centre, Sud\nNiveau 2"'));
    expect(export.contents, contains('"Gironde"'));
    expect(export.contents, contains('"Inactif"'));
  });

  test('neutralise les cellules interprétables comme formules Excel', () {
    final export = builder.build(
      directory: const PlatformActorDirectoryViewData(
        professionals: [
          PlatformProfessionalViewData(
            uid: 'professional-formula',
            displayName: '=HYPERLINK("https://example.test")',
            professionLabel: '+Médecin',
            participations: [],
          ),
        ],
        coordinators: [],
        managers: [],
      ),
      kind: PlatformActorKind.professional,
      filter: const PlatformActorFilter(),
      generatedAt: DateTime(2026, 8, 21),
    );

    expect(
      export.contents,
      contains('"\'=HYPERLINK(""https://example.test"")"'),
    );
    expect(export.contents, contains('"\'+Médecin"'));
  });
}

PlatformActorDirectoryViewData _directory() => PlatformActorDirectoryViewData(
  professionals: [
    const PlatformProfessionalViewData(
      uid: 'professional-a',
      displayName: 'Élodie "Martin",\nTest',
      professionLabel: 'Médecin urgentiste',
      cptsId: 'cpts-a',
      cptsLabel: 'CPTS Bordeaux',
      departmentLabel: 'Gironde',
      regionLabel: 'Nouvelle-Aquitaine',
      participations: [
        PlatformParticipationViewData(
          missionId: 'mission-a',
          missionLabel: 'Urgences, nuit',
          professionLabel: 'Médecin urgentiste',
          status: 'confirmed',
          operationId: 'operation-a',
          operationLabel: 'Opération Orage',
          mobilizationId: 'mobilization-a',
          mobilizationLabel: 'Mobilisation Orage',
          locationId: 'location-a',
          locationLabel: 'Centre, Sud\nNiveau 2',
          territoryId: 'territory-a',
          territoryLabel: 'Bordeaux Métropole',
        ),
      ],
    ),
    const PlatformProfessionalViewData(
      uid: 'professional-b',
      displayName: 'Bruno Durand',
      professionLabel: 'Infirmier',
      departmentLabel: 'Landes',
      regionLabel: 'Nouvelle-Aquitaine',
      participations: [
        PlatformParticipationViewData(
          missionId: 'mission-b',
          missionLabel: 'Accueil',
          professionLabel: 'Infirmier',
          status: 'cancelled',
          operationId: 'operation-b',
          operationLabel: 'Opération Feu',
        ),
      ],
    ),
  ],
  coordinators: const [
    PlatformCoordinatorViewData(
      uid: 'coordinator-a',
      displayName: 'Camille Martin',
      active: true,
      operations: [
        PlatformActorReference(id: 'operation-a', label: 'Opération Orage'),
      ],
      mobilizations: [
        PlatformCoordinatorMobilizationViewData(
          id: 'mobilization-a',
          label: 'Mobilisation Orage',
          active: true,
        ),
      ],
    ),
  ],
  managers: const [
    PlatformManagerViewData(
      uid: 'manager-a',
      displayName: 'Morgan Dupont',
      active: false,
      locations: [
        PlatformActorReference(
          id: 'location-a',
          label: 'Centre, Sud\nNiveau 2',
        ),
      ],
      operations: [
        PlatformActorReference(id: 'operation-a', label: 'Opération Orage'),
      ],
      territories: [
        PlatformActorReference(id: 'territory-a', label: 'Gironde'),
      ],
    ),
  ],
);
