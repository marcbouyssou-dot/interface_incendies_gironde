import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/need.dart';
import '../utils/switch_latest.dart';
import 'coordination_repository.dart';
import 'location_read_repository.dart';

class LiveCoordinationData {
  LiveCoordinationData(
    CoordinationRepository repository, {
    Stream<ResponsibleAccess?> Function()? responsibleAccessOverride,
    Stream<List<CoordinationNeed>> Function()? missionsOverride,
    Stream<List<ResponsePlace>> Function()? locationsOverride,
    MultiMobilizationCoordinationReadRepository?
    administrativeMissionRepository,
    Stream<Set<String>> Function()? coordinatorMobilizationIds,
    MissionEngagementReadRepository? administrativeEngagementRepository,
    LocationReadRepository? administrativeLocationRepository,
  }) : _repository = repository,
       _administrativeEngagementRepository =
           administrativeEngagementRepository {
    final accessSource =
        responsibleAccessOverride ?? repository.watchResponsibleAccess;
    _responsibleAccess = _SharedLatestStream(accessSource);
    _missions = _SharedLatestStream(() {
      if (missionsOverride != null) return missionsOverride();
      if (repository is! MultiMobilizationCoordinationReadRepository) {
        return repository.watchMissions();
      }
      final multiRepository =
          repository as MultiMobilizationCoordinationReadRepository;
      return switchLatest(_responsibleAccess.watch(), (access) {
        if (access == null) {
          return multiRepository.watchAllActiveMissions();
        }
        final administrativeRepository =
            administrativeMissionRepository ?? multiRepository;
        if (access.isSiteManager && !access.isCoordinator) {
          return administrativeRepository.watchMissionsForLocations(
            access.locationIds,
          );
        }
        if (access.isCoordinator && coordinatorMobilizationIds != null) {
          return switchLatest(
            coordinatorMobilizationIds(),
            administrativeRepository.watchMissionsForMobilizations,
          );
        }
        return administrativeRepository.watchAllActiveMissions();
      });
    }, onValue: _pruneMissionStreams);
    _locations = _SharedLatestStream(() {
      if (locationsOverride != null) return locationsOverride();
      if (administrativeLocationRepository == null) {
        return repository.watchLocations();
      }
      return switchLatest(
        _retainLastResponsibleAccess(_responsibleAccess.watch()),
        (access) {
          // Le Professionnel vérifié lit avec sa session volontaire RC3.
          // Les rôles privilégiés passent par le dépôt administratif borné.
          if (access == null) return repository.watchLocations();
          if (access.isSiteManager && !access.isCoordinator) {
            final scopedRepository = administrativeLocationRepository;
            final locations = scopedRepository is ScopedLocationReadRepository
                ? scopedRepository.watchLocationsForIds(access.locationIds)
                : scopedRepository.watchLocations();
            return locations.map(
              (items) => List<ResponsePlace>.unmodifiable(
                items.where((item) => access.locationIds.contains(item.id)),
              ),
            );
          }
          return administrativeLocationRepository.watchLocations();
        },
      );
    });
  }

  final CoordinationRepository _repository;
  final MissionEngagementReadRepository? _administrativeEngagementRepository;
  late final _SharedLatestStream<List<CoordinationNeed>> _missions;
  late final _SharedLatestStream<List<ResponsePlace>> _locations;
  late final _SharedLatestStream<ResponsibleAccess?> _responsibleAccess;
  final Map<String, _SharedLatestStream<EngagementInfo?>>
  _volunteerEngagements = {};
  final Map<String, _SharedLatestStream<List<EngagementInfo>>>
  _missionEngagements = {};

  Stream<List<CoordinationNeed>> watchMissions() => _missions.watch();

  Stream<List<ResponsePlace>> watchLocations() => _locations.watch();

  Stream<ResponsibleAccess?> watchResponsibleAccess() =>
      _responsibleAccess.watch();

