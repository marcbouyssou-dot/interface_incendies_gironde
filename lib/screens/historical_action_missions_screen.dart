import 'package:flutter/material.dart';

import '../models/operation.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../theme/v5_foundation.dart';
import '../widgets/professional_page_header.dart';
import '../widgets/v5_controls.dart';

/// Read-only Action history for a Coordinator's explicit historical grants.
class HistoricalActionMissionsScreen extends StatefulWidget {
  const HistoricalActionMissionsScreen({super.key});

  @override
  State<HistoricalActionMissionsScreen> createState() =>
      _HistoricalActionMissionsScreenState();
}

class _HistoricalActionMissionsScreenState
    extends State<HistoricalActionMissionsScreen> {
  LiveCoordinationData? _liveData;
  Stream<List<HistoricalActionMission>>? _history;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liveData = LiveCoordinationDataScope.of(context);
    if (identical(liveData, _liveData)) return;
    _liveData = liveData;
    _history = liveData.watchHistoricalActionMissions();
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<HistoricalActionMission>>(
        stream: _history,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Historique temporairement indisponible.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: V5ActivityIndicator());
          }
          final records = snapshot.data!;
          return ListView(
            key: const PageStorageKey('coordinator-action-history'),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
            children: [
              const MobSanteJourneyHeader(
                journey: MobSanteJourney.coordinator,
                pageTitle: 'Historique',
                showSubtitle: false,
              ),
              const SizedBox(height: V5Spacing.lg),
              if (records.isEmpty)
                const Text('Aucune Action terminée à consulter.'),
              for (final record in records) ...[
                V5Card(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.operationName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: V5Spacing.xs),
                      V5StatusPill(
                        label:
                            record.operationStatus == OperationStatus.archived
                            ? 'Archivée'
                            : 'Terminée',
                        tone: V5StatusTone.neutral,
                      ),
                      const SizedBox(height: V5Spacing.sm),
                      Text(record.mission.place),
                      Text(record.mission.date),
                    ],
                  ),
                ),
                const SizedBox(height: V5Spacing.sm),
              ],
            ],
          );
        },
      );
}
