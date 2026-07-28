import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app.dart';
import 'firebase_bootstrap.dart';
import 'repositories/coordination_repository.dart';
import 'repositories/firestore_coordination_repository.dart';
import 'repositories/mock_coordination_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final CoordinationRepository repository;
  if (FirebaseBootstrap.enabled) {
    await FirebaseBootstrap.initialize();
    repository = FirestoreCoordinationRepository(FirebaseFirestore.instance);
  } else {
    repository = MockCoordinationRepository.instance;
  }
  runApp(FireCoordinationApp(repository: repository));
}
