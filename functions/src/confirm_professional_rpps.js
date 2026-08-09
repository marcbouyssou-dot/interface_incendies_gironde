import {
  ProfessionalRppsVerificationError,
  verifyProfessionalRpps,
} from './verify_professional_rpps.js';

const EXPECTED_PROFESSION_CODES = Object.freeze({
  physician: '10',
  doctor: '10',
  nurse: '60',
  physiotherapist: '70',
  mk: '70',
  podiatrist: '80',
  pp: '80',
});

export async function confirmProfessionalRpps({callerUid, data, services}) {
  if (
    !services
    || typeof services.verifyRpps !== 'function'
    || typeof services.getVolunteerProfile !== 'function'
    || typeof services.persistVerifiedProfile !== 'function'
  ) {
    throw new ProfessionalRppsVerificationError(
      'internal',
      'Service de confirmation RPPS indisponible.',
    );
  }

  const result = await verifyProfessionalRpps({callerUid, data, services});
  if (result.status !== 'verified') return result;

  const profile = await services.getVolunteerProfile(callerUid);
  if (!profile) {
    throw new ProfessionalRppsVerificationError(
      'failed-precondition',
      'Le profil professionnel doit être enregistré avant confirmation.',
    );
  }
  const expectedCode = EXPECTED_PROFESSION_CODES[profile.profession];
  if (expectedCode === undefined || result.professionCode !== expectedCode) {
    throw new ProfessionalRppsVerificationError(
      'failed-precondition',
      'Ce RPPS correspond à une autre profession.',
    );
  }

  const persisted = await services.persistVerifiedProfile(
    callerUid,
    result,
    profile.profession,
  );
  if (persisted !== true) {
    throw new ProfessionalRppsVerificationError(
      'failed-precondition',
      'La profession du profil a changé pendant la confirmation.',
    );
  }
  return result;
}
