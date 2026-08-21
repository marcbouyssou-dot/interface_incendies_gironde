enum PlatformActorKind { professional, coordinator, manager }

extension PlatformActorKindLabel on PlatformActorKind {
  String get label => switch (this) {
    PlatformActorKind.professional => 'Professionnels',
    PlatformActorKind.coordinator => 'Coordinateurs',
    PlatformActorKind.manager => 'Responsables',
  };
}

class PlatformActorReference {
  const PlatformActorReference({required this.id, required this.label});

  final String id;
  final String label;

  factory PlatformActorReference.fromMap(Map<String, Object?> data) =>
      PlatformActorReference(
        id: _requiredText(data['id']),
        label: _requiredText(data['label']),
      );
}

class PlatformParticipationViewData {
  const PlatformParticipationViewData({
    required this.missionId,
    required this.missionLabel,
    required this.professionLabel,
    required this.status,
    this.mobilizationId,
    this.mobilizationLabel,
    this.operationId,
    this.operationLabel,
    this.locationId,
    this.locationLabel,
    this.territoryId,
    this.territoryLabel,
    this.occurredAt,
  });

  final String missionId;
  final String missionLabel;
  final String professionLabel;
  final String status;
  final String? mobilizationId;
  final String? mobilizationLabel;
  final String? operationId;
  final String? operationLabel;
  final String? locationId;
  final String? locationLabel;
  final String? territoryId;
  final String? territoryLabel;
  final DateTime? occurredAt;

  String get statusLabel => switch (status) {
    'pending' => 'En attente',
    'confirmed' => 'Confirmé',
    'standby' => 'Renfort',
    'cancelled' => 'Annulé',
    _ => 'Statut inconnu',
  };

  factory PlatformParticipationViewData.fromMap(Map<String, Object?> data) =>
      PlatformParticipationViewData(
        missionId: _requiredText(data['missionId']),
        missionLabel: _requiredText(data['missionLabel']),
        professionLabel: _requiredText(data['professionLabel']),
        status: _requiredText(data['status']),
        mobilizationId: _optionalText(data['mobilizationId']),
        mobilizationLabel: _optionalText(data['mobilizationLabel']),
        operationId: _optionalText(data['operationId']),
        operationLabel: _optionalText(data['operationLabel']),
        locationId: _optionalText(data['locationId']),
        locationLabel: _optionalText(data['locationLabel']),
        territoryId: _optionalText(data['territoryId']),
        territoryLabel: _optionalText(data['territoryLabel']),
        occurredAt: DateTime.tryParse(_optionalText(data['occurredAt']) ?? ''),
      );
}

class PlatformProfessionalViewData {
  const PlatformProfessionalViewData({
    required this.uid,
    required this.displayName,
    required this.professionLabel,
    required this.participations,
    this.cptsId,
    this.cptsLabel,
    this.departmentLabel,
    this.regionLabel,
  });

  final String uid;
  final String displayName;
  final String professionLabel;
  final String? cptsId;
  final String? cptsLabel;
  final String? departmentLabel;
  final String? regionLabel;
  final List<PlatformParticipationViewData> participations;

  int get activeParticipationCount =>
      participations.where((item) => item.status != 'cancelled').length;

  Set<String> get operationIds => participations
      .map((item) => item.operationId)
      .whereType<String>()
      .toSet();

  factory PlatformProfessionalViewData.fromMap(Map<String, Object?> data) {
    final uid = _requiredText(data['uid']);
    return PlatformProfessionalViewData(
      uid: uid,
      displayName:
          _optionalText(data['displayName']) ??
          _identityFallback('Professionnel', uid),
      professionLabel: _requiredText(data['professionLabel']),
      cptsId: _optionalText(data['cptsId']),
      cptsLabel: _optionalText(data['cptsLabel']),
      departmentLabel: _optionalText(data['departmentLabel']),
      regionLabel: _optionalText(data['regionLabel']),
      participations: _mapList(
        data['participations'],
        PlatformParticipationViewData.fromMap,
      ),
    );
  }
}

class PlatformCoordinatorMobilizationViewData extends PlatformActorReference {
  const PlatformCoordinatorMobilizationViewData({
    required super.id,
    required super.label,
    required this.active,
  });

  final bool active;

  factory PlatformCoordinatorMobilizationViewData.fromMap(
    Map<String, Object?> data,
  ) => PlatformCoordinatorMobilizationViewData(
    id: _requiredText(data['id']),
    label: _requiredText(data['label']),
    active: data['active'] == true,
  );
}

class PlatformCoordinatorViewData {
  const PlatformCoordinatorViewData({
    required this.uid,
    required this.displayName,
    required this.active,
    required this.operations,
    required this.mobilizations,
  });

