import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/organization.dart';
import '../models/organization_membership.dart';

/// Convertit les documents Firestore du domaine Organisation sans exposer
/// Firestore aux modèles métier.
///
/// Les champs inconnus restent dans la copie de travail puis sont ignorés par
/// les modèles de domaine. Cela permet une évolution additive du schéma sans
/// rendre les anciennes versions du client incompatibles.
abstract final class FirestoreOrganizationMapper {
  static Organization organizationFromFirestore({
    required String documentId,
    required Map<String, Object?> data,
  }) {
    final mapped = Map<String, Object?>.of(data);
    final embeddedId = mapped['id'];
    if (embeddedId != null && embeddedId != documentId) {
      throw const FormatException("Identifiant d'organisation incohérent.");
    }
    mapped['id'] = documentId;
    _mapDates(mapped, entity: 'organisation');
    return Organization.fromMap(mapped);
  }

  static OrganizationMembership membershipFromFirestore({
    required Map<String, Object?> data,
  }) {
    final mapped = Map<String, Object?>.of(data);
    _mapDates(mapped, entity: 'appartenance');
    return OrganizationMembership.fromMap(mapped);
  }

  static void _mapDates(Map<String, Object?> data, {required String entity}) {
    for (final field in const ['createdAt', 'updatedAt']) {
      final value = data[field];
      if (value is Timestamp) {
        data[field] = value.toDate();
      } else if (value is! DateTime) {
        throw FormatException('Date $entity invalide : $field.');
      }
    }
  }
}
