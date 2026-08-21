import '../utils/csv_export.dart';
import 'platform_actor_view_data.dart';

class PlatformActorCsvExport {
  const PlatformActorCsvExport({
    required this.fileName,
    required this.contents,
    required this.rowCount,
  });

  final String fileName;
  final String contents;
  final int rowCount;
}

abstract interface class PlatformActorCsvDownloader {
  Future<bool> download(PlatformActorCsvExport export);
}

class BrowserPlatformActorCsvDownloader implements PlatformActorCsvDownloader {
  const BrowserPlatformActorCsvDownloader();

  @override
  Future<bool> download(PlatformActorCsvExport export) =>
      exportCsvFile(fileName: export.fileName, contents: export.contents);
}

class PlatformActorCsvExportBuilder {
  const PlatformActorCsvExportBuilder();

  PlatformActorCsvExport build({
    required PlatformActorDirectoryViewData directory,
    required PlatformActorKind kind,
    required PlatformActorFilter filter,
    required DateTime generatedAt,
  }) {
    final rows = switch (kind) {
      PlatformActorKind.professional => _professionalRows(
        directory.filteredProfessionals(filter),
      ),
      PlatformActorKind.coordinator => _coordinatorRows(
        directory.filteredCoordinators(filter),
      ),
      PlatformActorKind.manager => _managerRows(
        directory.filteredManagers(filter),
      ),
    };
    final header = switch (kind) {
      PlatformActorKind.professional => const [
        'Identité',
        'Profession',
        'Territoire',
        'CPTS',
        'Opérations',
        'Engagements',
        'Nombre d’engagements actifs',
        'Statuts',
        'Établissements / sites concernés',
      ],
      PlatformActorKind.coordinator => const [
        'Identité',
        'Opérations pilotées',
        'Mobilisations',
        'État',
      ],
      PlatformActorKind.manager => const [
        'Identité',
        'Établissements / sites',
        'Territoires',
        'Opérations concernées',
        'État',
      ],
    };
    final csvRows = [header, ...rows];
    return PlatformActorCsvExport(
      fileName: _fileName(directory, kind, filter, generatedAt),
      contents: '\ufeff${csvRows.map(_csvRow).join('\r\n')}\r\n',
      rowCount: rows.length,
    );
  }
}

List<List<String>> _professionalRows(
  List<PlatformProfessionalViewData> actors,
) => actors
    .map(
      (actor) => [
        actor.displayName,
        actor.professionLabel,
        _joined([
          ...actor.participations.map((item) => item.territoryLabel),
          actor.departmentLabel,
          actor.regionLabel,
        ]),
        actor.cptsLabel ?? '',
        _joined(actor.participations.map((item) => item.operationLabel)),
        _joined(
          actor.participations.map(
            (item) => '${item.missionLabel} · ${item.statusLabel}',
          ),
        ),
        '${actor.activeParticipationCount}',
        _joined(actor.participations.map((item) => item.statusLabel)),
        _joined(actor.participations.map((item) => item.locationLabel)),
      ],
    )
    .toList(growable: false);

List<List<String>> _coordinatorRows(List<PlatformCoordinatorViewData> actors) =>
    actors
        .map(
          (actor) => [
            actor.displayName,
            _joined(actor.operations.map((item) => item.label)),
            _joined(
              actor.mobilizations.map(
                (item) =>
                    '${item.label} · ${item.active ? 'Active' : 'Inactive'}',
              ),
            ),
            actor.active ? 'Actif' : 'Inactif',
          ],
        )
        .toList(growable: false);

List<List<String>> _managerRows(List<PlatformManagerViewData> actors) => actors
    .map(
      (actor) => [
        actor.displayName,
        _joined(actor.locations.map((item) => item.label)),
        _joined(actor.territories.map((item) => item.label)),
        _joined(actor.operations.map((item) => item.label)),
        actor.active ? 'Actif' : 'Inactif',
      ],
    )
    .toList(growable: false);

String _joined(Iterable<String?> values) {
  final unique = <String>{};
  for (final value in values) {
    final text = value?.trim();
    if (text != null && text.isNotEmpty) unique.add(text);
  }
  return unique.join(' | ');
}

String _csvRow(List<String> values) => values.map(_csvCell).join(';');

String _csvCell(String value) {
  final trimmed = value.trimLeft();
  final safeValue = trimmed.startsWith(RegExp(r'[=+\-@]')) ? "'$value" : value;
  return '"${safeValue.replaceAll('"', '""')}"';
}

String _fileName(
  PlatformActorDirectoryViewData directory,
  PlatformActorKind kind,
  PlatformActorFilter filter,
  DateTime generatedAt,
) {
  final type = switch (kind) {
    PlatformActorKind.professional => 'professionnels',
    PlatformActorKind.coordinator => 'coordinateurs',
    PlatformActorKind.manager => 'responsables',
  };
  final filterParts = <String>[
    if (filter.search.trim().isNotEmpty)
      'recherche-${_slug(filter.search, maxLength: 18)}',
    if (filter.profession != null)
      'profession-${_slug(filter.profession!, maxLength: 18)}',
    if (filter.operationId != null)
      'operation-${_slug(_labelFor(directory.operations, filter.operationId!), maxLength: 18)}',
    if (filter.department != null)
      'departement-${_slug(filter.department!, maxLength: 18)}',
    if (filter.region != null) 'region-${_slug(filter.region!, maxLength: 18)}',
    if (filter.cptsId != null)
      'cpts-${_slug(_labelFor(directory.cpts, filter.cptsId!), maxLength: 18)}',
    if (filter.locationId != null)
      'site-${_slug(_labelFor(directory.locations, filter.locationId!), maxLength: 18)}',
    if (filter.participationStatus != null)
      'statut-${_slug(_statusLabel(filter.participationStatus!), maxLength: 18)}',
  ];
  final filterToken = _boundedFilterToken(filterParts);
  final date =
      '${generatedAt.year.toString().padLeft(4, '0')}-'
      '${generatedAt.month.toString().padLeft(2, '0')}-'
      '${generatedAt.day.toString().padLeft(2, '0')}';
  return 'MobSante_${type}_${filterToken}_$date.csv';
}

String _boundedFilterToken(List<String> parts) {
  if (parts.isEmpty) return 'tous';
  final token = parts.join('_');
  if (token.length <= 128) return token;
  final shortened = token.substring(0, 108).replaceFirst(RegExp(r'[-_]+$'), '');
  return '${shortened}_filtres-${parts.length}';
}

String _labelFor(List<PlatformActorReference> values, String id) {
  for (final value in values) {
    if (value.id == id) return value.label;
  }
  return id;
}

String _statusLabel(String status) => switch (status) {
  'pending' => 'en-attente',
  'confirmed' => 'confirme',
  'standby' => 'renfort',
  'cancelled' => 'annule',
  _ => status,
};

String _slug(String value, {required int maxLength}) {
  const accents = {
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
  final normalized = value
      .trim()
      .toLowerCase()
      .split('')
      .map((character) => accents[character] ?? character)
      .join();
  final slug = normalized
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) return 'filtre';
  return slug.length <= maxLength ? slug : slug.substring(0, maxLength);
}
