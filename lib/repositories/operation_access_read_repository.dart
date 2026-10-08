import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/organization_context.dart';
import '../models/organization_role.dart';

class OperationAccess {
  const OperationAccess({
    required this.operationId,
    required this.organizationId,
    required this.roles,
    required this.locationIds,
  });

  final String operationId;
  final String organizationId;
  final Set<OrganizationRole> roles;
  final Set<String> locationIds;

  bool canRead(OrganizationContext context) {
    if (!context.hasActiveMembership ||
        context.organization?.id != organizationId) {
      return false;
    }
    return (roles.contains(OrganizationRole.coordinator) &&
            context.hasRole(OrganizationRole.coordinator)) ||
        (roles.contains(OrganizationRole.siteManager) &&
            context.hasRole(OrganizationRole.siteManager) &&
            locationIds.intersection(
              context.membership!.locationIds,
            ).isNotEmpty);
  }

  bool canReadSite(OrganizationContext context, String locationId) =>
      canRead(context) &&
      ((roles.contains(OrganizationRole.coordinator) &&
              context.hasRole(OrganizationRole.coordinator)) ||
          (roles.contains(OrganizationRole.siteManager) &&
              context.hasRole(OrganizationRole.siteManager) &&
              locationIds.contains(locationId) &&
              context.membership?.locationIds.contains(locationId) == true));

  factory OperationAccess.fromMap(
    String documentId,
    Map<String, Object?> data,
  ) {
    final operationId = data['operationId'];
    final organizationId = data['organizationId'];
    final uid = data['uid'];
    final roles = data['roles'];
    final locationIds = data['locationIds'];
    if (operationId is! String ||
        organizationId is! String ||
        uid is! String ||
        !_validId(operationId) ||
        !_validId(organizationId) ||
        !_validId(uid) ||
        documentId != '${operationId}_$uid' ||
        data['active'] != true ||
        data['schemaVersion'] is! int ||
        (data['schemaVersion'] as int) < 1 ||
        roles is! List ||
        roles.isEmpty ||
        roles.length > 2 ||
        locationIds is! List ||
        locationIds.any((item) => item is! String || !_validId(item)) ||
        locationIds.toSet().length != locationIds.length) {
      throw const FormatException('Habilitation d’Action invalide.');
    }
    final parsedRoles = <OrganizationRole>{};
    for (final role in roles) {
      if (role == 'coordinator') {
        parsedRoles.add(OrganizationRole.coordinator);
      } else if (role == 'site_manager') {
        parsedRoles.add(OrganizationRole.siteManager);
      } else {
        throw const FormatException('Rôle d’Action invalide.');
      }
    }
    if (parsedRoles.length != roles.length ||
        (parsedRoles.contains(OrganizationRole.siteManager)
            ? locationIds.isEmpty
            : locationIds.isNotEmpty)) {
      throw const FormatException('Sites d’Action invalides.');
    }
    return OperationAccess(
      operationId: operationId,
      organizationId: organizationId,
      roles: Set.unmodifiable(parsedRoles),
      locationIds: Set.unmodifiable(locationIds.cast<String>()),
    );
  }
}

abstract interface class OperationAccessReadRepository {
  Stream<List<OperationAccess>> watchForUser(String uid);
}

class EmptyOperationAccessReadRepository
    implements OperationAccessReadRepository {
  const EmptyOperationAccessReadRepository();

  @override
  Stream<List<OperationAccess>> watchForUser(String uid) =>
      Stream.multi((controller) => controller.add(const []));
}

class FirestoreOperationAccessReadRepository
    implements OperationAccessReadRepository {
  const FirestoreOperationAccessReadRepository(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Stream<List<OperationAccess>> watchForUser(String uid) {
    if (!_validId(uid)) {
      return Stream.error(const FormatException('UID invalide.'));
    }
    return firestore
        .collection('operationAccess')
        .where('uid', isEqualTo: uid)
        .where('active', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => List<OperationAccess>.unmodifiable(
            snapshot.docs.map(
              (document) =>
                  OperationAccess.fromMap(document.id, document.data()),
            ),
          ),
        );
  }
}

bool _validId(String value) =>
    value.isNotEmpty && value.trim() == value && !value.contains('/');
