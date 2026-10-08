import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/operation.dart';

/// Synthetic records are historical display data, never authenticated users.
class DemoActor {
  const DemoActor({
    required this.id,
    required this.operationId,
    required this.label,
    required this.roles,
    required this.professions,
    required this.historicalSiteIds,
  });

  final String id;
  final String operationId;
  final String label;
  final List<String> roles;
  final List<String> professions;
  final List<String> historicalSiteIds;

  factory DemoActor.fromMap(String documentId, Map<String, Object?> data) {
    if (data['id'] != documentId) {
      throw const FormatException('Acteur fictif incohérent.');
    }
    return DemoActor(
      id: documentId,
      operationId: _text(data, 'operationId'),
      label: _text(data, 'label'),
      roles: _strings(data, 'roles'),
      professions: _strings(data, 'professions'),
      historicalSiteIds: _strings(data, 'historicalSiteIds'),
    );
  }
}

class DemoEngagement {
  const DemoEngagement({
    required this.id,
    required this.operationId,
    required this.actorId,
    required this.missionId,
    required this.locationId,
    required this.profession,
    required this.status,
    required this.statusKnown,
  });

  final String id;
  final String operationId;
  final String actorId;
  final String missionId;
  final String locationId;
  final String profession;
  final String status;
  final bool statusKnown;

  factory DemoEngagement.fromMap(String documentId, Map<String, Object?> data) {
    if (data['id'] != documentId || data['statusKnown'] is! bool) {
      throw const FormatException('Engagement fictif incohérent.');
    }
    final status = _text(data, 'status');
    final known = data['statusKnown'] as bool;
    if ((status == 'unknown') == known) {
      throw const FormatException('Statut fictif incohérent.');
    }
    return DemoEngagement(
      id: documentId,
      operationId: _text(data, 'operationId'),
      actorId: _text(data, 'actorId'),
      missionId: _text(data, 'missionId'),
      locationId: _text(data, 'locationId'),
      profession: _text(data, 'profession'),
      status: status,
      statusKnown: known,
    );
  }
}

class DemoHistory {
  const DemoHistory({required this.actors, required this.engagements});

  final List<DemoActor> actors;
  final List<DemoEngagement> engagements;
}

abstract interface class DemoHistoryReadRepository {
  Future<DemoHistory> readHistory(String operationId);
}

class FirestoreDemoHistoryReadRepository implements DemoHistoryReadRepository {
  const FirestoreDemoHistoryReadRepository(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<DemoHistory> readHistory(String operationId) async {
    if (!_validId(operationId)) {
      throw const FormatException('Identifiant d’Action invalide.');
    }
    final operationSnapshot = await firestore
        .collection('operations')
        .doc(operationId)
        .get();
    final operation = operationSnapshot.data();
    if (operation == null ||
        operation['id'] != operationId ||
        operation['purpose'] != OperationPurpose.demonstration.name ||
        !['completed', 'archived'].contains(operation['status'])) {
      throw const FormatException('Historique de démonstration indisponible.');
    }
    final actorsSnapshot = await firestore
        .collection('demoActors')
        .where('operationId', isEqualTo: operationId)
        .get();
    final engagementsSnapshot = await firestore
        .collection('demoEngagements')
        .where('operationId', isEqualTo: operationId)
        .get();
    final actors = actorsSnapshot.docs
        .map((doc) => DemoActor.fromMap(doc.id, doc.data()))
        .toList(growable: false);
    final engagements = engagementsSnapshot.docs
        .map((doc) => DemoEngagement.fromMap(doc.id, doc.data()))
        .toList(growable: false);
    if (actors.any((actor) => actor.operationId != operationId) ||
        engagements.any(
          (engagement) => engagement.operationId != operationId,
        )) {
      throw const FormatException('Historique fictif hors Action.');
    }
    final actorIds = actors.map((actor) => actor.id).toSet();
    if (engagements.any(
      (engagement) => !actorIds.contains(engagement.actorId),
    )) {
      throw const FormatException('Engagement fictif sans acteur.');
    }
    actors.sort((a, b) => a.label.compareTo(b.label));
    engagements.sort((a, b) => a.id.compareTo(b.id));
    return DemoHistory(
      actors: List.unmodifiable(actors),
      engagements: List.unmodifiable(engagements),
    );
  }
}

String _text(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! String || value.trim().isEmpty || value.trim() != value) {
    throw const FormatException('Donnée fictive invalide.');
  }
  return value;
}

List<String> _strings(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException('Liste fictive invalide.');
  }
  final strings = value.cast<String>();
  if (strings.any((item) => !_validId(item)) ||
      strings.toSet().length != strings.length) {
    throw const FormatException('Liste fictive invalide.');
  }
  return List.unmodifiable(strings);
}

bool _validId(String value) =>
    value.isNotEmpty && value.trim() == value && !value.contains('/');
