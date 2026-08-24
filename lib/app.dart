import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/app_identity.dart';
import 'dev/role_preview.dart';
import 'perspective/cross_role_perspective.dart';
import 'repositories/coordination_repository.dart';
import 'repositories/diffusion_read_repository.dart';
import 'repositories/diffusion_read_repository_scope.dart';
import 'repositories/admin_invitation_repository_scope.dart';
import 'repositories/mock_coordination_repository.dart';
import 'repositories/location_administration_repository_scope.dart';
import 'repositories/organization_read_repository.dart';
import 'repositories/organization_repository_scope.dart';
import 'repositories/repository_scope.dart';
import 'repositories/responsible_access_administration_repository_scope.dart';
import 'repositories/platform_runtime.dart';
import 'screens/app_shell.dart';
import 'services/professional_verification_service.dart';
import 'services/organization_context_controller.dart';
import 'theme/app_theme.dart';

class FireCoordinationApp extends StatelessWidget {
  const FireCoordinationApp({
    super.key,
    this.repository,
    this.initialTab = 0,
    this.useLegacyCoordinatorShellForTesting = false,
    this.professionalVerificationService,
    this.platformRuntime,
    this.organizationReadRepository,
    this.organizationContextController,
    this.initialNotificationId,
    this.diffusionReadRepository,
  });

  final CoordinationRepository? repository;
  final int initialTab;
  final ProfessionalVerificationService? professionalVerificationService;
  final PlatformRuntime? platformRuntime;
  final OrganizationReadRepository? organizationReadRepository;
  final OrganizationContextController? organizationContextController;
  final String? initialNotificationId;
  final DiffusionReadRepository? diffusionReadRepository;

  /// Explicit regression harness for screens removed from the live V5 shell.
  final bool useLegacyCoordinatorShellForTesting;

  @override
  Widget build(BuildContext context) {
    final coordinationRepository =
        repository ?? MockCoordinationRepository.instance;
    final resolvedPlatformRuntime =
        platformRuntime ??
        (coordinationRepository is PlatformRuntime
            ? coordinationRepository as PlatformRuntime
            : null);
    final resolvedOrganizationRepository =
        organizationReadRepository ??
        (resolvedPlatformRuntime is OrganizationRuntime
            ? (resolvedPlatformRuntime as OrganizationRuntime)
                  .organizationReadRepository
            : coordinationRepository is OrganizationRuntime
            ? (coordinationRepository as OrganizationRuntime)
                  .organizationReadRepository
            : const NoOrganizationReadRepository());
    return RepositoryScope(
      repository: coordinationRepository,
      child: OrganizationRepositoryScope(
        repository: resolvedOrganizationRepository,
        child: OrganizationContextBootstrap(
          repository: resolvedOrganizationRepository,
          controller: organizationContextController,
          child: AdminInvitationRepositoryScope(
            repository: coordinationRepository.adminInvitationRepository,
            child: LocationAdministrationRepositoryScope(
              repository:
                  coordinationRepository.locationAdministrationRepository,
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
                      localizationsDelegates:
                          GlobalMaterialLocalizations.delegates,
                      theme: AppTheme.light,
                      darkTheme: AppTheme.dark,
                      themeMode: ThemeMode.system,
                      builder: (context, child) => DiffusionReadRepositoryScope(
                        repository: diffusionReadRepository,
                        child: AppTheme.systemSurface(context, child),
                      ),
                      home: AppShell(
                        initialIndex: initialTab,
                        platformRuntime: resolvedPlatformRuntime,
                        professionalVerificationService:
                            professionalVerificationService ??
                            const FakeProfessionalVerificationService(),
                        useLegacyCoordinatorShellForTesting:
                            useLegacyCoordinatorShellForTesting,
                        initialNotificationId: initialNotificationId,
                      ),
                    ),
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
