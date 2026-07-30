import 'package:flutter/material.dart';

import 'repositories/coordination_repository.dart';
import 'repositories/admin_invitation_repository_scope.dart';
import 'repositories/mock_coordination_repository.dart';
import 'repositories/repository_scope.dart';
import 'screens/app_shell.dart';
import 'theme/app_theme.dart';

class FireCoordinationApp extends StatelessWidget {
  const FireCoordinationApp({super.key, this.repository, this.initialTab = 0});

  final CoordinationRepository? repository;
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final coordinationRepository =
        repository ?? MockCoordinationRepository.instance;
    return RepositoryScope(
      repository: coordinationRepository,
      child: AdminInvitationRepositoryScope(
        repository: coordinationRepository.adminInvitationRepository,
        child: MaterialApp(
          title: 'Interface Récup',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: AppShell(initialIndex: initialTab),
        ),
      ),
    );
  }
}
