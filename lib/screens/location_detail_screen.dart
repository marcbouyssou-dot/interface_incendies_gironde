import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/responsible_access.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/mission_location_details.dart';
import 'create_need_screen.dart';

class LocationDetailScreen extends StatefulWidget {
  const LocationDetailScreen({
    super.key,
    required this.location,
    this.missions,
    this.locations,
    this.responsibleAccess,
  });

  final ResponsePlace location;
  final Stream<List<CoordinationNeed>>? missions;
  final Stream<List<ResponsePlace>>? locations;
  final Stream<ResponsibleAccess?>? responsibleAccess;

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  String? _editingMissionId;

  ResponsePlace get location => widget.location;
  Stream<List<CoordinationNeed>>? get missions => widget.missions;
  Stream<List<ResponsePlace>>? get locations => widget.locations;
  Stream<ResponsibleAccess?>? get responsibleAccess => widget.responsibleAccess;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fiche du lieu')),
      body: SafeArea(
        top: false,
        child: StreamBuilder<ResponsibleAccess?>(
          stream: responsibleAccess ?? Stream.value(null),
          builder: (context, accessSnapshot) => PageContainer(
            child: locations == null
                ? _buildMissions(
                    context,
                    location,
                    accessSnapshot.hasError ? null : accessSnapshot.data,
                  )
                : StreamBuilder<List<CoordinationNeed>>(
                    stream:
                        missions ?? Stream.value(const <CoordinationNeed>[]),
                    builder: (context, missionsSnapshot) {
                      return StreamBuilder<List<ResponsePlace>>(
                        stream: locations,
                        builder: (context, locationsSnapshot) {
                          if (locationsSnapshot.hasError) {
                            return const CriticalDataUnavailableState(
                              stateKey: Key(
                                'location-detail-location-unavailable-state',
                              ),
                              eyebrow: 'Fiche du lieu',
                              title: 'Informations du centre indisponibles',
                              message:
                                  'Nous ne pouvons pas charger les informations '
                                  'de ce centre pour le moment.',
                              safetyMessage:
                                  'Les anciennes coordonnées ne sont pas '
                                  'affichées afin d’éviter toute information '
                                  'périmée.',
                            );
                          }
                          if (missionsSnapshot.hasError) {
                            return const CriticalDataUnavailableState(
                              stateKey: Key(
                                'location-missions-unavailable-state',
                              ),
                              eyebrow: 'Fiche du lieu',
                              title: 'Missions temporairement indisponibles',
                              message:
                                  'Nous ne pouvons pas charger les besoins de ce '
                                  'lieu pour le moment.',
                              safetyMessage:
                                  'Les anciennes missions ne sont pas affichées '
                                  'afin d’éviter toute information périmée.',
                            );
                          }
                          if (!locationsSnapshot.hasData ||
                              !missionsSnapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final currentLocation = _locationFrom(
                            locationsSnapshot.data!,
                          );
                          if (currentLocation == null) {
                            return const CriticalDataUnavailableState(
                              stateKey: Key(
                                'location-detail-location-missing-state',
                              ),
                              eyebrow: 'Fiche du lieu',
                              title: 'Lieu indisponible',
                              message:
                                  'Ce lieu ne figure plus dans les données '
                                  'actuellement disponibles.',
                              safetyMessage:
                                  'Les anciennes coordonnées ne sont pas '
                                  'affichées.',
                            );
                          }
                          return _buildContent(
                            context,
                            currentLocation,
                            missionsSnapshot.data!,
                            accessSnapshot.hasError
                                ? null
                                : accessSnapshot.data,
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissions(
    BuildContext context,
    ResponsePlace currentLocation,
    ResponsibleAccess? access,
  ) {
    return StreamBuilder<List<CoordinationNeed>>(
      stream: missions ?? Stream.value(const <CoordinationNeed>[]),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const CriticalDataUnavailableState(
            stateKey: Key('location-missions-unavailable-state'),
            eyebrow: 'Fiche du lieu',
            title: 'Missions temporairement indisponibles',
            message:
                'Nous ne pouvons pas charger les besoins de ce lieu pour '
                'le moment.',
            safetyMessage:
                'Les anciennes missions ne sont pas affichées afin '
                'd’éviter toute information périmée.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildContent(context, currentLocation, snapshot.data!, access);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    ResponsePlace currentLocation,
    List<CoordinationNeed> missions,
    ResponsibleAccess? access,
  ) {
    final activeMissions = _activeMissions(missions, currentLocation);
    return ListView(
      key: const Key('location-detail-screen'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          currentLocation.name,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 5),
        Text(
          currentLocation.type.label,
          style: const TextStyle(
            color: AppColors.orange,
            fontWeight: FontWeight.w800,
          ),
        ),
        MissionLocationDetails(
          location: currentLocation,
          phoneButtonLabel: 'Appeler le référent',
        ),
        const SizedBox(height: 28),
        Text('Besoins en cours', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (activeMissions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aucun besoin en cours pour ce lieu.'),
            ),
          )
        else
          for (var index = 0; index < activeMissions.length; index++) ...[
            NeedCard(
              key: ValueKey(activeMissions[index].id),
              need: activeMissions[index],
              location: currentLocation,
              isMissionEditorOpening:
                  _editingMissionId == activeMissions[index].id,
              isMissionEditorBlocked: _editingMissionId != null,
              onEditMission:
                  access?.hasPrivilegedAccess == true &&
                      access!.canManage(currentLocation.id)
                  ? () => _openMissionEditor(context, activeMissions[index])
                  : null,
            ),
            if (index != activeMissions.length - 1) const SizedBox(height: 16),
          ],
      ],
    );
  }

  Future<void> _openMissionEditor(
    BuildContext context,
    CoordinationNeed mission,
  ) async {
    if (_editingMissionId != null) return;
    setState(() => _editingMissionId = mission.id);
    try {
      await openMissionEditor(context, mission);
    } finally {
      if (mounted) setState(() => _editingMissionId = null);
    }
  }

  ResponsePlace? _locationFrom(List<ResponsePlace> values) {
    for (final value in values) {
      if (value.id == location.id) return value;
    }
    return null;
  }

  List<CoordinationNeed> _activeMissions(
    List<CoordinationNeed> values,
    ResponsePlace currentLocation,
  ) {
    final now = DateTime.now();
    final result = values
        .where(
          (mission) =>
              mission.isActive &&
              !mission.isCancelled &&
              (mission.endAt == null || now.isBefore(mission.endAt!)) &&
              responsePlaceForNeed(mission, [currentLocation]) != null,
        )
        .toList(growable: false);
    result.sort((left, right) {
      if (left.startAt == null && right.startAt == null) {
        return left.id.compareTo(right.id);
      }
      if (left.startAt == null) return 1;
      if (right.startAt == null) return -1;
      return left.startAt!.compareTo(right.startAt!);
    });
    return result;
  }
}
