import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/historical_action_missions_screen.dart';
import 'package:interface_incendies_gironde/screens/professional_engagements_screen.dart';
import 'package:interface_incendies_gironde/screens/responsible_needs_screen.dart';
import 'package:interface_incendies_gironde/screens/responsible_published_needs.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';

final _mission = CoordinationNeed(
  id: 'history-fire-mission',
  mobilizationId: 'history-fire-mobilization',
  locationId: 'history-fire-site',
  place: 'Site historique Gironde',
  group: TerritorialGroup.partnerSites,
  date: '07/10/2026',
  time: '08:00 — 12:00',
  startAt: DateTime.utc(2026, 10, 7, 8),
  endAt: DateTime.utc(2026, 10, 7, 12),
  requiredPhysiotherapists: 1,
  registeredPhysiotherapists: 1,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  equipment: const [],
  isActive: false,
);

final _engagement = EngagementInfo(
  missionId: _mission.id,
  volunteerId: 'historical-professional',
  profession: VolunteerProfession.mk,
);

final _historicalAction = HistoricalActionMission(
  operationId: 'incendies-gironde-fixture',
  operationName: 'Incendies Gironde 2026',
  operationStatus: OperationStatus.archived,
  mission: _mission,
);

class _HistoryRepository extends MockCoordinationRepository
    implements
        ProfessionalEngagementHistoryReadRepository,
        HistoricalActionMissionReadRepository {
  _HistoryRepository({ResponsibleAccess? access})
    : super(
        initialMissions: const [],
        initialLocations: const [],
        responsibleAccess: access,
      );

  @override
  Stream<List<ProfessionalEngagementRecord>> watchOwnEngagementRecords() =>
      Stream.value([
        ProfessionalEngagementRecord(
          mission: _mission,
          engagement: _engagement,
        ),
      ]);

  @override
  Stream<List<HistoricalActionMission>> watchHistoricalActionMissions() =>
      Stream.value([_historicalAction]);
}

void main() {
  testWidgets(
    'Professional sees own archived engagement in Passés, read-only',
    (tester) async {
      final liveData = LiveCoordinationData(_HistoryRepository());
      addTearDown(liveData.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: LiveCoordinationDataScope(
            data: liveData,
            child: const Scaffold(body: ProfessionalEngagementsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passés'));
      await tester.pumpAndSettle();
      expect(find.text('Site historique Gironde'), findsOneWidget);
      expect(find.text('Terminée'), findsOneWidget);
      expect(
        find.byKey(const Key('cancel-engagement-history-fire-mission')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Responsible sees archived Action outside current site as read-only',
    (tester) async {
      final repository = _HistoryRepository(
        access: ResponsibleAccess.v2(
          uid: 'history-manager',
          roles: const [ResponsibleRole.siteManager],
          locationIds: const {'current-site'},
          active: true,
        ),
      );
      final liveData = LiveCoordinationData(repository);
      final published = ResponsiblePublishedNeeds();
      addTearDown(liveData.dispose);
      addTearDown(published.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: LiveCoordinationDataScope(
            data: liveData,
            child: Scaffold(
              body: ResponsibleNeedsScreen(
                publishedNeeds: published,
                onOpenTeam: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passés').first);
      await tester.pumpAndSettle();
      expect(find.text('Incendies Gironde 2026'), findsOneWidget);
      expect(find.text('Archivée'), findsOneWidget);
      expect(
        find.byKey(const Key('responsible-edit-need-history-fire-mission')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('responsible-view-team-history-fire-mission')),
        findsNothing,
      );
    },
  );

  testWidgets('Coordinator has a read-only historical Action view', (
    tester,
  ) async {
    final liveData = LiveCoordinationData(_HistoryRepository());
    addTearDown(liveData.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LiveCoordinationDataScope(
          data: liveData,
          child: const Scaffold(body: HistoricalActionMissionsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Incendies Gironde 2026'), findsOneWidget);
    expect(find.text('Archivée'), findsOneWidget);
    expect(find.text('Site historique Gironde'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
}
