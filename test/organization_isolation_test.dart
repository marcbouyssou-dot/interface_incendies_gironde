import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/organization.dart';
import 'package:interface_incendies_gironde/models/organization_category.dart';
import 'package:interface_incendies_gironde/models/organization_context.dart';
import 'package:interface_incendies_gironde/models/organization_membership.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/models/organization_visibility.dart';
import 'package:interface_incendies_gironde/repositories/in_memory_organization_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/operation_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_scoped_operation_read_repository.dart';
import 'package:interface_incendies_gironde/services/legacy_organization_resolver.dart';

const _testOrganizationId = 'test-organization';
const _testUid = 'rc4-test-user';

void main() {
  group('RC4.2C organization isolation proof', () {
    test(
      'active test membership exposes only its explicit organization',
      () async {
        final fixture = _IsolationFixture(activeMembership: true);
        addTearDown(fixture.dispose);

        final accessibleOrganizations = await fixture.organizationRepository
            .watchAccessibleOrganizations(uid: _testUid)
            .first;
        fixture.context.value = fixture.testContext;

        expect(accessibleOrganizations.map((organization) => organization.id), [
          _testOrganizationId,
        ]);
        expect(await fixture.visibleOperationIds(), ['operation-test']);
      },
    );

    test('legacy context cannot list or read the test operation', () async {
      final fixture = _IsolationFixture();
      addTearDown(fixture.dispose);
      fixture.context.value = fixture.legacyContext;

      expect(await fixture.visibleOperationIds(), [
        'operation-legacy-implicit',
        'operation-gironde',
      ]);
      expect(
        await fixture.operationRepository
            .watchOperation('operation-test')
            .first,
        isNull,
      );
    });

    test('test context cannot list or read Gironde operations', () async {
      final fixture = _IsolationFixture();
      addTearDown(fixture.dispose);
      fixture.context.value = fixture.testContext;

      expect(await fixture.visibleOperationIds(), ['operation-test']);
      expect(
        await fixture.operationRepository
            .watchOperation('operation-gironde')
            .first,
        isNull,
      );
      expect(
        await fixture.operationRepository
            .watchOperation('operation-legacy-implicit')
            .first,
        isNull,
      );
    });

    test('global platform admin sees both organizations', () async {
      final fixture = _IsolationFixture();
      addTearDown(fixture.dispose);
      fixture.context.value = OrganizationContext.unselected(
        uid: 'platform-admin',
        isPlatformAdministrator: true,
      );

      expect(await fixture.visibleOperationIds(), [
        'operation-legacy-implicit',
        'operation-gironde',
        'operation-test',
      ]);
    });

    test(
      'contextualized platform admin sees only selected organization',
      () async {
        final fixture = _IsolationFixture();
        addTearDown(fixture.dispose);

        fixture.context.value = fixture.platformAdminContext(
          fixture.testOrganization,
        );
        expect(await fixture.visibleOperationIds(), ['operation-test']);

        fixture.context.value = fixture.platformAdminContext(
          LegacyOrganizationResolver.legacyOrganization,
        );
        expect(await fixture.visibleOperationIds(), [
          'operation-legacy-implicit',
          'operation-gironde',
        ]);
      },
    );

    test(
      'dynamic context switch never emits a mixed organization list',
      () async {
        final fixture = _IsolationFixture();
        addTearDown(fixture.dispose);
        fixture.context.value = fixture.legacyContext;
        final emissions = <List<String>>[];
        final subscription = fixture.operationRepository
            .watchOperations()
            .listen(
              (operations) => emissions.add(
                operations
                    .map((operation) => operation.id)
                    .toList(growable: false),
              ),
            );
        addTearDown(subscription.cancel);
        await _flushStreams();

        fixture.context.value = fixture.testContext;
        await _flushStreams();

        expect(emissions, [
          ['operation-legacy-implicit', 'operation-gironde'],
          ['operation-test'],
        ]);
      },
    );

    test(
      'inactive non-legacy membership exposes no operation and no read',
      () async {
        final fixture = _IsolationFixture(activeMembership: false);
        addTearDown(fixture.dispose);
        fixture.context.value = fixture.testContext;
        final readsBefore = fixture.operationDataSource.listReads;

        expect(await fixture.visibleOperationIds(), isEmpty);
        expect(
          await fixture.operationRepository
              .watchOperation('operation-test')
              .first,
          isNull,
        );
        expect(fixture.operationDataSource.listReads, readsBefore);
        expect(fixture.operationDataSource.documentReads, 0);
        expect(fixture.testContext.hasInactiveMembership, isTrue);
        expect(fixture.testContext.effectiveRoles, isEmpty);
      },
    );
  });
}

