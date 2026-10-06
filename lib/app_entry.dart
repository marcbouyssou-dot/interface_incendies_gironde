import 'package:flutter/material.dart';

import 'app.dart';
import 'dev/role_preview.dart';
import 'firebase_bootstrap.dart';
import 'firebase_startup_gate.dart';
import 'repositories/mock_coordination_repository.dart';
import 'repositories/recipe_admin_runtime.dart';
import 'screens/admin_account_activation_screen.dart';

bool isAdminActivationPath(Uri uri) =>
    uri.path == '/activation' || uri.path == '/activation/';

class MobSanteEntry extends StatelessWidget {
  const MobSanteEntry({
    super.key,
    required this.uri,
    this.activationBuilder,
    this.standardBuilder,
  });

  final Uri uri;
  final WidgetBuilder? activationBuilder;
  final WidgetBuilder? standardBuilder;

  @override
  Widget build(BuildContext context) {
    if (isAdminActivationPath(uri)) {
      return activationBuilder?.call(context) ??
          AdminAccountActivationApp(uri: uri);
    }
    return standardBuilder?.call(context) ??
        (FirebaseBootstrap.enabled
            ? FirebaseStartupGate(
                initialNotificationId: uri.queryParameters['notification'],
              )
            : FireCoordinationApp(
                repository: recipeModeEnabled
                    ? RecipeAdminCoordinationRepository.instance
                    : MockCoordinationRepository.instance,
                platformRuntime: recipeModeEnabled
                    ? RecipeAdminRuntime.instance
                    : null,
                initialNotificationId: uri.queryParameters['notification'],
              ));
  }
}
