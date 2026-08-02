import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_bootstrap.dart';
import '../firebase_startup_gate.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';

enum ActivationFailure { invalid, expired, alreadyUsed, unavailable }

class ActivationException implements Exception {
  const ActivationException(this.failure);

  final ActivationFailure failure;
}

class PasswordResetAction {
  const PasswordResetAction({required this.oobCode});

  final String oobCode;

  static PasswordResetAction parse(Uri uri) {
    if (!isPasswordResetMode(uri.queryParameters['mode'])) {
      throw const ActivationException(ActivationFailure.invalid);
    }
    final code = uri.queryParameters['oobCode']?.trim() ?? '';
    if (code.isEmpty) {
      throw const ActivationException(ActivationFailure.invalid);
    }
    return PasswordResetAction(oobCode: code);
  }

  static bool isPasswordResetMode(String? mode) => mode == 'resetPassword';
}

abstract interface class AdminAccountActivationService {
  Future<String> verifyPasswordResetCode(String code);

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  });
}

class FirebaseAdminAccountActivationService
    implements AdminAccountActivationService {
  FirebaseAdminAccountActivationService(this.auth);

  final FirebaseAuth auth;

  @override
  Future<String> verifyPasswordResetCode(String code) async {
    try {
      return await auth.verifyPasswordResetCode(code);
    } on FirebaseAuthException catch (error) {
      throw ActivationException(_failureForCode(error.code));
    }
  }

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      await auth.confirmPasswordReset(code: code, newPassword: newPassword);
    } on FirebaseAuthException catch (error) {
      throw ActivationException(_failureForCode(error.code));
    }
  }

  static ActivationFailure _failureForCode(String code) => switch (code) {
    'expired-action-code' => ActivationFailure.expired,
    'invalid-action-code' => ActivationFailure.alreadyUsed,
    _ => ActivationFailure.unavailable,
  };
}

class AdminAccountActivationApp extends StatefulWidget {
  const AdminAccountActivationApp({super.key, required this.uri});

  final Uri uri;

  @override
  State<AdminAccountActivationApp> createState() =>
      _AdminAccountActivationAppState();
}

class _AdminAccountActivationAppState extends State<AdminAccountActivationApp> {
  late final Future<AdminAccountActivationService> _service = _initialize();

  Future<AdminAccountActivationService> _initialize() async {
    try {
      if (Firebase.apps.isEmpty) await FirebaseBootstrap.initialize();
      return FirebaseAdminAccountActivationService(FirebaseAuth.instance);
    } catch (error, stackTrace) {
      _logUnexpectedActivationError('initialization', error, stackTrace);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Activation responsable — MobSanté',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: FutureBuilder<AdminAccountActivationService>(
        future: _service.timeout(const Duration(seconds: 20)),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return AdminAccountActivationScreen(
              uri: widget.uri,
              service: snapshot.data!,
              onSignIn: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => const FirebaseStartupGate(initialTab: 1),
                  ),
                );
              },
            );
          }
          return _ActivationFrame(
            child: snapshot.hasError
                ? const _ActivationMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'Activation indisponible',
                    message:
                        'Vérifiez votre connexion puis rechargez cette page.',
                  )
                : const _ActivationLoading(),
          );
        },
      ),
    );
  }
}

class AdminAccountActivationScreen extends StatefulWidget {
  const AdminAccountActivationScreen({
    super.key,
    required this.uri,
    required this.service,
    required this.onSignIn,
  });

  final Uri uri;
  final AdminAccountActivationService service;
  final VoidCallback onSignIn;

  @override
  State<AdminAccountActivationScreen> createState() =>
      _AdminAccountActivationScreenState();
}

