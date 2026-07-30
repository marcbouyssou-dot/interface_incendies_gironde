import 'package:flutter/material.dart';

import '../models/need.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/mission_location_details.dart';

class LocationDetailScreen extends StatelessWidget {
  const LocationDetailScreen({
    super.key,
    required this.location,
    this.missions,
  });

  final ResponsePlace location;
  final Stream<List<CoordinationNeed>>? missions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fiche du lieu')),
      body: PageContainer(
        child: StreamBuilder<List<CoordinationNeed>>(
          stream: missions ?? Stream.value(const <CoordinationNeed>[]),
          builder: (context, snapshot) {
            final activeMissions = _activeMissions(
              snapshot.data ?? const <CoordinationNeed>[],
            );
            return ListView(
              key: const Key('location-detail-screen'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(
                  location.name,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  location.type.label,
                  style: const TextStyle(
                    color: AppColors.orange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                MissionLocationDetails(
                  location: location,
                  phoneButtonLabel: 'Appeler le référent',
                ),
                const SizedBox(height: 28),
                Text(
                  'Besoins en cours',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (activeMissions.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Aucun besoin en cours pour ce lieu.'),
                    ),
                  )
                else
                  for (
                    var index = 0;
                    index < activeMissions.length;
                    index++
                  ) ...[
                    NeedCard(
                      key: ValueKey(activeMissions[index].id),
                      need: activeMissions[index],
                      location: location,
                    ),
                    if (index != activeMissions.length - 1)
                      const SizedBox(height: 16),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<CoordinationNeed> _activeMissions(List<CoordinationNeed> values) {
    final now = DateTime.now();
    final result = values
        .where(
          (mission) =>
              mission.isActive &&
              !mission.isCancelled &&
              (mission.endAt == null || now.isBefore(mission.endAt!)) &&
              responsePlaceForNeed(mission, [location]) != null,
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
