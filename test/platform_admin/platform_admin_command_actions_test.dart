import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/executive_dashboard_snapshot.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/operational_scope.dart';
import 'package:interface_incendies_gironde/platform_admin/platform_actor_view_data.dart';
import 'package:interface_incendies_gironde/platform_admin/platform_admin_command_actions.dart';

void main() {
  group('PlatformAdminCommandEngine', () {
    test('détecte et ordonne les six décisions attendues', () {
      final operations = [
        _operation('critical', OperationStatus.active, coordinator: 'coord'),
        _operation('responsible', OperationStatus.active, coordinator: 'coord'),
        _operation('coverage', OperationStatus.active, coordinator: 'coord'),
        _operation('coordinator', OperationStatus.active),
        _operation(
          'mobilization',
          OperationStatus.active,
          coordinator: 'coord',
        ),
        _operation('draft', OperationStatus.draft),
      ];
      final dashboard = ExecutiveDashboardSnapshot(
        operations: operations,
        mobilizations: [
          _mobilization('mob-critical', 'critical'),
          _mobilization('mob-responsible', 'responsible'),
          _mobilization('mob-coverage', 'coverage'),
          _mobilization('mob-coordinator', 'coordinator'),
        ],
        missions: [
          _mission('critical', 'mob-critical', 'site-critical', 2, 0),
          _mission('responsible', 'mob-responsible', 'site-uncovered', 1, 1),
          _mission('coverage', 'mob-coverage', 'site-coverage', 2, 1),
        ],
      );

      final actions = const PlatformAdminCommandEngine().evaluate(
        dashboard,
        actorDirectory: _directory(
          activeLocations: const ['site-critical', 'site-coverage'],
        ),
      );

      expect(actions.map((action) => action.kind), [
        PlatformAdminCommandActionKind.criticalNeeds,
        PlatformAdminCommandActionKind.missingResponsible,
        PlatformAdminCommandActionKind.insufficientCoverage,
        PlatformAdminCommandActionKind.missingCoordinator,
        PlatformAdminCommandActionKind.incompleteMobilization,
        PlatformAdminCommandActionKind.unfinishedDraft,
      ]);
      expect(
        actions.map((action) => action.priority),
        orderedEquals([600, 500, 400, 300, 200, 100]),
      );
    });

    test('ne déduit pas un responsable manquant sans annuaire fiable', () {
      final dashboard = ExecutiveDashboardSnapshot(
        operations: [
          _operation('operation', OperationStatus.active, coordinator: 'coord'),
        ],
        mobilizations: [_mobilization('mobilization', 'operation')],
        missions: [_mission('mission', 'mobilization', 'site', 1, 1)],
      );

      final actions = const PlatformAdminCommandEngine().evaluate(dashboard);

      expect(
        actions.where(
          (action) =>
              action.kind == PlatformAdminCommandActionKind.missingResponsible,
        ),
        isEmpty,
      );
    });

    test('un responsable actif doit couvrir chaque établissement concerné', () {
      final dashboard = ExecutiveDashboardSnapshot(
        operations: [
          _operation('operation', OperationStatus.active, coordinator: 'coord'),
        ],
        mobilizations: [_mobilization('mobilization', 'operation')],
        missions: [
          _mission('mission-a', 'mobilization', 'site-a', 1, 1),
          _mission('mission-b', 'mobilization', 'site-b', 1, 1),
        ],
      );

      final action = const PlatformAdminCommandEngine()
          .evaluate(
            dashboard,
            actorDirectory: _directory(activeLocations: const ['site-a']),
          )
          .single;

      expect(action.kind, PlatformAdminCommandActionKind.missingResponsible);
      expect(action.detail, contains('1 établissement actif'));
    });

    test('une mobilisation archivée ne finalise pas une opération à venir', () {
      final dashboard = ExecutiveDashboardSnapshot(
        operations: [
          _operation(
            'operation',
            OperationStatus.planned,
            coordinator: 'coord',
          ),
        ],
        mobilizations: [
          _mobilization(
            'mobilization',
            'operation',
            status: MobilizationStatus.archived,
          ),
        ],
        missions: const [],
      );

      final actions = const PlatformAdminCommandEngine().evaluate(dashboard);

      expect(
        actions.single.kind,
        PlatformAdminCommandActionKind.incompleteMobilization,
      );
    });

    test('ignore les opérations terminées et archivées', () {
      final operations = [
        _operation('completed', OperationStatus.completed),
        _operation('archived', OperationStatus.archived),
      ];
      final dashboard = ExecutiveDashboardSnapshot(
        operations: operations,
        mobilizations: [
          _mobilization('mob-completed', 'completed'),
          _mobilization('mob-archived', 'archived'),
        ],
        missions: [
          _mission('completed', 'mob-completed', 'site-a', 2, 0),
          _mission('archived', 'mob-archived', 'site-b', 2, 0),
        ],
      );

      expect(
        const PlatformAdminCommandEngine().evaluate(
          dashboard,
          actorDirectory: _directory(activeLocations: const []),
        ),
        isEmpty,
      );
    });

    test('accepte une règle de présentation additionnelle', () {
      final dashboard = ExecutiveDashboardSnapshot(
        operations: [_operation('draft', OperationStatus.draft)],
        mobilizations: const [],
        missions: const [],
      );

      final actions = const PlatformAdminCommandEngine(
        rules: [_TestCommandRule()],
      ).evaluate(dashboard);

      expect(actions.single.title, 'Règle additionnelle');
    });
  });
}

