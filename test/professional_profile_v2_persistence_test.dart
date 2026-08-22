import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/mobilization_preferences.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/professional_communication_preferences.dart';
import 'package:interface_incendies_gironde/models/professional_competencies.dart';
import 'package:interface_incendies_gironde/models/professional_consent.dart';
import 'package:interface_incendies_gironde/models/volunteer_profile.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/professional_profile_v2_firestore_mapper.dart';

void main() {
  group('ProfessionalProfileV2FirestoreMapper', () {
    test('accepts a legacy RC3 document without V2 data', () {
      final fields = ProfessionalProfileV2FirestoreMapper.fromFirestore({
        'futureTopLevelField': true,
      });

      expect(fields.profileSchemaVersion, isNull);
      expect(fields.competencies, isNull);
      expect(fields.mobilizationPreferences, isNull);
      expect(fields.communicationPreferences, isNull);
      expect(fields.consentRecords, isNull);
    });

    test('round-trips a complete V2 profile with versioned consents', () {
      final profile = _v2Profile();

      final serialized = ProfessionalProfileV2FirestoreMapper.toFirestore(
        profile,
      );
      final fields = ProfessionalProfileV2FirestoreMapper.fromFirestore(
        Map<String, dynamic>.from(serialized),
      );

      expect(fields.profileSchemaVersion, 2);
      expect(fields.competencies, profile.competencies);
      expect(fields.mobilizationPreferences, profile.mobilizationPreferences);
      expect(fields.communicationPreferences, profile.communicationPreferences);
      expect(
        fields.consentRecords?.map((record) => record.toMap()).toList(),
        profile.consentRecords?.map((record) => record.toMap()).toList(),
      );
      final consentData = (serialized['consentRecords']! as List).first as Map;
      expect(consentData['recordedAt'], isA<Timestamp>());
    });

    test('accepts partial blocks and ignores future nested fields', () {
      final fields = ProfessionalProfileV2FirestoreMapper.fromFirestore({
        'profileSchemaVersion': 4,
        'competencies': {
          'taxonomyVersion': 2,
          'futureCompetencyField': {'enabled': true},
        },
        'mobilizationPreferences': {
          'preferredMobilizationTypes': ['future_mobilization'],
          'futurePreferenceField': 42,
        },
        'communicationPreferences': {
          'push': true,
          'futureCommunicationField': 'ignored',
        },
        'consentRecords': [
          {
            'type': 'future_consent',
            'version': 'v3',
            'state': 'future_state',
            'recordedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 22)),
            'source': 'future_source',
            'futureConsentField': false,
          },
        ],
      });

      expect(fields.competencies?.skillIds, isEmpty);
      expect(fields.competencies?.taxonomyVersion, 2);
      expect(fields.mobilizationPreferences?.preferredMobilizationTypes, {
        'future_mobilization',
      });
      expect(fields.communicationPreferences?.push, isTrue);
      expect(
        fields.consentRecords?.single.type,
        ProfessionalConsentType('future_consent'),
      );
      expect(
        fields.consentRecords?.single.state,
        ProfessionalConsentState('future_state'),
      );
    });

    test('preserves existing V2 fields during an RC3-only save', () {
      final existing = ProfessionalProfileV2FirestoreMapper.toFirestore(
        _v2Profile(),
      );
      const rc3Only = VolunteerProfile(
        uid: 'professional',
        firstName: 'Alice',
        lastName: 'Martin',
        phone: '0600000000',
        profession: VolunteerProfession.mk,
      );

      final merged = ProfessionalProfileV2FirestoreMapper.forSave(
        profile: rc3Only,
        existingData: Map<String, dynamic>.from(existing),
      );

      expect(merged, existing);
    });
  });

  group('Mock profile V2 persistence', () {
    test('persists and reloads every optional V2 block', () async {
      final repository = MockCoordinationRepository(
        initialMissions: const [],
        initialLocations: const [],
      );
      final profile = _v2Profile(uid: 'mock-volunteer');

      await repository.saveVolunteerProfile(profile);
      final saved = await repository.getVolunteerProfile();

      expect(saved?.profileSchemaVersion, 2);
      expect(saved?.competencies, profile.competencies);
      expect(saved?.mobilizationPreferences, profile.mobilizationPreferences);
      expect(saved?.communicationPreferences, profile.communicationPreferences);
      expect(saved?.consentRecords, profile.consentRecords);
    });

    test('an RC3 edit preserves existing additive V2 blocks', () async {
      final repository = MockCoordinationRepository(
        initialMissions: const [],
        initialLocations: const [],
        initialProfiles: {'mock-volunteer': _v2Profile(uid: 'mock-volunteer')},
      );
      const rc3Edit = VolunteerProfile(
        uid: 'mock-volunteer',
        firstName: 'Alice',
        lastName: 'Martin',
        phone: '0611111111',
        email: 'alice@example.fr',
        professionalIdType: ProfessionalIdType.rpps,
        professionalIdValue: '10123456789',
        profession: VolunteerProfession.mk,
      );

      await repository.saveVolunteerProfile(rc3Edit);
      final saved = await repository.getVolunteerProfile();

      expect(saved?.phone, '0611111111');
      expect(saved?.profileSchemaVersion, 2);
      expect(saved?.competencies?.skillIds, {'triage', 'emergency_care'});
      expect(saved?.consentRecords, hasLength(2));
    });

    test('the RC3 engagement flow preserves additive V2 blocks', () async {
      final repository = MockCoordinationRepository(
        initialMissions: [
          CoordinationNeed(
            id: 'mission',
            place: 'Site',
            group: TerritorialGroup.medoc,
            date: 'Aujourd’hui',
            time: '08:00 — 12:00',
            endAt: DateTime.now().add(const Duration(hours: 2)),
            requiredPhysiotherapists: 1,
            registeredPhysiotherapists: 0,
            requiredPodiatrists: 0,
            registeredPodiatrists: 0,
            equipment: const [],
          ),
        ],
        initialLocations: const [],
        initialProfiles: {'mock-volunteer': _v2Profile(uid: 'mock-volunteer')},
      );

      await repository.createEngagement(
        missionId: 'mission',
        firstName: 'Alice',
        lastName: 'Martin',
        phone: '0600000000',
        email: 'alice@example.fr',
        professionalIdType: ProfessionalIdType.rpps,
        professionalIdValue: '10123456789',
        profession: VolunteerProfession.mk,
      );
      final saved = await repository.getVolunteerProfile();

      expect(saved?.competencies?.skillIds, {'triage', 'emergency_care'});
      expect(saved?.mobilizationPreferences?.territoryIds, {
        'gironde',
        'landes',
      });
      expect(saved?.communicationPreferences?.push, isTrue);
      expect(saved?.consentRecords, hasLength(2));
    });
  });
}

