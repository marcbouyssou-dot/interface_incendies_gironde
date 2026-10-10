import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../config/beta_terms.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/common.dart';
import '../widgets/v5_secondary_navigation.dart';
import 'legal_notice_screen.dart';
import 'privacy_policy_screen.dart';

// navy/fieldBackground/border/textMuted have no exact V5Colors equivalent
// (close but not identical values) and stay local rather than forced onto
// a near-match token, per this Lot's fidelity rule.
abstract final class _TermsVisuals {
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF5F6865);
}

class InformationConsentScreen extends StatelessWidget {
  const InformationConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: const V5SecondaryNavigationBar(
        title: 'Informations et consentement',
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
                color: colors.canvas,
                child: ListView(
                  key: const Key('information-consent-screen'),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    V5Spacing.sm,
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
                        'Version ${BetaTerms.version}. MobSanté Beta V1 est un '
                            'service expérimental gratuit et fermé, destiné à '
                            '20 professionnels invités au maximum. Chaque '
                            'personne utilise son propre compte ; un même '
                            'compte peut porter plusieurs capacités et vues.',
                        'L’application ne remplace ni les services d’urgence ni les '
                            'consignes données par les autorités et responsables '
                            'opérationnels. Sa disponibilité n’est pas garantie '
                            'comme celle d’un service de secours critique.',
                        'Chaque utilisateur emploie le service uniquement '
                            'pour les Actions et missions auxquelles il est '
                            'autorisé. Il respecte les consignes de sécurité '
                            'et d’organisation communiquées sur le terrain.',
                        'Des Actions peuvent être organisées par différentes '
                            'organisations, chacune dans son périmètre.',
                        'Les notifications sont une aide à la coordination, jamais '
                            'l’unique canal de sécurité ou d’alerte.',
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
                        'Ne saisissez aucune donnée permettant d’identifier un '
                            'patient ou concernant son état de santé.',
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
                        'Le professionnel met à jour son profil avant toute '
                            'nouvelle participation lorsque sa situation ou '
                            'ses coordonnées ont changé. Son identité, sa '
                            'profession et son RPPS sont vérifiés avant '
                            'l’admission opérationnelle.',
                        'Le compte est personnel et ne doit pas être partagé. '
                            'Une invitation peut être révoquée ou expirer ; '
                            'elle ne vaut pas admission à elle seule.',
                      ],
                    ),
                    const SizedBox(height: 13),
                    const _InformationSection(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Accès et fin de la Beta',
                      items: [
                        'L’accès à une Action dépend de la vérification du profil, '
                            'de la profession et des droits accordés. Une '
                            'participation doit rester exacte et à jour.',
                        'Un accès peut être suspendu ou révoqué en cas d’usage '
                            'incompatible avec ces conditions ou à la fin de la '
                            'Beta. L’intégrité du service et de ses contenus '
                            'doit être respectée. Le support est assuré par '
                            'une personne pendant cette Beta contrôlée.',
                        'Pour toute question, contactez Marc Bouyssou via '
                            'confidentialite@mobsante.fr. Pour vos droits sur '
                            'les données, consultez la notice de confidentialité.',
                      ],
                    ),
                    const SizedBox(height: 13),
                    const _InformationSection(
                      icon: Icons.history_outlined,
                      title: 'Historique des Actions',
                      items: [
                        'Une participation peut rester nominative après la fin '
                            'd’une Action pour l’historique, la traçabilité et '
                            'le retour d’expérience. La période proposée pour '
                            'la Beta V1 est de 12 mois après cette fin, suivie '
                            'd’un réexamen.',
                        'L’historique d’une Action peut subsister après la '
                            'suppression des comptes participants. Il est '
                            'distinct des démonstrations, qui ne doivent pas '
                            'exposer de données personnelles réelles.',
                      ],
                    ),
                    const SizedBox(height: 13),
                    const _InformationSection(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Acceptation des CGU',
                      items: [
                        'L’accès opérationnel sur invitation requiert une '
                            'acceptation explicite de la version en vigueur. '
                            'Une nouvelle version obligatoire pourra nécessiter '
                            'une nouvelle acceptation.',
                        'Les choix facultatifs pour les notifications et le ciblage '
                            'restent distincts de cette acceptation.',
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
            fontSize: 12,
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
        const SizedBox(height: V5Spacing.xs),
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
        color: context.v5Colors.surface,
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
              const SizedBox(width: V5Spacing.sm),
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
                  padding: EdgeInsets.only(top: V5Spacing.xs),
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
            if (index < items.length - 1) const SizedBox(height: V5Spacing.sm),
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
        color: context.v5Colors.surface,
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
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: V5Spacing.sm,
            ),
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
                const SizedBox(width: V5Spacing.sm),
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
                const SizedBox(width: V5Spacing.xs),
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
