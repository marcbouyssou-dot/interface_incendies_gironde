const MISSION_TEAM_FIELDS = Object.freeze(['missionId']);

export class UserDisplayIdentityError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'UserDisplayIdentityError';
    this.code = code;
  }
}

export async function listMissionTeam({callerUid, data, services}) {
  requireCaller(callerUid);
  if (!isPlainObject(data) || !hasExactlyKeys(data, MISSION_TEAM_FIELDS)) {
    throw invalidArgument();
  }
  const missionId = requiredText(data.missionId);
  const members = await services.listMissionTeam({callerUid, missionId});
  return {members};
}

export async function listPlatformCoordinatorIdentities({
  callerUid,
  services,
}) {
  requireCaller(callerUid);
  const coordinators = await services.listPlatformCoordinators({callerUid});
  return {coordinators};
}

export function safeProfessionalIdentity({engagement, profile}) {
  const uid = requiredText(engagement.volunteerId);
  const profession = requiredText(engagement.profession);
  const verified = profile?.verificationStatus === 'verified'
    && profile?.verificationSource === 'ans_rpps'
    && hasText(profile?.verifiedFirstName)
    && hasText(profile?.verifiedLastName);
  const firstName = verified
    ? profile.verifiedFirstName.trim()
    : optionalText(profile?.firstName);
  const lastName = verified
    ? profile.verifiedLastName.trim()
    : optionalText(profile?.lastName);
  const displayName = [firstName, lastName].filter(Boolean).join(' ') || null;
  return {
    uid,
    missionId: requiredText(engagement.missionId),
    displayName,
    profession,
    professionLabel: verified
      ? optionalText(profile.verifiedProfessionLabel)
        ?? professionLabel(profession)
      : professionLabel(profession),
    organizationLabel: null,
    status: safeEngagementStatus(engagement.status),
  };
}

export function safeCoordinatorIdentity({uid, identity, organizationLabel}) {
  return {
    uid: requiredText(uid),
    displayName: optionalText(identity?.displayName),
    professionLabel: 'Coordinateur',
    organizationLabel: optionalText(organizationLabel),
  };
}

function safeEngagementStatus(value) {
  return ['pending', 'confirmed', 'standby', 'cancelled'].includes(value)
    ? value
    : 'confirmed';
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

function requireCaller(callerUid) {
  if (!hasText(callerUid)) {
    throw new UserDisplayIdentityError(
      'unauthenticated',
      'Authentification requise.',
    );
  }
}

function requiredText(value) {
  if (!hasText(value)) throw invalidArgument();
  return value.trim();
}

function optionalText(value) {
  return hasText(value) ? value.trim() : null;
}

function hasText(value) {
  return typeof value === 'string' && value.trim() !== '';
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function hasExactlyKeys(value, expected) {
  const keys = Object.keys(value).sort();
  return keys.length === expected.length
    && [...expected].sort().every((key, index) => key === keys[index]);
}

function invalidArgument() {
  return new UserDisplayIdentityError(
    'invalid-argument',
    'La demande d’identité est invalide.',
  );
}
