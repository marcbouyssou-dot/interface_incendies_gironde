import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/organization.dart';
import '../models/organization_membership.dart';
import 'firestore_organization_mapper.dart';
import 'organization_read_repository.dart';

const organizationDocumentWhereInLimit = 30;

List<List<String>> boundedOrganizationDocumentIdBatches(
  Iterable<String> values,
) {
  final ids = values.toSet().toList(growable: false)..sort();
  return [
    for (
      var start = 0;
      start < ids.length;
      start += organizationDocumentWhereInLimit
    )
      List<String>.unmodifiable(
        ids.skip(start).take(organizationDocumentWhereInLimit),
      ),
  ];
}

/// Copie immutable minimale d'un document nécessaire au repository.
///
/// Cette frontière rend la logique de lecture testable sans émulateur et évite
/// que les types Firestore se propagent dans le domaine.
class OrganizationFirestoreDocument {
  OrganizationFirestoreDocument({
    required this.id,
    required Map<String, Object?> data,
  }) : data = Map<String, Object?>.unmodifiable(data);

  final String id;
  final Map<String, Object?> data;
}

/// Source de documents injectable utilisée par le repository Organisation.
abstract interface class OrganizationFirestoreDataSource {
  Stream<OrganizationFirestoreDocument?> watchOrganizationDocument(
    String organizationId,
  );

  Stream<List<OrganizationFirestoreDocument>> watchOrganizationDocumentsByIds(
    Set<String> organizationIds,
  );

  Stream<List<OrganizationFirestoreDocument>> watchMembershipDocumentsForUser(
    String uid,
  );

  Stream<List<OrganizationFirestoreDocument>> watchMembershipDocuments({
    required String organizationId,
    required String uid,
  });
}

/// Source Firestore réelle, exclusivement composée de lectures bornées.
class FirestoreOrganizationDataSource
    implements OrganizationFirestoreDataSource {
  const FirestoreOrganizationDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<OrganizationFirestoreDocument?> watchOrganizationDocument(
    String organizationId,
  ) => _firestore
      .collection('organizations')
      .doc(organizationId)
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data();
        return !snapshot.exists || data == null
            ? null
            : OrganizationFirestoreDocument(id: snapshot.id, data: data);
      });

  @override
  Stream<List<OrganizationFirestoreDocument>> watchOrganizationDocumentsByIds(
    Set<String> organizationIds,
  ) {
    final batches = boundedOrganizationDocumentIdBatches(organizationIds);
    if (batches.isEmpty) {
      return Stream<List<OrganizationFirestoreDocument>>.value(const []);
    }
    final streams = <Stream<List<OrganizationFirestoreDocument>>>[];
    for (final batch in batches) {
      streams.add(
        _firestore
            .collection('organizations')
            .where(FieldPath.documentId, whereIn: batch)
            .snapshots()
            .map(_documentsFromSnapshot),
      );
    }
    return streams.length == 1
        ? streams.single
        : _combineLatestDocumentBatches(streams);
  }

  @override
  Stream<List<OrganizationFirestoreDocument>> watchMembershipDocumentsForUser(
    String uid,
  ) => _firestore
      .collection('organizationMemberships')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map(_documentsFromSnapshot);

  @override
  Stream<List<OrganizationFirestoreDocument>> watchMembershipDocuments({
    required String organizationId,
    required String uid,
  }) => _firestore
      .collection('organizationMemberships')
      .where('organizationId', isEqualTo: organizationId)
      .where('uid', isEqualTo: uid)
      .limit(2)
      .snapshots()
      .map(_documentsFromSnapshot);

  List<OrganizationFirestoreDocument> _documentsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => List<OrganizationFirestoreDocument>.unmodifiable(
    snapshot.docs.map(
      (document) =>
          OrganizationFirestoreDocument(id: document.id, data: document.data()),
    ),
  );
}

/// Implémentation Firestore du contrat de lecture Organisation.
///
/// Elle n'est volontairement pas branchée aux scopes RC3. Une future couche de
/// composition pourra l'injecter sans modifier les écrans ni le contrat.
class FirestoreOrganizationReadRepository
    implements OrganizationReadRepository {
  const FirestoreOrganizationReadRepository(this._dataSource);

  factory FirestoreOrganizationReadRepository.withFirestore(
    FirebaseFirestore firestore,
  ) => FirestoreOrganizationReadRepository(
    FirestoreOrganizationDataSource(firestore),
  );

  final OrganizationFirestoreDataSource _dataSource;

  @override
  Stream<List<Organization>> watchAccessibleOrganizations({
    required String uid,
  }) {
    _validateUid(uid);
    return _switchLatestOrganizationStream(watchMembershipsForUser(uid), (
      memberships,
    ) {
      final organizationIds = memberships
          .where((membership) => membership.active)
          .map((membership) => membership.organizationId)
          .toSet();
      return _dataSource.watchOrganizationDocumentsByIds(organizationIds).map((
        documents,
      ) {
        if (documents.any(
          (document) => !organizationIds.contains(document.id),
        )) {
          throw const FormatException('Organisation accessible incohérente.');
        }
        final organizations = documents
            .map(_organizationFromDocument)
            .where((organization) => organization.active)
            .toList(growable: false);
        organizations.sort((left, right) {
          final byName = left.name.compareTo(right.name);
          return byName != 0 ? byName : left.id.compareTo(right.id);
        });
        return List<Organization>.unmodifiable(organizations);
      });
    });
  }

  @override
  Stream<Organization?> watchOrganization(String organizationId) {
    _validateOrganizationId(organizationId);
    return _dataSource
        .watchOrganizationDocument(organizationId)
        .map(
          (document) =>
              document == null ? null : _organizationFromDocument(document),
        );
  }

  @override
  Stream<List<OrganizationMembership>> watchMembershipsForUser(String uid) {
    _validateUid(uid);
    return _dataSource.watchMembershipDocumentsForUser(uid).map((documents) {
      final memberships = documents
          .map(_membershipFromDocument)
          .where((membership) => membership.uid == uid)
          .toList(growable: false);
      if (memberships.length != documents.length) {
        throw const FormatException('Appartenance utilisateur incohérente.');
      }
      final organizationIds = memberships
          .map((membership) => membership.organizationId)
          .toSet();
      if (organizationIds.length != memberships.length) {
        throw const FormatException('Appartenance dupliquée.');
      }
      memberships.sort(
        (left, right) => left.organizationId.compareTo(right.organizationId),
      );
      return List<OrganizationMembership>.unmodifiable(memberships);
    });
  }

  @override
  Stream<OrganizationMembership?> watchMembership({
    required String organizationId,
    required String uid,
  }) {
    _validateOrganizationId(organizationId);
    _validateUid(uid);
    return _dataSource
        .watchMembershipDocuments(organizationId: organizationId, uid: uid)
        .map((documents) {
          if (documents.length > 1) {
            throw const FormatException('Appartenance dupliquée.');
          }
          if (documents.isEmpty) return null;
          final membership = _membershipFromDocument(documents.single);
          if (membership.organizationId != organizationId ||
              membership.uid != uid) {
            throw const FormatException('Appartenance incohérente.');
          }
          return membership;
        });
  }

  Organization _organizationFromDocument(
    OrganizationFirestoreDocument document,
  ) => FirestoreOrganizationMapper.organizationFromFirestore(
    documentId: document.id,
    data: document.data,
  );

  OrganizationMembership _membershipFromDocument(
    OrganizationFirestoreDocument document,
  ) => FirestoreOrganizationMapper.membershipFromFirestore(data: document.data);
}

