import {createHash, randomBytes} from 'node:crypto';
import {Timestamp} from 'firebase-admin/firestore';

const PROFESSIONS = new Map([
  ['mk', 'physiotherapist'], ['physiotherapist', 'physiotherapist'],
  ['pp', 'podiatrist'], ['podiatrist', 'podiatrist'],
  ['doctor', 'physician'], ['physician', 'physician'],
  ['nurse', 'nurse'],
]);

export class ProfessionalAdmissionError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

export function canonicalAdmissionProfession(value) {
  return PROFESSIONS.get(value) ?? null;
}

export function normalizeProfessionalInvitationEmail(value) {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().toLowerCase();
  return normalized.length <= 254
    && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)
    ? normalized : null;
}

function requireId(value) {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9_-]{1,120}$/.test(value)) {
    throw new ProfessionalAdmissionError('invalid-argument', 'Périmètre invalide.');
  }
  return value;
}

function invitationIdFor(code) {
  return createHash('sha256').update(code).digest('hex');
}

function requireInvitationCode(code) {
  if (typeof code !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(code)) {
    throw new ProfessionalAdmissionError('permission-denied', 'Invitation indisponible.');
  }
  return invitationIdFor(code);
}

function requireCaller(uid) {
  if (typeof uid !== 'string' || uid.length === 0) {
    throw new ProfessionalAdmissionError('unauthenticated', 'Session requise.');
  }
}

async function requireAdministrator(db, uid) {
  requireCaller(uid);
  const snapshot = await db.collection('platformAdministrators').doc(uid).get();
  if (!snapshot.exists || snapshot.data()?.active !== true) {
    throw new ProfessionalAdmissionError('permission-denied', 'Accès réservé à l’administration.');
  }
}

async function requireInvitationMode(db) {
  const config = await db.doc('platform/config').get();
  if (config.data()?.admissionMode !== 'invitation_only') {
    throw new ProfessionalAdmissionError('failed-precondition', 'Admission sur invitation inactive.');
  }
}

async function requireInvitationPreparationMode(db) {
  const config = await db.doc('platform/config').get();
  const configuredMode = config.data()?.admissionMode;
  const mode = configuredMode === undefined ? 'open' : configuredMode;
  if (mode !== 'open' && mode !== 'invitation_only') {
    throw new ProfessionalAdmissionError('failed-precondition', 'Mode d’admission invalide.');
  }
}

// The returned 256-bit code is shown once to the administrator. Only its
// SHA-256 digest is persisted. The verified Auth email, never the profile
// email or the code alone, proves recipient ownership at redemption.
export async function createProfessionalInvitation({db, callerUid, data}) {
  await requireAdministrator(db, callerUid);
  // Administrators may stage invitations before the admission cutover.
  // Redemption and operational access remain gated by invitation_only.
  await requireInvitationPreparationMode(db);
  const organizationId = requireId(data?.organizationId);
  const operationId = requireId(data?.operationId);
  const expectedProfession = canonicalAdmissionProfession(data?.expectedProfession);
  const targetEmailNormalized = normalizeProfessionalInvitationEmail(data?.targetEmail);
  if (!targetEmailNormalized) {
    throw new ProfessionalAdmissionError('invalid-argument', 'Adresse destinataire invalide.');
  }
  if (!expectedProfession) {
    throw new ProfessionalAdmissionError('invalid-argument', 'Profession invalide.');
  }
  const expiryMillis = Date.parse(data?.expiresAt);
  if (!Number.isFinite(expiryMillis)
    || expiryMillis <= Date.now() + 60_000
    || expiryMillis > Date.now() + 30 * 86_400_000) {
    throw new ProfessionalAdmissionError('invalid-argument', 'Expiration invalide.');
  }
  const operation = await db.collection('operations').doc(operationId).get();
  if (!operation.exists
    || operation.data()?.ownerOrganizationId !== organizationId
    || operation.data()?.status !== 'active'
    || (operation.data()?.purpose ?? 'operational') !== 'operational') {
    throw new ProfessionalAdmissionError('failed-precondition', 'Action opérationnelle introuvable.');
  }
  const code = randomBytes(32).toString('base64url');
  const invitationId = invitationIdFor(code);
  await db.collection('professionalInvitations').doc(invitationId).create({
    id: invitationId,
    target: 'bearer_code_sha256',
    organizationId,
    operationId,
    expectedProfession,
    targetEmailNormalized,
    status: 'valid',
    createdAt: Timestamp.now(),
    expiresAt: Timestamp.fromMillis(expiryMillis),
    createdBy: callerUid,
    consumedAt: null,
    consumedBy: null,
    revokedAt: null,
    revokedBy: null,
    provenance: 'professional_admission_v1',
    deliveryStatus: 'pending',
  });
  return {invitationId, code};
}

