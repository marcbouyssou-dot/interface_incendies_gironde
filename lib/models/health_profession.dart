abstract final class HealthProfessionId {
  static const physiotherapist = 'physiotherapist';
  static const podiatrist = 'podiatrist';
  static const physician = 'physician';
  static const nurse = 'nurse';
  static const otherHealthProfessional = 'other_health_professional';

  /// Conservé uniquement pour lire les anciennes missions MK/PP.
  static const legacyPodiatrist = 'pp';

  static const canonical = {
    physiotherapist,
    podiatrist,
    physician,
    nurse,
    otherHealthProfessional,
  };

  static bool isCanonical(String id) => canonical.contains(id);

  static String normalize(String value) {
    return switch (value.trim()) {
      'mk' || physiotherapist => physiotherapist,
      'pp' || podiatrist => podiatrist,
      'doctor' || physician => physician,
      nurse => nurse,
      'otherHealthProfessional' ||
      otherHealthProfessional => otherHealthProfessional,
      _ => throw FormatException('Profession inconnue : $value'),
    };
  }
}

class HealthProfessionDefinition {
  const HealthProfessionDefinition({
    required this.id,
    required this.label,
    required this.shortLabel,
  });

  final String id;
  final String label;
  final String shortLabel;

  String get missionLabel =>
      id == HealthProfessionId.nurse ? 'Infirmier' : label;
}

abstract final class HealthProfessionRegistry {
  static const values = <HealthProfessionDefinition>[
    HealthProfessionDefinition(
      id: HealthProfessionId.physiotherapist,
      label: 'Masseur-kinésithérapeute',
      shortLabel: 'MK',
    ),
    HealthProfessionDefinition(
      id: HealthProfessionId.podiatrist,
      label: 'Pédicure-podologue',
      shortLabel: 'PP',
    ),
    HealthProfessionDefinition(
      id: HealthProfessionId.physician,
      label: 'Médecin',
      shortLabel: 'Médecin',
    ),
    HealthProfessionDefinition(
      id: HealthProfessionId.nurse,
      label: 'Infirmier / Infirmière',
      shortLabel: 'IDE',
    ),
    HealthProfessionDefinition(
      id: HealthProfessionId.otherHealthProfessional,
      label: 'Autre professionnel de santé',
      shortLabel: 'Autre',
    ),
  ];

  static HealthProfessionDefinition? byId(String id) {
    for (final profession in values) {
      if (profession.id == id) return profession;
    }
    return null;
  }
}
