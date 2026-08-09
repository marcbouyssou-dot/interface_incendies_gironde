import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/coordinator/territory_view_data.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/responsible_access.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/common.dart';
import 'package:interface_incendies_gironde/widgets/mission_card.dart';
import 'package:interface_incendies_gironde/widgets/responsible_mission_card.dart';
import 'package:interface_incendies_gironde/widgets/territory_components.dart';
import 'package:interface_incendies_gironde/widgets/v5_bottom_navigation.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';
import 'package:interface_incendies_gironde/widgets/v5_form_system.dart';
import 'package:interface_incendies_gironde/widgets/v5_secondary_navigation.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .textScaleFactorTestValue =
        2;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearTextScaleFactorTestValue();
  });

  testWidgets('secondary navigation grows and preserves its complete title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          appBar: V5SecondaryNavigationBar(
            title: 'Gestion des responsables du territoire',
          ),
        ),
      ),
    );

    final navigation = tester.widget<V5SecondaryNavigationBar>(
      find.byType(V5SecondaryNavigationBar),
    );
    final title = tester.widget<Text>(
      find.text('Gestion des responsables du territoire'),
    );
    expect(navigation.preferredSize.height, greaterThan(54));
    expect(title.maxLines, isNull);
    expect(title.overflow, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('V5 form controls wrap long functional values at 200 percent', (
    tester,
  ) async {
    const selected = 'Infirmier en pratique avancée — soins chroniques';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                V5SelectField<String>(
                  label: 'Profession principale',
                  value: selected,
                  options: const [
                    V5SelectOption(value: selected, label: selected),
                  ],
                  onChanged: (_) {},
                ),
                const SizedBox(height: 16),
                V5ChoiceChip(
                  label: 'Matériel de surveillance cardio-respiratoire',
                  selected: true,
                  onSelected: (_) {},
                ),
                const SizedBox(height: 16),
                V5Button(
                  expanded: true,
                  label: 'Enregistrer les modifications du profil',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final selectedText = tester.widget<Text>(find.text(selected));
    final buttonText = tester.widget<Text>(
      find.text('Enregistrer les modifications du profil'),
    );
    expect(selectedText.maxLines, isNull);
    expect(selectedText.overflow, isNull);
    expect(buttonText.maxLines, isNull);
    expect(buttonText.overflow, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mission cards and coordinator metrics reflow at 200 percent', (
    tester,
  ) async {
    final need = needs.first;
    const sector = TerritorySectorViewData(
      group: TerritorialGroup.bordeauxMetropole,
      status: TerritoryOperationalStatus.critical,
      centerCount: 3,
      activeNeeds: 12,
      uncoveredNeeds: 4,
      nextDeadline: 'Demain à 8 heures au plus tard',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              MissionCard(
                state: MissionCardState.urgent,
                professionalPalette: true,
                locationType: 'Établissement médico-social',
                locationName: 'Centre de santé au nom particulièrement long',
                dateLabel: 'Demain, samedi 15 août',
                timeLabel: 'De 7 heures à 19 heures',
                timingBadge: MissionTimingPill(mission: need),
                need: const Text('Deux renforts sont encore attendus'),
                professionTitle: 'Profession recherchée',
                professions: const [
                  V5ChoiceChip(
                    label: 'Infirmier en pratique avancée',
                    selected: true,
                    onSelected: null,
                  ),
                ],
                primaryAction: V5Button(
                  expanded: true,
                  label: 'Je souhaite participer à cette mission',
                  onPressed: () {},
                ),
                secondaryDetails: const Text('Accès et contact'),
              ),
              const SizedBox(height: 16),
              ResponsibleMissionCard(
                need: need,
                tone: ResponsibleMissionTone.urgent,
                statusLabel: 'Renforts nécessaires rapidement',
              ),
              const SizedBox(height: 16),
              const SectorStatusCard(sector: sector),
              const SizedBox(height: 16),
              const OperationalSummary(
                coveredCenters: 18,
                activeNeeds: 12,
                mobilizedProfessionals: 126,
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('professional filters stack without losing 44 point targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(responsibleAccess: null),
      ),
    );
    await tester.pumpAndSettle();

    final where = find.byKey(const Key('professional-hero-where'));
    final when = find.byKey(const Key('professional-hero-when'));
    expect(tester.getCenter(where).dy, lessThan(tester.getCenter(when).dy));
    expect(tester.getSize(where).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(when).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('responsible need form remains scrollable at 200 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final center = places.firstWhere(
      (place) => place.isOperational && place.isEnabled,
    );
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(
          responsibleAccess: ResponsibleAccess(
            uid: 'dynamic-type-responsible',
            role: ResponsibleRole.siteManager,
            locationIds: {center.id},
            active: true,
          ),
          initialLocations: [center],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final create = find.byKey(const Key('responsible-create-need'));
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    final publish = find.byKey(const Key('publish-mission'));
    await tester.ensureVisible(publish);
    await tester.pumpAndSettle();

    expect(tester.getSize(publish).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('coordinator dashboard metrics wrap at 200 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Statistiques globales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statistiques globales'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('coordinator-global-dashboard')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('professional profile editor remains usable at 200 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(responsibleAccess: null),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<V5BottomBar>(find.byKey(const Key('v5-bottom-navigation')))
        .onDestinationSelected(2);
    await tester.pumpAndSettle();
    expect(find.text('Mon profil'), findsOneWidget);

    final edit = find.byKey(const Key('edit-professional-profile'));
    for (var attempt = 0; attempt < 6 && edit.evaluate().isEmpty; attempt++) {
      await tester.drag(
        find.byKey(const PageStorageKey('professional-profile')),
        const Offset(0, -360),
      );
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();

    final save = find.byKey(const Key('save-professional-profile'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('professional-profile-first-name')), findsOne);
    expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}
