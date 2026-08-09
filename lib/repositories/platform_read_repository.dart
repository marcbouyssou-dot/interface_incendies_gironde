import '../models/mobilization.dart';
import '../models/territory.dart';

abstract interface class PlatformReadRepository {
  Stream<String?> watchPlatformConfig();

  Stream<List<Territory>> watchTerritories();

  Stream<List<Mobilization>> watchMobilizations({
    String? territoryId,
    bool includeInactive = false,
  });

  Stream<Mobilization?> watchActiveMobilization();
}
