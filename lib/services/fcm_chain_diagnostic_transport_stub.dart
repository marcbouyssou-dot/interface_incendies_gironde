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
}) => throw UnsupportedError('FCM chain diagnostic is Web-only.');
