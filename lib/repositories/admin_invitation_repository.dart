import '../models/admin_invitation.dart';

abstract interface class AdminInvitationRepository {
  Stream<List<AdminInvitation>> watchInvitations();

  Future<AdminInvitation?> getInvitation(String invitationId);

  Future<AdminInvitation> createInvitation(AdminInvitationDraft draft);

  Future<void> cancelInvitation(String invitationId);

  Future<AdminInvitation> updateInvitation(
    String invitationId,
    AdminInvitationUpdate update,
  );

  Future<void> reactivateInvitation(String invitationId, DateTime expiresAt);

  Future<void> deleteInvitation(String invitationId);

  Future<AdminProvisioningResult> provisionInvitation(
    String invitationId, {
    bool resend = false,
  });
}

class AdminProvisioningResult {
  const AdminProvisioningResult({
    required this.accountProvisioned,
    required this.emailDelivery,
    required this.alreadyProvisioned,
  });

  final bool accountProvisioned;
  final String emailDelivery;
  final bool alreadyProvisioned;
}
