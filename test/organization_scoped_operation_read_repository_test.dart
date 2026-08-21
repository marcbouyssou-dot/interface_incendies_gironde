import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/organization_context.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/repositories/operation_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_scoped_operation_read_repository.dart';
import 'package:interface_incendies_gironde/services/legacy_organization_resolver.dart';

void main() {
  group('OrganizationScopedOperationReadRepository', () {
    test(
      'legacy context includes implicit and explicit legacy operations',
      () async {
        final delegate = _OperationRepository(_operations());
        final context = ValueNotifier<OrganizationContext?>(
          _legacyContext(OrganizationRole.coordinator),
        );
        addTearDown(context.dispose);
        final repository = OrganizationScopedOperationReadRepository(
          delegate: delegate,
          context: context,
        );

        final operations = await repository.watchOperations().first;

        expect(operations.map((operation) => operation.id), [
          'legacy-implicit',
          'legacy-explicit',
        ]);
        expect(() => operations.clear(), throwsUnsupportedError);
        expect(delegate.listReads, 1);
      },
    );

    test('an operation owned by another organization never leaks', () async {
      final delegate = _OperationRepository(_operations());
      final context = ValueNotifier<OrganizationContext?>(
        _legacyContext(OrganizationRole.siteManager),
      );
      addTearDown(context.dispose);
      final repository = OrganizationScopedOperationReadRepository(
        delegate: delegate,
        context: context,
      );

      final operation = await repository.watchOperation('other').first;

      expect(operation, isNull);
      expect(delegate.documentReads, 1);
    });

    test(
      'global platform admin keeps the complete repository projection',
      () async {
        final delegate = _OperationRepository(_operations());
        final context = ValueNotifier<OrganizationContext?>(
          OrganizationContext.unselected(
            uid: 'platform-admin',
            isPlatformAdministrator: true,
          ),
        );
        addTearDown(context.dispose);
        final repository = OrganizationScopedOperationReadRepository(
          delegate: delegate,
          context: context,
        );

        final operations = await repository.watchOperations().first;

        expect(operations.map((operation) => operation.id), [
          'legacy-implicit',
          'legacy-explicit',
          'other',
        ]);
      },
    );

    test(
      'contextualized platform admin is bounded to legacy Gironde',
      () async {
        final delegate = _OperationRepository(_operations());
        final context = ValueNotifier<OrganizationContext?>(
          OrganizationContext.selected(
            uid: 'platform-admin',
            organization: LegacyOrganizationResolver.legacyOrganization,
            isLegacy: true,
            isPlatformAdministrator: true,
          ),
        );
        addTearDown(context.dispose);
        final repository = OrganizationScopedOperationReadRepository(
          delegate: delegate,
          context: context,
        );

        final operations = await repository.watchOperations().first;

        expect(operations.map((operation) => operation.id), [
          'legacy-implicit',
          'legacy-explicit',
        ]);
      },
    );

    test(
      'coordinator and responsible legacy receive the same RC3 operations',
      () async {
        for (final role in const [
          OrganizationRole.coordinator,
          OrganizationRole.siteManager,
        ]) {
          final delegate = _OperationRepository(_operations());
          final context = ValueNotifier<OrganizationContext?>(
            _legacyContext(role),
          );
          final repository = OrganizationScopedOperationReadRepository(
            delegate: delegate,
            context: context,
          );

          final ids = await repository.watchOperations().first.then(
            (operations) => operations.map((item) => item.id).toList(),
          );

          expect(ids, ['legacy-implicit', 'legacy-explicit']);
          context.dispose();
        }
      },
    );

    test(
      'an unresolved non-platform context cannot trigger or leak a read',
      () async {
        final delegate = _OperationRepository(_operations());
        final context = ValueNotifier<OrganizationContext?>(null);
        addTearDown(context.dispose);
        final repository = OrganizationScopedOperationReadRepository(
          delegate: delegate,
          context: context,
        );

        expect(await repository.watchOperations().first, isEmpty);
        expect(
          await repository.watchOperation('legacy-implicit').first,
          isNull,
        );
        expect(delegate.listReads, 0);
        expect(delegate.documentReads, 0);
      },
    );

    test(
      'a platform admin becomes bounded when a context is selected',
      () async {
        final delegate = _OperationRepository(_operations());
        final context = ValueNotifier<OrganizationContext?>(
          OrganizationContext.unselected(
            uid: 'platform-admin',
            isPlatformAdministrator: true,
          ),
        );
        addTearDown(context.dispose);
        final repository = OrganizationScopedOperationReadRepository(
          delegate: delegate,
          context: context,
        );
        final emissions = <List<String>>[];
        final subscription = repository.watchOperations().listen(
          (operations) => emissions.add(
            operations.map((operation) => operation.id).toList(),
          ),
        );
        addTearDown(subscription.cancel);
        await _flushStreams();

        context.value = OrganizationContext.selected(
          uid: 'platform-admin',
          organization: LegacyOrganizationResolver.legacyOrganization,
          isLegacy: true,
          isPlatformAdministrator: true,
        );
        await _flushStreams();

        expect(emissions, [
          ['legacy-implicit', 'legacy-explicit', 'other'],
          ['legacy-implicit', 'legacy-explicit'],
        ]);
      },
    );

    test(
      'status filters are forwarded before organization projection',
      () async {
        final delegate = _OperationRepository([
          ..._operations(),
          _operation(
            id: 'legacy-draft',
            status: OperationStatus.draft,
            ownerOrganizationId: 'legacy-gironde',
          ),
        ]);
        final context = ValueNotifier<OrganizationContext?>(
          _legacyContext(OrganizationRole.coordinator),
        );
        addTearDown(context.dispose);
        final repository = OrganizationScopedOperationReadRepository(
          delegate: delegate,
          context: context,
        );

        final operations = await repository
            .watchOperations(statuses: const {OperationStatus.draft})
            .first;

        expect(operations.map((operation) => operation.id), ['legacy-draft']);
        expect(delegate.lastStatuses, const {OperationStatus.draft});
      },
    );
  });
}

