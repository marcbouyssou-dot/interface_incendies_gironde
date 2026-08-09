import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/app_identity.dart';
import 'dev/role_preview.dart';
import 'perspective/cross_role_perspective.dart';
import 'repositories/coordination_repository.dart';
import 'repositories/admin_invitation_repository_scope.dart';
import 'repositories/mock_coordination_repository.dart';
import 'repositories/location_administration_repository_scope.dart';
import 'repositories/repository_scope.dart';
import 'repositories/responsible_access_administration_repository_scope.dart';
import 'screens/app_shell.dart';
import 'services/professional_verification_service.dart';
import 'theme/app_theme.dart';

class FireCoordinationApp extends StatelessWidget {
  const FireCoordinationApp({
    super.key,
    this.repository,
    this.initialTab = 0,
    this.useLegacyCoordinatorShellForTesting = false,
    this.professionalVerificationService,
  });

  final CoordinationRepository? repository;
  final int initialTab;
  final ProfessionalVerificationService? professionalVerificationService;

  /// Explicit regression harness for screens removed from the live V5 shell.
  final bool useLegacyCoordinatorShellForTesting;

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
            child: CrossRolePerspectiveScope(
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
                  home: AppShell(
                    initialIndex: initialTab,
                    professionalVerificationService:
                        professionalVerificationService ??
                        const FakeProfessionalVerificationService(),
                    useLegacyCoordinatorShellForTesting:
                        useLegacyCoordinatorShellForTesting,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
