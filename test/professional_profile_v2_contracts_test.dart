import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/mobilization_preferences.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/professional_communication_preferences.dart';
import 'package:interface_incendies_gironde/models/professional_competencies.dart';
import 'package:interface_incendies_gironde/models/professional_consent.dart';
import 'package:interface_incendies_gironde/models/volunteer_profile.dart';

void main() {
  group('ProfessionalCompetencies', () {
    test('round-trips several open skill identifiers', () {
      final competencies = ProfessionalCompetencies(
        skillIds: const {'triage', 'psychological_first_aid'},
        otherSkillDetails: 'Coordination de poste médical avancé',
        taxonomyVersion: 3,
      );

      final restored = ProfessionalCompetencies.fromMap(competencies.toMap());

      expect(restored, competencies);
      expect(restored.hashCode, competencies.hashCode);
      expect(restored.toMap(), {
        'skillIds': ['psychological_first_aid', 'triage'],
        'otherSkillDetails': 'Coordination de poste médical avancé',
        'taxonomyVersion': 3,
      });
    });

    test('defensively copies and exposes an immutable skill set', () {
      final skillIds = <String>{'triage'};
      final competencies = ProfessionalCompetencies(skillIds: skillIds);

      skillIds.add('future_skill');

      expect(competencies.skillIds, {'triage'});
      expect(
        () => competencies.skillIds.add('another_skill'),
        throwsUnsupportedError,
      );
    });

    test('accepts absent optional fields and additive future fields', () {
      final empty = ProfessionalCompetencies.fromMap(const {});
      final future = ProfessionalCompetencies.fromMap(const {
        'skillIds': <Object?>['future_taxonomy_skill'],
        'taxonomyVersion': 8,
        'futureCertificationIds': <Object?>['certification-a'],
      });

      expect(empty.skillIds, isEmpty);
      expect(empty.otherSkillDetails, isNull);
      expect(empty.taxonomyVersion, 1);
      expect(empty.toMap(), {'taxonomyVersion': 1});
      expect(future.skillIds, {'future_taxonomy_skill'});
      expect(future.taxonomyVersion, 8);
      expect(future.toMap(), isNot(contains('futureCertificationIds')));
    });
  });

  group('MobilizationPreferences', () {
    test('round-trips several general preferences deterministically', () {
      final preferences = MobilizationPreferences(
        preferredMobilizationTypes: const {'heatwave', 'fire'},
        territoryIds: const {'gironde', 'landes'},
        locationIds: const {'merignac', 'langon'},
        preferredWeekdays: const {
          ProfessionalWeekday.saturday,
          ProfessionalWeekday.monday,
        },
        preferredTimeBands: const {'evening', 'morning'},
        schemaVersion: 2,
      );

      final restored = MobilizationPreferences.fromMap(preferences.toMap());

      expect(restored, preferences);
      expect(restored.hashCode, preferences.hashCode);
      expect(restored.toMap(), {
        'preferredMobilizationTypes': ['fire', 'heatwave'],
        'territoryIds': ['gironde', 'landes'],
        'locationIds': ['langon', 'merignac'],
        'preferredWeekdays': ['monday', 'saturday'],
        'preferredTimeBands': ['evening', 'morning'],
        'schemaVersion': 2,
      });
    });

    test(
      'keeps future type and time-band values without a closed taxonomy',
      () {
        final preferences = MobilizationPreferences.fromMap(const {
          'preferredMobilizationTypes': <Object?>['future_crisis_type'],
          'preferredTimeBands': <Object?>['night_shift_v2'],
          'schemaVersion': 9,
          'futurePreference': true,
        });

        expect(preferences.preferredMobilizationTypes, {'future_crisis_type'});
        expect(preferences.preferredTimeBands, {'night_shift_v2'});
        expect(preferences.schemaVersion, 9);
        expect(preferences.toMap(), isNot(contains('futurePreference')));
      },
    );

    test('defensively copies every preference collection', () {
      final types = <String>{'fire'};
      final territories = <String>{'gironde'};
      final locations = <String>{'langon'};
      final weekdays = <ProfessionalWeekday>{ProfessionalWeekday.monday};
      final timeBands = <String>{'morning'};
      final preferences = MobilizationPreferences(
        preferredMobilizationTypes: types,
        territoryIds: territories,
        locationIds: locations,
        preferredWeekdays: weekdays,
        preferredTimeBands: timeBands,
      );

      types.add('flood');
      territories.add('landes');
      locations.add('merignac');
      weekdays.add(ProfessionalWeekday.tuesday);
      timeBands.add('evening');

      expect(preferences.preferredMobilizationTypes, {'fire'});
      expect(preferences.territoryIds, {'gironde'});
      expect(preferences.locationIds, {'langon'});
      expect(preferences.preferredWeekdays, {ProfessionalWeekday.monday});
      expect(preferences.preferredTimeBands, {'morning'});
      expect(
        () => preferences.locationIds.add('bordeaux'),
        throwsUnsupportedError,
      );
    });

    test('accepts every optional preference as absent', () {
      final preferences = MobilizationPreferences.fromMap(const {});

      expect(preferences.preferredMobilizationTypes, isEmpty);
      expect(preferences.territoryIds, isEmpty);
      expect(preferences.locationIds, isEmpty);
      expect(preferences.preferredWeekdays, isEmpty);
      expect(preferences.preferredTimeBands, isEmpty);
      expect(preferences.toMap(), {'schemaVersion': 1});
    });
  });

  group('ProfessionalCommunicationPreferences', () {
    test('round-trips channels, existing categories and quiet hours', () {
      final preferences = ProfessionalCommunicationPreferences(
        push: true,
        email: true,
        sms: false,
        compatibleMissions: false,
        engagementUpdates: true,
        operationalAlerts: true,
        quietHours: ProfessionalQuietHours(startHour: 22, endHour: 7),
        schemaVersion: 2,
      );

      final restored = ProfessionalCommunicationPreferences.fromMap(
        preferences.toMap(),
      );

      expect(restored, preferences);
      expect(restored.hashCode, preferences.hashCode);
      expect(restored.toMap(), {
        'push': true,
        'email': true,
        'sms': false,
        'compatibleMissions': false,
        'engagementUpdates': true,
        'operationalAlerts': true,
        'quietHoursStart': 22,
        'quietHoursEnd': 7,
        'schemaVersion': 2,
      });
    });

    test('reads existing RC3 preference fields without channel choices', () {
      final preferences = ProfessionalCommunicationPreferences.fromMap(const {
        'compatibleMissions': false,
        'engagementUpdates': true,
        'operationalAlerts': true,
        'quietHoursStart': 22,
        'quietHoursEnd': 7,
        'updatedAt': 'future-storage-metadata',
      });

      expect(preferences.push, isNull);
      expect(preferences.email, isNull);
      expect(preferences.sms, isNull);
      expect(preferences.compatibleMissions, isFalse);
      expect(preferences.engagementUpdates, isTrue);
      expect(preferences.operationalAlerts, isTrue);
      expect(
        preferences.quietHours,
        ProfessionalQuietHours(startHour: 22, endHour: 7),
      );
      expect(preferences.toMap(), isNot(contains('updatedAt')));
    });

    test('does not serialize or infer a system notification permission', () {
      final preferences = ProfessionalCommunicationPreferences.fromMap(const {
        'push': true,
        'systemPermission': 'denied',
        'schemaVersion': 5,
      });

      expect(preferences.push, isTrue);
      expect(preferences.schemaVersion, 5);
      expect(preferences.toMap(), isNot(contains('systemPermission')));
    });

    test('accepts all optional communication fields as absent', () {
      final preferences = ProfessionalCommunicationPreferences.fromMap(
        const {},
      );

      expect(preferences.push, isNull);
      expect(preferences.email, isNull);
      expect(preferences.sms, isNull);
      expect(preferences.quietHours, isNull);
      expect(preferences.toMap(), {'schemaVersion': 1});
    });
  });

  group('ProfessionalConsentRecord', () {
    test('round-trips an immutable versioned proof', () {
      final recordedAt = DateTime.utc(2026, 8, 22, 8, 30);
      final record = ProfessionalConsentRecord(
        type: ProfessionalConsentType.termsOfUse,
        version: '2026-08',
        state: ProfessionalConsentState.granted,
        recordedAt: recordedAt,
        source: 'professional_profile',
      );

      final restored = ProfessionalConsentRecord.fromMap(record.toMap());

      expect(restored, record);
      expect(restored.hashCode, record.hashCode);
      expect(restored.toMap(), {
        'type': 'terms_of_use',
        'version': '2026-08',
        'state': 'granted',
        'recordedAt': recordedAt,
        'source': 'professional_profile',
      });
    });

    test('keeps several types and versions as distinct records', () {
      final records = <ProfessionalConsentRecord>[
        ProfessionalConsentRecord(
          type: ProfessionalConsentType.privacyNotice,
          version: '1',
          state: ProfessionalConsentState.granted,
          recordedAt: DateTime.utc(2026, 8, 1),
          source: 'engagement',
        ),
        ProfessionalConsentRecord(
          type: ProfessionalConsentType.privacyNotice,
          version: '2',
          state: ProfessionalConsentState.withdrawn,
          recordedAt: DateTime.utc(2026, 8, 22),
          source: 'professional_profile',
        ),
      ];

      final restored = records
          .map((record) => ProfessionalConsentRecord.fromMap(record.toMap()))
          .toList(growable: false);

      expect(restored, records);
      expect(restored.map((record) => record.version), ['1', '2']);
      expect(restored.map((record) => record.state), [
        ProfessionalConsentState.granted,
        ProfessionalConsentState.withdrawn,
      ]);
    });

    test('preserves additive future type and state values', () {
      final record = ProfessionalConsentRecord.fromMap({
        'type': 'future_consent',
        'version': 'v3',
        'state': 'superseded',
        'recordedAt': DateTime.utc(2026, 8, 22),
        'source': 'future_import',
        'futureEvidence': <String, Object?>{'trace': 'abc'},
      });

      expect(record.type.serializedValue, 'future_consent');
      expect(record.state.serializedValue, 'superseded');
      expect(record.toMap(), isNot(contains('futureEvidence')));
    });
  });

  test('an RC3 profile remains valid without any V2 contract', () {
    const legacyProfile = VolunteerProfile(
      uid: 'legacy-professional',
      firstName: 'Alice',
      lastName: 'Martin',
      phone: '0600000000',
      rpps: '10123456789',
      profession: VolunteerProfession.mk,
    );

    expect(legacyProfile.effectiveProfessionalIdType, ProfessionalIdType.rpps);
    expect(legacyProfile.effectiveProfessionalIdValue, '10123456789');
    expect(ProfessionalCompetencies.fromMap(const {}).skillIds, isEmpty);
    expect(
      MobilizationPreferences.fromMap(const {}).preferredMobilizationTypes,
      isEmpty,
    );
    expect(ProfessionalCommunicationPreferences.fromMap(const {}).push, isNull);
  });
}
