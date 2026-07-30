import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/health_profession.dart';
import 'package:interface_incendies_gironde/models/professional_equipment.dart';

void main() {
  List<String> idsFor(String professionId) =>
      ProfessionalEquipmentRegistry.forProfession(
        professionId,
      ).map((item) => item.id).toList();

  test('each profession exposes its exact equipment catalogue', () {
    expect(idsFor(HealthProfessionId.physiotherapist), [
      ProfessionalEquipmentId.massageTable,
      ProfessionalEquipmentId.massageCreamOil,
      ProfessionalEquipmentId.massageGun,
      ProfessionalEquipmentId.pressotherapyBoots,
      ProfessionalEquipmentId.otherEquipment,
    ]);
    expect(idsFor(HealthProfessionId.podiatrist), [
      ProfessionalEquipmentId.adaptedSeat,
      ProfessionalEquipmentId.podiatryEquipment,
      ProfessionalEquipmentId.careConsumables,
      ProfessionalEquipmentId.protectiveEquipment,
      ProfessionalEquipmentId.otherEquipment,
    ]);
    expect(idsFor(HealthProfessionId.physician), [
      ProfessionalEquipmentId.stethoscope,
      ProfessionalEquipmentId.bloodPressureMonitor,
      ProfessionalEquipmentId.pulseOximeter,
      ProfessionalEquipmentId.examinationEquipment,
      ProfessionalEquipmentId.emergencyEquipment,
      ProfessionalEquipmentId.otherEquipment,
    ]);
    expect(idsFor(HealthProfessionId.nurse), [
      ProfessionalEquipmentId.bloodPressureMonitor,
      ProfessionalEquipmentId.pulseOximeter,
      ProfessionalEquipmentId.emergencyEquipment,
      ProfessionalEquipmentId.dressingEquipment,
      ProfessionalEquipmentId.careEquipment,
      ProfessionalEquipmentId.otherEquipment,
    ]);
    expect(idsFor(HealthProfessionId.otherHealthProfessional), [
      ProfessionalEquipmentId.protectiveEquipment,
      ProfessionalEquipmentId.examinationEquipment,
      ProfessionalEquipmentId.careEquipment,
      ProfessionalEquipmentId.professionSpecificEquipment,
      ProfessionalEquipmentId.otherEquipment,
    ]);
    expect(
      idsFor(HealthProfessionId.physician),
      isNot(contains(ProfessionalEquipmentId.massageTable)),
    );
  });

  test('legacy labels normalize while free historical values survive', () {
    expect(
      ProfessionalEquipmentRegistry.normalizeStoredValues([
        'Table de massage',
        'Tables',
        'Pistolet de massage',
        ' Sac personnel ',
      ]),
      [
        ProfessionalEquipmentId.massageTable,
        ProfessionalEquipmentId.massageGun,
        'Sac personnel',
      ],
    );
    expect(
      ProfessionalEquipmentRegistry.displayLabel(
        ProfessionalEquipmentId.massageTable,
      ),
      'Table de massage',
    );
    expect(
      ProfessionalEquipmentRegistry.displayLabel('Sac personnel'),
      'Sac personnel',
    );
  });

  test('details are required for both customizable choices', () {
    expect(
      ProfessionalEquipmentRegistry.requiresDetails([
        ProfessionalEquipmentId.otherEquipment,
      ]),
      isTrue,
    );
    expect(
      ProfessionalEquipmentRegistry.requiresDetails([
        ProfessionalEquipmentId.professionSpecificEquipment,
      ]),
      isTrue,
    );
    expect(
      ProfessionalEquipmentRegistry.requiresDetails([
        ProfessionalEquipmentId.careEquipment,
      ]),
      isFalse,
    );
  });
}