export async function sendProfessionalInvitationEmail({
  db, callerUid, data, notificationService, appUrl,
}) {
  await requireAdministrator(db, callerUid);
  const invitationId = requireInvitationCode(data?.code);
  if (!notificationService || typeof notificationService.send !== 'function'
    || typeof appUrl !== 'string' || !/^https?:\/\//.test(appUrl)) {
    throw new ProfessionalAdmissionError('failed-precondition', 'Envoi indisponible.');
  }
  const invitationRef = db.collection('professionalInvitations').doc(invitationId);
  const invitation = (await invitationRef.get()).data();
  if (!invitation || invitation.status !== 'valid'
    || !invitation.expiresAt?.toMillis
    || invitation.expiresAt.toMillis() <= Date.now()) {
    throw new ProfessionalAdmissionError('failed-precondition', 'Invitation indisponible.');
  }
  if (invitation.deliveryStatus === 'sent') return {alreadySent: true};
  try {
    const result = await notificationService.send({
      channel: 'email',
      recipient: invitation.targetEmailNormalized,
      subject: 'Votre invitation MobSanté',
      text: `Vous êtes invité(e) à rejoindre une Action MobSanté.\n\n` +
        `Ouvrez ${appUrl} et saisissez ce code personnel : ${data.code}\n\n` +
        `Ce code expire le ${invitation.expiresAt.toDate().toISOString()}. ` +
        `Ne le transférez pas. Aucune donnée de santé patient ne doit être envoyée par e-mail.`,
    }, {idempotencyKey: `professional-invitation:${invitationId}`});
    await invitationRef.update({
      deliveryStatus: 'sent', deliveredAt: Timestamp.now(),
      deliveryProvider: result.provider,
    });
    return {alreadySent: false};
  } catch {
    await invitationRef.update({deliveryStatus: 'failed', deliveryFailedAt: Timestamp.now()});
    throw new ProfessionalAdmissionError('unavailable', 'L’e-mail n’a pas pu être envoyé.');
  }
}

