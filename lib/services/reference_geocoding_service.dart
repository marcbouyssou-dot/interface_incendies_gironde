/// Résultat géographique éphémère. Le libellé n'est jamais écrit dans la
/// préférence de ciblage après confirmation.
class ReferenceAddressCandidate {
  const ReferenceAddressCandidate({
    required this.displayLabel,
    required this.latitude,
    required this.longitude,
    required this.provider,
    required this.precision,
    this.providerReference,
    this.confidence,
  });

  final String displayLabel;
  final double latitude;
  final double longitude;
  final String provider;
  final String precision;
  final String? providerReference;
  final double? confidence;
}

enum ReferenceGeocodingFailure {
  invalidQuery,
  invalidSelection,
  unavailable,
  timeout,
}

class ReferenceGeocodingException implements Exception {
  const ReferenceGeocodingException(this.failure);

  final ReferenceGeocodingFailure failure;
}

abstract interface class ReferenceGeocodingService {
  Future<List<ReferenceAddressCandidate>> searchAddress(String query);

  /// Accepte seulement une proposition renvoyée par la recherche courante.
  Future<ReferenceAddressCandidate> resolveAddress(
    ReferenceAddressCandidate selection,
  );
}
