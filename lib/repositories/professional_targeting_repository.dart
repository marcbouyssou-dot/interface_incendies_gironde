/// Préférence privée du Professionnel pour les sollicitations proches.
/// L'absence de point suit temporairement l'ancien opt-in tant que le serveur
/// est en mode de transition ; le ciblage géographique reste désactivé.
class ProfessionalTargetingPreference {
  const ProfessionalTargetingPreference({
    this.enabled = false,
    this.radiusKm = 20,
    this.latitude,
    this.longitude,
    this.source,
    this.geocodingProvider,
    this.geocodingPrecision,
    this.legacyOptIn = false,
  });

  static const radiusChoices = [10, 20, 30, 50];

  final bool enabled;
  final int radiusKm;
  final double? latitude;
  final double? longitude;
  final String? source;
  final String? geocodingProvider;
  final String? geocodingPrecision;

  /// Ancienne préférence encore honorée pendant la phase de transition.
  final bool legacyOptIn;

  bool get hasReferencePoint =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180 &&
      const {
        'selected_point',
        'commune_centroid',
        'device_location',
      }.contains(source);

  ProfessionalTargetingPreference withRadius(int value) =>
      ProfessionalTargetingPreference(
        enabled: enabled,
        radiusKm: value,
        latitude: latitude,
        longitude: longitude,
        source: source,
        geocodingProvider: geocodingProvider,
        geocodingPrecision: geocodingPrecision,
        legacyOptIn: legacyOptIn,
      );

  ProfessionalTargetingPreference withEnabled(bool value) =>
      ProfessionalTargetingPreference(
        enabled: value,
        radiusKm: radiusKm,
        latitude: latitude,
        longitude: longitude,
        source: source,
        geocodingProvider: geocodingProvider,
        geocodingPrecision: geocodingPrecision,
        legacyOptIn: legacyOptIn,
      );

  ProfessionalTargetingPreference withConfirmedPoint({
    required double latitude,
    required double longitude,
    required String provider,
    required String precision,
  }) => ProfessionalTargetingPreference(
    radiusKm: radiusKm,
    latitude: latitude,
    longitude: longitude,
    source: 'selected_point',
    geocodingProvider: provider,
    geocodingPrecision: precision,
  );

  ProfessionalTargetingPreference withoutPoint() =>
      ProfessionalTargetingPreference(radiusKm: radiusKm);
}

abstract interface class ProfessionalTargetingRepository {
  Stream<ProfessionalTargetingPreference> watchProfessionalTargeting();

  /// Synchronise l'intention visible avec la préférence des notifications.
  Future<void> saveProfessionalTargeting(
    ProfessionalTargetingPreference preference,
  );

  Future<void> disableLegacyProfessionalSolicitations();
}
