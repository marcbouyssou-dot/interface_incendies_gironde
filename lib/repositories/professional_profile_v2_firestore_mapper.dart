import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mobilization_preferences.dart';
import '../models/professional_communication_preferences.dart';
import '../models/professional_competencies.dart';
import '../models/professional_consent.dart';
import '../models/volunteer_profile.dart';

typedef ProfessionalProfileV2Fields = ({
  int? profileSchemaVersion,
  ProfessionalCompetencies? competencies,
  MobilizationPreferences? mobilizationPreferences,
  ProfessionalCommunicationPreferences? communicationPreferences,
  List<ProfessionalConsentRecord>? consentRecords,
});

abstract final class ProfessionalProfileV2FirestoreMapper {
  static ProfessionalProfileV2Fields fromFirestore(Map<String, dynamic> data) {
    final rawSchemaVersion = data['profileSchemaVersion'];
    if (rawSchemaVersion != null &&
        (rawSchemaVersion is! int || rawSchemaVersion < 1)) {
      throw const FormatException('Version de profil invalide.');
    }
    final competencies = _optionalMap(data, 'competencies');
    final mobilizationPreferences = _optionalMap(
      data,
      'mobilizationPreferences',
    );
    final communicationPreferences = _optionalMap(
      data,
      'communicationPreferences',
    );
    return (
      profileSchemaVersion: rawSchemaVersion as int?,
      competencies: competencies == null
          ? null
          : ProfessionalCompetencies.fromMap(competencies),
      mobilizationPreferences: mobilizationPreferences == null
          ? null
          : MobilizationPreferences.fromMap(mobilizationPreferences),
      communicationPreferences: communicationPreferences == null
          ? null
          : ProfessionalCommunicationPreferences.fromMap(
              communicationPreferences,
            ),
      consentRecords: _consentRecordsFromFirestore(data['consentRecords']),
    );
  }

  static Map<String, Object?> toFirestore(VolunteerProfile profile) => {
    if (profile.profileSchemaVersion != null)
      'profileSchemaVersion': profile.profileSchemaVersion,
    if (profile.competencies != null)
      'competencies': profile.competencies!.toMap(),
    if (profile.mobilizationPreferences != null)
      'mobilizationPreferences': profile.mobilizationPreferences!.toMap(),
    if (profile.communicationPreferences != null)
      'communicationPreferences': profile.communicationPreferences!.toMap(),
    if (profile.consentRecords != null)
      'consentRecords': profile.consentRecords!
          .map(
            (record) => {
              ...record.toMap(),
              'recordedAt': Timestamp.fromDate(record.recordedAt),
            },
          )
          .toList(growable: false),
  };

  static Map<String, Object?> forSave({
    required VolunteerProfile profile,
    Map<String, dynamic>? existingData,
  }) {
    final explicit = toFirestore(profile);
    return {
      for (final key in _fieldNames)
        if (explicit.containsKey(key))
          key: explicit[key]
        else if (existingData?.containsKey(key) ?? false)
          key: existingData![key],
    };
  }

  static const _fieldNames = <String>[
    'profileSchemaVersion',
    'competencies',
    'mobilizationPreferences',
    'communicationPreferences',
    'consentRecords',
  ];

  static Map<String, Object?>? _optionalMap(
    Map<String, dynamic> data,
    String key,
  ) {
    final value = data[key];
    if (value == null) return null;
    if (value is! Map) {
      throw FormatException('Bloc $key invalide.');
    }
    return value.map((key, value) {
      if (key is! String) throw FormatException('Bloc $key invalide.');
      return MapEntry(key, value);
    });
  }

  static List<ProfessionalConsentRecord>? _consentRecordsFromFirestore(
    Object? value,
  ) {
    if (value == null) return null;
    if (value is! List) {
      throw const FormatException('Consentements professionnels invalides.');
    }
    return List<ProfessionalConsentRecord>.unmodifiable(
      value.map((item) {
        if (item is! Map) {
          throw const FormatException('Consentement professionnel invalide.');
        }
        final data = item.map((key, value) {
          if (key is! String) {
            throw const FormatException('Consentement professionnel invalide.');
          }
          return MapEntry<String, Object?>(key, value);
        });
        final recordedAt = data['recordedAt'];
        if (recordedAt is Timestamp) {
          data['recordedAt'] = recordedAt.toDate().toUtc();
        }
        return ProfessionalConsentRecord.fromMap(data);
      }),
    );
  }
}
