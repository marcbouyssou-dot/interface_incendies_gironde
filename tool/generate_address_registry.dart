import 'dart:convert';
import 'dart:io';

void main() {
  final rows = _parseCsv(
    File('data/locations_verified.csv').readAsStringSync(),
  );
  final header = rows.removeAt(0);
  final records = rows
      .map(
        (values) => {
          for (var index = 0; index < header.length; index++)
            header[index]: values[index],
        },
      )
      .toList();
  final output = StringBuffer()
    ..writeln('// GENERATED FILE — DO NOT EDIT BY HAND.')
    ..writeln('// Source: data/locations_verified.csv')
    ..writeln()
    ..writeln("import '../models/need.dart';")
    ..writeln()
    ..writeln('class VerifiedLocationRecord {')
    ..writeln('  const VerifiedLocationRecord({')
    ..writeln('    required this.currentName,')
    ..writeln('    required this.displayName,')
    ..writeln('    required this.type,')
    ..writeln('    required this.isOperational,')
    ..writeln('    required this.address,')
    ..writeln('  });')
    ..writeln('  final String currentName;')
    ..writeln('  final String displayName;')
    ..writeln('  final ResponsePlaceType type;')
    ..writeln('  final bool isOperational;')
    ..writeln('  final LocationAddress address;')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'final verifiedLocationRegistry = <String, VerifiedLocationRecord>{',
    );
  for (final row in records) {
    output
      ..writeln("  ${_dart(row['name']!)}: VerifiedLocationRecord(")
      ..writeln('    currentName: ${_dart(row['name']!)},')
      ..writeln('    displayName: ${_dart(row['display_name']!)},')
      ..writeln('    type: ResponsePlaceType.${row['location_type']},')
      ..writeln("    isOperational: ${row['is_operational']},")
      ..writeln('    address: LocationAddress(')
      ..writeln('      addressLine1: ${_nullable(row['address_line_1']!)},')
      ..writeln('      addressLine2: ${_nullable(row['address_line_2']!)},')
      ..writeln('      postalCode: ${_nullable(row['postal_code']!)},')
      ..writeln('      city: ${_nullable(row['city']!)},')
      ..writeln("      country: ${_dart(row['country']!)},")
      ..writeln('      storedFullAddress: ${_nullable(row['full_address']!)},')
      ..writeln('      latitude: ${_number(row['latitude']!)},')
      ..writeln('      longitude: ${_number(row['longitude']!)},')
      ..writeln(
        '      status: AddressStatus.${_status(row['address_status']!)},',
      )
      ..writeln('      sourceLabel: ${_nullable(row['source_label']!)},')
      ..writeln('      sourceUrl: ${_nullable(row['source_url']!)},')
      ..writeln(
        '      secondSourceLabel: ${_nullable(row['second_source_label']!)},',
      )
      ..writeln(
        '      secondSourceUrl: ${_nullable(row['second_source_url']!)},',
      )
      ..writeln('      verifiedAt: ${_date(row['verified_at']!)},')
      ..writeln('      notes: ${_nullable(row['notes']!)},')
      ..writeln('    ),')
      ..writeln('  ),');
  }
  output.writeln('};');
  File(
    'lib/data/location_address_registry.dart',
  ).writeAsStringSync(output.toString());
  stdout.writeln('${records.length} adresses générées.');
}

String _status(String value) => switch (value) {
  'verified_official' => 'verifiedOfficial',
  'verified_cross_source' => 'verifiedCrossSource',
  'needs_confirmation' => 'needsConfirmation',
  'not_found' => 'notFound',
  _ => throw FormatException('Statut inconnu : $value'),
};

String _nullable(String value) => value.isEmpty ? 'null' : _dart(value);
String _number(String value) => value.isEmpty ? 'null' : value;
String _date(String value) =>
    value.isEmpty ? 'null' : "DateTime.utc(${value.split('-').join(', ')})";
String _dart(String value) => jsonEncode(value);

List<List<String>> _parseCsv(String input) {
  final result = <List<String>>[];
  var row = <String>[];
  var field = '';
  var quoted = false;
  for (var index = 0; index < input.length; index++) {
    final char = input[index];
    if (quoted && char == '"' && input[index + 1] == '"') {
      field += '"';
      index++;
    } else if (char == '"') {
      quoted = !quoted;
    } else if (!quoted && char == ',') {
      row.add(field);
      field = '';
    } else if (!quoted && (char == '\n' || char == '\r')) {
      if (char == '\r' && input[index + 1] == '\n') index++;
      row.add(field);
      if (row.any((value) => value.isNotEmpty)) result.add(row);
      row = <String>[];
      field = '';
    } else {
      field += char;
    }
  }
  return result;
}
