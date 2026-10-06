import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/volunteer_profile.dart';

VolunteerProfile verifiedMkProfile({String uid = 'mock-volunteer'}) =>
    VolunteerProfile(
      uid: uid,
      firstName: 'Alice',
      lastName: 'MARTIN',
      phone: '0600000000',
      email: 'alice@example.fr',
      profession: VolunteerProfession.mk,
      professionalIdType: ProfessionalIdType.rpps,
      professionalIdValue: '10123456789',
      verificationStatus: 'verified',
      verificationSource: 'ans_rpps',
      verifiedFirstName: 'Alice',
      verifiedLastName: 'MARTIN',
      verifiedProfessionCode: '70',
      verifiedProfessionLabel: 'Masseur-Kinésithérapeute',
      verifiedAt: DateTime(2026, 8, 9),
    );