export async function redeemProfessionalInvitation({db, auth, callerUid, data}) {
  requireCaller(callerUid);
  await requireInvitationMode(db);
  const invitationId = requireInvitationCode(data?.code);
  const identity = await auth.getUser(callerUid);
  const verifiedEmail = normalizeProfessionalInvitationEmail(identity.email);
  if (identity.disabled || !identity.emailVerified || !verifiedEmail) {
    throw new ProfessionalAdmissionError('permission-denied', 'Compte avec adresse e-mail vérifiée requis.');
  }
  const invitationRef = db.collection('professionalInvitations').doc(invitationId);
  const profileRef = db.collection('volunteers').doc(callerUid);
  return db.runTransaction(async (transaction) => {
    const [invitationSnapshot, profileSnapshot, acceptanceSnapshot,
      configSnapshot] = await Promise.all([
      transaction.get(invitationRef), transaction.get(profileRef),
      transaction.get(db.collection('termsAcceptances').doc(callerUid)),
      transaction.get(db.doc('platform/config')),
    ]);
    const requiredVersion = configSnapshot.data()?.mandatoryCguVersion ?? 'beta-v1';
    if (acceptanceSnapshot.data()?.uid !== callerUid
      || acceptanceSnapshot.data()?.acceptedVersion !== requiredVersion
      || !acceptanceSnapshot.data()?.acceptedAt) {
      throw new ProfessionalAdmissionError(
        'failed-precondition', 'Acceptez les CGU Beta en vigueur avant de valider l’invitation.',
      );
    }
    const invitation = invitationSnapshot.data();
    const profile = profileSnapshot.data();
    if (!invitation || !invitation.targetEmailNormalized
      || invitation.targetEmailNormalized !== verifiedEmail
      || !profile || profile.uid !== callerUid) {
      throw new ProfessionalAdmissionError('permission-denied', 'Invitation indisponible.');
    }
    if (canonicalAdmissionProfession(profile.profession) !== invitation.expectedProfession
      || !isVerifiedRppsProfile(profile)) {
      throw new ProfessionalAdmissionError('permission-denied', 'Profil professionnel non vérifié ou incompatible.');
    }
    const admissionRef = db.collection('professionalAdmissions')
      .doc(`${invitation.operationId}_${callerUid}`);
    const admissionSnapshot = await transaction.get(admissionRef);
    const admission = admissionSnapshot.data();
    if (invitation.status === 'consumed'
      && invitation.consumedBy === callerUid
      && admission?.sourceInvitationId === invitationId
      && admission.status === 'active'
      && admission.expiresAt.toMillis() > Date.now()) {
      return {operationId: invitation.operationId, alreadyRedeemed: true};
    }
    if (invitation.status !== 'valid'
      || invitation.expiresAt.toMillis() <= Date.now()) {
      throw new ProfessionalAdmissionError('failed-precondition', 'Invitation expirée, révoquée ou utilisée.');
    }
    if (admission?.status === 'active' && admission.expiresAt.toMillis() > Date.now()) {
      throw new ProfessionalAdmissionError('already-exists', 'Un accès actif existe pour cette Action.');
    }
    const operationRef = db.collection('operations').doc(invitation.operationId);
    const operation = (await transaction.get(operationRef)).data();
    const permitRef = invitation.preparedBy === callerUid
      ? db.collection('professionalRegistrationPermits').doc(callerUid)
      : null;
    const permit = permitRef ? (await transaction.get(permitRef)).data() : null;
    if (!operation
      || operation.ownerOrganizationId !== invitation.organizationId
      || operation.status !== 'active'
      || (operation.purpose ?? 'operational') !== 'operational') {
      throw new ProfessionalAdmissionError('failed-precondition', 'Action indisponible.');
    }
    const now = Timestamp.now();
    transaction.update(invitationRef, {
      status: 'consumed', consumedAt: now, consumedBy: callerUid,
    });
    if (permit?.invitationId === invitationId) {
      transaction.update(permitRef, {revoked: true, consumedAt: now});
    }
    transaction.set(admissionRef, {
      uid: callerUid,
      organizationId: invitation.organizationId,
      operationId: invitation.operationId,
      profession: profile.profession,
      status: 'active',
      expiresAt: invitation.expiresAt,
      sourceInvitationId: invitationId,
      admittedAt: now,
      provenance: 'professional_invitation',
    });
    transaction.update(profileRef, {
      admissionScopes: {
        ...(profile.admissionScopes ?? {}),
        [invitation.operationId]: {
          status: 'active',
          profession: profile.profession,
          organizationId: invitation.organizationId,
          expiresAt: invitation.expiresAt,
          sourceInvitationId: invitationId,
        },
      },
    });
    return {operationId: invitation.operationId, alreadyRedeemed: false};
  });
}

