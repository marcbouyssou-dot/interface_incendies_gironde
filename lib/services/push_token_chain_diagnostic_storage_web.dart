// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _storageKey = 'mobsante.push.token-chain-diagnostic.v1';

String? readPushTokenChainDiagnosticState() {
  try {
    return html.window.sessionStorage[_storageKey];
  } catch (_) {
    return null;
  }
}

void writePushTokenChainDiagnosticState(String value) {
  try {
    html.window.sessionStorage[_storageKey] = value;
  } catch (_) {
    // Diagnostic persistence is best-effort and non-throwing.
  }
}

void clearPushTokenChainDiagnosticState() {
  try {
    html.window.sessionStorage.remove(_storageKey);
  } catch (_) {
    // Diagnostic cleanup is best-effort and non-throwing.
  }
}
