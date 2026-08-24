import 'dart:convert';

import 'package:crypto/crypto.dart';

String diffusionIdForNeed(String needId) {
  if (needId.trim().isEmpty ||
      needId.trim() != needId ||
      needId.length > 180 ||
      needId.contains('/')) {
    throw const FormatException('Identifiant Besoin invalide.');
  }
  return sha256.convert(utf8.encode('diffusion:$needId')).toString();
}
