import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/screens/about_screen.dart';
import 'package:interface_incendies_gironde/screens/diagnostic_push_registration_screen.dart';
import 'package:interface_incendies_gironde/services/web_push_diagnostics_stub.dart'
    as stub_diagnostics;

void main() {
  test('non-web installation lookup stays absent and read-only', () {
    expect(stub_diagnostics.peekInstallationId(), isNull);
    expect(stub_diagnostics.peekInstallationId(), isNull);
  });

  testWidgets('absent installation is displayed literally as ABSENT', (
    tester,
  ) async {
    var calls = 0;
    await _pumpScreen(
      tester,
      reader: () async {
        calls += 1;
        return _diagnostics(installationId: null);
      },
    );

    expect(calls, 1);
    expect(_jsonText(tester), contains('"installationId": "ABSENT"'));
    expect(find.byKey(const Key('push-subscription-state')), findsNothing);
  });

  testWidgets('existing installation is displayed unchanged', (tester) async {
    await _pumpScreen(
      tester,
      reader: () async => _diagnostics(installationId: 'installation-existing'),
    );

    expect(
      _jsonText(tester),
      contains('"installationId": "installation-existing"'),
    );
  });

  testWidgets('reader contract cannot invoke forbidden mutation APIs', (
    tester,
  ) async {
    final reader = _StrictlyReadOnlyReader();
    await _pumpScreen(tester, reader: reader.call);

    // The injected contract exposes only call(). It cannot structurally reach
    // activate, renewRegistration, requestPermission, register, unregister or
    // getToken; the throwing methods below make any accidental test use fail.
    expect(reader.forbiddenCalls, 0);
    expect(_jsonText(tester), contains('"installationId": "ABSENT"'));
  });

  testWidgets('null controller and empty registrations remain JSON values', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      reader: () async => _diagnostics(installationId: 'ABSENT'),
    );

    final json = _jsonText(tester);
    expect(json, contains('"serviceWorkerController": null'));
    expect(json, contains('"serviceWorkerRegistrations": []'));
  });

  testWidgets('active service worker registration is visible', (tester) async {
    await _pumpScreen(
      tester,
      reader: () async => _diagnostics(
        installationId: 'ABSENT',
        registrations: const [
          {
            'scope': 'https://mobsante.example/app/',
            'active': 'https://mobsante.example/firebase-messaging-sw.js',
            'waiting': null,
            'installing': null,
          },
        ],
      ),
    );

    final json = _jsonText(tester);
    expect(json, contains('https://mobsante.example/app/'));
    expect(json, contains('https://mobsante.example/firebase-messaging-sw.js'));
  });

  testWidgets('Relire l’état invokes only the injected reader again', (
    tester,
  ) async {
    final reader = _StrictlyReadOnlyReader();
    await _pumpScreen(tester, reader: reader.call);
    expect(reader.calls, 1);

    await tester.tap(find.text('Relire l’état'));
    await tester.pumpAndSettle();

    expect(reader.calls, 2);
    expect(reader.forbiddenCalls, 0);
  });

  testWidgets('About link opens the Push diagnostic screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));

    final link = find.byKey(const Key('about-push-diagnostic-link'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(find.byType(DiagnosticPushRegistrationScreen), findsOneWidget);
    expect(find.text('Diagnostic Push'), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Future<Map<String, dynamic>> Function() reader,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DiagnosticPushRegistrationScreen(diagnosticsReader: reader),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _diagnostics({
  required Object? installationId,
  Map<String, dynamic>? controller,
  List<Map<String, String?>> registrations = const [],
}) => {
  'origin': 'https://mobsante.example',
  'installationId': installationId,
  'notificationPermission': 'granted',
  'standalone': true,
  'navigatorStandalone': null,
  'serviceWorkerController': controller,
  'serviceWorkerRegistrations': registrations,
};

String _jsonText(WidgetTester tester) =>
    tester.widget<SelectableText>(find.byType(SelectableText)).data!;

class _StrictlyReadOnlyReader {
  int calls = 0;
  int forbiddenCalls = 0;

  Future<Map<String, dynamic>> call() async {
    calls += 1;
    return _diagnostics(installationId: 'ABSENT');
  }

  Never activate() => _forbidden('activate');
  Never renewRegistration() => _forbidden('renewRegistration');
  Never requestPermission() => _forbidden('requestPermission');
  Never register() => _forbidden('register');
  Never unregister() => _forbidden('unregister');
  Never getToken() => _forbidden('getToken');

  Never _forbidden(String method) {
    forbiddenCalls += 1;
    throw StateError('$method is forbidden in read-only diagnostics');
  }
}
