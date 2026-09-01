import 'dart:convert';

import 'package:crypto/crypto.dart';

enum TokenChainComparison {
  identical('IDENTIQUE'),
  different('DIFFÉRENT'),
  indeterminate('INDÉTERMINÉ');

  const TokenChainComparison(this.label);
  final String label;
}

class PushTokenChainDiagnosticSnapshot {
  const PushTokenChainDiagnosticSnapshot({
    required this.getTokenVsPersistInput,
    required this.persistInputVsFirestoreAfterCommit,
  });

  final TokenChainComparison getTokenVsPersistInput;
  final TokenChainComparison persistInputVsFirestoreAfterCommit;
}

/// Temporary, process-memory-only evidence for the controlled activation run.
abstract final class PushTokenChainDiagnosticSession {
  static String? _getTokenSha256;
  static String? _persistInputSha256;
  static TokenChainComparison _getTokenVsPersistInput =
      TokenChainComparison.indeterminate;
  static TokenChainComparison _persistInputVsFirestoreAfterCommit =
      TokenChainComparison.indeterminate;
  static Future<Object?> Function()? _readFirestoreToken;

  static void startActivation() {
    try {
      _getTokenSha256 = null;
      _persistInputSha256 = null;
      _getTokenVsPersistInput = TokenChainComparison.indeterminate;
      _persistInputVsFirestoreAfterCommit = TokenChainComparison.indeterminate;
      _readFirestoreToken = null;
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

  static void recordPersistInput(String token) {
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
    } catch (_) {
      _persistInputSha256 = null;
      _getTokenVsPersistInput = TokenChainComparison.indeterminate;
      _persistInputVsFirestoreAfterCommit = TokenChainComparison.indeterminate;
      _readFirestoreToken = null;
    }
  }

  static Future<void> configureFirestoreVerification(
    Future<Object?> Function() readFirestoreToken, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    _readFirestoreToken = readFirestoreToken;
    await refreshFirestoreVerification(timeout: timeout);
  }

  static Future<void> refreshFirestoreVerification({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final expected = _persistInputSha256;
    final readFirestoreToken = _readFirestoreToken;
    if (expected == null || readFirestoreToken == null) return;
    try {
      final firestoreToken = await readFirestoreToken().timeout(timeout);
      if (_persistInputSha256 != expected) return;
      _persistInputVsFirestoreAfterCommit = firestoreToken is String
          ? _fingerprint(firestoreToken) == expected
                ? TokenChainComparison.identical
                : TokenChainComparison.different
          : TokenChainComparison.indeterminate;
    } catch (_) {
      if (_persistInputSha256 == expected) {
        _persistInputVsFirestoreAfterCommit =
            TokenChainComparison.indeterminate;
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

  static String _fingerprint(String token) =>
      sha256.convert(utf8.encode(token)).toString();
}

Future<void> verifyPersistedPushTokenForDiagnostic({
  required Future<Object?> Function() readFirestoreToken,
  Duration timeout = const Duration(seconds: 15),
}) async {
  try {
    await PushTokenChainDiagnosticSession.configureFirestoreVerification(
      readFirestoreToken,
      timeout: timeout,
    );
  } catch (_) {
    // Diagnostic state must never affect committed persistence.
  }
}
