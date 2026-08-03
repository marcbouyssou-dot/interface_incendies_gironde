import 'package:flutter/material.dart';

import '../widgets/common.dart';

abstract final class _PrivacyVisuals {
  static const background = Color(0xFFF5F5F3);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF7C817F);
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PrivacyVisuals.background,
      appBar: AppBar(
        title: const Text(
          'Politique de confidentialité',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: _PrivacyVisuals.background,
        foregroundColor: _PrivacyVisuals.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          color: _PrivacyVisuals.navy,
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
                color: _PrivacyVisuals.background,
                child: ListView(
                  key: const Key('privacy-policy-screen'),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    36,
                  ),
                  children: const [
                    _PrivacyHeader(),
                    SizedBox(height: 22),
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
                    SizedBox(height: 13),
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
                    SizedBox(height: 13),
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
                    SizedBox(height: 13),
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
                    SizedBox(height: 13),
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
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PrivacyHeader extends StatelessWidget {
  const _PrivacyHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DONNÉES PERSONNELLES',
          style: TextStyle(
            color: _PrivacyVisuals.textMuted,
            fontSize: 10,
            letterSpacing: 1.25,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Politique de confidentialité',
          style: TextStyle(
            color: _PrivacyVisuals.navy,
            fontSize: 27,
            height: 1.12,
            letterSpacing: -0.7,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Informations relatives aux professionnels utilisant MobSanté.',
          style: TextStyle(
            color: _PrivacyVisuals.textMuted,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _PrivacyVisuals.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _PrivacyVisuals.border),
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
                  color: _PrivacyVisuals.fieldBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _PrivacyVisuals.navy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _PrivacyVisuals.navy,
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
            child: Divider(height: 1, color: _PrivacyVisuals.border),
          ),
          for (var index = 0; index < paragraphs.length; index++) ...[
            Text(
              paragraphs[index],
              style: const TextStyle(
                color: _PrivacyVisuals.textMuted,
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (index < paragraphs.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
