import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_bootstrap.dart';
import 'firebase_startup_gate.dart';
import 'repositories/mock_coordination_repository.dart';
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
            ? const FirebaseStartupGate()
            : FireCoordinationApp(
                repository: MockCoordinationRepository.instance,
              ));
  }
}
