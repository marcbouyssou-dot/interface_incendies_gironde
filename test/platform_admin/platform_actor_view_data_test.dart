import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/platform_admin/platform_actor_view_data.dart';

void main() {
  group('PlatformActorDirectoryViewData', () {
    test('filtre les professionnels par profession et statut', () {
      final directory = _directory();

      expect(
        directory
            .filteredProfessionals(
              const PlatformActorFilter(profession: 'Infirmier'),
            )
            .map((actor) => actor.uid),
        ['professional-a'],
      );
      expect(
        directory
            .filteredProfessionals(
              const PlatformActorFilter(participationStatus: 'cancelled'),
            )
            .map((actor) => actor.uid),
        ['professional-b'],
      );
    });

    test('filtre par opération sans inclure une autre opération', () {
      final directory = _directory();

      expect(
        directory
            .filteredProfessionals(
              const PlatformActorFilter(operationId: 'operation-a'),
            )
            .map((actor) => actor.uid),
        ['professional-a'],
      );
      expect(
        directory
            .filteredCoordinators(
              const PlatformActorFilter(operationId: 'operation-a'),
            )
            .map((actor) => actor.uid),
        ['coordinator-a'],
      );
      expect(
        directory
            .filteredManagers(
              const PlatformActorFilter(operationId: 'operation-a'),
            )
            .map((actor) => actor.uid),
        ['manager-a'],
      );
    });

    test('filtre la géographie, la CPTS et l’établissement', () {
      final directory = _directory();

      expect(
        directory
            .filteredProfessionals(
              const PlatformActorFilter(
                department: 'Gironde',
                region: 'Nouvelle-Aquitaine',
                cptsId: 'cpts-a',
                locationId: 'location-a',
              ),
            )
            .map((actor) => actor.uid),
        ['professional-a'],
      );
      expect(
        directory.filteredManagers(
          const PlatformActorFilter(locationId: 'location-b'),
        ),
        isEmpty,
      );
    });

    test('agrège les participations et distingue les trois familles', () {
      final directory = _directory();
      final professional = directory.professionals.first;

      expect(professional.participations, hasLength(2));
      expect(professional.activeParticipationCount, 2);
      expect(professional.operationIds, {'operation-a'});
      expect(directory.professionals, hasLength(2));
      expect(directory.coordinators.single.uid, 'coordinator-a');
      expect(directory.managers.single.uid, 'manager-a');
    });

    test('expose les options de filtre dédupliquées', () {
      final directory = _directory();

      expect(directory.professions, ['Infirmier', 'Médecin']);
      expect(directory.operations.map((item) => item.id), [
        'operation-a',
        'operation-b',
      ]);
      expect(directory.locations.map((item) => item.id), ['location-a']);
      expect(directory.departments, ['Gironde', 'Landes']);
      expect(directory.cpts.map((item) => item.id), ['cpts-a']);
    });
  });
}

PlatformActorDirectoryViewData _directory() => PlatformActorDirectoryViewData(
  professionals: [
    PlatformProfessionalViewData(
      uid: 'professional-a',
      displayName: 'Alice Martin',
      professionLabel: 'Infirmier',
      cptsId: 'cpts-a',
      cptsLabel: 'CPTS A',
      departmentLabel: 'Gironde',
      regionLabel: 'Nouvelle-Aquitaine',
      participations: const [
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
        PlatformParticipationViewData(
          missionId: 'mission-a-2',
          missionLabel: 'Mission A 2',
          professionLabel: 'Infirmier',
          status: 'standby',
          operationId: 'operation-a',
          operationLabel: 'Opération A',
          locationId: 'location-a',
          locationLabel: 'Centre A',
        ),
      ],
    ),
    const PlatformProfessionalViewData(
      uid: 'professional-b',
      displayName: 'Bruno Durand',
      professionLabel: 'Médecin',
      departmentLabel: 'Landes',
      regionLabel: 'Nouvelle-Aquitaine',
      participations: [
        PlatformParticipationViewData(
          missionId: 'mission-b',
          missionLabel: 'Mission B',
          professionLabel: 'Médecin',
          status: 'cancelled',
          operationId: 'operation-b',
          operationLabel: 'Opération B',
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
  managers: const [
    PlatformManagerViewData(
      uid: 'manager-a',
      displayName: 'Morgan Dupont',
      active: true,
      locations: [PlatformActorReference(id: 'location-a', label: 'Centre A')],
      operations: [
        PlatformActorReference(id: 'operation-a', label: 'Opération A'),
      ],
      territories: [
        PlatformActorReference(id: 'territory-a', label: 'Gironde'),
      ],
    ),
  ],
);
