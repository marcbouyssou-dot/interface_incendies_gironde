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

/// Lecture unitaire (`get`) d'une mobilisation, sans requête de collection.
///
/// Un Coordinateur affecté peut lire ses mobilisations une à une, mais les
/// règles ne lui ouvrent pas le `list` global de `mobilizations`.
abstract interface class MobilizationLookupRepository {
  /// Émet la mobilisation lisible, ou `null` lorsqu'elle est absente ou n'est
  /// pas lisible pour l'identité courante.
  Stream<Mobilization?> watchMobilization(String mobilizationId);
}

/// Lecture des mobilisations actives utilisée par le parcours Responsable.
///
/// Contrairement à [PlatformReadRepository.watchMobilizations], ce contrat
/// garantit que le périmètre legacy peut être résolu sans requête de collection
/// globale sur les opérations ou les mobilisations.
abstract interface class ResponsibleMobilizationReadRepository {
  Stream<List<Mobilization>> watchResponsibleActiveMobilizations();
}
