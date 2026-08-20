import 'package:flutter/material.dart';

abstract final class OperationalMapConfig {
  static const lightStyleUrl = String.fromEnvironment(
    'MAPLIBRE_STYLE_URL',
    defaultValue: 'https://demotiles.maplibre.org/style.json',
  );
  static const darkStyleUrl = String.fromEnvironment('MAPLIBRE_DARK_STYLE_URL');

  static String styleFor(Brightness brightness) {
    if (brightness == Brightness.dark && darkStyleUrl.trim().isNotEmpty) {
      return darkStyleUrl.trim();
    }
    return lightStyleUrl.trim().isEmpty
        ? neutralStyle(brightness)
        : lightStyleUrl.trim();
  }

  static String neutralStyle(Brightness brightness) {
    final color = brightness == Brightness.dark ? '#172231' : '#E9EDF2';
    return '''
{
  "version": 8,
  "name": "MobSante operational map fallback",
  "sources": {},
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {"background-color": "$color"}
    }
  ]
}
''';
  }
}
