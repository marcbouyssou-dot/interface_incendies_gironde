import 'dart:io';

import 'package:interface_incendies_gironde/data/mock_data.dart';

String csv(String value) => '"${value.replaceAll('"', '""')}"';

void main() {
  final output = StringBuffer(
    'location_id,name,territorial_group,location_type,address_line_1,'
    'address_line_2,postal_code,city,country,full_address,latitude,longitude,'
    'address_status,source_label,source_url,second_source_url,verified_at,notes\n',
  );
  for (final place in places) {
    final isPark = place.id == 'parc-expositions-bordeaux';
    final isRedCross = place.id == 'croix-rouge-bordeaux';
    final values = <String>[
      stableId(place.group.name, place.name),
      place.name,
      place.group.name,
      place.type.name,
      if (isPark) 'Cours Jules Ladoumègue' else '',
      '',
      if (isPark) '33300' else '',
      if (isPark) 'Bordeaux' else '',
      'France',
      if (isPark) 'Cours Jules Ladoumègue, 33300 Bordeaux, France' else '',
      '',
      '',
      if (isPark)
        'verified_official'
      else if (isRedCross)
        'needs_confirmation'
      else
        'not_found',
      if (isPark)
        'Ville de Bordeaux'
      else if (isRedCross)
        'Croix-Rouge française'
      else
        '',
      if (isPark)
        'https://www.bordeaux.fr/agenda/le-triathlon-de-bordeaux'
      else if (isRedCross)
        'https://www.croix-rouge.fr/unite-locale-de-bordeaux'
      else
        '',
      '',
      if (isPark) '2026-07-29' else '',
      if (isPark)
        'Adresse publique officielle. Entrée opérationnelle à confirmer.'
      else if (isRedCross)
        'Plusieurs implantations sont mentionnées; le site opérationnel attendu doit être confirmé.'
      else
        'Recherche officielle à poursuivre avec le SDIS 33 ou la commune.',
    ];
    output.writeln(values.map(csv).join(','));
  }
  Directory('data').createSync(recursive: true);
  File('data/locations_verified.csv').writeAsStringSync(output.toString());
}

String stableId(String group, String name) {
  var normalized = '$group-$name'.toLowerCase();
  const replacements = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ÿ': 'y',
    'œ': 'oe',
  };
  for (final entry in replacements.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}
