import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/admin_invitation.dart';
import 'admin_invitation_repository.dart';

abstract interface class AdminInvitationFirestoreDataSource {
  String? get currentUserId;

  Object serverTimestamp();

  Object timestampFromDate(DateTime value);

  Stream<List<AdminInvitationDocument>> watchDocuments();

  Future<AdminInvitationDocument?> getDocument(String id);

  Future<Map<String, Object?>?> getCurrentRole();

  Future<String> addDocument(Map<String, Object?> data);

  Future<void> updateDocument(String id, Map<String, Object?> data);
}

class AdminInvitationDocument {
  const AdminInvitationDocument({required this.id, required this.data});

  final String id;
  final Map<String, Object?> data;
}

class FirestoreAdminInvitationDataSource
    implements AdminInvitationFirestoreDataSource {
  FirestoreAdminInvitationDataSource(this.firestore, this.auth);

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  @override
  String? get currentUserId => auth.currentUser?.uid;

  @override
  Object serverTimestamp() => FieldValue.serverTimestamp();

  @override
  Object timestampFromDate(DateTime value) => Timestamp.fromDate(value);

  @override
  Stream<List<AdminInvitationDocument>> watchDocuments() {
    return firestore
        .collection('adminInvitations')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => AdminInvitationDocument(
                  id: document.id,
                  data: document.data(),
                ),
              )
              .toList(),
        );
  }

  @override
  Future<AdminInvitationDocument?> getDocument(String id) async {
    final document = await firestore
        .collection('adminInvitations')
        .doc(id)
        .get();
    final data = document.data();
    if (!document.exists || data == null) return null;
    return AdminInvitationDocument(id: document.id, data: data);
  }

  @override
  Future<Map<String, Object?>?> getCurrentRole() async {
    final uid = currentUserId;
    if (uid == null) return null;
    return (await firestore.collection('roles').doc(uid).get()).data();
  }

  @override
  Future<String> addDocument(Map<String, Object?> data) async {
    return (await firestore.collection('adminInvitations').add(data)).id;
  }

  @override
  Future<void> updateDocument(String id, Map<String, Object?> data) {
    return firestore.collection('adminInvitations').doc(id).update(data);
  }
}

class FirestoreAdminInvitationRepository implements AdminInvitationRepository {
  FirestoreAdminInvitationRepository({
    required AdminInvitationFirestoreDataSource dataSource,
    DateTime Function()? now,
  }) : _dataSource = dataSource,
       _now = now ?? DateTime.now;

  factory FirestoreAdminInvitationRepository.withFirebase({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) {
    return FirestoreAdminInvitationRepository(
      dataSource: FirestoreAdminInvitationDataSource(firestore, auth),
    );
  }

  final AdminInvitationFirestoreDataSource _dataSource;
  final DateTime Function() _now;

  @override
  Stream<List<AdminInvitation>> watchInvitations() {
    return _dataSource.watchDocuments().map((documents) {
      final invitations = documents.map(_fromDocument).toList();
      invitations.sort(
        (left, right) => right.createdAt.compareTo(left.createdAt),
      );
      return invitations;
    });
  }

  @override
  Future<AdminInvitation?> getInvitation(String invitationId) async {
    await _requireCoordinator();
    final document = await _dataSource.getDocument(invitationId);
    return document == null ? null : _fromDocument(document);
  }

  @override
  Future<AdminInvitation> createInvitation(AdminInvitationDraft draft) async {
    final uid = await _requireCoordinator();
    final createdAt = _now();
    draft.validate(now: createdAt);
    final id = await _dataSource.addDocument({
      'email': draft.email,
      'displayName': draft.displayName,
      'role': draft.role,
      'locationIds': draft.locationIds.toList()..sort(),
      'createdBy': uid,
      'createdAt': _dataSource.serverTimestamp(),
      'expiresAt': _dataSource.timestampFromDate(draft.expiresAt),
      'status': AdminInvitationStatus.pending.firestoreValue,
      'acceptedAt': null,
    });
    return AdminInvitation(
      id: id,
      email: draft.email,
      displayName: draft.displayName,
      role: draft.role,
      locationIds: draft.locationIds,
      createdBy: uid,
      createdAt: createdAt,
      expiresAt: draft.expiresAt,
      status: AdminInvitationStatus.pending,
    );
  }

  @override
  Future<void> cancelInvitation(String invitationId) async {
    await _requireCoordinator();
    final document = await _dataSource.getDocument(invitationId);
    if (document == null) throw StateError('Invitation introuvable.');
    final invitation = _fromDocument(document);
    if (!invitation.isPending) {
      throw StateError('Seule une invitation en attente peut être annulée.');
    }
    await _dataSource.updateDocument(invitationId, {
      'status': AdminInvitationStatus.cancelled.firestoreValue,
    });
  }

  Future<String> _requireCoordinator() async {
    final uid = _dataSource.currentUserId;
    if (uid == null) throw StateError('Session responsable requise.');
    final role = await _dataSource.getCurrentRole();
    if (role?['active'] != true || role?['role'] != 'coordinator') {
      throw StateError('Accès coordinateur requis.');
    }
    return uid;
  }

  AdminInvitation _fromDocument(AdminInvitationDocument document) {
    final data = document.data;
    return AdminInvitation(
      id: document.id,
      email: _requiredString(data, 'email'),
      displayName: _requiredString(data, 'displayName'),
      role: _requiredString(data, 'role'),
      locationIds: Set<String>.from(data['locationIds'] as List? ?? const []),
      createdBy: _requiredString(data, 'createdBy'),
      createdAt: _dateTime(data['createdAt'], 'createdAt'),
      expiresAt: _dateTime(data['expiresAt'], 'expiresAt'),
      status: adminInvitationStatusFromValue(data['status']),
      acceptedAt: data['acceptedAt'] == null
          ? null
          : _dateTime(data['acceptedAt'], 'acceptedAt'),
    );
  }
}

String _requiredString(Map<String, Object?> data, String field) {
  final value = data[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Champ d’invitation invalide : $field.');
  }
  return value;
}

DateTime _dateTime(Object? value, String field) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  throw FormatException('Date d’invitation invalide : $field.');
}