  final String uid;
  final String displayName;
  final bool active;
  final List<PlatformActorReference> operations;
  final List<PlatformCoordinatorMobilizationViewData> mobilizations;

  factory PlatformCoordinatorViewData.fromMap(Map<String, Object?> data) {
    final uid = _requiredText(data['uid']);
    return PlatformCoordinatorViewData(
      uid: uid,
      displayName:
          _optionalText(data['displayName']) ??
          _identityFallback('Coordinateur', uid),
      active: data['active'] == true,
      operations: _mapList(data['operations'], PlatformActorReference.fromMap),
      mobilizations: _mapList(
        data['mobilizations'],
        PlatformCoordinatorMobilizationViewData.fromMap,
      ),
    );
  }
}

class PlatformManagerViewData {
  const PlatformManagerViewData({
    required this.uid,
    required this.displayName,
    required this.active,
    required this.locations,
    required this.operations,
    required this.territories,
  });

  final String uid;
  final String displayName;
  final bool active;
  final List<PlatformActorReference> locations;
  final List<PlatformActorReference> operations;
  final List<PlatformActorReference> territories;

  factory PlatformManagerViewData.fromMap(Map<String, Object?> data) {
    final uid = _requiredText(data['uid']);
    return PlatformManagerViewData(
      uid: uid,
      displayName:
          _optionalText(data['displayName']) ??
          _identityFallback('Responsable', uid),
      active: data['active'] == true,
      locations: _mapList(data['locations'], PlatformActorReference.fromMap),
      operations: _mapList(data['operations'], PlatformActorReference.fromMap),
      territories: _mapList(
        data['territories'],
        PlatformActorReference.fromMap,
      ),
    );
  }
}

class PlatformActorFilter {
  const PlatformActorFilter({
    this.search = '',
    this.profession,
    this.operationId,
    this.department,
    this.region,
    this.cptsId,
    this.locationId,
    this.participationStatus,
  });

  final String search;
  final String? profession;
  final String? operationId;
  final String? department;
  final String? region;
  final String? cptsId;
  final String? locationId;
  final String? participationStatus;

  int get activeCount => [
    profession,
    operationId,
    department,
    region,
    cptsId,
    locationId,
    participationStatus,
  ].whereType<String>().length;

  PlatformActorFilter copyWith({
    String? search,
    String? profession,
    bool clearProfession = false,
    String? operationId,
    bool clearOperation = false,
    String? department,
    bool clearDepartment = false,
    String? region,
    bool clearRegion = false,
    String? cptsId,
    bool clearCpts = false,
    String? locationId,
    bool clearLocation = false,
    String? participationStatus,
    bool clearStatus = false,
  }) => PlatformActorFilter(
    search: search ?? this.search,
    profession: clearProfession ? null : profession ?? this.profession,
    operationId: clearOperation ? null : operationId ?? this.operationId,
    department: clearDepartment ? null : department ?? this.department,
    region: clearRegion ? null : region ?? this.region,
    cptsId: clearCpts ? null : cptsId ?? this.cptsId,
    locationId: clearLocation ? null : locationId ?? this.locationId,
    participationStatus: clearStatus
        ? null
        : participationStatus ?? this.participationStatus,
  );
}

class PlatformActorDirectoryViewData {
  const PlatformActorDirectoryViewData({
    required this.professionals,
    required this.coordinators,
    required this.managers,
  });

  final List<PlatformProfessionalViewData> professionals;
  final List<PlatformCoordinatorViewData> coordinators;
  final List<PlatformManagerViewData> managers;

  factory PlatformActorDirectoryViewData.fromMap(Map<String, Object?> data) =>
      PlatformActorDirectoryViewData(
        professionals: _mapList(
          data['professionals'],
          PlatformProfessionalViewData.fromMap,
        ),
        coordinators: _mapList(
          data['coordinators'],
          PlatformCoordinatorViewData.fromMap,
        ),
        managers: _mapList(data['managers'], PlatformManagerViewData.fromMap),
      );

  List<PlatformProfessionalViewData> filteredProfessionals(
    PlatformActorFilter filter,
  ) => professionals
      .where((actor) {
        if (!_matchesSearch(filter.search, [
          actor.displayName,
          actor.professionLabel,
          actor.cptsLabel,
          actor.departmentLabel,
          actor.regionLabel,
          ...actor.participations.expand(
            (item) => [
              item.operationLabel,
              item.missionLabel,
              item.locationLabel,
            ],
          ),
        ])) {
          return false;
        }
        if (filter.profession != null &&
            !actor.participations.any(
              (item) => item.professionLabel == filter.profession,
            )) {
          return false;
        }
        if (filter.operationId != null &&
            !actor.participations.any(
              (item) => item.operationId == filter.operationId,
            )) {
          return false;
        }
        if (filter.department != null &&
            actor.departmentLabel != filter.department) {
          return false;
        }
        if (filter.region != null && actor.regionLabel != filter.region) {
          return false;
        }
        if (filter.cptsId != null && actor.cptsId != filter.cptsId) {
          return false;
        }
        if (filter.locationId != null &&
            !actor.participations.any(
              (item) => item.locationId == filter.locationId,
            )) {
          return false;
        }
        return filter.participationStatus == null ||
            actor.participations.any(
              (item) => item.status == filter.participationStatus,
            );
      })
      .toList(growable: false);

