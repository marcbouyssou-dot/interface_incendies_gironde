import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'push_token_chain_diagnostic_storage.dart';

enum TokenChainComparison {
  identical('IDENTIQUE'),
  different('DIFFÉRENT'),
  indeterminate('INDÉTERMINÉ');

  const TokenChainComparison(this.label);
  final String label;

  static TokenChainComparison parse(Object? value) => switch (value) {
    'IDENTIQUE' => identical,
    'DIFFÉRENT' => different,
    _ => indeterminate,
  };
}

abstract final class PushTokenChainLifecycleTraceState {
  static const chainStateCreated = 'CHAIN_STATE_CREATED';
  static const getTokenCompareStored = 'GETTOKEN_COMPARE_STORED';
  static const persistCompareStored = 'PERSIST_COMPARE_STORED';
  static const chainStatePresentBeforeAdmin =
      'CHAIN_STATE_PRESENT_BEFORE_ADMIN';
  static const chainStatePresentAtDiagnostic =
      'CHAIN_STATE_PRESENT_AT_DIAGNOSTIC';
  static const chainStateConsumed = 'CHAIN_STATE_CONSUMED';
}

void emitPushTokenChainLifecycleTrace(
  void Function(String state) trace,
  String state, {
  required bool value,
}) {
  try {
    trace('$state: ${value ? 'OUI' : 'NON'}');
  } catch (_) {
    // Temporary diagnostics must never affect notification behavior.
  }
}

class PushTokenChainDiagnosticStore {
  const PushTokenChainDiagnosticStore({
    required this.read,
    required this.write,
    required this.clear,
  });

  final String? Function() read;
  final void Function(String value) write;
  final void Function() clear;
}

class PushTokenChainDiagnosticSnapshot {
  const PushTokenChainDiagnosticSnapshot({
    required this.getTokenVsPersistInput,
    required this.persistInputVsFirestoreAfterCommit,
  });

  final TokenChainComparison getTokenVsPersistInput;
  final TokenChainComparison persistInputVsFirestoreAfterCommit;
}

class PushTokenChainDiagnosticLifecycleSnapshot {
  const PushTokenChainDiagnosticLifecycleSnapshot({
    required this.chainStateCreated,
    required this.getTokenCompareStored,
    required this.persistCompareStored,
    required this.chainStatePresentBeforeAdmin,
  });

  final bool chainStateCreated;
  final bool getTokenCompareStored;
  final bool persistCompareStored;
  final bool chainStatePresentBeforeAdmin;
}

/// Temporary evidence for the controlled activation run.
///
/// Raw values and their fingerprints stay process-memory-only. Only the two
/// allowlisted comparison enums and four lifecycle booleans may cross a
/// process restart through session storage.
abstract final class PushTokenChainDiagnosticSession {
  static final PushTokenChainDiagnosticStore _defaultStore =
      PushTokenChainDiagnosticStore(
        read: readPushTokenChainDiagnosticState,
        write: writePushTokenChainDiagnosticState,
        clear: clearPushTokenChainDiagnosticState,
      );
  static String? _getTokenSha256;
  static String? _persistInputSha256;
  static TokenChainComparison _getTokenVsPersistInput =
      TokenChainComparison.indeterminate;
  static TokenChainComparison _persistInputVsFirestoreAfterCommit =
      TokenChainComparison.indeterminate;
  static bool _chainStateCreated = false;
  static bool _getTokenCompareStored = false;
  static bool _persistCompareStored = false;
  static bool _chainStatePresentBeforeAdmin = false;
  static Future<Object?> Function()? _readFirestoreToken;
  static int _generation = 0;
  static int? _verificationGeneration;

  static void startActivation({PushTokenChainDiagnosticStore? store}) {
    _generation += 1;
    _resetVolatileState();
    try {
      (store ?? _defaultStore).clear();
    } catch (_) {
      // Diagnostic state must never affect Push activation.
    }
  }

