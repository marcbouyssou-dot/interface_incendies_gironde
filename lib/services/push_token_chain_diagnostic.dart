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

/// Temporary evidence for the controlled activation run.
///
/// Raw values and their fingerprints stay process-memory-only. Only the two
/// allowlisted comparison enums may cross a process restart through session
/// storage.
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

  static void recordGetToken(String token) {
    try {
      _getTokenSha256 = _fingerprint(token);
    } catch (_) {
      _getTokenSha256 = null;
    }
  }

  static void recordPersistInput(
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
      _persistComparisonEnums(diagnosticStore);
    } catch (_) {
      _persistInputSha256 = null;
      _getTokenVsPersistInput = TokenChainComparison.indeterminate;
      _persistInputVsFirestoreAfterCommit = TokenChainComparison.indeterminate;
      _readFirestoreToken = null;
      _persistComparisonEnums(diagnosticStore);
    }
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
      _persistComparisonEnums(store ?? _defaultStore);
    } catch (_) {
      if (_generation == verificationGeneration &&
          _persistInputSha256 == expected) {
        _persistInputVsFirestoreAfterCommit =
            TokenChainComparison.indeterminate;
        _persistComparisonEnums(store ?? _defaultStore);
      }
    }
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
    final persisted = _readPersistedSnapshot(diagnosticStore);
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
        }),
      );
    } catch (_) {
      // Session persistence must never affect notification behavior.
    }
  }

  static PushTokenChainDiagnosticSnapshot _readPersistedSnapshot(
    PushTokenChainDiagnosticStore store,
  ) {
    try {
      final encoded = store.read();
      if (encoded == null) return _indeterminateSnapshot;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map ||
          decoded.length != 2 ||
          !decoded.containsKey('getTokenVsPersistInput') ||
          !decoded.containsKey('persistInputVsFirestoreAfterCommit')) {
        return _indeterminateSnapshot;
      }
      return PushTokenChainDiagnosticSnapshot(
        getTokenVsPersistInput: TokenChainComparison.parse(
          decoded['getTokenVsPersistInput'],
        ),
        persistInputVsFirestoreAfterCommit: TokenChainComparison.parse(
          decoded['persistInputVsFirestoreAfterCommit'],
        ),
      );
    } catch (_) {
      return _indeterminateSnapshot;
    }
  }

  static void _resetVolatileState() {
    _getTokenSha256 = null;
    _persistInputSha256 = null;
    _getTokenVsPersistInput = TokenChainComparison.indeterminate;
    _persistInputVsFirestoreAfterCommit = TokenChainComparison.indeterminate;
    _readFirestoreToken = null;
    _verificationGeneration = null;
  }

  static const _indeterminateSnapshot = PushTokenChainDiagnosticSnapshot(
    getTokenVsPersistInput: TokenChainComparison.indeterminate,
    persistInputVsFirestoreAfterCommit: TokenChainComparison.indeterminate,
  );

  static String _fingerprint(String token) =>
      sha256.convert(utf8.encode(token)).toString();
}

Future<void> verifyPersistedPushTokenForDiagnostic({
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
  } catch (_) {
    // Diagnostic state must never affect committed persistence.
  }
}
