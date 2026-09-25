import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../theme/app_theme.dart';
import '../utils/app_page_route.dart';
import '../widgets/common.dart';
import '../widgets/v5_secondary_navigation.dart';
import 'diagnostic_push_registration_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const provisionalLegalNotice =
      'Les informations détaillées relatives au traitement des données '
      'personnelles seront précisées avant l’ouverture générale du service.';
  static const dataUseNotice =
      'Les coordonnées renseignées sont utilisées pour organiser les missions '
      'et permettre aux responsables autorisés de contacter les participants '
      'concernés.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const V5SecondaryNavigationBar(title: 'À propos'),
      body: SafeArea(
        child: PageContainer(
          child: ListView(
            key: const Key('about-screen'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Text(
                AppIdentity.productName,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Interface de mobilisation des professionnels de santé',
                style: TextStyle(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Outil facilitant la coordination des professionnels de santé '
                'mobilisés auprès des centres et sites d’intervention.',
              ),
              const SizedBox(height: 10),
              const Text(
                'Version ${AppIdentity.version}',
                key: Key('about-version'),
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: const [
                    ExpansionTile(
                      key: Key('privacy-section'),
                      title: Text('Confidentialité'),
                      childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 18),
                      children: [
                        Text(dataUseNotice),
                        SizedBox(height: 10),
                        Text(
                          provisionalLegalNotice,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    Divider(height: 1),
                    ExpansionTile(
                      key: Key('legal-section'),
                      title: Text('Mentions légales'),
                      childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 18),
                      children: [Text(provisionalLegalNotice)],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                AppIdentity.designerCredit,
                key: Key('design-credit'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextButton(
                key: const Key('about-push-diagnostic-link'),
                onPressed: () => Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) => const DiagnosticPushRegistrationScreen(),
                  ),
                ),
                child: const Text('Diagnostic Push'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
