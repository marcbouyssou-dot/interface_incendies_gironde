import 'package:flutter/foundation.dart';

import '../models/mobilization.dart';
import '../models/operation.dart';
import '../models/operational_scope.dart';

enum PlatformAdministrationSessionState { valid, expired }

abstract interface class PlatformAdministrationSessionProvider {
  ValueListenable<PlatformAdministrationSessionState> get sessionState;
}

abstract interface class TargetedPushTestService {
  Future<void> sendTargetedPushTest({required String installationId});
}

class PlatformAdministrationSessionController
    extends ValueNotifier<PlatformAdministrationSessionState> {
  PlatformAdministrationSessionController({bool initiallyValid = true})
    : super(
        initiallyValid
            ? PlatformAdministrationSessionState.valid
            : PlatformAdministrationSessionState.expired,
      );

  void markValid() => value = PlatformAdministrationSessionState.valid;

  void markExpired() => value = PlatformAdministrationSessionState.expired;
}

class MobilizationAdministrationDraft {
  const MobilizationAdministrationDraft({
    required this.mobilizationId,
    required this.territoryId,
    required this.name,
    required this.subtitle,
    required this.contextType,
    this.operationId,
    this.scopeRefs,
  });

  final String mobilizationId;
  final String territoryId;
  final String name;
  final String subtitle;
  final MobilizationContextType contextType;
  final String? operationId;
  final List<OperationalScopeRef>? scopeRefs;

  Map<String, Object?> toCallableData() => {
    'mobilizationId': mobilizationId,
    'territoryId': territoryId,
    'name': name.trim(),
    'subtitle': subtitle.trim(),
    'contextType': contextType.serializedValue,
    if (operationId != null) 'operationId': operationId,
    if (scopeRefs != null)
      'scopeRefs': scopeRefs!.map((ref) => ref.serializedValue).toList(),
  };
}

class OperationAdministrationDraft {
  const OperationAdministrationDraft({
    required this.operationId,
    required this.name,
    required this.type,
    required this.startAt,
    required this.scopeRefs,
    this.context,
    this.endAt,
  });

  final String operationId;
  final String name;
  final OperationType type;
  final String? context;
  final DateTime startAt;
  final DateTime? endAt;
  final List<OperationalScopeRef> scopeRefs;

  Map<String, Object?> toCallableData() => {
    'operationId': operationId,
    'name': name.trim(),
    'type': type.serializedValue,
    'context': context?.trim(),
    'startAtMillis': startAt.millisecondsSinceEpoch,
    'endAtMillis': endAt?.millisecondsSinceEpoch,
    'scopeRefs': scopeRefs.map((ref) => ref.serializedValue).toList(),
  };
}

abstract interface class PlatformAdministrationService {
  bool get isAvailable;

  Future<void> createMobilization(MobilizationAdministrationDraft draft);

  Future<void> createOperation(OperationAdministrationDraft draft);

  Future<void> updateOperation(OperationAdministrationDraft draft);

  Future<void> transitionOperation(
    String operationId,
    OperationStatus targetStatus,
  );

  Future<void> setOperationCoordinator({
    required String operationId,
    required String uid,
  });

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
  Future<void> setOperationCoordinator({
    required String operationId,
    required String uid,
  }) async => _unavailable();

  @override
  Future<void> createMobilization(
    MobilizationAdministrationDraft draft,
  ) async => _unavailable();

  @override
  Future<void> createOperation(OperationAdministrationDraft draft) async =>
      _unavailable();

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

  @override
  Future<void> updateOperation(OperationAdministrationDraft draft) async =>
      _unavailable();

  @override
  Future<void> transitionOperation(
    String operationId,
    OperationStatus targetStatus,
  ) async => _unavailable();
}

class PlatformAdministrationException implements Exception {
  const PlatformAdministrationException(this.message);

  final String message;

  @override
  String toString() => message;
}

String createMobilizationId(String name, {DateTime? now}) {
  return _createPlatformId(name, now: now);
}

String createOperationId(String name, {DateTime? now}) {
  return _createPlatformId(name, now: now);
}

String _createPlatformId(String name, {DateTime? now}) {
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
