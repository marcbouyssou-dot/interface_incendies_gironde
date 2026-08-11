import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_identity.dart';
import 'firebase_bootstrap.dart';
import 'repositories/coordination_repository.dart';
import 'repositories/firestore_coordination_repository.dart';
import 'repositories/firestore_platform_read_repository.dart';
import 'services/current_mobilization_provider.dart';
import 'screens/splash_screen.dart';
import 'services/firebase_professional_verification_service.dart';
import 'services/firestore_seed_service.dart';
import 'theme/app_theme.dart';
import 'theme/v5_foundation.dart';
import 'utils/system_theme.dart';
import 'widgets/brand_mark.dart';
import 'widgets/v5_controls.dart';

bool mustCreateAnonymousVolunteerSession({
  required bool hasUser,
  required bool isAnonymous,
}) => !hasUser || !isAnonymous;

class FirebaseStartupGate extends StatefulWidget {
  const FirebaseStartupGate({
    super.key,
    this.startup,
    this.initialTab = 0,
    this.splashPreparation,
  });

  final Future<CoordinationRepository> Function()? startup;
  final int initialTab;
  final SplashVisualPreparation? splashPreparation;

  @override
  State<FirebaseStartupGate> createState() => _FirebaseStartupGateState();
}

class _FirebaseStartupGateState extends State<FirebaseStartupGate> {
  late Future<CoordinationRepository> _startup;
  late final Completer<void> _splashVisualReady;
  bool _errorRevealScheduled = false;

  @override
  void initState() {
    super.initState();
    _splashVisualReady = Completer<void>();
    _startup = _start(preserveSplash: true);
  }

  Future<CoordinationRepository> _start({bool preserveSplash = false}) async {
    await Future<void>.delayed(Duration.zero);
    final startup = widget.startup?.call() ?? _initializeFirebase();
    if (!preserveSplash) return startup;
    await Future.wait<void>([
      startup.then<void>((_) {}),
      Future<void>.delayed(AppIdentity.splashRevealDuration),
      _splashVisualReady.future,
    ], eagerError: true);
    return startup;
  }

  void _markSplashComposed() {
    if (!_splashVisualReady.isCompleted) _splashVisualReady.complete();
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
    await FirebaseBootstrap.initialize();
    final volunteerAuth = FirebaseAuth.instance;
    final responsibleAppFuture = _initializeResponsibleApp();
    markStartupEvent('mobsante-auth-start');
    final restoredUser = volunteerAuth.currentUser;
    if (restoredUser != null && !restoredUser.isAnonymous) {
      await volunteerAuth.signOut();
    }
    if (mustCreateAnonymousVolunteerSession(
      hasUser: restoredUser != null,
      isAnonymous: restoredUser?.isAnonymous ?? false,
    )) {
      await volunteerAuth.signInAnonymously();
    }
    markStartupEvent('mobsante-auth-ready');
    final firestore = FirebaseFirestore.instance;
    final managerApp = await responsibleAppFuture;
    final responsibleAuth = FirebaseAuth.instanceFor(app: managerApp);
    final responsibleFirestore = FirebaseFirestore.instanceFor(app: managerApp);
    const enableLocationSeed = bool.fromEnvironment(
      'ENABLE_LOCATION_SEED',
      defaultValue: false,
    );
    if (enableLocationSeed) {
      await FirestoreSeedService(
        store: FirestoreLocationSeedStore(firestore),
      ).seedLocationsIfEmpty();
    }
    final mobilizationProvider = CurrentMobilizationProvider(
      repository: FirestorePlatformReadRepository.withFirebase(
        firestore: firestore,
      ),
    );
    final repository = FirestoreCoordinationRepository(
      firestore,
      volunteerAuth,
      mobilizationProvider: mobilizationProvider,
      responsibleFirestore: responsibleFirestore,
      responsibleAuth: responsibleAuth,
    );
    markStartupEvent('mobsante-firestore-session-ready');
    return repository;
  }

  Future<FirebaseApp> _initializeResponsibleApp() async {
    final existing = Firebase.apps
        .where((app) => app.name == 'responsible')
        .firstOrNull;
    if (existing != null) return existing;
    return Firebase.initializeApp(
      name: 'responsible',
      options: Firebase.app().options,
    );
  }

  void _scheduleErrorReveal() {
    if (_errorRevealScheduled) return;
    _errorRevealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) revealApplication();
    });
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
          return FireCoordinationApp(
            repository: snapshot.data,
            initialTab: widget.initialTab,
            professionalVerificationService:
                FirebaseProfessionalVerificationService(),
          );
        }
        if (snapshot.hasError) _scheduleErrorReveal();
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          builder: snapshot.hasError
              ? AppTheme.systemSurface
              : AppTheme.darkSystemSurface,
          home: Scaffold(
            backgroundColor: snapshot.hasError ? null : AppColors.navy,
            body: snapshot.hasError
                ? _StartupError(onRetry: _retry)
                : SplashScreen(
                    prepareVisuals: widget.splashPreparation,
                    onComposed: _markSplashComposed,
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
    final colors = context.v5Colors;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth <= 556
              ? 20.0
              : (constraints.maxWidth - 520) / 2;
          return CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _StartupIdentity(),
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colors.outline),
                          boxShadow: V5Elevation.level1(colors),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: colors.dangerContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.cloud_off_rounded,
                                color: colors.danger,
                                size: 31,
                              ),
                            ),
                            const SizedBox(height: 17),
                            Text(
                              'Connexion sécurisée impossible. Réessayez.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 19,
                                height: 1.3,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Vérifiez votre connexion.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 14,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 22),
                            V5Button(
                              expanded: true,
                              onPressed: onRetry,
                              backgroundColor: colors.accent,
                              foregroundColor: colors.onAccent,
                              label: 'Réessayer',
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StartupIdentity extends StatelessWidget {
  const _StartupIdentity();

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Row(
      children: [
        const BrandMark(size: 50),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            AppIdentity.productName,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 22,
              height: 1.1,
              letterSpacing: -0.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
