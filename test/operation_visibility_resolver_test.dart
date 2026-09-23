import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/organization.dart';
import 'package:interface_incendies_gironde/models/organization_category.dart';
import 'package:interface_incendies_gironde/models/organization_visibility.dart';
import 'package:interface_incendies_gironde/services/operation_visibility_resolver.dart';

void main() {
  const resolver = OperationVisibilityResolver();

  test(
    'explicit operation visibility always wins over organization default',
    () {
      final organization = _organization(OrganizationVisibility.platform);
      final operation = _operation(
        ownerOrganizationId: organization.id,
        visibility: OrganizationVisibility.organizationPrivate,
      );

      expect(
        resolver.resolve(operation: operation, ownerOrganization: organization),
        OrganizationVisibility.organizationPrivate,
      );
    },
  );

  test('missing RC4 visibility resolves from its owner during transition', () {
    final organization = _organization(OrganizationVisibility.shared);

    expect(
      resolver.resolve(
        operation: _operation(ownerOrganizationId: organization.id),
        ownerOrganization: organization,
      ),
      OrganizationVisibility.shared,
    );
  });

  test('legacy Gironde remains platform discoverable without visibility', () {
    final operation = _operation();

    expect(
      resolver.resolve(operation: operation),
      OrganizationVisibility.platform,
    );
    expect(resolver.isPlatformDiscoverable(operation: operation), isTrue);
  });

  test('unknown external default fails closed', () {
    expect(
      () => resolver.resolve(
        operation: _operation(ownerOrganizationId: 'organization-b'),
      ),
      throwsStateError,
    );
  });

  for (final visibility in const [
    OrganizationVisibility.organizationPrivate,
    OrganizationVisibility.shared,
    OrganizationVisibility.publicAccess,
  ]) {
    test('$visibility is not externally discoverable', () {
      expect(
        resolver.isPlatformDiscoverable(
          operation: _operation(
            ownerOrganizationId: 'organization-b',
            visibility: visibility,
          ),
        ),
        isFalse,
      );
    });
  }
}

Operation _operation({
  String? ownerOrganizationId,
  OrganizationVisibility? visibility,
}) => Operation.fromMap({
  'id': 'operation-a',
  'name': 'Opération A',
  'type': 'emergency',
  'status': 'active',
  'startAt': DateTime.utc(2026, 8, 21),
  'endAt': null,
  'ownerOrganizationId': ?ownerOrganizationId,
  'visibility': ?visibility?.serializedValue,
  'scopeRefs': <Object?>['territories/gironde'],
  'createdBy': 'admin',
  'createdAt': DateTime.utc(2026, 8, 21),
  'updatedBy': 'admin',
  'updatedAt': DateTime.utc(2026, 8, 21),
  'schemaVersion': 4,
});

Organization _organization(OrganizationVisibility defaultVisibility) =>
    Organization(
      id: 'organization-a',
      name: 'Organisation A',
      category: OrganizationCategory.cpts,
      defaultVisibility: defaultVisibility,
      active: true,
      createdAt: DateTime.utc(2026, 8, 21),
      updatedAt: DateTime.utc(2026, 8, 21),
      schemaVersion: 1,
    );
