import '../services/current_mobilization_provider.dart';
import '../services/accessible_mobilizations_provider.dart';
import '../services/operational_context_provider.dart';
import '../services/platform_administration_service.dart';
import 'operation_read_repository.dart';
import 'platform_actor_read_repository.dart';
import 'platform_administration_read_repository.dart';
import 'platform_read_repository.dart';

abstract interface class PlatformRuntime {
  PlatformReadRepository get platformReadRepository;

  MobilizationContextProvider get currentMobilizationProvider;

  PlatformAdministrationReadRepository get platformAdministrationReadRepository;

  PlatformAdministrationService get platformAdministrationService;
}

/// Capacités RC3.5, séparées du contrat historique pour préserver les runtimes
/// de test et les environnements qui ne les exposent pas encore.
abstract interface class MultiOperationPlatformRuntime {
  OperationReadRepository get operationReadRepository;

  AccessibleMobilizationsProvider get accessibleMobilizationsProvider;

  OperationalContextProvider get operationalContextProvider;
}

abstract interface class PlatformActorRuntime {
  PlatformActorReadRepository get platformActorReadRepository;
}

abstract interface class PlatformAccountAuthenticator {
  Future<void> signInPlatformOrResponsible({
    required String email,
    required String password,
  });
}