  Stream<EngagementInfo?> watchMyEngagement(String missionId) =>
      _volunteerEngagements
          .putIfAbsent(
            missionId,
            () => _SharedLatestStream(
              () => _repository.watchMyEngagement(missionId),
            ),
          )
          .watch();

  Stream<List<EngagementInfo>> watchMissionEngagements(String missionId) =>
      _missionEngagements
          .putIfAbsent(
            missionId,
            () => _SharedLatestStream(
              () => (_administrativeEngagementRepository ?? _repository)
                  .watchMissionEngagements(missionId),
            ),
          )
          .watch();

  void _pruneMissionStreams(List<CoordinationNeed> missions) {
    final activeIds = missions.map((mission) => mission.id).toSet();
    for (final id in _volunteerEngagements.keys.toList(growable: false)) {
      if (!activeIds.contains(id)) {
        unawaited(_volunteerEngagements.remove(id)?.dispose());
      }
    }
    for (final id in _missionEngagements.keys.toList(growable: false)) {
      if (!activeIds.contains(id)) {
        unawaited(_missionEngagements.remove(id)?.dispose());
      }
    }
  }

  Future<void> dispose() async {
    await _missions.dispose();
    await _locations.dispose();
    await _responsibleAccess.dispose();
    for (final stream in _volunteerEngagements.values) {
      await stream.dispose();
    }
    for (final stream in _missionEngagements.values) {
      await stream.dispose();
    }
  }
}

/// Conserve la dernière projection sélectionnée lorsqu'une source de contexte
/// finie (notamment les fakes `Stream.value` des tests RC3).
///
/// Les flux Firebase réels restent ouverts, mais fermer aussi leur projection
/// enfant rendrait les données définitivement indisponibles après une source
/// de contexte ponctuelle.
Stream<ResponsibleAccess?> _retainLastResponsibleAccess(
  Stream<ResponsibleAccess?> source,
) => Stream<ResponsibleAccess?>.multi((controller) {
  final subscription = source.listen(
    controller.add,
    // Un échec de lecture du rôle ne doit jamais réorienter un utilisateur
    // privilégié vers le dépôt anonyme des sites.
    onError: controller.addError,
    // La fermeture est volontairement absorbée : l'annulation du
    // consommateur libère toujours la souscription et le flux enfant.
    onDone: () {},
  );
  controller.onCancel = subscription.cancel;
});

class LiveCoordinationDataScope extends InheritedWidget {
  const LiveCoordinationDataScope({
    super.key,
    required this.data,
    required super.child,
  });

  final LiveCoordinationData data;

  static LiveCoordinationData of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<LiveCoordinationDataScope>();
    assert(scope != null, 'LiveCoordinationDataScope absent de l’arbre');
    return scope!.data;
  }

  @override
  bool updateShouldNotify(LiveCoordinationDataScope oldWidget) =>
      !identical(data, oldWidget.data);
}

class _SharedLatestStream<T> {
  _SharedLatestStream(this._source, {this.onValue});

  final Stream<T> Function() _source;
  final void Function(T value)? onValue;
  final StreamController<T> _events = StreamController<T>.broadcast(sync: true);
  StreamSubscription<T>? _sourceSubscription;
  bool _hasValue = false;
  T? _latest;
  bool _hasError = false;
  Object? _latestError;
  StackTrace? _latestErrorStackTrace;

  Stream<T> watch() => Stream<T>.multi((controller) {
    if (_hasError) {
      controller.addError(_latestError!, _latestErrorStackTrace);
    } else if (_hasValue) {
      controller.add(_latest as T);
    }
    final subscription = _events.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
    _sourceSubscription ??= _source().listen(
      (value) {
        _latest = value;
        _hasValue = true;
        _hasError = false;
        _latestError = null;
        _latestErrorStackTrace = null;
        onValue?.call(value);
        _events.add(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        _hasError = true;
        _latestError = error;
        _latestErrorStackTrace = stackTrace;
        _events.addError(error, stackTrace);
      },
      onDone: _events.close,
    );
  });

  Future<void> dispose() async {
    await _sourceSubscription?.cancel();
    unawaited(_events.close());
  }
}
