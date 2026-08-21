import '../models/need.dart';
import '../utils/switch_latest.dart';
import 'coordination_repository.dart';
import 'platform_read_repository.dart';

/// Projection des missions bornée aux mobilisations de l'organisation active.
///
/// La résolution organisationnelle, y compris le fallback des mobilisations
/// RC3 sans `operationId`, reste exclusivement portée par
/// [PlatformReadRepository]. Ce repository ne reçoit donc jamais un identifiant
/// de mobilisation appartenant à une autre organisation.
class OrganizationScopedMissionReadRepository
    implements
        MultiMobilizationCoordinationReadRepository,
        MissionAccessReadRepository {
  const OrganizationScopedMissionReadRepository({
    required MultiMobilizationCoordinationReadRepository delegate,
    required PlatformReadRepository platformRepository,
    required Future<CoordinationNeed?> Function(String missionId) missionLookup,
  }) : _delegate = delegate,
       _platformRepository = platformRepository,
       _missionLookup = missionLookup;

  final MultiMobilizationCoordinationReadRepository _delegate;
  final PlatformReadRepository _platformRepository;
  final Future<CoordinationNeed?> Function(String missionId) _missionLookup;

  @override
  Stream<CoordinationNeed?> watchAccessibleMission(String missionId) async* {
    if (!_isValidDocumentId(missionId)) {
      yield null;
      return;
    }
    final mission = await _missionLookup(missionId);
    final mobilizationId = mission?.mobilizationId;
    if (mission == null ||
        mission.id != missionId ||
        !mission.isActive ||
        mobilizationId == null ||
        !_isValidDocumentId(mobilizationId)) {
      yield null;
      return;
    }
    yield* _platformRepository
        .watchMobilizations(includeInactive: true)
        .map(
          (mobilizations) =>
              mobilizations.any(
                (mobilization) => mobilization.id == mobilizationId,
              )
              ? mission
              : null,
        );
  }

  @override
  Stream<List<CoordinationNeed>> watchAllActiveMissions() =>
      switchLatest(_platformRepository.watchMobilizations(), (mobilizations) {
        final accessibleIds = mobilizations
            .map((mobilization) => mobilization.id)
            .toSet();
        if (accessibleIds.isEmpty) {
          return Stream<List<CoordinationNeed>>.value(const []);
        }
        // Le flux public actif reste requis par les previews Administrateur :
        // leur identité réelle ne peut pas emprunter les lectures Responsable.
        return _delegate.watchAllActiveMissions().map(
          (missions) => _filterMissions(missions, accessibleIds),
        );
      });

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> mobilizationIds,
  ) {
    if (mobilizationIds.isEmpty) {
      return Stream<List<CoordinationNeed>>.value(const []);
    }
    return switchLatest(
      _platformRepository.watchMobilizations(includeInactive: true),
      (mobilizations) {
        final accessibleIds = mobilizations
            .map((mobilization) => mobilization.id)
            .where(mobilizationIds.contains)
            .toSet();
        return _watchMissionsForAccessibleMobilizations(accessibleIds);
      },
    );
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForLocations(
    Set<String> locationIds,
  ) {
    if (locationIds.isEmpty) {
      return Stream<List<CoordinationNeed>>.value(const []);
    }
    return switchLatest(
      _platformRepository.watchMobilizations(),
      (mobilizations) =>
          _watchMissionsForAccessibleMobilizations(
            mobilizations.map((mobilization) => mobilization.id).toSet(),
          ).map(
            (missions) => List<CoordinationNeed>.unmodifiable(
              missions.where(
                (mission) =>
                    mission.locationId != null &&
                    locationIds.contains(mission.locationId),
              ),
            ),
          ),
    );
  }

  Stream<List<CoordinationNeed>> _watchMissionsForAccessibleMobilizations(
    Set<String> mobilizationIds,
  ) {
    if (mobilizationIds.isEmpty) {
      return Stream<List<CoordinationNeed>>.value(const []);
    }
    return _delegate
        .watchMissionsForMobilizations(mobilizationIds)
        .map((missions) => _filterMissions(missions, mobilizationIds));
  }

  List<CoordinationNeed> _filterMissions(
    List<CoordinationNeed> missions,
    Set<String> mobilizationIds,
  ) => List<CoordinationNeed>.unmodifiable(
    missions.where(
      (mission) => mobilizationIds.contains(mission.mobilizationId),
    ),
  );

  bool _isValidDocumentId(String value) =>
      value.isNotEmpty && value.trim() == value && !value.contains('/');
}