  List<PlatformCoordinatorViewData> filteredCoordinators(
    PlatformActorFilter filter,
  ) => coordinators
      .where((actor) {
        if (!_matchesSearch(filter.search, [
          actor.displayName,
          actor.uid,
          ...actor.operations.map((item) => item.label),
          ...actor.mobilizations.map((item) => item.label),
        ])) {
          return false;
        }
        return filter.operationId == null ||
            actor.operations.any((item) => item.id == filter.operationId);
      })
      .toList(growable: false);

  List<PlatformManagerViewData> filteredManagers(PlatformActorFilter filter) =>
      managers
          .where((actor) {
            if (!_matchesSearch(filter.search, [
              actor.displayName,
              actor.uid,
              ...actor.locations.map((item) => item.label),
              ...actor.operations.map((item) => item.label),
              ...actor.territories.map((item) => item.label),
            ])) {
              return false;
            }
            if (filter.operationId != null &&
                !actor.operations.any(
                  (item) => item.id == filter.operationId,
                )) {
              return false;
            }
            if (filter.locationId != null &&
                !actor.locations.any((item) => item.id == filter.locationId)) {
              return false;
            }
            return filter.region == null && filter.department == null ||
                actor.territories.any(
                  (item) =>
                      item.label == filter.region ||
                      item.label == filter.department,
                );
          })
          .toList(growable: false);

  List<PlatformActorReference> get operations => _uniqueReferences([
    ...professionals.expand(
      (actor) => actor.participations
          .where((item) => item.operationId != null)
          .map(
            (item) => PlatformActorReference(
              id: item.operationId!,
              label: item.operationLabel ?? 'Opération',
            ),
          ),
    ),
    ...coordinators.expand((actor) => actor.operations),
    ...managers.expand((actor) => actor.operations),
  ]);

  List<PlatformActorReference> get locations => _uniqueReferences([
    ...professionals.expand(
      (actor) => actor.participations
          .where((item) => item.locationId != null)
          .map(
            (item) => PlatformActorReference(
              id: item.locationId!,
              label: item.locationLabel ?? 'Établissement',
            ),
          ),
    ),
    ...managers.expand((actor) => actor.locations),
  ]);

  List<String> get professions => _sortedUnique(
    professionals.expand(
      (actor) => actor.participations.map((item) => item.professionLabel),
    ),
  );
  List<String> get departments => _sortedUnique(
    professionals.map((actor) => actor.departmentLabel).whereType<String>(),
  );
  List<String> get regions => _sortedUnique([
    ...professionals.map((actor) => actor.regionLabel).whereType<String>(),
    ...managers.expand((actor) => actor.territories.map((item) => item.label)),
  ]);
  List<PlatformActorReference> get cpts => _uniqueReferences(
    professionals
        .where((actor) => actor.cptsId != null)
        .map(
          (actor) => PlatformActorReference(
            id: actor.cptsId!,
            label: actor.cptsLabel ?? 'CPTS',
          ),
        ),
  );
}

bool _matchesSearch(String search, Iterable<String?> values) {
  final query = search.trim().toLowerCase();
  if (query.isEmpty) return true;
  return values.whereType<String>().any(
    (value) => value.toLowerCase().contains(query),
  );
}

List<T> _mapList<T>(Object? value, T Function(Map<String, Object?>) parse) {
  if (value is! List) throw const FormatException('Annuaire invalide.');
  return value.map((item) => parse(_map(item))).toList(growable: false);
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) throw const FormatException('Annuaire invalide.');
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _requiredText(Object? value) {
  final text = _optionalText(value);
  if (text == null) throw const FormatException('Annuaire invalide.');
  return text;
}

String? _optionalText(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

String _identityFallback(String role, String uid) {
  final suffix = uid.length <= 8 ? uid : uid.substring(0, 8);
  return '$role · $suffix';
}

List<String> _sortedUnique(Iterable<String> values) =>
    values.toSet().toList(growable: false)..sort();

List<PlatformActorReference> _uniqueReferences(
  Iterable<PlatformActorReference> values,
) {
  final byId = <String, PlatformActorReference>{
    for (final value in values) value.id: value,
  };
  return byId.values.toList(growable: false)
    ..sort((left, right) => left.label.compareTo(right.label));
}
