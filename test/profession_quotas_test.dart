import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/health_profession.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';

void main() {
  test('canonical profession identifiers and labels have one source', () {
    expect(HealthProfessionRegistry.values.map((profession) => profession.id), [
      'physiotherapist',
      'podiatrist',
      'physician',
      'nurse',
      'other_health_professional',
    ]);
    expect(
      HealthProfessionRegistry.values
          .map((profession) => profession.id)
          .toSet(),
      hasLength(5),
    );
    expect(HealthProfessionRegistry.byId('physician')?.label, 'Médecin');
    expect(HealthProfessionRegistry.byId('pp'), isNull);
    expect(HealthProfessionId.normalize('mk'), 'physiotherapist');
    expect(HealthProfessionId.normalize('pp'), 'podiatrist');
    expect(HealthProfessionId.normalize('doctor'), 'physician');
    expect(
      HealthProfessionId.normalize('otherHealthProfessional'),
      'other_health_professional',
    );
    expect(
      () => HealthProfessionId.normalize('unknown'),
      throwsFormatException,
    );
    expect(
      VolunteerProfession.mk.canonicalId,
      HealthProfessionId.physiotherapist,
    );
    expect(
      VolunteerProfession.doctor.canonicalId,
      HealthProfessionId.physician,
    );
    expect(VolunteerProfession.pp.canonicalId, HealthProfessionId.podiatrist);
    expect(volunteerProfessionFromId('physician'), VolunteerProfession.doctor);
    expect(volunteerProfessionFromId('mk'), VolunteerProfession.mk);
    expect(volunteerProfessionFromId('podiatrist'), VolunteerProfession.pp);
    expect(VolunteerProfession.pp.label, 'Pédicure-podologue');
    expect(
      VolunteerProfession.nurse.label,
      HealthProfessionRegistry.byId(HealthProfessionId.nurse)?.label,
    );
  });

  test('generic quotas calculate totals, missing values and coverage', () {
    final quotas = ProfessionQuotas.fromMaps(
      requiredByProfession: const {
        HealthProfessionId.physiotherapist: 4,
        HealthProfessionId.physician: 1,
      },
      registeredByProfession: const {
        HealthProfessionId.physiotherapist: 2,
        HealthProfessionId.physician: 1,
      },
    );

    expect(quotas.requiredTotal, 5);
    expect(quotas.registeredTotal, 3);
    expect(quotas.coverage, .6);
    expect(quotas.quotaFor(HealthProfessionId.physiotherapist).missing, 2);
    expect(quotas.isCovered, isFalse);
  });

  test('legacy MK and PP quotas remain lossless and isolated', () {
    final quotas = ProfessionQuotas.fromLegacyMkPp(
      requiredMk: 4,
      registeredMk: 2,
      requiredPp: 1,
      registeredPp: 1,
    );

    expect(quotas.quotaFor(HealthProfessionId.physiotherapist).required, 4);
    expect(quotas.quotaFor(HealthProfessionId.podiatrist).registered, 1);
    expect(HealthProfessionId.isCanonical('pp'), isFalse);
    expect(HealthProfessionId.isCanonical('podiatrist'), isTrue);
  });

  test('missing profession quotas default to zero without mutation', () {
    final quotas = ProfessionQuotas.fromMaps(
      requiredByProfession: const {},
      registeredByProfession: const {},
    );

    final missing = quotas.quotaFor(HealthProfessionId.nurse);
    expect(missing.required, 0);
    expect(missing.registered, 0);
    expect(quotas.requiredByProfession, hasLength(5));
    expect(quotas.requiredByProfession.values, everyElement(0));
  });

  test('mission updates synchronize generic and historic MK PP fields', () {
    final quotas = ProfessionQuotas.fromMaps(
      requiredByProfession: const {'physician': 1, 'pp': 2},
      registeredByProfession: const {'physician': 1, 'podiatrist': 1},
    );

    expect(quotas.toMissionUpdate(), {
      'requiredByProfession': {
        'physiotherapist': 0,
        'podiatrist': 2,
        'physician': 1,
        'nurse': 0,
        'other_health_professional': 0,
      },
      'registeredByProfession': {
        'physiotherapist': 0,
        'podiatrist': 1,
        'physician': 1,
        'nurse': 0,
        'other_health_professional': 0,
      },
      'requiredMk': 0,
      'registeredMk': 0,
      'requiredPp': 2,
      'registeredPp': 1,
    });
  });
}
