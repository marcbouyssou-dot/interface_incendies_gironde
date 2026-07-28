import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'repositories/coordination_repository.dart';
import 'repositories/mock_coordination_repository.dart';
import 'repositories/repository_scope.dart';
import 'theme/app_theme.dart';

class FireCoordinationApp extends StatelessWidget {
  const FireCoordinationApp({super.key, this.repository});

  final CoordinationRepository? repository;

  @override
  Widget build(BuildContext context) {
    return RepositoryScope(
      repository: repository ?? MockCoordinationRepository.instance,
      child: MaterialApp(
        title: 'InterfaceRecup33',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AppShell(),
      ),
    );
  }
}