class _IsolationFixture {
  _IsolationFixture({bool activeMembership = true})
    : testOrganization = _organization(),
      testMembership = _membership(active: activeMembership),
      operationDataSource = _OperationRepository(_operations()) {
    organizationRepository = InMemoryOrganizationReadRepository(
      organizations: [
        LegacyOrganizationResolver.legacyOrganization,
        testOrganization,
      ],
      memberships: [testMembership],
    );
    context = ValueNotifier<OrganizationContext?>(null);
    operationRepository = OrganizationScopedOperationReadRepository(
      delegate: operationDataSource,
      context: context,
    );
  }

  static const resolver = LegacyOrganizationResolver();

  final Organization testOrganization;
  final OrganizationMembership testMembership;
  late final InMemoryOrganizationReadRepository organizationRepository;
  final _OperationRepository operationDataSource;
  late final ValueNotifier<OrganizationContext?> context;
  late final OrganizationScopedOperationReadRepository operationRepository;

  OrganizationContext get legacyContext => resolver.resolveContext(
    uid: 'legacy-coordinator',
    selectedOrganization: LegacyOrganizationResolver.legacyOrganization,
    legacyRoleValues: const ['coordinator'],
  );

  OrganizationContext get testContext => resolver.resolveContext(
    uid: _testUid,
    selectedOrganization: testOrganization,
    membership: testMembership,
  );

  OrganizationContext platformAdminContext(Organization organization) =>
      resolver.resolveContext(
        uid: 'platform-admin',
        selectedOrganization: organization,
        isPlatformAdministrator: true,
      );

  Future<List<String>> visibleOperationIds() =>
      operationRepository.watchOperations().first.then(
        (operations) =>
            operations.map((operation) => operation.id).toList(growable: false),
      );

  void dispose() => context.dispose();
}

class _OperationRepository implements OperationReadRepository {
  _OperationRepository(this.operations);

  final List<Operation> operations;
  int listReads = 0;
  int documentReads = 0;

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

Organization _organization() => Organization(
  id: _testOrganizationId,
  name: 'Organisation de test RC4',
  category: OrganizationCategory.other,
  defaultVisibility: OrganizationVisibility.organizationPrivate,
  active: true,
  createdAt: DateTime.utc(2026, 8, 21),
  updatedAt: DateTime.utc(2026, 8, 21),
  schemaVersion: 1,
);

OrganizationMembership _membership({required bool active}) =>
    OrganizationMembership(
      organizationId: _testOrganizationId,
      uid: _testUid,
      roles: const {OrganizationRole.organizationAdmin},
      active: active,
      createdAt: DateTime.utc(2026, 8, 21),
      updatedAt: DateTime.utc(2026, 8, 21),
      schemaVersion: 1,
    );

List<Operation> _operations() => [
  _operation(id: 'operation-legacy-implicit'),
  _operation(
    id: 'operation-gironde',
    ownerOrganizationId: LegacyOrganizationResolver.legacyOrganizationId,
  ),
  _operation(id: 'operation-test', ownerOrganizationId: _testOrganizationId),
];

Operation _operation({required String id, String? ownerOrganizationId}) =>
    Operation.fromMap({
      'id': id,
      'name': 'Opération $id',
      'type': 'exercise',
      'status': 'draft',
      'context': null,
      'startAt': DateTime.utc(2026, 8, 21),
      'endAt': null,
      'ownerOrganizationId': ?ownerOrganizationId,
      'scopeRefs': <Object?>['territories/gironde'],
      'createdBy': 'rc4-test',
      'createdAt': DateTime.utc(2026, 8, 21),
      'updatedBy': 'rc4-test',
      'updatedAt': DateTime.utc(2026, 8, 21),
      'schemaVersion': ownerOrganizationId == null ? 1 : 3,
    });

Future<void> _flushStreams() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
