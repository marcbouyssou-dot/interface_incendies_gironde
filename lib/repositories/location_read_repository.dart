import '../models/need.dart';

/// Contrat de lecture des sites opérationnels.
///
/// Il sépare la source persistée de ses projections organisationnelles et
/// prépare un futur mécanisme de partage sans l'activer dans RC4.3A.
abstract interface class LocationReadRepository {
  Stream<List<ResponsePlace>> watchLocations();
}

/// Lecture de sites déjà bornée par les identifiants du rôle Responsable.
abstract interface class ScopedLocationReadRepository
    implements LocationReadRepository {
  Stream<List<ResponsePlace>> watchLocationsForIds(Set<String> locationIds);
}

/// Source de données capable d'exécuter les lectures administratives avec
/// l'identité Firebase privilégiée et, pour une organisation explicite, avec
/// une requête Firestore bornée.
///
/// Ce contrat reste séparé de [LocationReadRepository] afin que le parcours
/// Professionnel vérifié conserve sa session volontaire RC3 et que les fakes
/// existants ne soient pas contraints d'implémenter des lectures privilégiées.
abstract interface class OrganizationLocationReadDataSource
    implements ScopedLocationReadRepository {
  Stream<List<ResponsePlace>> watchAllAdministrativeLocations();

  Stream<List<ResponsePlace>> watchLegacyAdministrativeLocations();

  Stream<List<ResponsePlace>> watchLocationsManagedByOrganization(
    String organizationId,
  );
}
