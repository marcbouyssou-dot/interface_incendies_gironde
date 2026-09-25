// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef FcmChainDiagnosticTransport =
    Future<Object?> Function({
      required FirebaseAuth? auth,
      required String region,
      required Map<String, Object?> data,
    });

Future<Object?> invokeFcmChainDiagnosticWithoutMessaging({
  required FirebaseAuth? auth,
  required String region,
  required Map<String, Object?> data,
}) async {
  if (auth == null) {
    throw StateError('Authenticated diagnostic context unavailable.');
  }
  final user = auth.currentUser;
  final projectId = auth.app.options.projectId;
  if (user == null || user.isAnonymous || projectId.isEmpty) {
    throw StateError('Authenticated diagnostic context unavailable.');
  }
  final authToken = await user.getIdToken(false);
  final appCheckToken = await FirebaseAppCheck.instanceFor(
    app: auth.app,
  ).getToken(false);
  if (authToken == null ||
      authToken.isEmpty ||
      appCheckToken == null ||
      appCheckToken.isEmpty) {
    throw StateError('Protected diagnostic context unavailable.');
  }
  final endpoint = Uri.https(
    '$region-$projectId.cloudfunctions.net',
    '/diagnoseFcmChain',
  );
  final response = await html.HttpRequest.request(
    endpoint.toString(),
    method: 'POST',
    requestHeaders: {
      'Authorization': 'Bearer $authToken',
      'Content-Type': 'application/json',
      'X-Firebase-AppCheck': appCheckToken,
    },
    sendData: jsonEncode({'data': data}),
  );
  final decoded = jsonDecode(response.responseText ?? '');
  if (decoded is! Map) throw const FormatException();
  final result = decoded['result'] ?? decoded['data'];
  if (result is! Map) throw const FormatException();
  return result;
}
