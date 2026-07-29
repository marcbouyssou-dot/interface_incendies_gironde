class LocationImportRow {
  const LocationImportRow({
    required this.id,
    required this.name,
    required this.group,
    required this.type,
    required this.status,
    required this.addressFields,
  });

  final String id;
  final String name;
  final String group;
  final String type;
  final String status;
  final Map<String, Object?> addressFields;

  bool get isValidated =>
      status == 'verified_official' || status == 'verified_cross_source';
}

class LocationImportDocument {
  const LocationImportDocument({
    required this.id,
    required this.name,
    required this.group,
    required this.type,
  });

  final String id;
  final String name;
  final String group;
  final String type;
}

class LocationAddressPatch {
  const LocationAddressPatch({required this.id, required this.fields});
  final String id;
  final Map<String, Object?> fields;
}

abstract interface class LocationAddressImportStore {
  Future<List<LocationImportDocument>> readLocations();
  Future<void> backupLocations();
  Future<void> applyAddressPatches(List<LocationAddressPatch> patches);
}

class LocationAddressImportService {
  const LocationAddressImportService(this.store);

  final LocationAddressImportStore store;

  Future<List<LocationAddressPatch>> run({
    required List<LocationImportRow> rows,
    required bool dryRun,
  }) async {
    final documents = await store.readLocations();
    final byId = {for (final document in documents) document.id: document};
    final unknown = rows.where((row) => !byId.containsKey(row.id)).toList();
    if (unknown.isNotEmpty) {
      throw StateError(
        'Identifiants inconnus : ${unknown.map((row) => row.id).join(', ')}',
      );
    }
    final patches = rows
        .where((row) => row.isValidated)
        .map((row) {
          final document = byId[row.id]!;
          if (row.name != document.name ||
              row.group != document.group ||
              row.type != document.type) {
            throw StateError('Métadonnées divergentes pour ${row.id}');
          }
          return LocationAddressPatch(
            id: row.id,
            fields: Map.unmodifiable(row.addressFields),
          );
        })
        .toList(growable: false);
    if (!dryRun) {
      await store.backupLocations();
      await store.applyAddressPatches(patches);
    }
    return patches;
  }
}
