enum AppNotificationType {
  missionPublished,
  missionUpdated,
  missionCancelled,
  engagementCreated,
  engagementCancelled,
  missionBecameCritical,
  missionFullyCovered,
}

AppNotificationType appNotificationTypeFromValue(String value) =>
    switch (value) {
      'mission.published' => AppNotificationType.missionPublished,
      'mission.updated' => AppNotificationType.missionUpdated,
      'mission.cancelled' => AppNotificationType.missionCancelled,
      'engagement.created' => AppNotificationType.engagementCreated,
      'engagement.cancelled' => AppNotificationType.engagementCancelled,
      'mission.became_critical' => AppNotificationType.missionBecameCritical,
      'mission.fully_covered' => AppNotificationType.missionFullyCovered,
      _ => throw FormatException('Type de notification inconnu : $value'),
    };

class AppNotification {
  const AppNotification({
    required this.id,
    required this.eventId,
    required this.type,
    required this.title,
    required this.body,
    required this.occurredAt,
    required this.missionId,
    this.engagementId,
    this.readAt,
  });

  final String id;
  final String eventId;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime occurredAt;
  final String missionId;
  final String? engagementId;
  final DateTime? readAt;

  bool get isRead => readAt != null;
}

class NotificationPreferences {
  const NotificationPreferences({
    this.compatibleMissions = false,
    this.engagementUpdates = true,
    this.operationalAlerts = true,
    this.quietHoursStart = 22,
    this.quietHoursEnd = 7,
  });

  final bool compatibleMissions;
  final bool engagementUpdates;
  final bool operationalAlerts;
  final int quietHoursStart;
  final int quietHoursEnd;

  NotificationPreferences copyWith({
    bool? compatibleMissions,
    bool? engagementUpdates,
    bool? operationalAlerts,
  }) => NotificationPreferences(
    compatibleMissions: compatibleMissions ?? this.compatibleMissions,
    engagementUpdates: engagementUpdates ?? this.engagementUpdates,
    operationalAlerts: operationalAlerts ?? this.operationalAlerts,
    quietHoursStart: quietHoursStart,
    quietHoursEnd: quietHoursEnd,
  );
}

class PushSubscriptionRegistration {
  const PushSubscriptionRegistration({
    required this.installationId,
    required this.token,
    required this.platform,
  });

  final String installationId;
  final String token;
  final String platform;
}
