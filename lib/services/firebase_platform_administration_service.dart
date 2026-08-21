import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/operation.dart';
import 'platform_administration_service.dart';

typedef PlatformCallable =
    Future<Object?> Function(String functionName, Map<String, Object?> data);

class FirebasePlatformAdministrationService
    implements
        PlatformAdministrationService,
        PlatformAdministrationSessionProvider {
  FirebasePlatformAdministrationService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    PlatformCallable? callable,
  }) : assert(functions == null || callable == null),
       _functions = functions,
       _callable = callable {
    if (auth != null) {
      _setSessionFromUser(auth.currentUser);
      _authSubscription = auth.idTokenChanges().listen(
        _setSessionFromUser,
        onError: (_, _) => _sessionState.markExpired(),
      );
    }
  }

  static const region = 'europe-west1';

  final FirebaseFunctions? _functions;
  final PlatformCallable? _callable;
  final PlatformAdministrationSessionController _sessionState =
      PlatformAdministrationSessionController();
  StreamSubscription<User?>? _authSubscription;

  @override
  PlatformAdministrationSessionController get sessionState => _sessionState;

  void _setSessionFromUser(User? user) {
    if (user == null || user.isAnonymous) {
      _sessionState.markExpired();
    } else {
      _sessionState.markValid();
    }
  }

  void dispose() {
    unawaited(_authSubscription?.cancel());
    _sessionState.dispose();
  }

  @override
  bool get isAvailable => true;

  @override
  Future<void> createMobilization(MobilizationAdministrationDraft draft) =>
      _invokeMobilization('createMobilization', draft);

  @override
  Future<void> createOperation(OperationAdministrationDraft draft) =>
      _invokeOperation('createOperation', draft);

  @override
  Future<void> updateOperation(OperationAdministrationDraft draft) =>
      _invokeOperation('updateOperation', draft);

  @override
  Future<void> transitionOperation(
    String operationId,
    OperationStatus targetStatus,
  ) => _invoke('transitionOperation', {
    'operationId': _validId(operationId),
    'targetStatus': targetStatus.serializedValue,
  });

  @override
  Future<void> setOperationCoordinator({
    required String operationId,
    required String uid,
  }) => _invoke('setOperationCoordinator', {
    'operationId': _validId(operationId),
    'uid': _validUid(uid),
  });

  @override
  Future<void> updateMobilization(MobilizationAdministrationDraft draft) =>
      _invokeMobilization('updateMobilization', draft);

  @override
  Future<void> activateMobilization(String mobilizationId) =>
      _invokeId('activateMobilization', mobilizationId);

  @override
  Future<void> deactivateMobilization(String mobilizationId) =>
      _invokeId('deactivateMobilization', mobilizationId);

  @override
  Future<void> archiveMobilization(String mobilizationId) =>
      _invokeId('archiveMobilization', mobilizationId);

  @override
  Future<void> assignMobilizationCoordinator({
    required String mobilizationId,
    required String uid,
  }) => _invoke('assignMobilizationCoordinator', {
    'mobilizationId': _validId(mobilizationId),
    'uid': _validUid(uid),
  });

  @override
  Future<void> removeMobilizationCoordinator({
    required String mobilizationId,
    required String uid,
  }) => _invoke('removeMobilizationCoordinator', {
    'mobilizationId': _validId(mobilizationId),
    'uid': _validUid(uid),
  });

  Future<void> _invokeMobilization(
    String functionName,
    MobilizationAdministrationDraft draft,
  ) {
    final data = draft.toCallableData();
    _validId(data['mobilizationId']);
    _validId(data['territoryId']);
    _validText(data['name'], maximumLength: 160);
    _validText(data['subtitle'], maximumLength: 240);
    final operationId = data['operationId'];
    if (operationId != null) _validId(operationId);
    final scopeRefs = data['scopeRefs'];
    if (scopeRefs != null) _validScopeRefs(scopeRefs);
    return _invoke(functionName, data);
  }

  Future<void> _invokeOperation(
    String functionName,
    OperationAdministrationDraft draft,
  ) {
    final data = draft.toCallableData();
    _validId(data['operationId']);
    _validText(data['name'], maximumLength: 160);
    _validScopeRefs(data['scopeRefs']);
    final startAt = data['startAtMillis'];
    final endAt = data['endAtMillis'];
    if (startAt is! int ||
        startAt <= 0 ||
        (endAt != null && (endAt is! int || endAt <= startAt))) {
      throw const PlatformAdministrationException(
        'La période de l’opération est invalide.',
      );
    }
    return _invoke(functionName, data);
  }

  void _validScopeRefs(Object? value) {
    if (value is! List || value.length > 65) {
      throw const PlatformAdministrationException(
        'Le périmètre opérationnel est invalide.',
      );
    }
    final refs = value.whereType<String>().toList(growable: false);
    if (refs.length != value.length ||
        refs.toSet().length != refs.length ||
        refs.any(
          (ref) =>
              !RegExp(r'^(territories|locations)/[^/]{1,160}$').hasMatch(ref),
        )) {
      throw const PlatformAdministrationException(
        'Le périmètre opérationnel est invalide.',
      );
    }
  }

  Future<void> _invokeId(String functionName, String mobilizationId) =>
      _invoke(functionName, {'mobilizationId': _validId(mobilizationId)});

  Future<void> _invoke(String functionName, Map<String, Object?> data) async {
    if (_sessionState.value == PlatformAdministrationSessionState.expired) {
      throw const PlatformAdministrationException(
        'Votre session a expiré. Reconnectez-vous.',
      );
    }
    try {
      final callable = _callable;
      final response = callable != null
          ? await callable(functionName, data)
          : (await (_functions ?? FirebaseFunctions.instanceFor(region: region))
                    .httpsCallable(functionName)
                    .call<Object?>(data))
                .data;
      if (response is! Map) throw const FormatException();
    } on PlatformAdministrationException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated') {
        _sessionState.markExpired();
      }
      throw PlatformAdministrationException(_messageFor(error.code));
    } catch (_) {
      throw const PlatformAdministrationException(
        'Le service d’administration est momentanément indisponible.',
      );
    }
  }

  String _validId(Object? value) {
    if (value is! String ||
        value.length > 120 ||
        !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(value)) {
      throw const PlatformAdministrationException(
        'La demande d’administration est invalide.',
      );
    }
    return value;
  }

  String _validUid(Object? value) {
    if (value is! String ||
        value.isEmpty ||
        value.length > 128 ||
        value.trim() != value ||
        value.contains('/')) {
      throw const PlatformAdministrationException(
        'Le Coordinateur sélectionné est invalide.',
      );
    }
    return value;
  }

  String _validText(Object? value, {required int maximumLength}) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.length > maximumLength) {
      throw const PlatformAdministrationException(
        'Renseignez tous les champs obligatoires.',
      );
    }
    return value.trim();
  }

  String _messageFor(String code) => switch (code) {
    'unauthenticated' => 'Votre session a expiré. Reconnectez-vous.',
    'permission-denied' => 'Accès Administrateur requis.',
    'invalid-argument' => 'La demande d’administration est invalide.',
    'already-exists' => 'Cette donnée existe déjà.',
    'not-found' => 'Cette donnée n’existe plus. Actualisez la page.',
    'failed-precondition' =>
      'Cette action n’est plus possible dans l’état actuel.',
    'unavailable' ||
    'deadline-exceeded' => 'Le service est momentanément indisponible.',
    _ => 'L’action d’administration n’a pas pu aboutir.',
  };
}
