// Mirrors the canonical mission equipment catalog in lib/models/professional_equipment.dart.
const LABELS = Object.freeze({
  massage_table: 'Table de massage',
  massage_cream_oil: 'Crèmes / huiles de massage',
  massage_gun: 'Pistolet de massage',
  pressotherapy_boots: 'Bottes de pressothérapie',
  adapted_seat: 'Fauteuil ou siège adapté',
  podiatry_equipment: 'Matériel de podologie',
  care_consumables: 'Consommables de soins',
  protective_equipment: 'Matériel de protection',
  stethoscope: 'Stéthoscope',
  blood_pressure_monitor: 'Tensiomètre',
  pulse_oximeter: 'Saturomètre',
  examination_equipment: 'Matériel d’examen',
  emergency_equipment: 'Matériel d’urgence',
  dressing_equipment: 'Matériel de pansement',
  care_equipment: 'Matériel de soins',
  veterinary_examination_kit: 'Kit d’examen vétérinaire',
  veterinary_care_equipment: 'Matériel de soins vétérinaires',
  animal_restraint_equipment: 'Matériel de contention animale',
  animal_transport_equipment: 'Matériel de transport animalier',
  electronic_chip_reader: 'Lecteur de puce électronique',
  other_veterinary_equipment: 'Autre matériel vétérinaire',
  profession_specific_equipment: 'Matériel spécifique à ma profession',
  other_equipment: 'Autre matériel',
});

// A site inventory accepts only concrete items from the shared catalog.
export const SITE_EQUIPMENT_IDS = Object.freeze(
  Object.keys(LABELS).filter((id) => ![
    'other_equipment', 'other_veterinary_equipment',
    'profession_specific_equipment',
  ].includes(id)),
);

const CATALOG = Object.freeze({
  physiotherapist: ['massage_table', 'massage_cream_oil', 'massage_gun',
    'pressotherapy_boots', 'other_equipment'],
  podiatrist: ['adapted_seat', 'podiatry_equipment', 'care_consumables',
    'protective_equipment', 'other_equipment'],
  physician: ['stethoscope', 'blood_pressure_monitor', 'pulse_oximeter',
    'examination_equipment', 'emergency_equipment', 'other_equipment'],
  nurse: ['blood_pressure_monitor', 'pulse_oximeter', 'emergency_equipment',
    'dressing_equipment', 'care_equipment', 'other_equipment'],
  veterinarian: ['veterinary_examination_kit', 'veterinary_care_equipment',
    'animal_restraint_equipment', 'animal_transport_equipment',
    'electronic_chip_reader', 'other_veterinary_equipment'],
  other_health_professional: ['protective_equipment', 'examination_equipment',
    'care_equipment', 'profession_specific_equipment', 'other_equipment'],
});

export function normalizeMissionEquipment(raw, requiredByProfession) {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new TypeError('Invalid equipment map');
  }
  if (Object.keys(raw).some((id) => !Object.hasOwn(CATALOG, id))) {
    throw new TypeError('Unknown equipment profession');
  }
  const normalized = {};
  for (const [profession, catalog] of Object.entries(CATALOG)) {
    if (!Object.hasOwn(raw, profession)) continue;
    const selected = raw[profession];
    if (!Array.isArray(selected) || selected.length === 0 ||
        requiredByProfession[profession] <= 0 ||
        selected.some((id) => typeof id !== 'string' || !catalog.includes(id))) {
      throw new TypeError('Invalid equipment selection');
    }
    const selectedIds = new Set(selected);
    normalized[profession] = catalog.filter((id) => selectedIds.has(id));
  }
  return normalized;
}

export function globalMissionEquipmentLabels(byProfession) {
  const seen = new Set();
  const labels = [];
  for (const profession of Object.keys(CATALOG)) {
    for (const id of byProfession[profession] ?? []) {
      if (seen.has(id)) continue;
      seen.add(id);
      labels.push(LABELS[id]);
    }
  }
  return labels;
}
