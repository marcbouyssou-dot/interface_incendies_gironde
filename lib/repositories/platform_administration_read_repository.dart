import '../models/platform_administrator_access.dart';

abstract interface class PlatformAdministrationReadRepository {
  Stream<PlatformAdministratorAccess?> watchCurrentAdministrator();

  Stream<List<MobilizationCoordinatorAssignment>> watchMobilizationCoordinators(
    String mobilizationId,
  );

  Stream<List<ActivePlatformCoordinator>> watchActiveCoordinators();
}

class NoPlatformAdministrationReadRepository
    implements PlatformAdministrationReadRepository {
  const NoPlatformAdministrationReadRepository();

  @override
  Stream<PlatformAdministratorAccess?> watchCurrentAdministrator() =>
      Stream<PlatformAdministratorAccess?>.value(null);

  @override
  Stream<List<MobilizationCoordinatorAssignment>> watchMobilizationCoordinators(
    String mobilizationId,
  ) => Stream<List<MobilizationCoordinatorAssignment>>.value(const []);

  @override
  Stream<List<ActivePlatformCoordinator>> watchActiveCoordinators() =>
      Stream<List<ActivePlatformCoordinator>>.value(const []);
}
