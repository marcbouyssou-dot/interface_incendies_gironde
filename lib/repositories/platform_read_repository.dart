import '../models/mobilization.dart';
import '../models/territory.dart';

abstract interface class PlatformReadRepository {
  Stream<List<Territory>> watchTerritories();

  Stream<List<Mobilization>> watchMobilizations({String? territoryId});

  Stream<Mobilization?> watchActiveMobilization();
}
