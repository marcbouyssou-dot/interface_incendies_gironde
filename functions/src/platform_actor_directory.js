const PROFESSIONAL_STATUSES = new Set([
  'pending',
  'confirmed',
  'standby',
  'cancelled',
]);

export class PlatformActorDirectoryError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'PlatformActorDirectoryError';
    this.code = code;
  }
}

export async function listPlatformActorDirectory({callerUid, services}) {
  if (!hasText(callerUid)) {
    throw new PlatformActorDirectoryError(
      'unauthenticated',
      'Authentification requise.',
    );
  }
  const authorized = await services.isPlatformAdministrator(callerUid);
  if (!authorized) {
    throw new PlatformActorDirectoryError(
      'permission-denied',
      'Accès Administrateur plateforme requis.',
    );
  }
  return buildPlatformActorDirectory(await services.loadDirectoryData());
}

export function buildPlatformActorDirectory(data) {
  const operations = indexById(data.operations);
  const mobilizations = indexById(data.mobilizations);
  const missions = indexById(data.missions);
  const locations = indexById(data.locations);
  const territories = indexById(data.territories);
  const volunteers = indexById(data.volunteers);
  const roleIdentities = new Map(
    (data.roleIdentities ?? []).map((identity) => [identity.uid, identity]),
  );

  const professionalGroups = new Map();
  for (const engagement of data.engagements ?? []) {
    if (!hasText(engagement.volunteerId) || !hasText(engagement.missionId)) {
      continue;
    }
    const mission = missions.get(engagement.missionId);
    if (!mission) continue;
    const mobilizationId = textOrNull(engagement.mobilizationId)
      ?? textOrNull(mission.mobilizationId);
    const mobilization = mobilizations.get(mobilizationId);
    const operation = operations.get(textOrNull(mobilization?.operationId));
    const locationId = textOrNull(mission.locationId);
    const location = locations.get(locationId);
    const territory = territories.get(textOrNull(mobilization?.territoryId));
    const profession = textOrNull(engagement.profession) ?? 'unknown';
    const group = professionalGroups.get(engagement.volunteerId) ?? [];
    group.push({
      missionId: mission.id,
      missionLabel: textOrNull(mission.locationName)
        ?? textOrNull(location?.name)
        ?? 'Mission',
      mobilizationId: textOrNull(mobilization?.id),
      mobilizationLabel: textOrNull(mobilization?.name),
      operationId: textOrNull(operation?.id),
      operationLabel: textOrNull(operation?.name),
      locationId,
      locationLabel: textOrNull(location?.name)
        ?? textOrNull(mission.locationName),
      territoryId: textOrNull(territory?.id),
      territoryLabel: textOrNull(territory?.name),
      profession,
      professionLabel: professionLabel(profession),
      status: PROFESSIONAL_STATUSES.has(engagement.status)
        ? engagement.status
        : 'confirmed',
      occurredAt: timestampText(engagement.updatedAt)
        ?? timestampText(engagement.createdAt),
    });
    professionalGroups.set(engagement.volunteerId, group);
  }

  const professionals = [...professionalGroups.entries()].map(
    ([uid, participations]) => {
      const profile = volunteers.get(uid);
      const professions = unique(
        participations.map((item) => item.professionLabel),
      );
      const postalCode = textOrNull(profile?.professionalPostalCode);
      return {
        uid,
        displayName: professionalDisplayName(profile),
        professionLabel: professions.join(', ') || 'Profession non renseignée',
        cptsId: textOrNull(profile?.cptsId),
        cptsLabel: textOrNull(profile?.cptsLabel),
        departmentLabel: departmentLabel(postalCode),
        regionLabel: regionLabel(postalCode),
        participations: participations.sort(compareParticipation),
      };
    },
  ).sort(compareActor);

  const assignmentsByUid = groupBy(data.assignments, (item) => item.uid);
  const missionsByLocation = groupBy(
    [...missions.values()],
    (item) => item.locationId,
  );
  const coordinators = [];
  const managers = [];
  for (const role of data.roles ?? []) {
    if (!hasText(role.id)) continue;
    const roles = normalizedRoles(role);
    const identity = roleIdentities.get(role.id);
    const base = {
      uid: role.id,
      displayName: textOrNull(identity?.displayName),
      active: role.active === true,
    };
    if (roles.has('coordinator')) {
      const assignedMobilizations = uniqueById(
        (assignmentsByUid.get(role.id) ?? []).map((assignment) => {
          const mobilization = mobilizations.get(assignment.mobilizationId);
          if (!mobilization) return null;
          return {
            id: mobilization.id,
            label: textOrNull(mobilization.name) ?? 'Mobilisation',
            active: assignment.active === true,
          };
        }).filter(Boolean),
      );
      const operationIds = new Set(
        assignedMobilizations
          .map((item) => mobilizations.get(item.id)?.operationId)
          .filter(hasText),
      );
      for (const operation of operations.values()) {
        if (operation.coordinatorUid === role.id) operationIds.add(operation.id);
      }
      coordinators.push({
        ...base,
        mobilizations: assignedMobilizations,
        operations: [...operationIds]
          .map((id) => operations.get(id))
          .filter(Boolean)
          .map((item) => ({id: item.id, label: item.name}))
          .sort(compareLabel),
      });
    }
    if (roles.has('site_manager')) {
      const managedLocations = unique(
        Array.isArray(role.locationIds) ? role.locationIds.filter(hasText) : [],
      ).map((id) => ({
        id,
        label: textOrNull(locations.get(id)?.name) ?? 'Établissement',
      })).sort(compareLabel);
      const relatedMobilizations = new Map();
      for (const location of managedLocations) {
        for (const mission of missionsByLocation.get(location.id) ?? []) {
          const mobilization = mobilizations.get(mission.mobilizationId);
          if (mobilization) relatedMobilizations.set(mobilization.id, mobilization);
        }
      }
      const relatedOperations = uniqueById(
        [...relatedMobilizations.values()]
          .map((item) => operations.get(item.operationId))
          .filter(Boolean)
          .map((item) => ({id: item.id, label: item.name})),
      ).sort(compareLabel);
      const relatedTerritories = uniqueById(
        [...relatedMobilizations.values()]
          .map((item) => territories.get(item.territoryId))
          .filter(Boolean)
          .map((item) => ({id: item.id, label: item.name})),
      ).sort(compareLabel);
      managers.push({
        ...base,
        locations: managedLocations,
        operations: relatedOperations,
        territories: relatedTerritories,
      });
    }
  }

  coordinators.sort(compareActor);
  managers.sort(compareActor);
  return {professionals, coordinators, managers};
}

