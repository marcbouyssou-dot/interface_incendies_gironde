import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/responsible_profile_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';

void main() {
  testWidgets('Bassens manager edits only assigned site equipment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bassens = ResponsePlace(
      id: 'bordeauxmetropole-bassens',
      name: 'Bassens',
      type: places.first.type,
      group: places.first.group,
      activeNeeds: 0,
    );
    final other = places.firstWhere((site) => site.id != bassens.id);
    final repository = MockCoordinationRepository(
      initialLocations: [bassens, other],
      responsibleAccess: ResponsibleAccess(
        uid: 'bassens-manager',
        role: 'site_manager',
        locationIds: {bassens.id},
        active: true,
      ),
    );
    final data = LiveCoordinationData(repository);
    addTearDown(data.dispose);
    await tester.pumpWidget(
      RepositoryScope(
        repository: repository,
        child: LiveCoordinationDataScope(
          data: data,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: ResponsibleProfileScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('save-site-equipment-${bassens.id}')),
      findsOneWidget,
    );
    expect(find.byKey(Key('save-site-equipment-${other.id}')), findsNothing);
    final chip = find.byKey(const Key('site-equipment-massage_table'));
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    final save = find.byKey(Key('save-site-equipment-${bassens.id}'));
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    final sites = await tester.runAsync(
      () => repository.watchLocations().first,
    );
    expect(sites!.first.availableEquipment, ['massage_table']);
    expect(sites.last.availableEquipment, isNull);
    await expectLater(
      repository.updateSiteEquipment(other.id, const ['stethoscope']),
      throwsA(isA<RepositoryException>()),
    );
  });
}