class _OperationRepository implements OperationReadRepository {
  _OperationRepository(this.operations);

  final List<Operation> operations;
  int listReads = 0;
  int documentReads = 0;
  Set<OperationStatus>? lastStatuses;

  @override
  Stream<Operation?> watchOperation(String operationId) {
    documentReads++;
    return Stream.value(
      operations.where((operation) => operation.id == operationId).firstOrNull,
    );
  }

  @override
  Stream<List<Operation>> watchOperations({Set<OperationStatus>? statuses}) {
    listReads++;
    lastStatuses = statuses;
    return Stream.value(
      operations
          .where(
            (operation) =>
                statuses == null || statuses.contains(operation.status),
          )
          .toList(growable: false),
    );
  }
}

List<Operation> _operations() => [
  _operation(id: 'legacy-implicit'),
  _operation(id: 'legacy-explicit', ownerOrganizationId: 'legacy-gironde'),
  _operation(id: 'other', ownerOrganizationId: 'organization-b'),
];

Operation _operation({
  required String id,
  String? ownerOrganizationId,
  OperationStatus status = OperationStatus.active,
}) => Operation.fromMap({
  'id': id,
  'name': 'Opération $id',
  'type': 'emergency',
  'status': status.serializedValue,
  'context': null,
  'startAt': DateTime.utc(2026, 8, 21),
  'endAt': null,
  'ownerOrganizationId': ?ownerOrganizationId,
  'scopeRefs': <Object?>['territories/gironde'],
  'createdBy': 'admin',
  'createdAt': DateTime.utc(2026, 8, 21),
  'updatedBy': 'admin',
  'updatedAt': DateTime.utc(2026, 8, 21),
  'schemaVersion': ownerOrganizationId == null ? 1 : 3,
});

OrganizationContext _legacyContext(OrganizationRole role) =>
    OrganizationContext.selected(
      uid: role == OrganizationRole.coordinator
          ? 'coordinator-a'
          : 'responsible-a',
      organization: LegacyOrganizationResolver.legacyOrganization,
      effectiveRoles: {role},
      isLegacy: true,
    );

Future<void> _flushStreams() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