  static bool recordGetToken(
    String token, {
    PushTokenChainDiagnosticStore? store,
  }) {
    final diagnosticStore = store ?? _defaultStore;
    try {
      _getTokenSha256 = _fingerprint(token);
    } catch (_) {
      _getTokenSha256 = null;
    }
    _chainStateCreated = true;
    _persistComparisonEnums(diagnosticStore);
    final persisted = _readPersistedState(diagnosticStore);
    return persisted.valid && persisted.lifecycle.chainStateCreated;
  }

  static bool recordPersistInput(
    String token, {
    PushTokenChainDiagnosticStore? store,
  }) {
    final diagnosticStore = store ?? _defaultStore;
    try {
      final persistInputSha256 = _fingerprint(token);
      _persistInputSha256 = persistInputSha256;
      final getTokenSha256 = _getTokenSha256;
      _getTokenVsPersistInput = getTokenSha256 == null
          ? TokenChainComparison.indeterminate
          : getTokenSha256 == persistInputSha256
          ? TokenChainComparison.identical
          : TokenChainComparison.different;
      _persistInputVsFirestoreAfterCommit = TokenChainComparison.indeterminate;
      _readFirestoreToken = null;
      _getTokenCompareStored =
          _getTokenVsPersistInput != TokenChainComparison.indeterminate;
      _persistCompareStored = false;
      _persistComparisonEnums(diagnosticStore);
    } catch (_) {
      _persistInputSha256 = null;
      _getTokenVsPersistInput = TokenChainComparison.indeterminate;
      _persistInputVsFirestoreAfterCommit = TokenChainComparison.indeterminate;
      _readFirestoreToken = null;
      _getTokenCompareStored = false;
      _persistCompareStored = false;
      _persistComparisonEnums(diagnosticStore);
    }
    final persisted = _readPersistedState(diagnosticStore);
    return persisted.valid && persisted.lifecycle.getTokenCompareStored;
  }

  static Future<void> configureFirestoreVerification(
    Future<Object?> Function() readFirestoreToken, {
    Duration timeout = const Duration(seconds: 15),
    PushTokenChainDiagnosticStore? store,
  }) async {
    _readFirestoreToken = readFirestoreToken;
    _verificationGeneration = _generation;
    await refreshFirestoreVerification(timeout: timeout, store: store);
  }

  static Future<void> refreshFirestoreVerification({
    Duration timeout = const Duration(seconds: 15),
    PushTokenChainDiagnosticStore? store,
  }) async {
    final expected = _persistInputSha256;
    final readFirestoreToken = _readFirestoreToken;
    final verificationGeneration = _verificationGeneration;
    if (expected == null ||
        readFirestoreToken == null ||
        verificationGeneration == null) {
      return;
    }
    try {
      final firestoreToken = await readFirestoreToken().timeout(timeout);
      if (_generation != verificationGeneration ||
          _persistInputSha256 != expected) {
        return;
      }
      _persistInputVsFirestoreAfterCommit = firestoreToken is String
          ? _fingerprint(firestoreToken) == expected
                ? TokenChainComparison.identical
                : TokenChainComparison.different
          : TokenChainComparison.indeterminate;
      _persistCompareStored =
          _persistInputVsFirestoreAfterCommit !=
          TokenChainComparison.indeterminate;
      _persistComparisonEnums(store ?? _defaultStore);
    } catch (_) {
      if (_generation == verificationGeneration &&
          _persistInputSha256 == expected) {
        _persistInputVsFirestoreAfterCommit =
            TokenChainComparison.indeterminate;
        _persistCompareStored = false;
        _persistComparisonEnums(store ?? _defaultStore);
      }
    }
  }

