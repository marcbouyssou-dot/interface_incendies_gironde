import 'dart:async';

import '../models/admin_invitation.dart';
import 'admin_invitation_repository.dart';

class MockAdminInvitationRepository implements AdminInvitationRepository {
  MockAdminInvitationRepository({
    this.coordinatorUid = 'mock-coordinator',
    List<AdminInvitation> initialInvitations = const [],
    DateTime Function()? now,
  }) : _invitations = {
         for (final invitation in initialInvitations) invitation.id: invitation,
       },
       _now = now ?? DateTime.now;

  final String coordinatorUid;
  final DateTime Function() _now;
  final Map<String, AdminInvitation> _invitations;
  final StreamController<List<AdminInvitation>> _updates =
      StreamController<List<AdminInvitation>>.broadcast(sync: true);
  int _nextId = 1;

  @override
  Stream<List<AdminInvitation>> watchInvitations() async* {
    yield _sortedInvitations();
    yield* _updates.stream;
  }

  @override
  Future<AdminInvitation?> getInvitation(String invitationId) async {
    return _invitations[invitationId];
  }

  @override
  Future<AdminInvitation> createInvitation(AdminInvitationDraft draft) async {
    final createdAt = _now();
    draft.validate(now: createdAt);
    final role = draft.role;
    final locationIds = draft.locationIds;
    final invitation = AdminInvitation(
      id: 'mock-invitation-${_nextId++}',
      email: draft.email,
      displayName: draft.displayName,
      role: role,
      locationIds: Set<String>.unmodifiable(locationIds),
      createdBy: coordinatorUid,
      createdAt: createdAt,
      expiresAt: draft.expiresAt,
      status: AdminInvitationStatus.pending,
    );
    _invitations[invitation.id] = invitation;
    _emit();
    return invitation;
  }

  @override
  Future<void> cancelInvitation(String invitationId) async {
    final invitation = _invitations[invitationId];
    if (invitation == null) {
      throw StateError('Invitation introuvable.');
    }
    if (!invitation.isPending) {
      throw StateError('Seule une invitation en attente peut être annulée.');
    }
    _invitations[invitationId] = invitation.copyWith(
      status: AdminInvitationStatus.cancelled,
    );
    _emit();
  }

  @override
  Future<AdminInvitation> updateInvitation(
    String invitationId,
    AdminInvitationUpdate update,
  ) async {
    update.validate();
    final invitation = _invitations[invitationId];
    if (invitation == null) throw StateError('Invitation introuvable.');
    if (invitation.acceptedAt != null ||
        !{
          AdminInvitationStatus.pending,
          AdminInvitationStatus.cancelled,
        }.contains(invitation.status)) {
      throw StateError('Cette invitation ne peut plus être modifiée.');
    }
    final updated = invitation.copyWith(
      displayName: update.displayName,
      role: update.role,
      locationIds: Set<String>.unmodifiable(update.locationIds),
    );
    _invitations[invitationId] = updated;
    _emit();
    return updated;
  }

  @override
  Future<void> reactivateInvitation(
    String invitationId,
    DateTime expiresAt,
  ) async {
    final invitation = _invitations[invitationId];
    if (invitation == null) throw StateError('Invitation introuvable.');
    if (invitation.acceptedAt != null ||
        invitation.status != AdminInvitationStatus.cancelled ||
        !expiresAt.isAfter(_now())) {
      throw StateError('Cette invitation ne peut pas être réactivée.');
    }
    _invitations[invitationId] = invitation.copyWith(
      status: AdminInvitationStatus.pending,
      expiresAt: expiresAt,
    );
    _emit();
  }

  @override
  Future<void> deleteInvitation(String invitationId) async {
    final invitation = _invitations[invitationId];
    if (invitation == null) throw StateError('Invitation introuvable.');
    if (!invitation.isUnused) {
      throw StateError('Cette invitation ne peut pas être supprimée.');
    }
    _invitations.remove(invitationId);
    _emit();
  }

  @override
  Future<AdminProvisioningResult> provisionInvitation(
    String invitationId, {
    bool resend = false,
  }) async {
    final invitation = _invitations[invitationId];
    if (invitation == null) throw StateError('Invitation introuvable.');
    if (invitation.status == AdminInvitationStatus.accepted) {
      if (resend) {
        final resentAt = _now();
        _invitations[invitationId] = invitation.copyWith(
          activationLinkGeneratedAt: resentAt,
        );
        _emit();
      }
      return const AdminProvisioningResult(
        accountProvisioned: true,
        emailDelivery: 'pending',
        alreadyProvisioned: true,
      );
    }
    if (!invitation.isPending || invitation.isExpired) {
      throw StateError('Cette invitation ne peut pas être préparée.');
    }
    final provisionedAt = _now();
    _invitations[invitationId] = invitation.copyWith(
      status: AdminInvitationStatus.accepted,
      acceptedAt: provisionedAt,
      acceptedUid: 'mock-admin-$invitationId',
      provisionedAt: provisionedAt,
      activationLinkGeneratedAt: provisionedAt,
    );
    _emit();
    return const AdminProvisioningResult(
      accountProvisioned: true,
      emailDelivery: 'pending',
      alreadyProvisioned: false,
    );
  }

  Future<void> dispose() => _updates.close();

  void _emit() => _updates.add(_sortedInvitations());

  List<AdminInvitation> _sortedInvitations() {
    final result = _invitations.values
        .where((invitation) => invitation.isUnused)
        .toList();
    result.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return result;
  }
}
