import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/responsible_access.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_runtime.dart';
import 'package:interface_incendies_gironde/screens/create_need_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';

void main() {
  testWidgets(
    'site login uses the responsible auth path and can be cancelled',
    (tester) async {
      final repository = _LoginRepository();
      var cancelled = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ResponsibleLogin(
              repository: repository,
              allowPlatformAdministrator: false,
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('manager-email')),
        'responsable@example.test',
      );
      await tester.enterText(find.byKey(const Key('manager-password')), 'test');
      await tester.tap(find.byKey(const Key('manager-sign-in')));
      await tester.pumpAndSettle();
      expect(repository.responsibleCalls, 1);
      expect(repository.platformCalls, 0);
      await tester.tap(find.byKey(const Key('responsible-login-cancel')));
      expect(cancelled, isTrue);
    },
  );
}

class _LoginRepository extends MockCoordinationRepository
    implements PlatformAccountAuthenticator {
  _LoginRepository() : super(responsibleAccess: null);

  int responsibleCalls = 0;
  int platformCalls = 0;

  @override
  Future<ResponsibleAccess> signInResponsible({
    required String email,
    required String password,
  }) async {
    responsibleCalls++;
    return const ResponsibleAccess(
      uid: 'manager',
      role: ResponsibleRole.siteManager,
      locationIds: {'site'},
      active: true,
    );
  }

  @override
  Future<void> signInPlatformOrResponsible({
    required String email,
    required String password,
  }) async {
    platformCalls++;
  }
}
