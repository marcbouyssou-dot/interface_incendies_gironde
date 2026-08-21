import 'package:flutter/widgets.dart';

import '../perspective/cross_role_perspective.dart';
import 'admin_invitation_repository.dart';
import 'read_only_preview_coordination_repository.dart';

class AdminInvitationRepositoryScope extends InheritedWidget {
  const AdminInvitationRepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final AdminInvitationRepository repository;

  static AdminInvitationRepository of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AdminInvitationRepositoryScope>();
    assert(scope != null, 'AdminInvitationRepositoryScope absent de l’arbre');
    final repository = scope!.repository;
    return CrossRolePerspectiveScope.maybeOf(context)?.operationContext == null
        ? repository
        : ReadOnlyPreviewAdminInvitationRepository(repository);
  }

  @override
  bool updateShouldNotify(AdminInvitationRepositoryScope oldWidget) =>
      !identical(repository, oldWidget.repository);
}