function indexById(values = []) {
  return new Map(values.filter((item) => hasText(item?.id)).map((item) => [item.id, item]));
}

function groupBy(values = [], keyOf) {
  const result = new Map();
  for (const value of values) {
    const key = keyOf(value);
    if (!hasText(key)) continue;
    const group = result.get(key) ?? [];
    group.push(value);
    result.set(key, group);
  }
  return result;
}

function normalizedRoles(role) {
  const values = Array.isArray(role.roles) ? role.roles : [role.role];
  return new Set(values.filter((value) =>
    value === 'coordinator' || value === 'site_manager'));
}

function professionalDisplayName(profile) {
  const verified = profile?.verificationStatus === 'verified'
    && profile?.verificationSource === 'ans_rpps';
  const firstName = verified
    ? textOrNull(profile?.verifiedFirstName)
    : textOrNull(profile?.firstName);
  const lastName = verified
    ? textOrNull(profile?.verifiedLastName)
    : textOrNull(profile?.lastName);
  return [firstName, lastName].filter(Boolean).join(' ') || null;
}

function departmentLabel(postalCode) {
  if (!hasText(postalCode) || !/^\d{5}$/.test(postalCode)) return null;
  const code = postalCode.startsWith('97') || postalCode.startsWith('98')
    ? postalCode.slice(0, 3)
    : postalCode.slice(0, 2);
  return code === '33' ? 'Gironde' : `Département ${code}`;
}

function regionLabel(postalCode) {
  if (!hasText(postalCode) || !/^\d{5}$/.test(postalCode)) return null;
  const code = postalCode.slice(0, 2);
  return new Set([
    '16', '17', '19', '23', '24', '33', '40', '47', '64', '79', '86', '87',
  ]).has(code) ? 'Nouvelle-Aquitaine' : null;
}

function professionLabel(value) {
  return {
    physiotherapist: 'Masseur-Kinésithérapeute',
    mk: 'Masseur-Kinésithérapeute',
    podiatrist: 'Pédicure-Podologue',
    pp: 'Pédicure-Podologue',
    physician: 'Médecin',
    doctor: 'Médecin',
    nurse: 'Infirmier',
    veterinarian: 'Vétérinaire',
    other_health_professional: 'Autre professionnel de santé',
    otherHealthProfessional: 'Autre professionnel de santé',
  }[value] ?? 'Profession non renseignée';
}

function compareParticipation(left, right) {
  return (right.occurredAt ?? '').localeCompare(left.occurredAt ?? '');
}

function compareActor(left, right) {
  return (left.displayName ?? left.uid).localeCompare(
    right.displayName ?? right.uid,
    'fr',
  );
}

function compareLabel(left, right) {
  return left.label.localeCompare(right.label, 'fr');
}

function unique(values) {
  return [...new Set(values)];
}

function uniqueById(values) {
  return [...new Map(values.map((value) => [value.id, value])).values()];
}

function timestampText(value) {
  const date = value?.toDate instanceof Function ? value.toDate() : value;
  return date instanceof Date && !Number.isNaN(date.valueOf())
    ? date.toISOString()
    : null;
}

function textOrNull(value) {
  return hasText(value) ? value.trim() : null;
}

function hasText(value) {
  return typeof value === 'string' && value.trim() !== '';
}
