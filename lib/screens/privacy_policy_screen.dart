import 'package:flutter/material.dart';

import '../theme/v5_foundation.dart';
import '../widgets/common.dart';
import '../widgets/v5_secondary_navigation.dart';

// navy/fieldBackground/border/textMuted have no exact V5Colors equivalent
// (close but not identical values) and stay local rather than forced onto
// a near-match token, per this Lot's fidelity rule.
abstract final class _PrivacyVisuals {
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF5F6865);
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: const V5SecondaryNavigationBar(
        title: 'Politique de confidentialité',
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
                  key: const Key('privacy-policy-screen'),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    V5Spacing.sm,
                    horizontalPadding,
                    36,
                  ),
                  children: const [
                    _PrivacyHeader(),
                    SizedBox(height: 22),
                    _PrivacySection(
                      icon: Icons.info_outline,
                      title: 'MobSanté Beta V1',
                      paragraphs: [
                        'MobSanté aide à mobiliser des professionnels de santé '
                            'vérifiés pour des Actions et missions. La Beta V1 '
                            'est gratuite et fermée. Elle est destinée à un '
                            'maximum de 20 professionnels invités. '
                            'La découverte des seules informations publiques '
                            'autorisées peut rester accessible sans admission.',
                        'Éditeur en nom personnel et responsable du '
                            'traitement : Marc Bouyssou. '
                            'Aucune donnée patient ne doit être saisie. '
                            'MobSanté n’est pas un service de secours critique.',
                      ],
                    ),
                    SizedBox(height: 13),
                    _PrivacySection(
                      icon: Icons.inventory_2_outlined,
                      title: 'Données collectées',
                      paragraphs: [
                        'Selon votre rôle, MobSanté traite les informations de '
                            'compte et de profil : identité, coordonnées, '
                            'profession, RPPS ou autre identifiant professionnel, statut de '
                            'vérification, CPTS et matériel déclaré lorsque ces '
                            'champs sont renseignés.',
                        'Le service enregistre aussi les rôles, invitations et '
                            'admissions, Actions, missions, engagements et '
                            'statuts associés. Les coordonnées de contact '
                            'professionnelles restent privées. '
                            'Les notifications, abonnements push et journaux '
                            'techniques utilisent des identifiants et des dates. '
                            'Le point privé de ciblage, si activé, reste facultatif.',
                      ],
                    ),
                    SizedBox(height: 13),
                    _PrivacySection(
                      icon: Icons.gavel_outlined,
                      title: 'Bases juridiques proposées',
                      paragraphs: [
                        'Compte, profil, participation et vérification du '
                            'RPPS nécessaires au service : exécution des CGU '
                            'Beta envisagée, sous réserve de vérifier la '
                            'nécessité de chaque donnée. Les journaux de '
                            'sécurité nécessaires pourraient relever de '
                            'l’intérêt légitime, après mise en balance '
                            'documentée.',
                        'Les notifications push facultatives et le point '
                            'privé de ciblage reposeraient sur des choix '
                            'distincts et révocables. Le ciblage Beta V1 '
                            'reste fondé sur les préférences existantes. Le '
                            'ciblage géographique strict, envisagé après la '
                            'Beta, demanderait un consentement distinct.',
                        'Cette matrice est une proposition à valider avant '
                            'l’ouverture, pas un avis juridique définitif. '
                            'L’acceptation des CGU ne vaut pas consentement '
                            'global à tous les traitements.',
                      ],
                    ),
                    SizedBox(height: 13),
                    _PrivacySection(
                      icon: Icons.flag_outlined,
                      title: 'Finalités du traitement',
                      paragraphs: [
                        'Ces données permettent de gérer les comptes, vérifier '
                            'les professionnels, organiser les Actions et missions, '
                            'suivre les engagements et sécuriser le service.',
                        'Les professionnels consultent leurs données. Les '
                            'responsables et coordinateurs accèdent aux données '
                            'nécessaires dans le périmètre de leurs Actions et '
                            'sites. L’administration MobSanté gère la plateforme '
                            'et ses Actions selon ses habilitations.',
                        'Chaque Action est présentée dans le contexte de son '
                            'organisation. MobSanté peut accueillir plusieurs '
                            'organisations et Actions.',
                      ],
                    ),
                    SizedBox(height: 13),
                    _PrivacySection(
                      icon: Icons.schedule_outlined,
                      title: 'Durées de conservation',
                      paragraphs: [
                        'Compte et profil : pendant la participation, avec '
                            'réexamen après 12 mois d’inactivité. '
                            'Invitation expirée : 30 jours après '
                            'expiration, sauf audit justifié. Abonnement push '
                            ': jusqu’à désactivation, invalidation ou '
                            'fermeture. Point privé de ciblage : jusqu’au '
                            'retrait du choix ou à la fermeture.',
                        'Journaux techniques : 90 jours par défaut. '
                            'Participation à une Action terminée : 12 mois '
                            'nominatifs après sa fin, puis '
                            'réexamen pour détachement, anonymisation ou '
                            'usage en démonstration sans données personnelles '
                            'réelles, selon le besoin. L’historique '
                            'de l’Action peut subsister après suppression '
                            'des comptes participants.',
                        'Ces durées cadrent la Beta V1 et restent soumises à '
                            'validation juridique. Aucune purge automatique '
                            'par catégorie n’est actuellement configurée.',
                        'Les exports CSV de gestion produits par l’administration '
                            'ne sont pas un export individuel déclenchable par les '
                            'professionnels dans l’application.',
                      ],
                    ),
                    SizedBox(height: 13),
                    _PrivacySection(
                      icon: Icons.verified_user_outlined,
                      title: 'Vos droits RGPD',
                      paragraphs: [
                        'Les utilisateurs peuvent demander l’accès à leurs '
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
                        'Contact : confidentialite@mobsante.fr. Les demandes '
                            'sont traitées avec l’aide d’un opérateur habilité ; '
                            'aucun bouton d’export ou d’effacement individuel '
                            'en libre-service n’est proposé. Une preuve '
                            'd’identité n’est demandée que si elle est '
                            'nécessaire pour sécuriser la demande.',
                      ],
                    ),
                    SizedBox(height: 13),
                    _PrivacySection(
                      icon: Icons.tune_outlined,
                      title: 'Choix facultatifs',
                      paragraphs: [
                        'Les notifications facultatives et le point privé de '
                            'ciblage peuvent être désactivés ou retirés sans '
                            'retirer l’acceptation des CGU. En Beta V1, le '
                            'ciblage reste fondé sur les préférences existantes.',
                        'Les démonstrations sont distinctes de l’historique '
                            'réel. Aucune donnée personnelle réelle ne doit '
                            'être exposée dans une démonstration ; la relecture '
                            'générique des démonstrations est prévue après '
                            'la Beta.',
                      ],
                    ),
                    SizedBox(height: 13),
                    _PrivacySection(
                      icon: Icons.cloud_outlined,
                      title: 'Prestataires techniques',
                      paragraphs: [
                        'Le client Web est servi par Netlify, Inc. Les '
                            'comptes, données et notifications utilisent '
                            'Firebase / Google Cloud. Les courriels de la '
                            'Beta utilisent Resend (Plus Five Five, Inc.). '
                            'IGN intervient seulement lorsqu’un géocodage '
                            'est utilisé.',
                        'L’utilisation de Netlify et Resend implique des '
                            'traitements aux États-Unis ; les services '
                            'Firebase / Google peuvent aussi traiter des '
                            'données hors de l’Espace économique européen. '
                            'Les fournisseurs publient des garanties de '
                            'transfert, notamment des clauses contractuelles '
                            'types. Leur application précise à MobSanté et '
                            'les sous-traitants concernés restent à vérifier. '
                            'Cette infrastructure Beta pourra évoluer.',
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
            fontSize: 12,
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
        SizedBox(height: V5Spacing.xs),
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
        color: context.v5Colors.surface,
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
              const SizedBox(width: V5Spacing.sm),
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
            if (index < paragraphs.length - 1)
              const SizedBox(height: V5Spacing.sm),
          ],
        ],
      ),
    );
  }
}