Stream<R> _switchLatestOrganizationStream<T, R>(
  Stream<T> source,
  Stream<R> Function(T value) follow,
) {
  late StreamController<R> controller;
  StreamSubscription<T>? sourceSubscription;
  StreamSubscription<R>? innerSubscription;
  var revision = 0;
  var switching = 0;
  var sourceDone = false;

  void closeIfComplete() {
    if (sourceDone &&
        switching == 0 &&
        innerSubscription == null &&
        !controller.isClosed) {
      controller.close();
    }
  }

  Future<void> switchTo(T value) async {
    final currentRevision = ++revision;
    switching += 1;
    final previous = innerSubscription;
    innerSubscription = null;
    if (previous != null) await previous.cancel();
    if (currentRevision == revision && !controller.isClosed) {
      late StreamSubscription<R> next;
      next = follow(value).listen(
        controller.add,
        onError: controller.addError,
        onDone: () {
          if (identical(innerSubscription, next)) {
            innerSubscription = null;
            closeIfComplete();
          }
        },
      );
      innerSubscription = next;
    }
    switching -= 1;
    closeIfComplete();
  }

  controller = StreamController<R>(
    onListen: () {
      sourceSubscription = source.listen(
        (value) => unawaited(switchTo(value)),
        onError: controller.addError,
        onDone: () {
          sourceDone = true;
          closeIfComplete();
        },
      );
    },
    onPause: () {
      sourceSubscription?.pause();
      innerSubscription?.pause();
    },
    onResume: () {
      sourceSubscription?.resume();
      innerSubscription?.resume();
    },
    onCancel: () async {
      revision += 1;
      await sourceSubscription?.cancel();
      await innerSubscription?.cancel();
    },
  );
  return controller.stream;
}

Stream<List<OrganizationFirestoreDocument>> _combineLatestDocumentBatches(
  List<Stream<List<OrganizationFirestoreDocument>>> sources,
) {
  late StreamController<List<OrganizationFirestoreDocument>> controller;
  final subscriptions =
      <StreamSubscription<List<OrganizationFirestoreDocument>>>[];
  final latest = List<List<OrganizationFirestoreDocument>?>.filled(
    sources.length,
    null,
  );
  var completed = 0;

  void emitIfComplete() {
    if (latest.any((documents) => documents == null) || controller.isClosed) {
      return;
    }
    final byId = <String, OrganizationFirestoreDocument>{};
    for (final documents in latest) {
      for (final document in documents!) {
        byId[document.id] = document;
      }
    }
    controller.add(
      List<OrganizationFirestoreDocument>.unmodifiable(byId.values),
    );
  }

  controller = StreamController<List<OrganizationFirestoreDocument>>(
    onListen: () {
      for (var index = 0; index < sources.length; index++) {
        subscriptions.add(
          sources[index].listen(
            (documents) {
              latest[index] = documents;
              emitIfComplete();
            },
            onError: controller.addError,
            onDone: () {
              completed += 1;
              if (completed == sources.length && !controller.isClosed) {
                controller.close();
              }
            },
          ),
        );
      }
    },
    onPause: () {
      for (final subscription in subscriptions) {
        subscription.pause();
      }
    },
    onResume: () {
      for (final subscription in subscriptions) {
        subscription.resume();
      }
    },
    onCancel: () =>
        Future.wait(subscriptions.map((subscription) => subscription.cancel())),
  );
  return controller.stream;
}

void _validateOrganizationId(String value) {
  if (value.trim().isEmpty ||
      value.trim() != value ||
      value.length > 160 ||
      value.contains('/')) {
    throw const FormatException("Identifiant d'organisation invalide.");
  }
}

void _validateUid(String value) {
  if (value.trim().isEmpty ||
      value.trim() != value ||
      value.length > 128 ||
      value.contains('/')) {
    throw const FormatException('UID organisationnel invalide.');
  }
}
