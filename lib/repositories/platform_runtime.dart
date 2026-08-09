import '../services/current_mobilization_provider.dart';
import '../services/platform_administration_service.dart';
import 'platform_administration_read_repository.dart';
import 'platform_read_repository.dart';

abstract interface class PlatformRuntime {
  PlatformReadRepository get platformReadRepository;

  MobilizationContextProvider get currentMobilizationProvider;

  PlatformAdministrationReadRepository get platformAdministrationReadRepository;

  PlatformAdministrationService get platformAdministrationService;
}

abstract interface class PlatformAccountAuthenticator {
  Future<void> signInPlatformOrResponsible({
    required String email,
    required String password,
  });
}
