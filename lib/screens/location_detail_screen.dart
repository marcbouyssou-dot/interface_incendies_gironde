import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/responsible_access.dart';
import '../widgets/common.dart';
import '../widgets/mission_location_details.dart';
import 'create_need_screen.dart';

abstract final class _MissionDetailVisuals {
  static const background = Color(0xFFF5F5F3);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF7C817F);
}

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
      backgroundColor: _MissionDetailVisuals.background,
      appBar: AppBar(
        title: const Text('Fiche du lieu'),
        backgroundColor: _MissionDetailVisuals.background,
        foregroundColor: _MissionDetailVisuals.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          color: _MissionDetailVisuals.navy,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth <= 556
            ? 18.0
            : (constraints.maxWidth - 520) / 2;
        return Material(
          color: _MissionDetailVisuals.background,
          child: ListView(
            key: const Key('location-detail-screen'),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              36,
            ),
            children: [
              _LocationSummaryCard(location: currentLocation),
              const SizedBox(height: 24),
              _ActiveNeedsHeader(count: activeMissions.length),
              const SizedBox(height: 12),
              if (activeMissions.isEmpty)
                const _EmptyNeedsCard()
              else
                for (var index = 0; index < activeMissions.length; index++) ...[
                  NeedCard(
                    key: ValueKey(activeMissions[index].id),
                    need: activeMissions[index],
                    location: currentLocation,
                    harmonized: true,
                    isMissionEditorOpening:
                        _editingMissionId == activeMissions[index].id,
                    isMissionEditorBlocked: _editingMissionId != null,
                    onEditMission:
                        access?.hasPrivilegedAccess == true &&
                            access!.canManage(currentLocation.id)
                        ? () =>
                              _openMissionEditor(context, activeMissions[index])
                        : null,
                  ),
                  if (index != activeMissions.length - 1)
                    const SizedBox(height: 14),
                ],
            ],
          ),
        );
      },
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

class _LocationSummaryCard extends StatelessWidget {
  const _LocationSummaryCard({required this.location});

  final ResponsePlace location;

  @override
  Widget build(BuildContext context) {
    final hasLocationDetails =
        location.verifiedAddress != null ||
        location.hasContactName ||
        location.hasContactPhone ||
        LocationActionLinks.directions(location) != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: _MissionDetailVisuals.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _MissionDetailVisuals.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A173052),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIEU D’INTERVENTION',
            style: TextStyle(
              color: _MissionDetailVisuals.textMuted,
              fontSize: 10,
              letterSpacing: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _MissionDetailVisuals.fieldBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: _MissionDetailVisuals.navy,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: const TextStyle(
                        color: _MissionDetailVisuals.navy,
                        fontSize: 22,
                        height: 1.15,
                        letterSpacing: -0.45,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      location.type.label,
                      style: const TextStyle(
                        color: _MissionDetailVisuals.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasLocationDetails)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _MissionDetailVisuals.fieldBackground,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _MissionDetailVisuals.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
                  child: MissionLocationDetails(
                    location: location,
                    phoneButtonLabel: 'Appeler le référent',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveNeedsHeader extends StatelessWidget {
  const _ActiveNeedsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final countLabel = count == 1 ? '1 mission' : '$count missions';
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MISSIONS ACTIVES',
                style: TextStyle(
                  color: _MissionDetailVisuals.textMuted,
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Besoins en cours',
                style: TextStyle(
                  color: _MissionDetailVisuals.navy,
                  fontSize: 20,
                  letterSpacing: -0.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: _MissionDetailVisuals.fieldBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _MissionDetailVisuals.border),
          ),
          child: Text(
            countLabel,
            style: const TextStyle(
              color: _MissionDetailVisuals.navy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyNeedsCard extends StatelessWidget {
  const _EmptyNeedsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _MissionDetailVisuals.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _MissionDetailVisuals.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_available_outlined,
            color: _MissionDetailVisuals.textMuted,
            size: 22,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aucun besoin en cours pour ce lieu.',
              style: TextStyle(
                color: _MissionDetailVisuals.navy,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
