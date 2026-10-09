import {createHmac} from 'node:crypto';

export class ProfessionalIdentityClaimError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ProfessionalIdentityClaimError';
    this.code = code;
  }
}

export function professionalIdentityClaimId(rpps, secret) {
  if (!/^[0-9]{11}$/.test(rpps)
    || typeof secret !== 'string'
    || Buffer.byteLength(secret, 'utf8') < 32) {
    throw new ProfessionalIdentityClaimError(
      'failed-precondition', 'Revendication professionnelle indisponible.');
  }
  return createHmac('sha256', secret)
    .update(`mobsante:professional-rpps:v1:${rpps}`)
    .digest('hex');
}

function isVerifiedForRpps(profile, rpps) {
  return profile?.verificationStatus === 'verified'
    && profile?.verificationSource === 'ans_rpps'
    && profile?.professionalIdType === 'rpps'
    && profile?.professionalIdValue === rpps
    && profile?.rpps === rpps;
}

/** The ANS response is already verified before this transaction is called. */
export async function claimVerifiedProfessionalIdentity({
  firestore, uid, result, expectedProfession, secret, serverTimestamp,
}) {
  const claimId = professionalIdentityClaimId(result?.rpps, secret);
  if (typeof uid !== 'string' || uid.length === 0
    || typeof expectedProfession !== 'string'
    || result?.status !== 'verified'
    || typeof serverTimestamp !== 'function') {
    throw new ProfessionalIdentityClaimError(
      'failed-precondition', 'Confirmation professionnelle invalide.');
  }
  const profileRef = firestore.collection('volunteers').doc(uid);
  const claims = firestore.collection('professionalIdentityClaims');
  const claimRef = claims.doc(claimId);
  return firestore.runTransaction(async (transaction) => {
    // All reads precede writes. The claim document serializes competing UIDs.
    const profile = await transaction.get(profileRef);
    const claim = await transaction.get(claimRef);
    const existingForUid = await transaction.get(claims.where('uid', '==', uid));
    const otherVerified = await transaction.get(firestore.collection('volunteers')
      .where('rpps', '==', result.rpps));
    if (!profile.exists || profile.data()?.profession !== expectedProfession) {
      return false;
    }
    if (isVerifiedForRpps(profile.data(), result.rpps)
      && claim.exists && claim.data()?.uid === uid) return true;
    if (profile.data()?.verificationStatus === 'verified'
      && profile.data()?.rpps !== result.rpps) {
      throw new ProfessionalIdentityClaimError(
        'failed-precondition', 'Une identité professionnelle est déjà vérifiée.');
    }
    if (claim.exists && claim.data()?.uid !== uid) {
      throw new ProfessionalIdentityClaimError(
        'already-exists', 'Cette identité professionnelle est déjà utilisée.');
    }
    if (existingForUid.docs.some((doc) => doc.id !== claimId)) {
      throw new ProfessionalIdentityClaimError(
        'failed-precondition', 'Une revendication professionnelle existe déjà.');
    }
    if (otherVerified.docs.some((doc) => doc.id !== uid
      && isVerifiedForRpps(doc.data(), result.rpps))) {
      throw new ProfessionalIdentityClaimError(
        'already-exists', 'Cette identité professionnelle est déjà utilisée.');
    }
    const now = serverTimestamp();
    if (!claim.exists) {
      transaction.create(claimRef, {
        uid, identityType: 'rpps', createdAt: now, updatedAt: now,
      });
    }
    transaction.update(profileRef, {
      professionalIdType: 'rpps',
      professionalIdValue: result.rpps,
      rpps: result.rpps,
      verificationStatus: 'verified',
      verificationSource: 'ans_rpps',
      verifiedFirstName: result.firstName,
      verifiedLastName: result.lastName,
      verifiedProfessionCode: result.professionCode,
      verifiedProfessionLabel: result.professionLabel,
      verifiedAt: now,
      updatedAt: now,
    });
    return true;
  });
}

/** Server-only administrative release after the verified profile was retired. */
export async function releaseRetiredProfessionalIdentityClaim({
  firestore, uid, rpps, secret,
}) {
  const claimId = professionalIdentityClaimId(rpps, secret);
  if (typeof uid !== 'string' || uid.length === 0) {
    throw new ProfessionalIdentityClaimError('invalid-argument', 'Compte invalide.');
  }
  const profileRef = firestore.collection('volunteers').doc(uid);
  const claimRef = firestore.collection('professionalIdentityClaims').doc(claimId);
  return firestore.runTransaction(async (transaction) => {
    const profile = await transaction.get(profileRef);
    const claim = await transaction.get(claimRef);
    if (profile.exists && isVerifiedForRpps(profile.data(), rpps)) {
      throw new ProfessionalIdentityClaimError(
        'failed-precondition', 'Le profil vérifié doit être retiré avant la revendication.');
    }
    if (!claim.exists) return false;
    if (claim.data()?.uid !== uid) {
      throw new ProfessionalIdentityClaimError(
        'permission-denied', 'Cette revendication appartient à un autre compte.');
    }
    transaction.delete(claimRef);
    return true;
  });
}
