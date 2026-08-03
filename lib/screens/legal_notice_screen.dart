import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../utils/app_page_route.dart';
import '../widgets/common.dart';
import 'credits_screen.dart';
import 'information_consent_screen.dart';
import 'privacy_policy_screen.dart';

abstract final class _LegalVisuals {
  static const background = Color(0xFFF5F5F3);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF7C817F);
}

class LegalNoticeScreen extends StatelessWidget {
  const LegalNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LegalVisuals.background,
      appBar: AppBar(
        title: const Text('Mentions légales'),
        backgroundColor: _LegalVisuals.background,
        foregroundColor: _LegalVisuals.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          color: _LegalVisuals.navy,
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
                color: _LegalVisuals.background,
                child: ListView(
                  key: const Key('legal-notice-screen'),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    36,
                  ),
                  children: [
                    const Text(
                      'INFORMATIONS LÉGALES',
                      style: TextStyle(
                        color: _LegalVisuals.textMuted,
                        fontSize: 10,
                        letterSpacing: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      AppIdentity.productName,
                      style: const TextStyle(
                        color: _LegalVisuals.navy,
                        fontSize: 28,
                        height: 1.1,
                        letterSpacing: -0.7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      AppIdentity.productSubtitle,
                      style: TextStyle(
                        color: _LegalVisuals.textMuted,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _LegalSectionHeader(
                      eyebrow: 'IDENTITÉ DU SERVICE',
                      title: 'Édition et hébergement',
                    ),
                    const SizedBox(height: 10),
                    const _LegalInformationPanel(),
                    const SizedBox(height: 22),
                    const _LegalSectionHeader(
                      eyebrow: 'DOCUMENTS',
                      title: 'Informations complémentaires',
                    ),
                    const SizedBox(height: 10),
                    _LegalNavigationPanel(
                      onOpenPrivacy: () => Navigator.of(context).push(
                        AppPageRoute<void>(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      ),
                      onOpenCredits: () => Navigator.of(context).push(
                        AppPageRoute<void>(
                          builder: (_) => const CreditsScreen(),
                        ),
                      ),
                      onOpenInformation: () => Navigator.of(context).push(
                        AppPageRoute<void>(
                          builder: (_) => const InformationConsentScreen(),
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

class _LegalSectionHeader extends StatelessWidget {
  const _LegalSectionHeader({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: _LegalVisuals.textMuted,
            fontSize: 9,
            letterSpacing: 1.05,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: _LegalVisuals.navy,
            fontSize: 19,
            height: 1.15,
            letterSpacing: -0.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LegalInformationPanel extends StatelessWidget {
  const _LegalInformationPanel();

  @override
  Widget build(BuildContext context) {
    return const _LegalPanel(
      child: Column(
        children: [
          _LegalInformationRow(
            icon: Icons.business_outlined,
            title: 'Éditeur de l’application',
            content:
                'Marc Bouyssou, vice-président de l’URPS MK '
                'Nouvelle-Aquitaine',
          ),
          _LegalDivider(),
          _LegalInformationRow(
            icon: Icons.alternate_email_rounded,
            title: 'Contact',
            content: 'URPS MK Nouvelle-Aquitaine',
          ),
          _LegalDivider(),
          _LegalInformationRow(
            icon: Icons.cloud_outlined,
            title: 'Hébergeur',
            content: 'Netlify, Inc. — mobsante.netlify.app',
          ),
          _LegalDivider(),
          _LegalInformationRow(
            icon: Icons.info_outline_rounded,
            title: 'Version de l’application',
            content: AppIdentity.version,
          ),
        ],
      ),
    );
  }
}

class _LegalInformationRow extends StatelessWidget {
  const _LegalInformationRow({
    required this.icon,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _LegalVisuals.fieldBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _LegalVisuals.navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _LegalVisuals.textMuted,
                    fontSize: 10,
                    letterSpacing: 0.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  content,
                  style: const TextStyle(
                    color: _LegalVisuals.navy,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalNavigationPanel extends StatelessWidget {
  const _LegalNavigationPanel({
    required this.onOpenPrivacy,
    required this.onOpenCredits,
    required this.onOpenInformation,
  });

  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenCredits;
  final VoidCallback onOpenInformation;

  @override
  Widget build(BuildContext context) {
    return _LegalPanel(
      child: Column(
        children: [
          _LegalNavigationRow(
            key: const Key('privacy-policy-entry'),
            icon: Icons.privacy_tip_outlined,
            title: 'Politique de confidentialité',
            subtitle: 'Données personnelles et droits RGPD',
            onTap: onOpenPrivacy,
          ),
          const _LegalDivider(),
          _LegalNavigationRow(
            key: const Key('credits-entry'),
            icon: Icons.favorite_outline_rounded,
            title: 'Crédits',
            onTap: onOpenCredits,
          ),
          const _LegalDivider(),
          _LegalNavigationRow(
            key: const Key('information-consent-entry'),
            icon: Icons.fact_check_outlined,
            title: 'Informations et consentement',
            onTap: onOpenInformation,
          ),
        ],
      ),
    );
  }
}

class _LegalNavigationRow extends StatelessWidget {
  const _LegalNavigationRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _LegalVisuals.fieldBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _LegalVisuals.navy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _LegalVisuals.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: _LegalVisuals.textMuted,
                          fontSize: 11,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: _LegalVisuals.textMuted,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalPanel extends StatelessWidget {
  const _LegalPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _LegalVisuals.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _LegalVisuals.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _LegalDivider extends StatelessWidget {
  const _LegalDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 14,
      endIndent: 14,
      color: _LegalVisuals.border,
    );
  }
}
