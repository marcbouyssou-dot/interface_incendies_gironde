import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/professional_engagements_screen.dart';
import 'package:interface_incendies_gironde/screens/slots_screen.dart';

import 'support/verified_professional_profile.dart';

void main() {
  testWidgets(
    'unverified visitor sees profile CTA instead of mission details',
    (tester) async {
      final repository = MockCoordinationRepository(responsibleAccess: null);
      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();

      expect(find.byType(SlotsScreen), findsNothing);
      expect(find.text('Voir les détails'), findsNothing);
      expect(
        find.byKey(const Key('professional-verification-cta')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const Key('professional-verification-cta')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('professional-verification-cta')));
      await tester.pumpAndSettle();
      expect(find.text('Mon profil'), findsOneWidget);

      repository.volunteerProfiles[repository.volunteerUid] =
          verifiedMkProfile();
      await tester.tap(find.text('Missions'));
      await tester.pumpAndSettle();
      expect(find.byType(SlotsScreen), findsOneWidget);

      repository.volunteerProfiles[repository.volunteerUid] =
          verifiedMkProfile().copyWith(verificationStatus: 'unverified');
      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfessionalEngagementsScreen), findsNothing);
      expect(
        find.byKey(const Key('professional-verification-cta')),
        findsOneWidget,
      );
    },
  );

  testWidgets('complete but unverified profile cannot enter mission flow', (
    tester,
  ) async {
    final incompleteVerification = verifiedMkProfile().copyWith(
      verificationStatus: 'unverified',
    );
    expect(incompleteVerification.hasVerifiedProfessionalIdentity, isFalse);
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(
          responsibleAccess: null,
          initialProfiles: {'mock-volunteer': incompleteVerification},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SlotsScreen), findsNothing);
    expect(
      find.byKey(const Key('professional-verification-cta')),
      findsOneWidget,
    );
  });

  testWidgets(
    'verified MK enters the Professional mission and engagement flows',
    (tester) async {
      final profile = verifiedMkProfile();
      expect(profile.hasVerifiedProfessionalIdentity, isTrue);
      await tester.pumpWidget(
        FireCoordinationApp(
          repository: MockCoordinationRepository(
            responsibleAccess: null,
            initialProfiles: {'mock-volunteer': profile},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SlotsScreen), findsOneWidget);
      expect(
        find.byKey(const Key('professional-verification-cta')),
        findsNothing,
      );
      expect(find.text('Voir les détails'), findsWidgets);
      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfessionalEngagementsScreen), findsOneWidget);
    },
  );

  testWidgets('verified MK does not fall back to an open nurse mission', (
    tester,
  ) async {
    final nurseMission = CoordinationNeed(
      id: 'nurse-only-mission',
      place: 'Site infirmier',
      group: TerritorialGroup.medoc,
      date: 'Demain',
      time: '08:00 — 12:00',
      requiredPhysiotherapists: 0,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      professionQuotas: ProfessionQuotas.fromMaps(
        requiredByProfession: const {'nurse': 1},
        registeredByProfession: const {},
      ),
      equipment: const [],
    );
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(
          responsibleAccess: null,
          initialMissions: [nurseMission],
          initialProfiles: {'mock-volunteer': verifiedMkProfile()},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SlotsScreen), findsOneWidget);
    expect(find.text('Site infirmier'), findsNothing);
    expect(find.text('Je me mobilise'), findsNothing);
  });
}
