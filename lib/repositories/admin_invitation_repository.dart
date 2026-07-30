import '../models/admin_invitation.dart';

abstract interface class AdminInvitationRepository {
  Stream<List<AdminInvitation>> watchInvitations();

  Future<AdminInvitation?> getInvitation(String invitationId);

  Future<AdminInvitation> createInvitation(AdminInvitationDraft draft);

  Future<void> cancelInvitation(String invitationId);

  Future<AdminProvisioningResult> provisionInvitation(String invitationId);
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
