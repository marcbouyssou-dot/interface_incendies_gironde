import 'package:flutter/material.dart';
import 'app.dart';
import 'firebase_bootstrap.dart';
import 'firebase_startup_gate.dart';
import 'repositories/mock_coordination_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (FirebaseBootstrap.enabled) {
    runApp(const FirebaseStartupGate());
  } else {
    runApp(
      FireCoordinationApp(repository: MockCoordinationRepository.instance),
    );
  }
}
