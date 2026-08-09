import '../models/mobilization_context.dart';
import '../repositories/platform_read_repository.dart';

class CurrentMobilizationProvider {
  const CurrentMobilizationProvider({
    required PlatformReadRepository repository,
  }) : _repository = repository;

  final PlatformReadRepository _repository;

  Stream<String?> watchActiveMobilizationId() {
    return _repository.watchPlatformConfig();
  }

  Stream<MobilizationContext?> watchContext() {
    return _repository.watchActiveMobilization().map(
      (mobilization) => mobilization == null
          ? null
          : MobilizationContext.fromMobilization(mobilization),
    );
  }
}