export async function acceptBetaTerms({db, auth, callerUid, data}) {
  requireCaller(callerUid);
  const identity = await auth.getUser(callerUid);
  if (identity.disabled || !identity.emailVerified || !identity.email) {
    throw new ProfessionalAdmissionError('permission-denied', 'Compte avec adresse e-mail vérifiée requis.');
  }
  const config = await db.doc('platform/config').get();
  const requiredVersion = config.data()?.mandatoryCguVersion ?? 'beta-v1';
  if (data?.version !== requiredVersion) {
    throw new ProfessionalAdmissionError('failed-precondition', 'Mettez l’application à jour pour accepter les CGU.');
  }
  await db.collection('termsAcceptances').doc(callerUid).set({
    uid: callerUid, acceptedVersion: requiredVersion,
    acceptedAt: Timestamp.now(),
  });
  await auth.setCustomUserClaims(callerUid, {
    ...(identity.customClaims ?? {}), cguVersion: requiredVersion,
  });
  return {acceptedVersion: requiredVersion};
}

// A verified invitee may prepare an unverified profile before RPPS verification.
// The permit is bound to this UID; revocation updates it in the same transaction
// as the invitation. Firestore rules enforce its expiry and revoked state.
export async function prepareProfessionalRegistration({db, auth, callerUid, data}) {
  requireCaller(callerUid);
  await requireInvitationMode(db);
  const invitationId = requireInvitationCode(data?.code);
  const identity = await auth.getUser(callerUid);
  const verifiedEmail = normalizeProfessionalInvitationEmail(identity.email);
  if (identity.disabled || !identity.emailVerified || !verifiedEmail) {
    throw new ProfessionalAdmissionError('permission-denied', 'Compte avec adresse e-mail vérifiée requis.');
  }
  const invitationRef = db.collection('professionalInvitations').doc(invitationId);
  const permitRef = db.collection('professionalRegistrationPermits').doc(callerUid);
  return db.runTransaction(async (transaction) => {
    const [invitationSnapshot, profileSnapshot] = await Promise.all([
      transaction.get(invitationRef),
      transaction.get(db.collection('volunteers').doc(callerUid)),
    ]);
    const invitation = invitationSnapshot.data();
    if (!invitation || invitation.status !== 'valid'
      || invitation.targetEmailNormalized !== verifiedEmail
      || !invitation.expiresAt?.toMillis
      || invitation.expiresAt.toMillis() <= Date.now()
      || !canonicalAdmissionProfession(invitation.expectedProfession)
      || (invitation.preparedBy && invitation.preparedBy !== callerUid)
      || profileSnapshot.exists) {
      throw new ProfessionalAdmissionError('permission-denied', 'Invitation indisponible.');
    }
    const operation = (await transaction.get(
      db.collection('operations').doc(invitation.operationId))).data();
    if (!operation || operation.ownerOrganizationId !== invitation.organizationId
      || operation.status !== 'active'
      || (operation.purpose ?? 'operational') !== 'operational') {
      throw new ProfessionalAdmissionError('failed-precondition', 'Action indisponible.');
    }
    transaction.set(permitRef, {
      uid: callerUid,
      verifiedAuthEmail: identity.email,
      invitationId,
      expectedProfession: invitation.expectedProfession,
      expiresAt: invitation.expiresAt,
      preparedAt: Timestamp.now(),
      revoked: false,
    });
    transaction.update(invitationRef, {preparedBy: callerUid});
    return {operationId: invitation.operationId};
  });
}

export async function getProfessionalInvitationStatus({db, callerUid, data}) {
  await requireAdministrator(db, callerUid);
  const invitationId = requireId(data?.invitationId);
  const snapshot = await db.collection('professionalInvitations').doc(invitationId).get();
  if (!snapshot.exists) {
    throw new ProfessionalAdmissionError('not-found', 'Invitation introuvable.');
  }
  const invitation = snapshot.data();
  return {
    invitationId,
    targetEmailNormalized: invitation.targetEmailNormalized ?? null,
    organizationId: invitation.organizationId,
    operationId: invitation.operationId,
    expectedProfession: invitation.expectedProfession,
    status: invitation.status,
    deliveryStatus: invitation.deliveryStatus ?? 'unknown',
    expiresAt: invitation.expiresAt?.toDate().toISOString() ?? null,
    consumedAt: invitation.consumedAt?.toDate().toISOString() ?? null,
    revokedAt: invitation.revokedAt?.toDate().toISOString() ?? null,
  };
}

