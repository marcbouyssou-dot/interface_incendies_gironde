import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/services/location_address_import_service.dart';

void main() {
  const existing = LocationImportDocument(
    id: 'site-a',
    name: 'Site A',
    group: 'medoc',
    type: 'sdisStation',
  );
  const verified = LocationImportRow(
    id: 'site-a',
    name: 'Site A',
    group: 'medoc',
    type: 'sdisStation',
    status: 'verified_official',
    addressFields: {'fullAddress': '1 rue Test'},
  );

  test('dry-run reports validated changes without writing', () async {
    final store = _MemoryStore([existing]);
    final patches = await LocationAddressImportService(
      store,
    ).run(rows: [verified], dryRun: true);
    expect(patches, hasLength(1));
    expect(store.backups, 0);
    expect(store.writes, 0);
  });

  test('a non-validated row is ignored', () async {
    final store = _MemoryStore([existing]);
    final patches = await LocationAddressImportService(store).run(
      rows: [
        const LocationImportRow(
          id: 'site-a',
          name: 'Site A',
          group: 'medoc',
          type: 'sdisStation',
          status: 'needs_confirmation',
          addressFields: {},
        ),
      ],
      dryRun: true,
    );
    expect(patches, isEmpty);
  });

  test('an unknown identifier blocks the complete import', () async {
    final store = _MemoryStore([existing]);
    expect(
      () => LocationAddressImportService(store).run(
        rows: [
          const LocationImportRow(
            id: 'unknown',
            name: 'X',
            group: 'medoc',
            type: 'sdisStation',
            status: 'verified_official',
            addressFields: {},
          ),
        ],
        dryRun: true,
      ),
      throwsStateError,
    );
  });

  test('name, group and type cannot diverge', () async {
    final store = _MemoryStore([existing]);
    for (final row in [
      const LocationImportRow(
        id: 'site-a',
        name: 'Changed',
        group: 'medoc',
        type: 'sdisStation',
        status: 'verified_official',
        addressFields: {},
      ),
      const LocationImportRow(
        id: 'site-a',
        name: 'Site A',
        group: 'other',
        type: 'sdisStation',
        status: 'verified_official',
        addressFields: {},
      ),
      const LocationImportRow(
        id: 'site-a',
        name: 'Site A',
        group: 'medoc',
        type: 'other',
        status: 'verified_official',
        addressFields: {},
      ),
    ]) {
      expect(
        () =>
            LocationAddressImportService(store).run(rows: [row], dryRun: true),
        throwsStateError,
      );
    }
  });
}

class _MemoryStore implements LocationAddressImportStore {
  _MemoryStore(this.documents);

  final List<LocationImportDocument> documents;
  int backups = 0;
  int writes = 0;

  @override
  Future<void> applyAddressPatches(List<LocationAddressPatch> patches) async {
    writes++;
  }

  @override
  Future<void> backupLocations() async {
    backups++;
  }

  @override
  Future<List<LocationImportDocument>> readLocations() async => documents;
}
