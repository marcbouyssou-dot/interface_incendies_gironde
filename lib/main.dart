import 'package:flutter/material.dart';

import 'app_entry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MobSanteEntry(uri: Uri.base));
}