class _TestCommandRule implements PlatformAdminCommandRule {
  const _TestCommandRule();

  @override
  PlatformAdminCommandAction evaluate(PlatformAdminCommandContext context) =>
      PlatformAdminCommandAction(
        kind: PlatformAdminCommandActionKind.unfinishedDraft,
        level: PlatformAdminCommandActionLevel.preparation,
        priority: 1,
        operation: context.snapshot.operation,
        title: 'Règle additionnelle',
        detail: 'Test',
      );
}

Operation _operation(
  String id,
  OperationStatus status, {
  String? coordinator,
}) => Operation(
  id: id,
  name: 'Opération $id',
  type: OperationType.emergency,
  status: status,
  startAt: DateTime(2026, 8, 21),
  coordinatorUid: coordinator,
  scopeRefs: const [
    OperationalScopeRef(kind: OperationalScopeKind.territory, id: 'gironde'),
  ],
  createdBy: 'admin',
  createdAt: DateTime(2026, 8, 20),
  updatedBy: 'admin',
  updatedAt: DateTime(2026, 8, 21),
  schemaVersion: 1,
);

Mobilization _mobilization(
  String id,
  String operationId, {
  MobilizationStatus status = MobilizationStatus.active,
}) => Mobilization(
  id: id,
  territoryId: 'gironde',
  name: 'Mobilisation $id',
  subtitle: 'Test',
  contextType: MobilizationContextType.other,
  status: status,
  createdBy: 'admin',
  createdAt: DateTime(2026, 8, 20),
  updatedAt: DateTime(2026, 8, 21),
  schemaVersion: 2,
  operationId: operationId,
);

CoordinationNeed _mission(
  String id,
  String mobilizationId,
  String locationId,
  int required,
  int registered,
) => CoordinationNeed(
  id: id,
  place: 'Centre $locationId',
  group: TerritorialGroup.southGironde,
  date: '21 août',
  time: '12:00 — 16:00',
  requiredPhysiotherapists: required,
  registeredPhysiotherapists: registered,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  equipment: const [],
  mobilizationId: mobilizationId,
  locationId: locationId,
);

PlatformActorDirectoryViewData _directory({
  required List<String> activeLocations,
}) => PlatformActorDirectoryViewData(
  professionals: const [],
  coordinators: const [],
  managers: [
    PlatformManagerViewData(
      uid: 'manager',
      displayName: 'Responsable',
      active: true,
      locations: [
        for (final id in activeLocations)
          PlatformActorReference(id: id, label: 'Centre $id'),
      ],
      operations: const [],
      territories: const [],
    ),
  ],
);
