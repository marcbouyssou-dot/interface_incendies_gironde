import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/mission_equipment.dart';

void main() {
  const quotas = {
    'physiotherapist': 3,
    'podiatrist': 1,
    'physician': 1,
    'nurse': 2,
    'veterinarian': 0,
    'other_health_professional': 0,
  };

  test(
    'canonical selection deduplicates and projects shared equipment once',
    () {
      final selected = MissionEquipment.normalize({
        'nurse': ['dressing_equipment', 'blood_pressure_monitor'],
        'physician': ['blood_pressure_monitor'],
        'physiotherapist': [
          'massage_cream_oil',
          'massage_table',
          'massage_table',
        ],
      }, quotas);

      expect(selected, {
        'physiotherapist': ['massage_table', 'massage_cream_oil'],
        'physician': ['blood_pressure_monitor'],
        'nurse': ['blood_pressure_monitor', 'dressing_equipment'],
      });
      expect(MissionEquipment.globalLabels(selected), [
        'Table de massage',
        'Crèmes / huiles de massage',
        'Tensiomètre',
        'Matériel de pansement',
      ]);
    },
  );

  test('unknown professions, zero quotas and incompatible ids are refused', () {
    for (final invalid in [
      {
        'doctor': ['stethoscope'],
      },
      {
        'veterinarian': ['veterinary_examination_kit'],
      },
      {
        'physiotherapist': ['stethoscope'],
      },
      {'physiotherapist': <String>[]},
    ]) {
      expect(
        () => MissionEquipment.normalize(invalid, quotas),
        throwsFormatException,
      );
    }
  });
}
