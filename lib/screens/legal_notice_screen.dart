import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class LegalNoticeScreen extends StatelessWidget {
  const LegalNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mentions légales')),
      body: SafeArea(
        child: PageContainer(
          child: ListView(
            key: const Key('legal-notice-screen'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                AppIdentity.productName,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                AppIdentity.productSubtitle,
                style: TextStyle(
                  color: AppColors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              const _LegalInformationCard(
                icon: Icons.business_outlined,
                title: 'Éditeur de l’application',
                content:
                    'Marc Bouyssou, vice-président de l’URPS MK '
                    'Nouvelle-Aquitaine',
              ),
              const SizedBox(height: 12),
              const _LegalInformationCard(
                icon: Icons.alternate_email_rounded,
                title: 'Contact',
                content: 'URPS MK Nouvelle-Aquitaine',
              ),
              const SizedBox(height: 12),
              const _LegalInformationCard(
                icon: Icons.cloud_outlined,
                title: 'Hébergeur',
                content: 'Netlify, Inc. — mobsante.netlify.app',
              ),
              const SizedBox(height: 12),
              const _LegalInformationCard(
                icon: Icons.info_outline_rounded,
                title: 'Version de l’application',
                content: AppIdentity.version,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalInformationCard extends StatelessWidget {
  const _LegalInformationCard({
    required this.icon,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.orange, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    content,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