  static bool markAdminEntry({PushTokenChainDiagnosticStore? store}) {
    final diagnosticStore = store ?? _defaultStore;
    final persisted = _readPersistedState(diagnosticStore);
    if (!persisted.valid) return false;
    _restorePersistedEnumsAndLifecycle(persisted);
    _chainStatePresentBeforeAdmin = true;
    _persistComparisonEnums(diagnosticStore);
    return _readPersistedState(
      diagnosticStore,
    ).lifecycle.chainStatePresentBeforeAdmin;
  }

  static bool hasPersistedState({PushTokenChainDiagnosticStore? store}) =>
      _readPersistedState(store ?? _defaultStore).valid;

  static PushTokenChainDiagnosticLifecycleSnapshot lifecycleSnapshot({
    PushTokenChainDiagnosticStore? store,
  }) {
    final persisted = _readPersistedState(store ?? _defaultStore);
    return persisted.lifecycle;
  }

  static PushTokenChainDiagnosticSnapshot snapshot() {
    try {
      return PushTokenChainDiagnosticSnapshot(
        getTokenVsPersistInput: _getTokenVsPersistInput,
        persistInputVsFirestoreAfterCommit: _persistInputVsFirestoreAfterCommit,
      );
    } catch (_) {
      return const PushTokenChainDiagnosticSnapshot(
        getTokenVsPersistInput: TokenChainComparison.indeterminate,
        persistInputVsFirestoreAfterCommit: TokenChainComparison.indeterminate,
      );
    }
  }

  static PushTokenChainDiagnosticSnapshot consumeSnapshot({
    PushTokenChainDiagnosticStore? store,
  }) {
    final diagnosticStore = store ?? _defaultStore;
    final persisted = _readPersistedState(diagnosticStore).snapshot;
    final current = snapshot();
    final result = PushTokenChainDiagnosticSnapshot(
      getTokenVsPersistInput:
          current.getTokenVsPersistInput != TokenChainComparison.indeterminate
          ? current.getTokenVsPersistInput
          : persisted.getTokenVsPersistInput,
      persistInputVsFirestoreAfterCommit:
          current.persistInputVsFirestoreAfterCommit !=
              TokenChainComparison.indeterminate
          ? current.persistInputVsFirestoreAfterCommit
          : persisted.persistInputVsFirestoreAfterCommit,
    );
    _generation += 1;
    _resetVolatileState();
    try {
      diagnosticStore.clear();
    } catch (_) {
      // Consumption remains best-effort and non-throwing.
    }
    return result;
  }

  static void discardVolatileStateForTesting() {
    _generation += 1;
    _resetVolatileState();
  }

  static void _persistComparisonEnums(PushTokenChainDiagnosticStore store) {
    try {
      store.write(
        jsonEncode({
          'getTokenVsPersistInput': _getTokenVsPersistInput.label,
          'persistInputVsFirestoreAfterCommit':
              _persistInputVsFirestoreAfterCommit.label,
          'chainStateCreated': _chainStateCreated,
          'getTokenCompareStored': _getTokenCompareStored,
          'persistCompareStored': _persistCompareStored,
          'chainStatePresentBeforeAdmin': _chainStatePresentBeforeAdmin,
        }),
      );
    } catch (_) {
      // Session persistence must never affect notification behavior.
    }
  }

