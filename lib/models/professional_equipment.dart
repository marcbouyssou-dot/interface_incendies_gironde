import 'health_profession.dart';

abstract final class ProfessionalEquipmentId {
  static const massageTable = 'massage_table';
  static const massageCreamOil = 'massage_cream_oil';
  static const massageGun = 'massage_gun';
  static const pressotherapyBoots = 'pressotherapy_boots';
  static const adaptedSeat = 'adapted_seat';
  static const podiatryEquipment = 'podiatry_equipment';
  static const careConsumables = 'care_consumables';
  static const protectiveEquipment = 'protective_equipment';
  static const stethoscope = 'stethoscope';
  static const bloodPressureMonitor = 'blood_pressure_monitor';
  static const pulseOximeter = 'pulse_oximeter';
  static const examinationEquipment = 'examination_equipment';
  static const emergencyEquipment = 'emergency_equipment';
  static const dressingEquipment = 'dressing_equipment';
  static const careEquipment = 'care_equipment';
  static const professionSpecificEquipment = 'profession_specific_equipment';
  static const otherEquipment = 'other_equipment';
}

class ProfessionalEquipmentDefinition {
  const ProfessionalEquipmentDefinition({
    required this.id,
    required this.label,
    required this.professionIds,
    this.requiresDetails = false,
  });

  final String id;
  final String label;
  final Set<String> professionIds;
  final bool requiresDetails;
}

abstract final class ProfessionalEquipmentRegistry {
  static const values = <ProfessionalEquipmentDefinition>[
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.massageTable,
      label: 'Table de massage',
      professionIds: {HealthProfessionId.physiotherapist},
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.massageCreamOil,
      label: 'Crèmes / huiles de massage',
      professionIds: {HealthProfessionId.physiotherapist},
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.massageGun,
      label: 'Pistolet de massage',
      professionIds: {HealthProfessionId.physiotherapist},
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.pressotherapyBoots,
      label: 'Bottes de pressothérapie',
      professionIds: {HealthProfessionId.physiotherapist},
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.adaptedSeat,
      label: 'Fauteuil ou siège adapté',
      professionIds: {HealthProfessionId.podiatrist},
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.podiatryEquipment,
      label: 'Matériel de podologie',
      professionIds: {HealthProfessionId.podiatrist},
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.careConsumables,
      label: 'Consommables de soins',
      professionIds: {HealthProfessionId.podiatrist},
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.protectiveEquipment,
      label: 'Matériel de protection',
      professionIds: {
        HealthProfessionId.podiatrist,
        HealthProfessionId.otherHealthProfessional,
      },
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.stethoscope,
      label: 'Stéthoscope',
      professionIds: {HealthProfessionId.physician},
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.bloodPressureMonitor,
      label: 'Tensiomètre',
      professionIds: {HealthProfessionId.physician, HealthProfessionId.nurse},
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.pulseOximeter,
      label: 'Saturomètre',
      professionIds: {HealthProfessionId.physician, HealthProfessionId.nurse},
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.examinationEquipment,
      label: 'Matériel d’examen',
      professionIds: {
        HealthProfessionId.physician,
        HealthProfessionId.otherHealthProfessional,
      },
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.emergencyEquipment,
      label: 'Matériel d’urgence',
      professionIds: {HealthProfessionId.physician, HealthProfessionId.nurse},
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.dressingEquipment,
      label: 'Matériel de pansement',
      professionIds: {HealthProfessionId.nurse},
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.careEquipment,
      label: 'Matériel de soins',
      professionIds: {
        HealthProfessionId.nurse,
        HealthProfessionId.otherHealthProfessional,
      },
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.professionSpecificEquipment,
      label: 'Matériel spécifique à ma profession',
      professionIds: {HealthProfessionId.otherHealthProfessional},
      requiresDetails: true,
    ),
    ProfessionalEquipmentDefinition(
      id: ProfessionalEquipmentId.otherEquipment,
      label: 'Autre matériel',
      professionIds: {
        HealthProfessionId.physiotherapist,
        HealthProfessionId.podiatrist,
        HealthProfessionId.physician,
        HealthProfessionId.nurse,
        HealthProfessionId.otherHealthProfessional,
      },
      requiresDetails: true,
    ),
  ];

  static List<ProfessionalEquipmentDefinition> forProfession(
    String professionId,
  ) => values
      .where((definition) => definition.professionIds.contains(professionId))
      .toList(growable: false);

  static ProfessionalEquipmentDefinition? byId(String id) {
    for (final definition in values) {
      if (definition.id == id) return definition;
    }
    return null;
  }

  static String normalizeStoredValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final normalized = trimmed.toLowerCase();
    return _legacyAliases[normalized] ?? byId(trimmed)?.id ?? trimmed;
  }

  static List<String> normalizeStoredValues(Iterable<String> values) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final item = normalizeStoredValue(value);
      if (item.isNotEmpty && seen.add(item)) normalized.add(item);
    }
    return normalized;
  }

  static String displayLabel(String value) =>
      byId(normalizeStoredValue(value))?.label ?? value.trim();

  static bool isCompatible(String value, String professionId) =>
      byId(normalizeStoredValue(value))?.professionIds.contains(professionId) ??
      false;

  static bool requiresDetails(Iterable<String> values) => values.any(
    (value) => byId(normalizeStoredValue(value))?.requiresDetails ?? false,
  );

  static const _legacyAliases = <String, String>{
    'table': ProfessionalEquipmentId.massageTable,
    'tables': ProfessionalEquipmentId.massageTable,
    'table de massage': ProfessionalEquipmentId.massageTable,
    'huile': ProfessionalEquipmentId.massageCreamOil,
    'huiles': ProfessionalEquipmentId.massageCreamOil,
    'crème': ProfessionalEquipmentId.massageCreamOil,
    'crèmes': ProfessionalEquipmentId.massageCreamOil,
    'crèmes / huiles de massage': ProfessionalEquipmentId.massageCreamOil,
    'pistolet de massage': ProfessionalEquipmentId.massageGun,
    'bottes de pressothérapie': ProfessionalEquipmentId.pressotherapyBoots,
    'fauteuil ou siège adapté': ProfessionalEquipmentId.adaptedSeat,
    'matériel de podologie': ProfessionalEquipmentId.podiatryEquipment,
    'consommables de soins': ProfessionalEquipmentId.careConsumables,
    'matériel de protection': ProfessionalEquipmentId.protectiveEquipment,
    'stéthoscope': ProfessionalEquipmentId.stethoscope,
    'tensiomètre': ProfessionalEquipmentId.bloodPressureMonitor,
    'saturomètre': ProfessionalEquipmentId.pulseOximeter,
    'matériel d’examen': ProfessionalEquipmentId.examinationEquipment,
    'matériel d’urgence': ProfessionalEquipmentId.emergencyEquipment,
    'matériel de pansement': ProfessionalEquipmentId.dressingEquipment,
    'matériel de soins': ProfessionalEquipmentId.careEquipment,
    'matériel spécifique à ma profession':
        ProfessionalEquipmentId.professionSpecificEquipment,
    'autre matériel': ProfessionalEquipmentId.otherEquipment,
  };
}
