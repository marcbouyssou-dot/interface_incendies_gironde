/// Plage horaire récurrente durant laquelle les contacts doivent être évités.
///
/// Elle reprend la représentation horaire RC3 sans lui ajouter de fuseau ou de
/// comportement implicite.
class ProfessionalQuietHours {
  factory ProfessionalQuietHours({
    required int startHour,
    required int endHour,
  }) {
    if (startHour < 0 || startHour > 23 || endHour < 0 || endHour > 23) {
      throw const FormatException('Heures calmes invalides.');
    }
    return ProfessionalQuietHours._(startHour: startHour, endHour: endHour);
  }

  const ProfessionalQuietHours._({
    required this.startHour,
    required this.endHour,
  });

  factory ProfessionalQuietHours.fromMap(Map<String, Object?> data) {
    final startHour = data['quietHoursStart'];
    final endHour = data['quietHoursEnd'];
    if (startHour is! int ||
        endHour is! int ||
        startHour < 0 ||
        startHour > 23 ||
        endHour < 0 ||
        endHour > 23) {
      throw const FormatException('Heures calmes invalides.');
    }
    return ProfessionalQuietHours(startHour: startHour, endHour: endHour);
  }

  final int startHour;
  final int endHour;

  Map<String, Object?> toMap() => {
    'quietHoursStart': startHour,
    'quietHoursEnd': endHour,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionalQuietHours &&
          startHour == other.startHour &&
          endHour == other.endHour;

  @override
  int get hashCode => Object.hash(startHour, endHour);
}

/// Préférences métier de contact du professionnel.
///
/// [push] exprime un choix métier et non la permission système du navigateur ou
/// de l'OS. Une valeur nulle signifie que le choix n'a pas encore été exprimé.
/// Les trois catégories RC3 restent disponibles sans changement de nom.
class ProfessionalCommunicationPreferences {
  factory ProfessionalCommunicationPreferences({
    bool? push,
    bool? email,
    bool? sms,
    bool? compatibleMissions,
    bool? engagementUpdates,
    bool? operationalAlerts,
    ProfessionalQuietHours? quietHours,
    int schemaVersion = 1,
  }) {
    if (schemaVersion < 1) {
      throw const FormatException(
        'Version de préférences de communication invalide.',
      );
    }
    return ProfessionalCommunicationPreferences._(
      push: push,
      email: email,
      sms: sms,
      compatibleMissions: compatibleMissions,
      engagementUpdates: engagementUpdates,
      operationalAlerts: operationalAlerts,
      quietHours: quietHours,
      schemaVersion: schemaVersion,
    );
  }

  const ProfessionalCommunicationPreferences._({
    required this.push,
    required this.email,
    required this.sms,
    required this.compatibleMissions,
    required this.engagementUpdates,
    required this.operationalAlerts,
    required this.quietHours,
    required this.schemaVersion,
  });

  factory ProfessionalCommunicationPreferences.fromMap(
    Map<String, Object?> data,
  ) {
    final quietHoursStart = data['quietHoursStart'];
    final quietHoursEnd = data['quietHoursEnd'];
    if ((quietHoursStart == null) != (quietHoursEnd == null)) {
      throw const FormatException('Heures calmes incomplètes.');
    }
    final schemaVersion = data['schemaVersion'] ?? 1;
    if (schemaVersion is! int || schemaVersion < 1) {
      throw const FormatException(
        'Version de préférences de communication invalide.',
      );
    }
    return ProfessionalCommunicationPreferences(
      push: _optionalBool(data, 'push'),
      email: _optionalBool(data, 'email'),
      sms: _optionalBool(data, 'sms'),
      compatibleMissions: _optionalBool(data, 'compatibleMissions'),
      engagementUpdates: _optionalBool(data, 'engagementUpdates'),
      operationalAlerts: _optionalBool(data, 'operationalAlerts'),
      quietHours: quietHoursStart == null
          ? null
          : ProfessionalQuietHours.fromMap(data),
      schemaVersion: schemaVersion,
    );
  }

  final bool? push;
  final bool? email;
  final bool? sms;
  final bool? compatibleMissions;
  final bool? engagementUpdates;
  final bool? operationalAlerts;
  final ProfessionalQuietHours? quietHours;
  final int schemaVersion;

  Map<String, Object?> toMap() => {
    if (push != null) 'push': push,
    if (email != null) 'email': email,
    if (sms != null) 'sms': sms,
    if (compatibleMissions != null) 'compatibleMissions': compatibleMissions,
    if (engagementUpdates != null) 'engagementUpdates': engagementUpdates,
    if (operationalAlerts != null) 'operationalAlerts': operationalAlerts,
    if (quietHours != null) ...quietHours!.toMap(),
    'schemaVersion': schemaVersion,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionalCommunicationPreferences &&
          push == other.push &&
          email == other.email &&
          sms == other.sms &&
          compatibleMissions == other.compatibleMissions &&
          engagementUpdates == other.engagementUpdates &&
          operationalAlerts == other.operationalAlerts &&
          quietHours == other.quietHours &&
          schemaVersion == other.schemaVersion;

  @override
  int get hashCode => Object.hash(
    push,
    email,
    sms,
    compatibleMissions,
    engagementUpdates,
    operationalAlerts,
    quietHours,
    schemaVersion,
  );
}

bool? _optionalBool(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! bool) {
    throw const FormatException('Préférences de communication invalides.');
  }
  return value;
}
