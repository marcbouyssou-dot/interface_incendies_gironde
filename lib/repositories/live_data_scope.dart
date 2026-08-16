import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/need.dart';
import '../utils/switch_latest.dart';
import 'coordination_repository.dart';

class LiveCoordinationData {
  LiveCoordinationData(
    CoordinationRepository repository, {
    Stream<ResponsibleAccess?> Function()? responsibleAccessOverride,
  }) : _repository = repository {
    final accessSource =
        responsibleAccessOverride ?? repository.watchResponsibleAccess;
    _missions = _SharedLatestStream(() {
      if (repository is! MultiMobilizationCoordinationReadRepository) {
        return repository.watchMissions();
      }
      final multiRepository =
          repository as MultiMobilizationCoordinationReadRepository;
      return switchLatest(accessSource(), (access) {
        if (access == null) {
          return multiRepository.watchAllActiveMissions();
        }
        if (access.isSiteManager && !access.isCoordinator) {
          return multiRepository.watchMissionsForLocations(access.locationIds);
        }
        // Le Coordinateur sélectionne sa mobilisation dans le Cockpit.
        // Les autres écrans conservent leur flux historique tant qu'ils ne
        // portent pas encore de sélecteur explicite.
        return repository.watchMissions();
      });
    }, onValue: _pruneMissionStreams);
    _locations = _SharedLatestStream(repository.watchLocations);
    _responsibleAccess = _SharedLatestStream(accessSource);
  }

  final CoordinationRepository _repository;
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
              () => _repository.watchMissionEngagements(missionId),
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