export async function listProfessionalInvitations({db, callerUid}) {
  await requireAdministrator(db, callerUid);
  const snapshot = await db.collection('professionalInvitations')
    .orderBy('createdAt', 'desc').limit(50).get();
  return {invitations: snapshot.docs.map((document) => {
    const invitation = document.data();
    return {
      invitationId: document.id,
      targetEmailNormalized: invitation.targetEmailNormalized ?? null,
      operationId: invitation.operationId ?? null,
      expectedProfession: invitation.expectedProfession ?? null,
      status: invitation.status ?? 'unknown',
      deliveryStatus: invitation.deliveryStatus ?? 'unknown',
      expiresAt: invitation.expiresAt?.toDate().toISOString() ?? null,
    };
  })};
}

export async function revokeProfessionalInvitation({db, callerUid, data}) {
  await requireAdministrator(db, callerUid);
  const invitationId = requireId(data?.invitationId);
  const invitationRef = db.collection('professionalInvitations').doc(invitationId);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(invitationRef);
    const invitation = snapshot.data();
    if (!invitation) {
      throw new ProfessionalAdmissionError('not-found', 'Invitation introuvable.');
    }
    const admissionRef = invitation.consumedBy
      ? db.collection('professionalAdmissions')
        .doc(`${invitation.operationId}_${invitation.consumedBy}`)
      : null;
    const admission = admissionRef ? (await transaction.get(admissionRef)).data() : null;
    const profileRef = invitation.consumedBy
      ? db.collection('volunteers').doc(invitation.consumedBy)
      : null;
    const profile = profileRef ? (await transaction.get(profileRef)).data() : null;
    const permitRef = invitation.preparedBy
      ? db.collection('professionalRegistrationPermits').doc(invitation.preparedBy)
      : null;
    const permit = permitRef ? (await transaction.get(permitRef)).data() : null;
    if (invitation.status === 'revoked') return {revoked: true};
    const now = Timestamp.now();
    transaction.update(invitationRef, {
      status: 'revoked', revokedAt: now, revokedBy: callerUid,
    });
    if (permit?.invitationId === invitationId) {
      transaction.update(permitRef, {revoked: true, revokedAt: now});
    }
    if (admission?.sourceInvitationId === invitationId) {
      transaction.update(admissionRef, {
        status: 'revoked', revokedAt: now, revokedBy: callerUid,
      });
    }
    const scope = profile?.admissionScopes?.[invitation.operationId];
    if (profileRef && scope?.sourceInvitationId === invitationId) {
      transaction.update(profileRef, {
        admissionScopes: {
          ...profile.admissionScopes,
          [invitation.operationId]: {...scope, status: 'revoked', revokedAt: now},
        },
      });
    }
    return {revoked: true};
  });
}

const MISSION_LOCATION_FIELDS = [
  'name', 'type', 'group', 'territorialGroup', 'address', 'addressLine1',
  'addressLine2', 'postalCode', 'city', 'country', 'fullAddress',
  'latitude', 'longitude', 'addressStatus', 'contactName', 'contactPhone',
];

export function isVerifiedRppsProfile(profile) {
  const expectedCodes = new Map([
    ['physiotherapist', '70'], ['mk', '70'],
    ['podiatrist', '80'], ['pp', '80'],
    ['nurse', '60'], ['physician', '10'], ['doctor', '10'],
  ]);
  return profile?.verificationStatus === 'verified'
    && profile.verificationSource === 'ans_rpps'
    && profile.professionalIdType === 'rpps'
    && /^[0-9]{11}$/.test(profile.professionalIdValue ?? '')
    && profile.rpps === profile.professionalIdValue
    && typeof profile.verifiedFirstName === 'string'
    && profile.verifiedFirstName.trim().length > 0
    && typeof profile.verifiedLastName === 'string'
    && profile.verifiedLastName.trim().length > 0
    && profile.verifiedProfessionCode === expectedCodes.get(profile.profession)
    && typeof profile.verifiedProfessionLabel === 'string'
    && profile.verifiedProfessionLabel.trim().length > 0
    && profile.verifiedAt?.toMillis instanceof Function;
}

