import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Politique de confidentialité',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: PageContainer(
          child: ListView(
            key: const Key('privacy-policy-screen'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: const [
              PageHeader(
                eyebrow: 'Données personnelles',
                title: 'Politique de confidentialité',
                subtitle:
                    'Informations relatives aux professionnels utilisant '
                    'MobSanté.',
              ),
              SizedBox(height: 24),
              _PrivacySection(
                icon: Icons.inventory_2_outlined,
                title: 'Données collectées',
                paragraphs: [
                  'MobSanté collecte les informations de profil nécessaires '
                      'à la mobilisation : prénom, nom, téléphone, adresse '
                      'email, profession, identifiant RPPS ou ordinal, CPTS '
                      'éventuelle et matériel pouvant être apporté.',
                  'Les participations enregistrent également la mission, le '
                      'lieu, la profession mobilisée, le statut de la '
                      'participation et les dates techniques associées. Un '
                      'identifiant technique de session est utilisé pour '
                      'sécuriser les opérations.',
                ],
              ),
              SizedBox(height: 12),
              _PrivacySection(
                icon: Icons.flag_outlined,
                title: 'Finalités du traitement',
                paragraphs: [
                  'Ces données servent à organiser les missions, vérifier les '
                      'informations professionnelles requises, suivre les '
                      'quotas et permettre aux responsables autorisés de '
                      'contacter les participants lorsque la coordination '
                      'l’exige.',
                  'Les statistiques du tableau de bord sont calculées sous '
                      'forme agrégée et ne présentent aucune donnée '
                      'nominative.',
                ],
              ),
              SizedBox(height: 12),
              _PrivacySection(
                icon: Icons.schedule_outlined,
                title: 'Durées de conservation',
                paragraphs: [
                  'Les profils et participations sont conservés pendant la '
                      'durée nécessaire à l’organisation et au suivi du '
                      'dispositif Incendies Gironde.',
                  'Cette version ne comporte pas de suppression automatique : '
                      'les données restent conservées jusqu’à une demande '
                      'd’effacement ou jusqu’à la clôture et l’archivage du '
                      'dispositif par l’éditeur. Les exports CSV sont générés '
                      'à la demande et ne sont pas stockés par l’application.',
                ],
              ),
              SizedBox(height: 12),
              _PrivacySection(
                icon: Icons.verified_user_outlined,
                title: 'Vos droits RGPD',
                paragraphs: [
                  'Les professionnels peuvent demander l’accès à leurs '
                      'données, leur rectification, leur effacement, la '
                      'limitation du traitement, s’opposer au traitement ou '
                      'demander la portabilité lorsque ce droit s’applique.',
                  'Ils peuvent également introduire une réclamation auprès de '
                      'la CNIL s’ils estiment que leurs droits ne sont pas '
                      'respectés.',
                ],
              ),
              SizedBox(height: 12),
              _PrivacySection(
                icon: Icons.contact_mail_outlined,
                title: 'Exercer vos droits',
                paragraphs: [
                  'Toute demande peut être adressée à l’éditeur de MobSanté '
                      'via l’URPS MK Nouvelle-Aquitaine, avec la mention '
                      '« Exercice des droits RGPD — MobSanté ». Une preuve '
                      'd’identité pourra être demandée uniquement si elle est '
                      'nécessaire pour sécuriser la demande.',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({
    required this.icon,
    required this.title,
    required this.paragraphs,
  });

  final IconData icon;
  final String title;
  final List<String> paragraphs;

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
            for (var index = 0; index < paragraphs.length; index++) ...[
              Text(
                paragraphs[index],
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (index < paragraphs.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
