import '../models/mobilization_context.dart';
import '../repositories/platform_read_repository.dart';

abstract interface class MobilizationContextProvider {
  Stream<String?> watchActiveMobilizationId();

  Stream<MobilizationContext?> watchContext();
}

/// Adaptateur legacy conservé jusqu’à la migration des écrans RC3.5B vers
/// [AccessibleMobilizationsProvider]. Il ne doit plus être injecté dans un
/// nouveau flux multi-mobilisations.
class CurrentMobilizationProvider implements MobilizationContextProvider {
  const CurrentMobilizationProvider({
    required PlatformReadRepository repository,
  }) : _repository = repository;

  final PlatformReadRepository _repository;

  @override
  Stream<String?> watchActiveMobilizationId() {
    return _repository.watchPlatformConfig();
  }

  @override
  Stream<MobilizationContext?> watchContext() {
    return _repository.watchActiveMobilization().map(
      (mobilization) => mobilization == null
          ? null
          : MobilizationContext.fromMobilization(mobilization),
    );
  }
}
