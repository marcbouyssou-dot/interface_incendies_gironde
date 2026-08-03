import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../utils/app_page_route.dart';
import '../widgets/common.dart';
import 'legal_notice_screen.dart';
import 'privacy_policy_screen.dart';

abstract final class _TermsVisuals {
  static const background = Color(0xFFF5F5F3);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF7C817F);
}

class InformationConsentScreen extends StatelessWidget {
  const InformationConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _TermsVisuals.background,
      appBar: AppBar(
        title: const Text(
          'Informations et consentement',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: _TermsVisuals.background,
        foregroundColor: _TermsVisuals.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          color: _TermsVisuals.navy,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      body: SafeArea(
        top: false,
        child: PageContainer(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth <= 556
                  ? 18.0
                  : (constraints.maxWidth - 520) / 2;
              return Material(
                color: _TermsVisuals.background,
                child: ListView(
                  key: const Key('information-consent-screen'),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    36,
                  ),
                  children: [
                    const _TermsHeader(),
                    const SizedBox(height: 22),
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
                    const SizedBox(height: 13),
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
                    const SizedBox(height: 13),
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
                    const SizedBox(height: 13),
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
                    const SizedBox(height: 22),
                    _TermsNavigationPanel(
                      onOpenLegalNotice: () => Navigator.of(context).push(
                        AppPageRoute<void>(
                          builder: (_) => const LegalNoticeScreen(),
                        ),
                      ),
                      onOpenPrivacy: () => Navigator.of(context).push(
                        AppPageRoute<void>(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TermsHeader extends StatelessWidget {
  const _TermsHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppIdentity.productName.toUpperCase(),
          style: const TextStyle(
            color: _TermsVisuals.textMuted,
            fontSize: 10,
            letterSpacing: 1.25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Informations et consentement',
          style: TextStyle(
            color: _TermsVisuals.navy,
            fontSize: 27,
            height: 1.12,
            letterSpacing: -0.7,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'À lire avant de proposer votre participation à une mission.',
          style: TextStyle(
            color: _TermsVisuals.textMuted,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _TermsVisuals.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _TermsVisuals.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08173052),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _TermsVisuals.fieldBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _TermsVisuals.navy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _TermsVisuals.navy,
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: _TermsVisuals.border),
          ),
          for (var index = 0; index < items.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.circle, color: _TermsVisuals.navy, size: 5),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    items[index],
                    style: const TextStyle(
                      color: _TermsVisuals.textMuted,
                      fontSize: 13,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (index < items.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _TermsNavigationPanel extends StatelessWidget {
  const _TermsNavigationPanel({
    required this.onOpenLegalNotice,
    required this.onOpenPrivacy,
  });

  final VoidCallback onOpenLegalNotice;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _TermsVisuals.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _TermsVisuals.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08173052),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _TermsNavigationRow(
            key: const Key('information-legal-notice-entry'),
            icon: Icons.gavel_outlined,
            title: 'Mentions légales',
            onTap: onOpenLegalNotice,
          ),
          const Divider(height: 1, color: _TermsVisuals.border),
          _TermsNavigationRow(
            key: const Key('information-privacy-policy-entry'),
            icon: Icons.privacy_tip_outlined,
            title: 'Politique de confidentialité',
            onTap: onOpenPrivacy,
          ),
        ],
      ),
    );
  }
}

class _TermsNavigationRow extends StatelessWidget {
  const _TermsNavigationRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _TermsVisuals.fieldBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _TermsVisuals.navy, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _TermsVisuals.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _TermsVisuals.textMuted,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
