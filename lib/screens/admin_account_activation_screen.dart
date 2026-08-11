import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../firebase_bootstrap.dart';
import '../firebase_startup_gate.dart';
import '../theme/app_theme.dart';
import '../utils/app_page_route.dart';
import '../utils/system_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/v5_controls.dart';

abstract final class _ActivationVisuals {
  static const background = Color(0xFFF6F7F8);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF5F6865);
  static const orange = Color(0xFFB9470A);
}

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) revealApplication();
    });
  }

  Future<AdminAccountActivationService> _initialize() async {
    try {
      await FirebaseBootstrap.initialize();
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
      builder: AppTheme.lightSystemSurface,
      home: FutureBuilder<AdminAccountActivationService>(
        future: _service.timeout(const Duration(seconds: 20)),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return AdminAccountActivationScreen(
              uri: widget.uri,
              service: snapshot.data!,
              onSignIn: () {
                Navigator.of(context).pushReplacement(
                  AppPageRoute<void>(
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
      backgroundColor: _ActivationVisuals.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth <= 568
                ? 20.0
                : (constraints.maxWidth - 520) / 2;
            return Material(
              color: _ActivationVisuals.background,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  24,
                  horizontalPadding,
                  36,
                ),
                children: [
                  const _ActivationHeader(),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _ActivationVisuals.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _ActivationVisuals.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A173052),
                          blurRadius: 18,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActivationHeader extends StatelessWidget {
  const _ActivationHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BrandMark(size: 58),
        SizedBox(height: 18),
        Text(
          'MobSanté',
          style: TextStyle(
            color: _ActivationVisuals.navy,
            fontSize: 29,
            height: 1.08,
            letterSpacing: -0.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Activation de votre accès responsable',
          style: TextStyle(
            color: _ActivationVisuals.textMuted,
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: V5ActivityIndicator(
            size: 34,
            color: _ActivationVisuals.orange,
          ),
        ),
        SizedBox(height: 18),
        Text(
          'Vérification de votre invitation…',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ActivationVisuals.navy,
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
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
          const Text(
            'Définissez votre mot de passe',
            style: TextStyle(
              color: _ActivationVisuals.navy,
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (email != null && email!.isNotEmpty) ...[
            const SizedBox(height: 17),
            TextFormField(
              key: const Key('activation-email'),
              initialValue: email,
              readOnly: true,
              style: const TextStyle(
                color: _ActivationVisuals.navy,
                fontWeight: FontWeight.w600,
              ),
              decoration: _activationInputDecoration(
                labelText: 'Adresse email',
                prefixIcon: Icons.alternate_email_rounded,
                readOnly: true,
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            key: const Key('activation-password'),
            controller: password,
            obscureText: !showPassword,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: const [AutofillHints.newPassword],
            style: const TextStyle(
              color: _ActivationVisuals.navy,
              fontWeight: FontWeight.w600,
            ),
            decoration: _activationInputDecoration(
              labelText: 'Nouveau mot de passe',
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                tooltip: showPassword ? 'Masquer' : 'Afficher',
                onPressed: onTogglePassword,
                color: _ActivationVisuals.navy,
                icon: Icon(
                  showPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('activation-confirmation'),
            controller: confirmation,
            obscureText: !showConfirmation,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => submitting ? null : onSubmit(),
            style: const TextStyle(
              color: _ActivationVisuals.navy,
              fontWeight: FontWeight.w600,
            ),
            decoration: _activationInputDecoration(
              labelText: 'Confirmer le mot de passe',
              prefixIcon: Icons.lock_reset_rounded,
              suffixIcon: IconButton(
                tooltip: showConfirmation ? 'Masquer' : 'Afficher',
                onPressed: onToggleConfirmation,
                color: _ActivationVisuals.navy,
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD6D2)),
              ),
              child: Text(
                formError!,
                key: const Key('activation-form-error'),
                style: const TextStyle(
                  color: AppColors.red,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          V5Button(
            key: const Key('activate-account'),
            expanded: true,
            backgroundColor: _ActivationVisuals.orange,
            foregroundColor: Colors.white,
            loading: submitting,
            onPressed: submitting ? null : onSubmit,
            label: submitting ? 'Activation…' : 'Activer mon accès',
          ),
        ],
      ),
    );
  }
}

InputDecoration _activationInputDecoration({
  required String labelText,
  required IconData prefixIcon,
  Widget? suffixIcon,
  bool readOnly = false,
}) {
  return InputDecoration(
    labelText: labelText,
    labelStyle: const TextStyle(
      color: _ActivationVisuals.textMuted,
      fontWeight: FontWeight.w600,
    ),
    prefixIcon: Icon(
      prefixIcon,
      color: readOnly ? _ActivationVisuals.textMuted : _ActivationVisuals.navy,
      size: 21,
    ),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: _ActivationVisuals.fieldBackground,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _ActivationVisuals.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _ActivationVisuals.navy, width: 1.5),
    ),
  );
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
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 32, color: iconColor),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ActivationVisuals.navy,
            fontSize: 19,
            height: 1.25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ActivationVisuals.textMuted,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 22),
          V5Button(
            expanded: true,
            onPressed: onAction,
            backgroundColor: _ActivationVisuals.orange,
            foregroundColor: Colors.white,
            label: actionLabel!,
          ),
        ],
      ],
    );
  }
}
