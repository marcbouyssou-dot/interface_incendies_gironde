const DEFAULT_PREFERENCES = Object.freeze({
  compatibleMissions: false,
  engagementUpdates: true,
  operationalAlerts: true,
  quietHoursStart: 22,
  quietHoursEnd: 7,
});

export function recipientsForEvent({event, mission, roles, volunteers, engagements, preferences, recentNotifications, now}) {
  const recipients = new Map();
  const add = (uid, role, category) => {
    if (!uid || uid === event.actorUid) return;
    const prefs = {...DEFAULT_PREFERENCES, ...(preferences.get(uid) ?? {})};
    if (category === 'compatible' && !prefs.compatibleMissions) return;
    if (category === 'engagement' && !prefs.engagementUpdates) return;
    if (category === 'operational' && !prefs.operationalAlerts) return;
    recipients.set(uid, {uid, role, preferences: prefs});
  };
  const activeEngagements = engagements.filter((item) =>
    item.status !== 'cancelled' && item.missionId === event.missionId);
  if (event.eventType === 'mission.published') {
    const endAt = mission.endAt?.toMillis?.() ?? Number.POSITIVE_INFINITY;
    if (mission.isActive !== true || mission.status === 'cancelled' || endAt <= now) {
      return [];
    }
    const needed = neededProfessions(event.payload);
    for (const volunteer of volunteers) {
      if (!needed.has(canonicalProfession(volunteer.profession))) continue;
      if (activeEngagements.some((item) => item.volunteerId === volunteer.uid)) continue;
      const solicitations = (recentNotifications.get(volunteer.uid) ?? [])
        .filter((item) => item.category === 'compatible' && now - item.occurredAt < 86400000);
      if (solicitations.length < 3) add(volunteer.uid, 'professional', 'compatible');
    }
  }
  if (event.eventType === 'mission.updated' || event.eventType === 'mission.cancelled') {
    for (const engagement of activeEngagements) {
      add(engagement.volunteerId, 'professional', 'engagement');
    }
  }
  const managerEvent = [
    'engagement.created', 'engagement.cancelled',
    'mission.became_critical', 'mission.fully_covered',
  ].includes(event.eventType);
  if (managerEvent) {
    add(mission.createdBy, 'responsible', 'operational');
    for (const role of roles) {
      if (hasRole(role, 'site_manager') && role.locationIds?.includes(mission.locationId)) {
        add(role.uid, 'responsible', 'operational');
      }
    }
  }
  if (event.eventType === 'mission.became_critical' ||
      (event.eventType === 'mission.cancelled' && importantCancellation(mission, now))) {
    for (const role of roles) {
      if (hasRole(role, 'coordinator')) add(role.uid, 'coordinator', 'operational');
    }
  }
  return [...recipients.values()];
}

export function notificationContent(event) {
  const place = event.payload.locationName || 'Centre concerné';
  return switchContent(event.eventType, place, event);
}

function switchContent(type, place, event) {
  if (type === 'mission.published') return {title: `Mission disponible à ${place}`, body: 'Une mission compatible recherche votre profession.'};
  if (type === 'mission.updated') return {title: 'Votre mission a été modifiée', body: `${place} · consultez les nouvelles informations.`};
  if (type === 'mission.cancelled') return {title: 'Mission annulée', body: `${place} · consultez le contexte.`};
  if (type === 'engagement.created') return {title: 'Nouvel engagement', body: `${place} · un professionnel a rejoint la mission.`};
  if (type === 'engagement.cancelled') return {title: 'Désengagement reçu', body: `${place} · vérifiez la couverture.`};
  if (type === 'mission.became_critical') return {title: 'Une mission devient critique', body: `${place} · une action est nécessaire.`};
  return {title: 'Votre besoin est maintenant couvert', body: `${place} · l’équipe attendue est complète.`};
}

export function isQuietHour(preferences, date) {
  const start = preferences.quietHoursStart ?? 22;
  const end = preferences.quietHoursEnd ?? 7;
  const hour = Number(new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/Paris', hour: '2-digit', hourCycle: 'h23',
  }).format(date));
  return start > end ? hour >= start || hour < end : hour >= start && hour < end;
}

export function isCriticalEvent(type) {
  return type === 'mission.cancelled' || type === 'mission.became_critical';
}

function neededProfessions(payload) {
  const required = payload.requiredByProfession ?? {};
  const registered = payload.registeredByProfession ?? {};
  return new Set(Object.keys(required).filter((key) => (required[key] ?? 0) > (registered[key] ?? 0)));
}

function canonicalProfession(value) {
  return {mk: 'physiotherapist', pp: 'podiatrist', doctor: 'physician', otherHealthProfessional: 'other_health_professional'}[value] ?? value;
}

function hasRole(role, expected) {
  return role.active === true && (role.roles?.includes(expected) || role.role === expected);
}

function importantCancellation(mission, now) {
  const start = mission.startAt?.toMillis?.() ?? Number.POSITIVE_INFINITY;
  return start - now <= 86400000;
}
