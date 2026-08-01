import '../models/admin_location.dart';

abstract interface class LocationAdministrationRepository {
  Future<List<AdminLocation>> listLocations();

  Future<AdminLocation> createLocation(AdminLocationDraft draft);

  Future<AdminLocation> updateLocation(AdminLocationDraft draft);

  Future<AdminLocation> setLocationActive({
    required String locationId,
    required bool active,
  });

  Future<void> deleteLocation(String locationId);
}

class LocationAdministrationException implements Exception {
  const LocationAdministrationException(this.message);

  final String message;

  @override
  String toString() => message;
}