class _AdminAccountActivationScreenState
    extends State<AdminAccountActivationScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  PasswordResetAction? _action;
  String? _email;
  ActivationFailure? _failure;
  String? _formError;
  bool _checking = true;
  bool _submitting = false;
  bool _success = false;
  bool _showPassword = false;
  bool _showConfirmation = false;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    try {
      final action = PasswordResetAction.parse(widget.uri);
      final email = await widget.service
          .verifyPasswordResetCode(action.oobCode)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _action = action;
        _email = email;
        _checking = false;
      });
    } on ActivationException catch (error) {
      _showFailure(error.failure);
    } on TimeoutException {
      _showFailure(ActivationFailure.unavailable);
    } catch (error, stackTrace) {
      _logUnexpectedActivationError('verification', error, stackTrace);
      _showFailure(ActivationFailure.unavailable);
    }
  }

  void _showFailure(ActivationFailure failure) {
    if (!mounted) return;
    setState(() {
      _failure = failure;
      _checking = false;
      _submitting = false;
    });
  }

  Future<void> _activate() async {
    if (_submitting || _action == null) return;
    final password = _password.text;
    if (password.length < 8) {
      setState(() => _formError = 'Utilisez au moins 8 caractères.');
      return;
    }
    if (password != _confirmation.text) {
      setState(() => _formError = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() {
      _formError = null;
      _submitting = true;
    });
    try {
      await widget.service
          .confirmPasswordReset(code: _action!.oobCode, newPassword: password)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      _password.clear();
      _confirmation.clear();
      setState(() {
        _submitting = false;
        _success = true;
      });
    } on ActivationException catch (error) {
      _clearPasswordFields();
      _showFailure(error.failure);
    } on TimeoutException {
      _clearPasswordFields();
      _showFailure(ActivationFailure.unavailable);
    } catch (error, stackTrace) {
      _clearPasswordFields();
      _logUnexpectedActivationError('confirmation', error, stackTrace);
      _showFailure(ActivationFailure.unavailable);
    }
  }

  void _clearPasswordFields() {
    _password.clear();
    _confirmation.clear();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_checking) {
      content = const _ActivationLoading();
    } else if (_success) {
      content = _ActivationMessage(
        icon: Icons.check_circle_rounded,
        iconColor: AppColors.green,
        title: 'Votre accès responsable est activé.',
        message: 'Vous pouvez maintenant vous connecter à MobSanté.',
        actionLabel: 'Se connecter',
        onAction: widget.onSignIn,
      );
    } else if (_failure != null) {
      content = _failureMessage(_failure!);
    } else {
      content = _ActivationForm(
        email: _email,
        password: _password,
        confirmation: _confirmation,
        formError: _formError,
        submitting: _submitting,
        showPassword: _showPassword,
        showConfirmation: _showConfirmation,
        onTogglePassword: () => setState(() => _showPassword = !_showPassword),
        onToggleConfirmation: () =>
            setState(() => _showConfirmation = !_showConfirmation),
        onSubmit: _activate,
      );
    }
    return _ActivationFrame(child: content);
  }

  Widget _failureMessage(ActivationFailure failure) => switch (failure) {
    ActivationFailure.expired => const _ActivationMessage(
      icon: Icons.schedule_rounded,
      title: 'Ce lien d’activation a expiré.',
      message:
          'Contactez le coordinateur pour recevoir une nouvelle invitation.',
    ),
    ActivationFailure.alreadyUsed => _ActivationMessage(
      icon: Icons.info_outline_rounded,
      title: 'Ce lien a déjà été utilisé ou n’est plus valide.',
      message: 'Essayez de vous connecter avec votre mot de passe.',
      actionLabel: 'Se connecter',
      onAction: widget.onSignIn,
    ),
    ActivationFailure.invalid => const _ActivationMessage(
      icon: Icons.link_off_rounded,
      title: 'Ce lien d’activation est invalide.',
      message: 'Demandez une nouvelle invitation au coordinateur.',
    ),
    ActivationFailure.unavailable => const _ActivationMessage(
      icon: Icons.cloud_off_rounded,
      title: 'Vérification impossible',
      message: 'Vérifiez votre connexion puis rechargez cette page.',
    ),
  };
}

void _logUnexpectedActivationError(
  String phase,
  Object error,
  StackTrace stackTrace,
) {
  debugPrint('Admin account activation $phase failed (${error.runtimeType}).');
  debugPrintStack(stackTrace: stackTrace);
}

class _ActivationFrame extends StatelessWidget {
  const _ActivationFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
              children: [
                const Center(child: BrandMark(size: 72)),
                const SizedBox(height: 16),
                Text(
                  'MobSanté',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Activation de votre accès responsable',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivationLoading extends StatelessWidget {
  const _ActivationLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        SizedBox(height: 18),
        Text('Vérification de votre invitation…', textAlign: TextAlign.center),
      ],
    );
  }
}

class _ActivationForm extends StatelessWidget {
  const _ActivationForm({
    required this.email,
    required this.password,
    required this.confirmation,
    required this.formError,
    required this.submitting,
    required this.showPassword,
    required this.showConfirmation,
    required this.onTogglePassword,
    required this.onToggleConfirmation,
    required this.onSubmit,
  });

  final String? email;
  final TextEditingController password;
  final TextEditingController confirmation;
  final String? formError;
  final bool submitting;
  final bool showPassword;
  final bool showConfirmation;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmation;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FormSectionTitle(title: 'Définissez votre mot de passe'),
          if (email != null && email!.isNotEmpty) ...[
            const SizedBox(height: AppFormLayout.titleSpacing),
            TextFormField(
              key: const Key('activation-email'),
              initialValue: email,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Adresse email'),
            ),
          ],
          const SizedBox(height: AppFormLayout.fieldSpacing),
          TextField(
            key: const Key('activation-password'),
            controller: password,
            obscureText: !showPassword,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe',
              suffixIcon: IconButton(
                tooltip: showPassword ? 'Masquer' : 'Afficher',
                onPressed: onTogglePassword,
                icon: Icon(
                  showPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppFormLayout.fieldSpacing),
          TextField(
            key: const Key('activation-confirmation'),
            controller: confirmation,
            obscureText: !showConfirmation,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => submitting ? null : onSubmit(),
            decoration: InputDecoration(
              labelText: 'Confirmer le mot de passe',
              suffixIcon: IconButton(
                tooltip: showConfirmation ? 'Masquer' : 'Afficher',
                onPressed: onToggleConfirmation,
                icon: Icon(
                  showConfirmation
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
          ),
          if (formError != null) ...[
            const SizedBox(height: 12),
            Text(
              formError!,
              key: const Key('activation-form-error'),
              style: const TextStyle(
                color: AppColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: AppFormLayout.sectionSpacing),
          SizedBox(
            height: AppFormLayout.actionHeight,
            child: FilledButton(
              key: const Key('activate-account'),
              onPressed: submitting ? null : onSubmit,
              child: Text(submitting ? 'Activation…' : 'Activer mon accès'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivationMessage extends StatelessWidget {
  const _ActivationMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor = AppColors.orange,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: iconColor),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 22),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}
