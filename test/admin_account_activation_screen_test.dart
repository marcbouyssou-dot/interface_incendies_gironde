import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app_entry.dart';
import 'package:interface_incendies_gironde/screens/admin_account_activation_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';

void main() {
  Widget activationApp({
    Uri? uri,
    required AdminAccountActivationService service,
    VoidCallback? onSignIn,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: AdminAccountActivationScreen(
        uri:
            uri ??
            Uri.parse(
              'https://mobsante.example/activation'
              '?mode=resetPassword&oobCode=test-code'
              '&continueUrl=https%3A%2F%2Fevil.example'
              '&lang=fr&apiKey=public-key&unknown=ignored',
            ),
        service: service,
        onSignIn: onSignIn ?? () {},
      ),
    );
  }

  test('activation path is selected with or without Firebase parameters', () {
    expect(
      isAdminActivationPath(
        Uri.parse('https://mobsante.netlify.app/activation'),
      ),
      isTrue,
    );
    expect(
      isAdminActivationPath(
        Uri.parse(
          'https://mobsante.netlify.app/activation'
          '?mode=resetPassword&oobCode=test',
        ),
      ),
      isTrue,
    );
    expect(
      isAdminActivationPath(Uri.parse('https://mobsante.netlify.app/')),
      isFalse,
    );
  });

  testWidgets('/activation selects the lightweight activation branch', (
    tester,
  ) async {
    var activationBuilds = 0;
    var standardBuilds = 0;
    await tester.pumpWidget(
      MobSanteEntry(
        uri: Uri.parse(
          'https://mobsante.example/activation'
          '?mode=resetPassword&oobCode=secret',
        ),
        activationBuilder: (_) {
          activationBuilds += 1;
          return const MaterialApp(home: Text('ACTIVATION_ONLY'));
        },
        standardBuilder: (_) {
          standardBuilds += 1;
          return const MaterialApp(home: Text('STANDARD_APP'));
        },
      ),
    );
    expect(find.text('ACTIVATION_ONLY'), findsOneWidget);
    expect(activationBuilds, 1);
    expect(standardBuilds, 0);
    expect(find.text('Missions'), findsNothing);
  });

  testWidgets('/ keeps the standard application branch', (tester) async {
    var activationBuilds = 0;
    await tester.pumpWidget(
      MobSanteEntry(
        uri: Uri.parse('https://mobsante.example/'),
        activationBuilder: (_) {
          activationBuilds += 1;
          return const SizedBox();
        },
        standardBuilder: (_) => const MaterialApp(home: Text('STANDARD_APP')),
      ),
    );
    expect(find.text('STANDARD_APP'), findsOneWidget);
    expect(activationBuilds, 0);
  });

  testWidgets('valid link displays verified read-only email', (tester) async {
    final service = _FakeActivationService();
    await tester.pumpWidget(activationApp(service: service));
    await tester.pumpAndSettle();

    expect(find.text('Définissez votre mot de passe'), findsOneWidget);
    expect(find.text('responsable@example.fr'), findsOneWidget);
    final email = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('activation-email')),
        matching: find.byType(EditableText),
      ),
    );
    expect(email.readOnly, isTrue);
    expect(find.text('test-code'), findsNothing);
    expect(find.textContaining('apiKey'), findsNothing);
    expect(find.textContaining('evil.example'), findsNothing);
  });

  testWidgets('missing code and invalid mode are rejected without Auth call', (
    tester,
  ) async {
    for (final uri in [
      Uri.parse('https://mobsante.example/activation?mode=resetPassword'),
      Uri.parse(
        'https://mobsante.example/activation?mode=verifyEmail&oobCode=code',
      ),
    ]) {
      final service = _FakeActivationService();
      await tester.pumpWidget(activationApp(uri: uri, service: service));
      await tester.pumpAndSettle();
      expect(find.text('Ce lien d’activation est invalide.'), findsOneWidget);
      expect(service.verifiedCodes, isEmpty);
    }
  });

  for (final entry in <ActivationFailure, String>{
    ActivationFailure.invalid: 'Ce lien d’activation est invalide.',
    ActivationFailure.expired: 'Ce lien d’activation a expiré.',
    ActivationFailure.alreadyUsed:
        'Ce lien a déjà été utilisé ou n’est plus valide.',
    ActivationFailure.unavailable: 'Vérification impossible',
  }.entries) {
    testWidgets('${entry.key.name} link has a clear finite state', (
      tester,
    ) async {
      final service = _FakeActivationService(verifyFailure: entry.key);
      await tester.pumpWidget(activationApp(service: service));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('test-code'), findsNothing);
    });
  }

  testWidgets('short and mismatched passwords are rejected locally', (
    tester,
  ) async {
    final service = _FakeActivationService();
    await tester.pumpWidget(activationApp(service: service));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('activation-password')),
      'court',
    );
    await tester.enterText(
      find.byKey(const Key('activation-confirmation')),
      'court',
    );
    await tester.tap(find.byKey(const Key('activate-account')));
    await tester.pump();
    expect(find.text('Utilisez au moins 8 caractères.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('activation-password')),
      'motdepasse1',
    );
    await tester.enterText(
      find.byKey(const Key('activation-confirmation')),
      'motdepasse2',
    );
    await tester.tap(find.byKey(const Key('activate-account')));
    await tester.pump();
    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
    expect(service.confirmations, isEmpty);
  });

  testWidgets('password visibility can be toggled', (tester) async {
    final service = _FakeActivationService();
    await tester.pumpWidget(activationApp(service: service));
    await tester.pumpAndSettle();

    TextField password() =>
        tester.widget(find.byKey(const Key('activation-password')));
    expect(password().obscureText, isTrue);
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.visibility_rounded).first,
    );
    await tester.pump();
    expect(password().obscureText, isFalse);
  });

  testWidgets(
    'successful activation clears password and opens login on demand',
    (tester) async {
      final service = _FakeActivationService();
      var loginOpened = false;
      await tester.pumpWidget(
        activationApp(service: service, onSignIn: () => loginOpened = true),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('activation-password')),
        'motdepasse-solide',
      );
      await tester.enterText(
        find.byKey(const Key('activation-confirmation')),
        'motdepasse-solide',
      );
      await tester.tap(find.byKey(const Key('activate-account')));
      await tester.pumpAndSettle();

      expect(find.text('Votre accès responsable est activé.'), findsOneWidget);
      expect(service.confirmations.single.code, 'test-code');
      expect(service.confirmations.single.password, 'motdepasse-solide');
      expect(find.text('motdepasse-solide'), findsNothing);
      expect(loginOpened, isFalse);

      await tester.tap(find.text('Se connecter'));
      expect(loginOpened, isTrue);
    },
  );

  testWidgets('already-used link offers the internal login action', (
    tester,
  ) async {
    var loginOpened = false;
    await tester.pumpWidget(
      activationApp(
        service: _FakeActivationService(
          verifyFailure: ActivationFailure.alreadyUsed,
        ),
        onSignIn: () => loginOpened = true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se connecter'));
    expect(loginOpened, isTrue);
  });

  testWidgets('activation stays responsive at 390 x 844', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(activationApp(service: _FakeActivationService()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('activate-account')), findsOneWidget);
  });

  testWidgets('activation button remains reachable with iPhone keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(activationApp(service: _FakeActivationService()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activation-password')));
    await tester.showKeyboard(find.byKey(const Key('activation-password')));
    await tester.ensureVisible(find.byKey(const Key('activate-account')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('activate-account')), findsOneWidget);
  });

  testWidgets('pending verification shows an explicit loading state', (
    tester,
  ) async {
    final service = _FakeActivationService(delayedVerification: true);
    await tester.pumpWidget(activationApp(service: service));
    await tester.pump();
    expect(find.text('Vérification de votre invitation…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Définissez votre mot de passe'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('confirmation failure exposes a finite retry state', (
    tester,
  ) async {
    final service = _FakeActivationService(
      confirmFailure: ActivationFailure.unavailable,
    );
    await tester.pumpWidget(activationApp(service: service));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('activation-password')),
      'mot-de-passe-solide',
    );
    await tester.enterText(
      find.byKey(const Key('activation-confirmation')),
      'mot-de-passe-solide',
    );
    await tester.tap(find.byKey(const Key('activate-account')));
    await tester.pumpAndSettle();

    expect(find.text('Vérification impossible'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('double activation submission is ignored while pending', (
    tester,
  ) async {
    final service = _FakeActivationService(delayedConfirmation: true);
    await tester.pumpWidget(activationApp(service: service));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('activation-password')),
      'mot-de-passe-solide',
    );
    await tester.enterText(
      find.byKey(const Key('activation-confirmation')),
      'mot-de-passe-solide',
    );

    await tester.tap(find.byKey(const Key('activate-account')));
    await tester.tap(find.byKey(const Key('activate-account')));
    await tester.pump();

    expect(service.confirmationAttempts, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Votre accès responsable est activé.'), findsOneWidget);
  });
}

class _Confirmation {
  const _Confirmation(this.code, this.password);
  final String code;
  final String password;
}

class _FakeActivationService implements AdminAccountActivationService {
  _FakeActivationService({
    this.verifyFailure,
    this.confirmFailure,
    this.delayedVerification = false,
    this.delayedConfirmation = false,
  });

  final ActivationFailure? verifyFailure;
  final ActivationFailure? confirmFailure;
  final bool delayedVerification;
  final bool delayedConfirmation;
  final List<String> verifiedCodes = [];
  final List<_Confirmation> confirmations = [];
  int confirmationAttempts = 0;

  @override
  Future<String> verifyPasswordResetCode(String code) async {
    verifiedCodes.add(code);
    if (delayedVerification) {
      return Future<String>.delayed(
        const Duration(seconds: 1),
        () => 'responsable@example.fr',
      );
    }
    if (verifyFailure != null) throw ActivationException(verifyFailure!);
    return 'responsable@example.fr';
  }

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    confirmationAttempts += 1;
    if (confirmFailure != null) throw ActivationException(confirmFailure!);
    if (delayedConfirmation) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    confirmations.add(_Confirmation(code, newPassword));
  }
}
