import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_bootstrap.dart';
import 'repositories/coordination_repository.dart';
import 'repositories/firestore_coordination_repository.dart';
import 'services/firestore_seed_service.dart';
import 'theme/app_theme.dart';

class FirebaseStartupGate extends StatefulWidget {
  const FirebaseStartupGate({super.key, this.startup});

  final Future<CoordinationRepository> Function()? startup;

  @override
  State<FirebaseStartupGate> createState() => _FirebaseStartupGateState();
}

class _FirebaseStartupGateState extends State<FirebaseStartupGate> {
  late Future<CoordinationRepository> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _start();
  }

  Future<CoordinationRepository> _start() async {
    await Future<void>.delayed(Duration.zero);
    return widget.startup?.call() ?? _initializeFirebase();
  }

  Future<CoordinationRepository> _initializeFirebase() async {
    try {
      return await _initializeFirebaseWork().timeout(
        const Duration(seconds: 20),
      );
    } catch (error, stackTrace) {
      debugPrint('Échec de l’amorçage Firestore locations : $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<CoordinationRepository> _initializeFirebaseWork() async {
    if (Firebase.apps.isEmpty) await FirebaseBootstrap.initialize();
    final firestore = FirebaseFirestore.instance;
    await FirestoreSeedService(
      store: FirestoreLocationSeedStore(firestore),
    ).seedLocationsIfEmpty();
    return FirestoreCoordinationRepository(firestore);
  }

  void _retry() {
    final startup = _start();
    setState(() {
      _startup = startup;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CoordinationRepository>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return FireCoordinationApp(repository: snapshot.data);
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: snapshot.hasError
                  ? _StartupError(onRetry: _retry)
                  : const CircularProgressIndicator(),
            ),
          ),
        );
      },
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.red, size: 44),
          const SizedBox(height: 16),
          Text(
            'Impossible d’initialiser les lieux.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Vérifiez la connexion puis réessayez.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
