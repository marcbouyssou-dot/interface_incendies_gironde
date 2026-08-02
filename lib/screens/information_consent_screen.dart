import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../theme/app_theme.dart';
import '../utils/app_page_route.dart';
import '../widgets/common.dart';
import 'legal_notice_screen.dart';
import 'privacy_policy_screen.dart';

class InformationConsentScreen extends StatelessWidget {
  const InformationConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Informations et consentement',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: PageContainer(
          child: ListView(
            key: const Key('information-consent-screen'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const PageHeader(
                eyebrow: AppIdentity.productName,
                title: 'Informations et consentement',
                subtitle:
                    'À lire avant de proposer votre participation à une '
                    'mission.',
              ),
              const SizedBox(height: 24),
              const _InformationSection(
                icon: Icons.rule_outlined,
                title: 'Conditions d’utilisation',
                items: [
                  'MobSanté est un outil de coordination des professionnels '
                      'mobilisés dans le cadre du dispositif Incendies '
                      'Gironde.',
                  'L’application ne remplace ni les services d’urgence ni les '
                      'consignes données par les autorités et responsables '
                      'opérationnels.',
                  'Chaque utilisateur emploie le service uniquement pour les '
                      'missions proposées et respecte les règles de sécurité '
                      'et d’organisation communiquées sur le terrain.',
                ],
              ),
              const SizedBox(height: 12),
              const _InformationSection(
                icon: Icons.handshake_outlined,
                title: 'Engagements des professionnels',
                items: [
                  'Ne confirmer une participation qu’en cas de disponibilité '
                      'réelle et prévenir la coordination en cas '
                      'd’empêchement.',
                  'Respecter le lieu, le créneau, la profession et les besoins '
                      'en matériel indiqués pour la mission.',
                  'Utiliser les informations accessibles dans l’application '
                      'avec discrétion et uniquement pour la coordination du '
                      'dispositif.',
                ],
              ),
              const SizedBox(height: 12),
              const _InformationSection(
                icon: Icons.badge_outlined,
                title: 'Exactitude du profil',
                items: [
                  'Les informations d’identité, de contact, de profession et '
                      'd’identification professionnelle doivent être exactes '
                      'et à jour.',
                  'Le professionnel met à jour son profil avant toute nouvelle '
                      'participation lorsque sa situation ou ses coordonnées '
                      'ont changé.',
                ],
              ),
              const SizedBox(height: 12),
              const _InformationSection(
                icon: Icons.check_circle_outline_rounded,
                title: 'Prise de connaissance',
                items: [
                  'La confirmation d’une mission manifeste la prise de '
                      'connaissance de ces informations. Elle reste distincte '
                      'de la consultation de cette page et intervient '
                      'uniquement avec l’action de participation prévue dans '
                      'le formulaire.',
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      key: const Key('information-legal-notice-entry'),
                      leading: const Icon(
                        Icons.gavel_outlined,
                        color: AppColors.orange,
                      ),
                      title: const Text('Mentions légales'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        AppPageRoute<void>(
                          builder: (_) => const LegalNoticeScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const Key('information-privacy-policy-entry'),
                      leading: const Icon(
                        Icons.privacy_tip_outlined,
                        color: AppColors.orange,
                      ),
                      title: const Text('Politique de confidentialité'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        AppPageRoute<void>(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InformationSection extends StatelessWidget {
  const _InformationSection({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.orange, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < items.length; index++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, color: AppColors.orange, size: 6),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      items[index],
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (index < items.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
