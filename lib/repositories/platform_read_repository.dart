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

/// Lecture des mobilisations actives utilisée par le parcours Responsable.
///
/// Contrairement à [PlatformReadRepository.watchMobilizations], ce contrat
/// garantit que le périmètre legacy peut être résolu sans requête de collection
/// globale sur les opérations ou les mobilisations.
abstract interface class ResponsibleMobilizationReadRepository {
  Stream<List<Mobilization>> watchResponsibleActiveMobilizations();
}
