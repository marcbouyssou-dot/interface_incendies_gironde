import 'package:flutter/material.dart';

import 'app_entry.dart';
import 'utils/system_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MobSanteEntry(uri: Uri.base));
  WidgetsBinding.instance.addPostFrameCallback((_) => markFlutterFirstFrame());
}
