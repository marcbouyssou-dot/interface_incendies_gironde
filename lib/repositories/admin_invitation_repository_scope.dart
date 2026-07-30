import 'package:flutter/widgets.dart';

import 'admin_invitation_repository.dart';

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
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(AdminInvitationRepositoryScope oldWidget) =>
      !identical(repository, oldWidget.repository);
}
