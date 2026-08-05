import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/app_identity.dart';
import 'dev/role_preview.dart';
import 'repositories/coordination_repository.dart';
import 'repositories/admin_invitation_repository_scope.dart';
import 'repositories/mock_coordination_repository.dart';
import 'repositories/location_administration_repository_scope.dart';
import 'repositories/repository_scope.dart';
import 'repositories/responsible_access_administration_repository_scope.dart';
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
        child: LocationAdministrationRepositoryScope(
          repository: coordinationRepository.locationAdministrationRepository,
          child: ResponsibleAccessAdministrationRepositoryScope(
            repository: coordinationRepository
                .responsibleAccessAdministrationRepository,
            child: RolePreviewScope(
              child: MaterialApp(
                title: AppIdentity.productName,
                debugShowCheckedModeBanner: false,
                locale: const Locale('fr', 'FR'),
                supportedLocales: const [Locale('fr', 'FR')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: ThemeMode.system,
                builder: AppTheme.systemSurface,
                home: AppShell(initialIndex: initialTab),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
