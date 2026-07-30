import '../models/admin_invitation.dart';

abstract interface class AdminInvitationRepository {
  Stream<List<AdminInvitation>> watchInvitations();

  Future<AdminInvitation?> getInvitation(String invitationId);

  Future<AdminInvitation> createInvitation(AdminInvitationDraft draft);

  Future<void> cancelInvitation(String invitationId);
}
