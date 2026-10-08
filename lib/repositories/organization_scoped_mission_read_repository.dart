import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/need.dart';
import '../models/mobilization.dart';
import '../models/organization_context.dart';
import '../models/organization_role.dart';
import '../utils/switch_latest.dart';
import '../utils/value_listenable_stream.dart';
import 'coordination_repository.dart';
import 'operation_access_read_repository.dart';
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
        HistoricalMobilizationMissionReadRepository,
        MobilizationLocationMissionReadRepository,
        MissionAccessReadRepository {
  const OrganizationScopedMissionReadRepository({
    required MultiMobilizationCoordinationReadRepository delegate,
    required PlatformReadRepository platformRepository,
    required Future<CoordinationNeed?> Function(String missionId) missionLookup,
    ValueListenable<OrganizationContext?>? context,
    OperationAccessReadRepository accessRepository =
        const EmptyOperationAccessReadRepository(),
  }) : _delegate = delegate,
       _platformRepository = platformRepository,
       _missionLookup = missionLookup,
       _context = context,
       _accessRepository = accessRepository;

  final MultiMobilizationCoordinationReadRepository _delegate;
  final PlatformReadRepository _platformRepository;
  final Future<CoordinationNeed?> Function(String missionId) _missionLookup;
  final ValueListenable<OrganizationContext?>? _context;
  final OperationAccessReadRepository _accessRepository;

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
    final platformRepository = _platformRepository;
    if (platformRepository is MobilizationLookupRepository) {
      yield* (platformRepository as MobilizationLookupRepository)
          .watchMobilization(mobilizationId)
          .map((mobilization) => mobilization == null ? null : mission);
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
        if (_context?.value?.hasActiveMembership == true) {
          return switchLatest(_watchGrants(), (grants) {
            final accessibleIds = _coordinatorMobilizationIds(
              mobilizations,
              grants,
            );
            return _watchMissionsForAccessibleMobilizations(accessibleIds);
          });
        }
        final accessibleIds = mobilizations
            .map((mobilization) => mobilization.id)
            .toSet();
        if (accessibleIds.isEmpty) {
          return Stream<List<CoordinationNeed>>.value(const []);
        }
        return _delegate
            .watchMissionsForMobilizations(accessibleIds)
            .map((missions) => _filterMissions(missions, accessibleIds));
      });

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> mobilizationIds,
  ) {
    if (mobilizationIds.isEmpty) {
      return Stream<List<CoordinationNeed>>.value(const []);
    }
    if (_context?.value?.hasActiveMembership == true) {
      return switchLatest(
        _platformRepository.watchMobilizations(),
        (mobilizations) => switchLatest(
          _watchGrants(),
          (grants) => _watchMissionsForAccessibleMobilizations(
            _coordinatorMobilizationIds(
              mobilizations,
              grants,
            ).intersection(mobilizationIds),
          ),
        ),
      );
    }
    final platformRepository = _platformRepository;
    if (platformRepository is MobilizationLookupRepository) {
      // Lecture unitaire : un Coordinateur affecté ne peut pas lister toute la
      // collection `mobilizations` (règle `list`), mais peut lire chacune de
      // ses mobilisations. Un identifiant non lisible est simplement exclu.
      return switchLatest(
        _watchReadableMobilizationIds(
          platformRepository as MobilizationLookupRepository,
          mobilizationIds,
        ),
        _watchMissionsForAccessibleMobilizations,
      );
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
  Stream<List<CoordinationNeed>> watchHistoricalMissionsForMobilizations(
    Set<String> mobilizationIds,
  ) {
    final delegate = _delegate;
    final platformRepository = _platformRepository;
    if (delegate is! HistoricalMobilizationMissionReadRepository ||
        platformRepository is! MobilizationLookupRepository) {
      return Stream.error(StateError('Historique des missions indisponible.'));
    }
    return switchLatest(
      _watchReadableMobilizationIds(
        platformRepository as MobilizationLookupRepository,
        mobilizationIds,
      ),
      (readableIds) => readableIds.isEmpty
          ? Stream<List<CoordinationNeed>>.value(const [])
          : (delegate as HistoricalMobilizationMissionReadRepository)
                .watchHistoricalMissionsForMobilizations(readableIds)
                .map((missions) => _filterMissions(missions, readableIds)),
    );
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForLocations(
    Set<String> locationIds,
  ) {
    if (locationIds.isEmpty) {
      return Stream<List<CoordinationNeed>>.value(const []);
    }
    final platformRepository = _platformRepository;
    final missionRepository = _delegate;
    if (platformRepository is! ResponsibleMobilizationReadRepository ||
        missionRepository is! MobilizationLocationMissionReadRepository) {
      return Stream<List<CoordinationNeed>>.error(
        StateError('Lecture Responsable bornée indisponible.'),
      );
    }
    final responsiblePlatformRepository =
        platformRepository as ResponsibleMobilizationReadRepository;
    final scopedMissionRepository =
        missionRepository as MobilizationLocationMissionReadRepository;
    return switchLatest(
      responsiblePlatformRepository.watchResponsibleActiveMobilizations(),
      (mobilizations) => _context == null
          ? scopedMissionRepository.watchMissionsForMobilizationsAndLocations(
              mobilizationIds: mobilizations.map((item) => item.id).toSet(),
              locationIds: locationIds,
            )
          : switchLatest(
              _watchGrants(),
              (grants) => _watchResponsibleMissions(
                mobilizations,
                locationIds,
                grants,
                scopedMissionRepository,
              ),
            ),
    );
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizationsAndLocations({
    required Set<String> mobilizationIds,
    required Set<String> locationIds,
  }) {
    if (mobilizationIds.isEmpty || locationIds.isEmpty) {
      return Stream<List<CoordinationNeed>>.value(const []);
    }
    final platformRepository = _platformRepository;
    final delegate = _delegate;
    if (platformRepository is! MobilizationLookupRepository) {
      return Stream<List<CoordinationNeed>>.error(
        StateError('Lecture missions et sites bornée indisponible.'),
      );
    }
    if (delegate is! MobilizationLocationMissionReadRepository) {
      return watchMissionsForMobilizations(mobilizationIds).map(
        (missions) => missions
            .where((mission) => locationIds.contains(mission.locationId))
            .toList(growable: false),
      );
    }
    if (_context != null) {
      return switchLatest(
        _platformRepository.watchMobilizations(),
        (mobilizations) => switchLatest(
          _watchGrants(),
          (grants) => _watchResponsibleMissions(
            mobilizations
                .where((item) => mobilizationIds.contains(item.id))
                .toList(growable: false),
            locationIds,
            grants,
            delegate as MobilizationLocationMissionReadRepository,
          ),
        ),
      );
    }
    return switchLatest(
      _watchReadableMobilizationIds(
        platformRepository as MobilizationLookupRepository,
        mobilizationIds,
      ),
      (readableIds) => readableIds.isEmpty
          ? Stream<List<CoordinationNeed>>.value(const [])
          : (delegate as MobilizationLocationMissionReadRepository)
                .watchMissionsForMobilizationsAndLocations(
                  mobilizationIds: readableIds,
                  locationIds: locationIds,
                ),
    );
  }

  Stream<List<OperationAccess>> _watchGrants() {
    final context = _context;
    if (context == null) return Stream.value(const []);
    return switchLatest(
      watchValueListenable(context),
      (value) => value == null
          ? Stream.value(const <OperationAccess>[])
          : _accessRepository.watchForUser(value.uid),
    );
  }

  Set<String> _coordinatorMobilizationIds(
    List<Mobilization> mobilizations,
    List<OperationAccess> grants,
  ) {
    final context = _context?.value;
    if (context == null || !context.hasRole(OrganizationRole.coordinator)) {
      return {};
    }
    final actionIds = grants
        .where(
          (grant) =>
              grant.roles.contains(OrganizationRole.coordinator) &&
              grant.canRead(context),
        )
        .map((grant) => grant.operationId)
        .toSet();
    return mobilizations
        .where((mobilization) => actionIds.contains(mobilization.operationId))
        .map((mobilization) => mobilization.id)
        .toSet();
  }

  Stream<List<CoordinationNeed>> _watchResponsibleMissions(
    List<Mobilization> mobilizations,
    Set<String> requestedSites,
    List<OperationAccess> grants,
    MobilizationLocationMissionReadRepository delegate,
  ) {
    final context = _context?.value;
    if (context == null || !context.hasRole(OrganizationRole.siteManager)) {
      return Stream.value(const []);
    }
    final streams = <Stream<List<CoordinationNeed>>>[];
    for (final mobilization in mobilizations) {
      final operationId = mobilization.operationId;
      Set<String> sites;
      if (operationId == null) {
        sites = requestedSites;
      } else {
        final grant = grants
            .where(
              (item) =>
                  item.operationId == operationId &&
                  item.roles.contains(OrganizationRole.siteManager) &&
                  item.canRead(context),
            )
            .firstOrNull;
        sites = grant == null
            ? const {}
            : requestedSites
                .intersection(grant.locationIds)
                .intersection(context.membership!.locationIds);
      }
      if (sites.isEmpty) continue;
      streams.add(
        delegate.watchMissionsForMobilizationsAndLocations(
          mobilizationIds: {mobilization.id},
          locationIds: sites,
        ),
      );
    }
    return _combineMissionStreams(streams);
  }

  Stream<Set<String>> _watchReadableMobilizationIds(
    MobilizationLookupRepository lookup,
    Set<String> requestedIds,
  ) => Stream<Set<String>>.multi((controller) {
    final ids = requestedIds.where(_isValidDocumentId).toList()..sort();
    if (ids.isEmpty) {
      controller.add(const <String>{});
      controller.close();
      return;
    }
    final readable = <String, bool>{};
    Set<String>? lastEmitted;
    var completed = 0;
    final subscriptions = <StreamSubscription<Object?>>[];

    void emitWhenReady() {
      if (readable.length != ids.length) return;
      final current = {
        for (final entry in readable.entries)
          if (entry.value) entry.key,
      };
      final previous = lastEmitted;
      if (previous != null &&
          previous.length == current.length &&
          previous.containsAll(current)) {
        return;
      }
      lastEmitted = current;
      controller.add(current);
    }

    for (final id in ids) {
      subscriptions.add(
        lookup
            .watchMobilization(id)
            .listen(
              (mobilization) {
                readable[id] = mobilization != null && mobilization.id == id;
                emitWhenReady();
              },
              onError: controller.addError,
              onDone: () {
                readable.putIfAbsent(id, () => false);
                emitWhenReady();
                if (++completed == ids.length) controller.close();
              },
            ),
      );
    }
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  });

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

Stream<List<CoordinationNeed>> _combineMissionStreams(
  List<Stream<List<CoordinationNeed>>> streams,
) {
  if (streams.isEmpty) return Stream.value(const []);
  late final StreamController<List<CoordinationNeed>> controller;
  final values = <int, List<CoordinationNeed>>{};
  final subscriptions = <StreamSubscription<List<CoordinationNeed>>>[];

  void emit() {
    if (values.length != streams.length || controller.isClosed) return;
    final seen = <String>{};
    controller.add(
      List.unmodifiable([
        for (var index = 0; index < streams.length; index++)
          for (final mission in values[index]!)
            if (seen.add(mission.id)) mission,
      ]),
    );
  }

  controller = StreamController<List<CoordinationNeed>>(
    onListen: () {
      for (var index = 0; index < streams.length; index++) {
        final key = index;
        subscriptions.add(
          streams[index].listen((missions) {
            values[key] = missions;
            emit();
          }, onError: controller.addError),
        );
      }
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );
  return controller.stream;
}