  static _PersistedTokenChainDiagnosticState _readPersistedState(
    PushTokenChainDiagnosticStore store,
  ) {
    try {
      final encoded = store.read();
      if (encoded == null) return _invalidPersistedState;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map ||
          decoded.length != 6 ||
          !decoded.containsKey('getTokenVsPersistInput') ||
          !decoded.containsKey('persistInputVsFirestoreAfterCommit') ||
          decoded['chainStateCreated'] is! bool ||
          decoded['getTokenCompareStored'] is! bool ||
          decoded['persistCompareStored'] is! bool ||
          decoded['chainStatePresentBeforeAdmin'] is! bool) {
        return _invalidPersistedState;
      }
      return _PersistedTokenChainDiagnosticState(
        valid: true,
        snapshot: PushTokenChainDiagnosticSnapshot(
          getTokenVsPersistInput: TokenChainComparison.parse(
            decoded['getTokenVsPersistInput'],
          ),
          persistInputVsFirestoreAfterCommit: TokenChainComparison.parse(
            decoded['persistInputVsFirestoreAfterCommit'],
          ),
        ),
        lifecycle: PushTokenChainDiagnosticLifecycleSnapshot(
          chainStateCreated: decoded['chainStateCreated'] as bool,
          getTokenCompareStored: decoded['getTokenCompareStored'] as bool,
          persistCompareStored: decoded['persistCompareStored'] as bool,
          chainStatePresentBeforeAdmin:
              decoded['chainStatePresentBeforeAdmin'] as bool,
        ),
      );
    } catch (_) {
      return _invalidPersistedState;
    }
  }

  static void _restorePersistedEnumsAndLifecycle(
    _PersistedTokenChainDiagnosticState persisted,
  ) {
    _getTokenVsPersistInput = persisted.snapshot.getTokenVsPersistInput;
    _persistInputVsFirestoreAfterCommit =
        persisted.snapshot.persistInputVsFirestoreAfterCommit;
    _chainStateCreated = persisted.lifecycle.chainStateCreated;
    _getTokenCompareStored = persisted.lifecycle.getTokenCompareStored;
    _persistCompareStored = persisted.lifecycle.persistCompareStored;
    _chainStatePresentBeforeAdmin =
        persisted.lifecycle.chainStatePresentBeforeAdmin;
  }

  static void _resetVolatileState() {
    _getTokenSha256 = null;
    _persistInputSha256 = null;
    _getTokenVsPersistInput = TokenChainComparison.indeterminate;
    _persistInputVsFirestoreAfterCommit = TokenChainComparison.indeterminate;
    _chainStateCreated = false;
    _getTokenCompareStored = false;
    _persistCompareStored = false;
    _chainStatePresentBeforeAdmin = false;
    _readFirestoreToken = null;
    _verificationGeneration = null;
  }

  static const _indeterminateSnapshot = PushTokenChainDiagnosticSnapshot(
    getTokenVsPersistInput: TokenChainComparison.indeterminate,
    persistInputVsFirestoreAfterCommit: TokenChainComparison.indeterminate,
  );

  static const _indeterminateLifecycle =
      PushTokenChainDiagnosticLifecycleSnapshot(
        chainStateCreated: false,
        getTokenCompareStored: false,
        persistCompareStored: false,
        chainStatePresentBeforeAdmin: false,
      );

  static const _invalidPersistedState = _PersistedTokenChainDiagnosticState(
    valid: false,
    snapshot: _indeterminateSnapshot,
    lifecycle: _indeterminateLifecycle,
  );

  static String _fingerprint(String token) =>
      sha256.convert(utf8.encode(token)).toString();
}

class _PersistedTokenChainDiagnosticState {
  const _PersistedTokenChainDiagnosticState({
    required this.valid,
    required this.snapshot,
    required this.lifecycle,
  });

  final bool valid;
  final PushTokenChainDiagnosticSnapshot snapshot;
  final PushTokenChainDiagnosticLifecycleSnapshot lifecycle;
}

Future<bool> verifyPersistedPushTokenForDiagnostic({
  required Future<Object?> Function() readFirestoreToken,
  Duration timeout = const Duration(seconds: 15),
  PushTokenChainDiagnosticStore? store,
}) async {
  try {
    await PushTokenChainDiagnosticSession.configureFirestoreVerification(
      readFirestoreToken,
      timeout: timeout,
      store: store,
    );
    return PushTokenChainDiagnosticSession.lifecycleSnapshot(
      store: store,
    ).persistCompareStored;
  } catch (_) {
    // Diagnostic state must never affect committed persistence.
    return false;
  }
}
