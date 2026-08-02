import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crédits')),
      body: SafeArea(
        child: PageContainer(
          child: ListView(
            key: const Key('credits-screen'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const PageHeader(
                eyebrow: AppIdentity.productName,
                title: 'Crédits',
                subtitle: AppIdentity.productSubtitle,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: const BoxDecoration(
                          color: AppColors.orangeSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.orange,
                          size: 31,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Application conçue par Marc Bouyssou.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vice-président de l’URPS '
                        'Masseurs-Kinésithérapeutes Nouvelle-Aquitaine.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_outline_rounded,
                            color: AppColors.orange,
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Remerciements',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 13),
                      Text(
                        'Remerciements aux professionnels de santé, '
                        'coordinateurs et partenaires ayant participé aux '
                        'tests terrain.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