// A callable projection is required because a location document cannot prove
// which mission granted access in Firestore rules. Read only the sites behind
// the requested missions; never return the full location document.
export async function listProfessionalMissionLocations({db, callerUid, data}) {
  requireCaller(callerUid);
  await requireInvitationMode(db);
  const missionIds = data?.missionIds;
  if (!Array.isArray(missionIds) || missionIds.length > 30
    || missionIds.some((id) => typeof id !== 'string'
      || !/^[a-zA-Z0-9_-]{1,120}$/.test(id))
    || new Set(missionIds).size !== missionIds.length) {
    throw new ProfessionalAdmissionError('invalid-argument', 'Missions invalides.');
  }
  if (missionIds.length === 0) return {locations: []};
  const profileSnapshot = await db.collection('volunteers').doc(callerUid).get();
  const profile = profileSnapshot.data();
  if (!profile || profile.uid !== callerUid
    || !isVerifiedRppsProfile(profile)) {
    throw new ProfessionalAdmissionError('permission-denied', 'Profil professionnel non vérifié.');
  }
  const now = Date.now();
  const missions = await Promise.all(missionIds.map((id) =>
    db.collection('missions').doc(id).get()));
  const mobilizationIds = new Set();
  for (const snapshot of missions) {
    const mission = snapshot.data();
    if (!mission || mission.isActive !== true || mission.cancelledAt
      || typeof mission.mobilizationId !== 'string'
      || typeof mission.locationId !== 'string') {
      throw new ProfessionalAdmissionError('permission-denied', 'Mission hors périmètre.');
    }
    mobilizationIds.add(mission.mobilizationId);
  }
  const mobilizations = new Map(await Promise.all([...mobilizationIds].map(async (id) =>
    [id, (await db.collection('mobilizations').doc(id).get()).data()])));
  const operationIds = new Set();
  for (const mobilization of mobilizations.values()) {
    if (!mobilization || mobilization.status !== 'active'
      || typeof mobilization.operationId !== 'string') {
      throw new ProfessionalAdmissionError('permission-denied', 'Mobilisation hors périmètre.');
    }
    operationIds.add(mobilization.operationId);
  }
  const operations = new Map(await Promise.all([...operationIds].map(async (id) =>
    [id, (await db.collection('operations').doc(id).get()).data()])));
  const admissions = new Map(await Promise.all([...operationIds].map(async (id) =>
    [id, (await db.collection('professionalAdmissions')
      .doc(`${id}_${callerUid}`).get()).data()])));
  for (const id of operationIds) {
    const operation = operations.get(id);
    const admission = admissions.get(id);
    if (!operation || operation.status !== 'active'
      || (operation.purpose ?? 'operational') !== 'operational'
      || typeof operation.ownerOrganizationId !== 'string'
      || !admission || admission.uid !== callerUid
      || admission.operationId !== id
      || admission.organizationId !== operation.ownerOrganizationId
      || admission.profession !== profile.profession
      || admission.status !== 'active'
      || !admission.expiresAt?.toMillis
      || admission.expiresAt.toMillis() <= now) {
      throw new ProfessionalAdmissionError('permission-denied', 'Action hors périmètre.');
    }
  }
  const locationIds = new Set(missions.map((snapshot) => snapshot.data().locationId));
  const locations = await Promise.all([...locationIds].map(async (id) => {
    const source = (await db.collection('locations').doc(id).get()).data();
    if (!source) return null;
    const projected = {id};
    for (const field of MISSION_LOCATION_FIELDS) {
      if (source[field] != null) projected[field] = source[field];
    }
    return projected;
  }));
  return {locations: locations.filter(Boolean)};
}
