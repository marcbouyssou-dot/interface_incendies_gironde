import '../models/mobilization.dart';

class MobilizationAdministrationDraft {
  const MobilizationAdministrationDraft({
    required this.mobilizationId,
    required this.territoryId,
    required this.name,
    required this.subtitle,
    required this.contextType,
  });

  final String mobilizationId;
  final String territoryId;
  final String name;
  final String subtitle;
  final MobilizationContextType contextType;

  Map<String, Object?> toCallableData() => {
    'mobilizationId': mobilizationId,
    'territoryId': territoryId,
    'name': name.trim(),
    'subtitle': subtitle.trim(),
    'contextType': contextType.serializedValue,
  };
}

abstract interface class PlatformAdministrationService {
  bool get isAvailable;

  Future<void> createMobilization(MobilizationAdministrationDraft draft);

  Future<void> updateMobilization(MobilizationAdministrationDraft draft);

  Future<void> activateMobilization(String mobilizationId);

  Future<void> deactivateMobilization(String mobilizationId);

  Future<void> archiveMobilization(String mobilizationId);

  Future<void> assignMobilizationCoordinator({
    required String mobilizationId,
    required String uid,
  });

  Future<void> removeMobilizationCoordinator({
    required String mobilizationId,
    required String uid,
  });
}

class NoPlatformAdministrationService implements PlatformAdministrationService {
  const NoPlatformAdministrationService();

  @override
  bool get isAvailable => false;

  Never _unavailable() => throw const PlatformAdministrationException(
    'Les actions d’administration ne sont pas disponibles.',
  );

  @override
  Future<void> activateMobilization(String mobilizationId) async =>
      _unavailable();

  @override
  Future<void> archiveMobilization(String mobilizationId) async =>
      _unavailable();

  @override
  Future<void> assignMobilizationCoordinator({
    required String mobilizationId,
    required String uid,
  }) async => _unavailable();

  @override
  Future<void> createMobilization(
    MobilizationAdministrationDraft draft,
  ) async => _unavailable();

  @override
  Future<void> deactivateMobilization(String mobilizationId) async =>
      _unavailable();

  @override
  Future<void> removeMobilizationCoordinator({
    required String mobilizationId,
    required String uid,
  }) async => _unavailable();

  @override
  Future<void> updateMobilization(
    MobilizationAdministrationDraft draft,
  ) async => _unavailable();
}

class PlatformAdministrationException implements Exception {
  const PlatformAdministrationException(this.message);

  final String message;

  @override
  String toString() => message;
}

String createMobilizationId(String name, {DateTime? now}) {
  var slug = name.trim().toLowerCase();
  const replacements = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ÿ': 'y',
    'œ': 'oe',
  };
  for (final entry in replacements.entries) {
    slug = slug.replaceAll(entry.key, entry.value);
  }
  slug = slug
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) {
    throw const PlatformAdministrationException(
      'Le nom doit contenir au moins une lettre ou un chiffre.',
    );
  }
  final year = (now ?? DateTime.now()).year;
  final maximumSlugLength = 120 - year.toString().length - 1;
  if (slug.length > maximumSlugLength) {
    slug = slug
        .substring(0, maximumSlugLength)
        .replaceFirst(RegExp(r'-+$'), '');
  }
  return '$slug-$year';
}
