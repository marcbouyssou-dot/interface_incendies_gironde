import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/site_equipment.dart';
import 'package:interface_incendies_gironde/repositories/firestore_location_mapper.dart';
import 'package:interface_incendies_gironde/repositories/firestore_mission_mapper.dart';
import 'package:interface_incendies_gironde/widgets/site_equipment_items.dart';

void main() {
  test(
    'catalog shares concrete professional IDs without free-text placeholders',
    () {
      expect(SiteEquipment.catalog, hasLength(20));
      expect(
        SiteEquipment.catalog.map((item) => item.id),
        contains('massage_table'),
      );
      expect(
        SiteEquipment.catalog.map((item) => item.id),
        isNot(contains('other_equipment')),
      );
      expect(
        SiteEquipment.catalog.map((item) => item.id),
        isNot(contains('profession_specific_equipment')),
      );
    },
  );

  test(
    'site and mission mappers preserve absent, empty and populated states',
    () {
      expect(
        FirestoreLocationMapper.fromFirestore(
          id: 'legacy',
          data: const {},
        ).availableEquipment,
        isNull,
      );
      expect(
        FirestoreMissionMapper.fromFirestore(
          id: 'legacy',
          data: const {},
        ).availableEquipmentOnSite,
        isNull,
      );
      expect(
        FirestoreLocationMapper.fromFirestore(
          id: 'empty',
          data: const {'availableEquipment': <String>[]},
        ).availableEquipment,
        isEmpty,
      );
      expect(
        FirestoreMissionMapper.fromFirestore(
          id: 'empty',
          data: const {'availableEquipmentOnSite': <String>[]},
        ).availableEquipmentOnSite,
        isEmpty,
      );
      expect(
        FirestoreLocationMapper.fromFirestore(
          id: 'site',
          data: const {
            'availableEquipment': [
              'stethoscope',
              'massage_table',
              'stethoscope',
            ],
          },
        ).availableEquipment,
        ['massage_table', 'stethoscope'],
      );
      expect(
        FirestoreMissionMapper.fromFirestore(
          id: 'mission',
          data: const {
            'availableEquipmentOnSite': ['massage_table', 'stethoscope'],
          },
        ).availableEquipmentOnSite,
        ['massage_table', 'stethoscope'],
      );
      expect(() => SiteEquipment.normalize(['invalid']), throwsFormatException);
    },
  );

  testWidgets(
    'read-only site equipment presentation keeps three states distinct',
    (tester) async {
      Future<void> render(List<String>? items) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: SiteEquipmentItems(equipment: items)),
          ),
        );
      }

      await render(null);
      expect(
        find.text('Matériel disponible sur site non renseigné'),
        findsOneWidget,
      );
      await render(const []);
      expect(find.text('Aucun matériel disponible sur site'), findsOneWidget);
      await render(const ['massage_table', 'stethoscope']);
      expect(find.text('• Table de massage'), findsOneWidget);
      expect(find.text('• Stéthoscope'), findsOneWidget);
    },
  );
}
