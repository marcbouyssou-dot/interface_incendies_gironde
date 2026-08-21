import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/organization.dart';
import 'package:interface_incendies_gironde/models/organization_category.dart';
import 'package:interface_incendies_gironde/models/organization_membership.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/models/organization_visibility.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_repository_scope.dart';
import 'package:interface_incendies_gironde/screens/coordinator_shell.dart';
import 'package:interface_incendies_gironde/screens/professional_shell.dart';
import 'package:interface_incendies_gironde/screens/responsible_shell.dart';
import 'package:interface_incendies_gironde/services/legacy_organization_resolver.dart';
import 'package:interface_incendies_gironde/services/organization_context_controller.dart';

void main() {
  group('OrganizationContextController', () {
    test(
      'resolves an active legacy coordinator through RC4 contracts',
      () async {
        final membership = _membership(
          uid: 'coordinator-a',
          roles: const {OrganizationRole.coordinator},
        );
        final repository = _RecordingOrganizationRepository(
          organization: _legacyOrganization(),
          memberships: {'coordinator-a': membership},
        );
        final controller = OrganizationContextController(
          repository: repository,
        );
        addTearDown(controller.dispose);

        controller.resolveLegacyIdentity(
          uid: 'coordinator-a',
          legacyRoleValues: const ['coordinator'],
        );
        await _flushStreams();

        expect(controller.value?.organization?.id, 'legacy-gironde');
        expect(controller.value?.membership, membership);
        expect(controller.value?.effectiveRoles, {
          OrganizationRole.coordinator,
        });
        expect(repository.membershipReads, 1);
        expect(repository.organizationReads, 1);
      },
    );

    test(
      'keeps the responsible legacy fallback when membership is absent',
      () async {
        final repository = _RecordingOrganizationRepository(
          organization: _legacyOrganization(),
        );
        final controller = OrganizationContextController(
          repository: repository,
        );
        addTearDown(controller.dispose);

        controller.resolveLegacyIdentity(
          uid: 'responsible-a',
          legacyRoleValues: const ['site_manager'],
        );
        await _flushStreams();

        expect(controller.value?.isLegacy, isTrue);
        expect(controller.value?.membership, isNull);
        expect(controller.value?.effectiveRoles, {
          OrganizationRole.siteManager,
        });
        expect(repository.membershipReads, 1);
        expect(
          repository.organizationReads,
          0,
          reason: 'Une lecture refusée ne doit pas casser le fallback RC3.',
        );
      },
    );

    test(
      'exposes an inactive membership without changing RC3 permissions',
      () async {
        final membership = _membership(
          uid: 'coordinator-a',
          roles: const {OrganizationRole.coordinator},
          active: false,
        );
        final repository = _RecordingOrganizationRepository(
          organization: _legacyOrganization(),
          memberships: {'coordinator-a': membership},
        );
        final controller = OrganizationContextController(
          repository: repository,
        );
        addTearDown(controller.dispose);

        controller.resolveLegacyIdentity(
          uid: 'coordinator-a',
          legacyRoleValues: const ['coordinator'],
        );
        await _flushStreams();

        expect(controller.value?.membership, membership);
        expect(controller.value?.hasInactiveMembership, isTrue);
        expect(controller.value?.effectiveRoles, isEmpty);
        expect(repository.organizationReads, 0);
      },
    );

    test(
      'keeps platform admin global while selecting the legacy perimeter',
      () async {
        final repository = _RecordingOrganizationRepository(
          organization: _legacyOrganization(),
        );
        final controller = OrganizationContextController(
          repository: repository,
        );
        addTearDown(controller.dispose);

        controller.resolveLegacyIdentity(
          uid: 'platform-admin',
          isPlatformAdministrator: true,
        );
        await _flushStreams();

        expect(controller.value?.organization?.id, 'legacy-gironde');
        expect(controller.value?.isPlatformAdministrator, isTrue);
        expect(controller.value?.effectiveRoles, isEmpty);
        expect(repository.organizationReads, 1);
      },
    );

    test('centralizes implicit and explicit operation ownership', () {
      final controller = OrganizationContextController(
        repository: const NoOrganizationReadRepository(),
      );
      addTearDown(controller.dispose);

      expect(
        controller.resolveOperationOrganizationId(_operation()),
        LegacyOrganizationResolver.legacyOrganizationId,
      );
      expect(
        controller.resolveOperationOrganizationId(
          _operation(ownerOrganizationId: 'organization-explicit'),
        ),
        'organization-explicit',
      );
    });

    testWidgets('injects one repository and one central listenable context', (
      tester,
    ) async {
      final repository = _RecordingOrganizationRepository(
        organization: _legacyOrganization(),
      );
      final controller = OrganizationContextController(repository: repository);
      addTearDown(controller.dispose);
      OrganizationReadRepository? injectedRepository;
      OrganizationContextController? injectedController;

      await tester.pumpWidget(
        OrganizationRepositoryScope(
          repository: repository,
          child: OrganizationContextBootstrap(
            repository: repository,
            controller: controller,
            child: Builder(
              builder: (context) {
                injectedRepository = OrganizationRepositoryScope.of(context);
                injectedController = OrganizationContextScope.controllerOf(
                  context,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(injectedRepository, same(repository));
      expect(injectedController, same(controller));
    });
  });

  group('AppShell legacy organization integration', () {
    testWidgets('coordinator journey resolves legacy without visible change', (
      tester,
    ) async {
      final repository = _RecordingOrganizationRepository(
        organization: _legacyOrganization(),
        memberships: {
          'coordinator-a': _membership(
            uid: 'coordinator-a',
            roles: const {OrganizationRole.coordinator},
          ),
        },
      );
      final controller = OrganizationContextController(repository: repository);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        FireCoordinationApp(
          repository: MockCoordinationRepository(
            responsibleAccess: const ResponsibleAccess(
              uid: 'coordinator-a',
              role: ResponsibleRole.coordinator,
              locationIds: {},
              active: true,
            ),
          ),
          organizationReadRepository: repository,
          organizationContextController: controller,
        ),
      );
      await _pumpOrganizationRouting(tester);

      expect(find.byType(CoordinatorShell), findsOneWidget);
      expect(controller.value?.organization?.id, 'legacy-gironde');
      expect(controller.value?.effectiveRoles, {OrganizationRole.coordinator});
    });

    testWidgets('responsible journey resolves legacy without visible change', (
      tester,
    ) async {
      final repository = _RecordingOrganizationRepository(
        organization: _legacyOrganization(),
        memberships: {
          'responsible-a': _membership(
            uid: 'responsible-a',
            roles: const {OrganizationRole.siteManager},
            locationIds: const {'merignac'},
          ),
        },
      );
      final controller = OrganizationContextController(repository: repository);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        FireCoordinationApp(
          repository: MockCoordinationRepository(
            responsibleAccess: const ResponsibleAccess(
              uid: 'responsible-a',
              role: ResponsibleRole.siteManager,
              locationIds: {'merignac'},
              active: true,
            ),
          ),
          organizationReadRepository: repository,
          organizationContextController: controller,
        ),
      );
      await _pumpOrganizationRouting(tester);

      expect(find.byType(ResponsibleShell), findsOneWidget);
      expect(controller.value?.organization?.id, 'legacy-gironde');
      expect(controller.value?.effectiveRoles, {OrganizationRole.siteManager});
    });

    testWidgets(
      'membership-only coordinator is routed without a legacy role document',
      (tester) async {
        final repository = _RecordingOrganizationRepository(
          organization: _legacyOrganization(),
          memberships: {
            'membership-coordinator': _membership(
              uid: 'membership-coordinator',
              roles: const {
                OrganizationRole.coordinator,
                OrganizationRole.professional,
              },
            ),
          },
        );
        final controller = OrganizationContextController(
          repository: repository,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          FireCoordinationApp(
            repository: _MembershipOnlyCoordinationRepository(
              'membership-coordinator',
            ),
            organizationReadRepository: repository,
            organizationContextController: controller,
          ),
        );
        await _pumpOrganizationRouting(tester);

        expect(find.byType(CoordinatorShell), findsOneWidget);
        expect(controller.value?.membership, isNotNull);
        expect(controller.value?.effectiveRoles, {
          OrganizationRole.coordinator,
          OrganizationRole.professional,
        });
      },
    );

    testWidgets(
      'professional journey performs no organization read or filter',
      (tester) async {
        final repository = _RecordingOrganizationRepository(
          organization: _legacyOrganization(),
        );
        final controller = OrganizationContextController(
          repository: repository,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          FireCoordinationApp(
            repository: MockCoordinationRepository(responsibleAccess: null),
            organizationReadRepository: repository,
            organizationContextController: controller,
          ),
        );
        await _pumpOrganizationRouting(tester);

        expect(find.byType(ProfessionalShell), findsOneWidget);
        expect(controller.value, isNull);
        expect(repository.membershipReads, 0);
        expect(repository.organizationReads, 0);
      },
    );
  });
}

Future<void> _pumpOrganizationRouting(WidgetTester tester) async {
  for (var index = 0; index < 6; index++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

class _RecordingOrganizationRepository implements OrganizationReadRepository {
  _RecordingOrganizationRepository({
    required this.organization,
    this.memberships = const {},
  });

  final Organization organization;
  final Map<String, OrganizationMembership> memberships;
  int membershipReads = 0;
  int organizationReads = 0;

  @override
  Stream<List<Organization>> watchAccessibleOrganizations({
    required String uid,
  }) => Stream.value(const []);

  @override
  Stream<List<OrganizationMembership>> watchMembershipsForUser(String uid) =>
      Stream.value([?memberships[uid]]);

  @override
  Stream<OrganizationMembership?> watchMembership({
    required String organizationId,
    required String uid,
  }) {
    membershipReads++;
    return Stream.value(memberships[uid]);
  }

  @override
  Stream<Organization?> watchOrganization(String organizationId) {
    organizationReads++;
    return Stream.value(
      organizationId == organization.id ? organization : null,
    );
  }
}

Organization _legacyOrganization() => Organization(
  id: LegacyOrganizationResolver.legacyOrganizationId,
  name: 'Organisation legacy Gironde',
  category: OrganizationCategory.other,
  defaultVisibility: OrganizationVisibility.platform,
  active: true,
  createdAt: DateTime.utc(2026, 8, 21),
  updatedAt: DateTime.utc(2026, 8, 21),
  schemaVersion: 1,
);

OrganizationMembership _membership({
  required String uid,
  required Set<OrganizationRole> roles,
  Set<String> locationIds = const {},
  bool active = true,
}) => OrganizationMembership(
  organizationId: LegacyOrganizationResolver.legacyOrganizationId,
  uid: uid,
  roles: roles,
  locationIds: locationIds,
  active: active,
  createdAt: DateTime.utc(2026, 8, 21),
  updatedAt: DateTime.utc(2026, 8, 21),
  schemaVersion: 1,
);

class _MembershipOnlyCoordinationRepository extends MockCoordinationRepository
    implements AdministrativeIdentityReadRepository {
  _MembershipOnlyCoordinationRepository(this.uid)
    : super(responsibleAccess: null);

  final String uid;

  @override
  Stream<String?> watchAdministrativeUid() => Stream.value(uid);
}

Operation _operation({String? ownerOrganizationId}) => Operation.fromMap({
  'id': 'operation-a',
  'name': 'Opération A',
  'type': 'emergency',
  'status': 'active',
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

Future<void> _flushStreams() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