VolunteerProfile _v2Profile({String uid = 'professional'}) => VolunteerProfile(
  uid: uid,
  firstName: 'Alice',
  lastName: 'Martin',
  phone: '0600000000',
  email: 'alice@example.fr',
  profession: VolunteerProfession.mk,
  professionalIdType: ProfessionalIdType.rpps,
  professionalIdValue: '10123456789',
  profileSchemaVersion: 2,
  competencies: ProfessionalCompetencies(
    skillIds: const ['triage', 'emergency_care'],
    otherSkillDetails: 'Coordination terrain',
    taxonomyVersion: 3,
  ),
  mobilizationPreferences: MobilizationPreferences(
    preferredMobilizationTypes: const ['emergency', 'reinforcement'],
    territoryIds: const ['gironde', 'landes'],
    locationIds: const ['site-a', 'site-b'],
    preferredWeekdays: const [
      ProfessionalWeekday.monday,
      ProfessionalWeekday.saturday,
    ],
    preferredTimeBands: const ['morning', 'evening'],
    schemaVersion: 2,
  ),
  communicationPreferences: ProfessionalCommunicationPreferences(
    push: true,
    email: false,
    sms: true,
    compatibleMissions: true,
    engagementUpdates: false,
    operationalAlerts: true,
    quietHours: ProfessionalQuietHours(startHour: 22, endHour: 7),
    schemaVersion: 2,
  ),
  consentRecords: [
    ProfessionalConsentRecord(
      type: ProfessionalConsentType.privacyNotice,
      version: '2026-08',
      state: ProfessionalConsentState.granted,
      recordedAt: DateTime.utc(2026, 8, 1),
      source: 'profile',
    ),
    ProfessionalConsentRecord(
      type: ProfessionalConsentType.privacyNotice,
      version: '2027-01',
      state: ProfessionalConsentState.withdrawn,
      recordedAt: DateTime.utc(2027, 1, 2),
      source: 'profile',
    ),
  ],
);
