import 'dart:io';

const _header = [
  'location_id',
  'name',
  'display_name',
  'territorial_group',
  'previous_location_type',
  'location_type',
  'is_operational',
  'address_line_1',
  'address_line_2',
  'postal_code',
  'city',
  'country',
  'full_address',
  'latitude',
  'longitude',
  'address_status',
  'source_label',
  'source_url',
  'second_source_label',
  'second_source_url',
  'verified_at',
  'notes',
];

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/import_location_source.dart <source.md>',
    );
    exitCode = 64;
    return;
  }
  final source = File(arguments.single);
  if (!source.existsSync()) {
    stderr.writeln('Source introuvable : ${source.path}');
    exitCode = 66;
    return;
  }
  final records = <List<String>>[];
  for (final line in source.readAsLinesSync()) {
    if (!line.startsWith('| SDIS33-')) continue;
    final cells = line
        .substring(1, line.length - 1)
        .split('|')
        .map((cell) => cell.trim())
        .toList();
    if (cells.length != 15) {
      throw FormatException('Ligne Markdown invalide (${cells.length})');
    }
    final sourceId = cells[0];
    if (sourceId == 'SDIS33-HG-PAUILLAC-DUP') continue;
    final sourceName = cells[1];
    final currentName = sourceId == 'SDIS33-SPECIAL-CROIXROUGE'
        ? 'Croix-Rouge Bordeaux'
        : sourceName;
    final group = _groupFor(sourceId);
    final previousType = sourceId == 'SDIS33-SPECIAL-PARCEXPO'
        ? 'civilianReceptionSite'
        : sourceId == 'SDIS33-SPECIAL-CROIXROUGE'
        ? 'redCross'
        : 'sdisStation';
    final isSector =
        cells[2] == 'Secteur sans CIS autonome' || cells[10] == 'not_found';
    final targetType = isSector ? 'interventionSector' : previousType;
    final addressLine1 = _nullableValue(cells[3]);
    final addressLine2 = _nullableValue(cells[4]);
    final postalCode = _nullableValue(cells[5]);
    final fullAddress = _nullableValue(cells[7]);
    final source1 = _link(cells[11]);
    final source2 = _link(cells[12]);
    records.add([
      _stableId(group, currentName),
      currentName,
      sourceName,
      group,
      previousType,
      targetType,
      (!isSector).toString(),
      addressLine1,
      addressLine2,
      postalCode,
      _nullableValue(cells[6]),
      'France',
      fullAddress,
      _nullableValue(cells[8]),
      _nullableValue(cells[9]),
      cells[10],
      source1.label,
      source1.url,
      source2.label,
      source2.url,
      _nullableValue(cells[13]),
      cells[14],
    ]);
  }
  if (records.length != 65) {
    throw StateError('65 lieux uniques attendus, ${records.length} obtenus.');
  }
  final output = StringBuffer()..writeln(_header.map(_csv).join(','));
  for (final record in records) {
    output.writeln(record.map(_csv).join(','));
  }
  File('data/locations_verified.csv').writeAsStringSync(output.toString());
  stdout.writeln(
    '65 lieux importés; doublon Haute Gironde/Pauillac explicitement ignoré.',
  );
}

({String label, String url}) _link(String value) {
  final match = RegExp(r'^\[(.*)\]\((https?://.*)\)$').firstMatch(value);
  if (match == null) return (label: '', url: '');
  return (label: match.group(1)!, url: match.group(2)!);
}

String _nullableValue(String value) {
  return value == 'needs_confirmation' || value == 'not_found' ? '' : value;
}

String _groupFor(String id) {
  if (id.startsWith('SDIS33-BM-')) return 'bordeauxMetropole';
  if (id.startsWith('SDIS33-NB-')) return 'northBasin';
  if (id.startsWith('SDIS33-SB-')) return 'southBasin';
  if (id.startsWith('SDIS33-MED-')) return 'medoc';
  if (id.startsWith('SDIS33-SG-')) return 'southGironde';
  if (id.startsWith('SDIS33-LIB-')) return 'libournais';
  if (id.startsWith('SDIS33-HG-')) return 'hauteGironde';
  if (id.startsWith('SDIS33-SPECIAL-')) return 'partnerSites';
  throw FormatException('Groupe inconnu pour $id');
}

String _stableId(String group, String name) {
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

String _csv(String value) => '"${value.replaceAll('"', '""')}"';
