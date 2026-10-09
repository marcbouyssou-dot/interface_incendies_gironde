# MobSanté Beta V1 — décisions produit et propositions juridiques

**Statut : candidat à revue humaine et juridique ; pas une politique approuvée.**
L'éditeur et responsable du traitement indiqués par le propriétaire sont Marc
Bouyssou (`MB` si un affichage court suffit). Le contact proposé est
`confidentialite@mobsante.fr`. Sa création et un essai de réception humain ne
sont pas encore prouvés. L'adresse postale de l'éditeur, la répartition éventuelle
des responsabilités avec les organisations et les contrats de sous-traitance
restent à fournir. Ces manques bloquent l'ouverture réelle de la Beta.

## Périmètre produit décidé

- Beta V1 gratuite, fermée, sur invitation ; maximum recommandé de 20
  professionnels ; CGU acceptées avant accès opérationnel invité.
- Une personne, un compte Auth, plusieurs capacités et perspectives :
  Professional, Responsable, Coordinateur et Admin. Récupération du mot de passe
  commune. La découverte publique qualifiée peut rester accessible.
- Aucun renseignement permettant d'identifier un patient ou concernant son
  état de santé ne doit être saisi. Aucune détection automatique n'est promise.
- `legacy_opt_in` est le ciblage Beta V1. Le ciblage géographique strict et le
  replay générique de démonstration sont post-Beta.
- Architecture actuelle : Firebase/Google Cloud (Auth, Firestore, Functions,
  App Check, FCM), Netlify (PWA Web) et Resend (e-mail d'invitation). IGN n'est
  sollicité que par la fonctionnalité de géocodage. Cette architecture est la
  référence technique de Beta contrôlée ; une migration UE/France sera étudiée
  dans un dépôt distinct après le checkpoint, sans être engagée ici.

## Bases envisagées par finalité — validation juridique requise

| Finalité | Base envisagée | Vérification préalable |
|---|---|---|
| Compte, profil, participation nécessaire au service | Exécution des CGU Beta | Nécessité de chaque champ et articulation avec les organisations |
| RPPS et profession | Nécessité du service et relation contractuelle | Proportionnalité et preuve de vérification |
| Sécurité, prévention des abus et journaux nécessaires | Intérêt légitime envisagé | Mise en balance, répartition des responsables et cas d'acteur public |
| Notifications facultatives | Consentement/opt-in distinct des CGU | Retrait effectif et preuve du choix |
| Point/rayon de ciblage futur | Consentement explicite et révocable | Information, suppression et requalification avant activation |
| Statistiques réellement anonymisées | Hors données personnelles si anonymisation effective | Vérifier l'absence de réidentification |

## Durées proposées — aucune purge automatique dans ce lot

| Catégorie | Proposition Beta |
|---|---|
| Compte et profil | Pendant la participation ; réexamen après 12 mois d'inactivité |
| Invitation expirée | 30 jours après expiration, sauf nécessité d'audit documentée |
| Abonnement push | Jusqu'à désactivation, fermeture ou invalidation |
| Journaux techniques | 90 jours par défaut ; justifier tout autre délai |
| Point privé de ciblage | Jusqu'au retrait du consentement, suppression ou fermeture |
| Participation à une Action | 12 mois sous forme nominative après sa fin, puis revue |
| Démonstration | Conservation possible seulement sans donnée personnelle réelle nécessaire |

Les sauvegardes, journaux de fournisseurs, preuves RPPS et admissions requièrent
des durées et modalités de purge complémentaires. La proposition de 12 mois
nominatifs n'est pas une durée légale universelle.

## Contrat historique et démonstration

`REAL_ACTION → COMPLETED → AUTHORIZED_HISTORY → later DEMO_PROJECTION`.

L'historique réel reste réservé aux personnes habilitées pendant la période
validée. Une Action terminée doit survivre à la fermeture ou à la suppression
des comptes de ses participants : les références d'Action, de mission et les
faits non personnels nécessaires à la traçabilité ne doivent donc pas dépendre
de la présence d'un compte Auth. Après revue, une projection démonstrative ne
doit utiliser ni identité ni coordonnées réelles des participants et doit
reposer sur des acteurs fictifs ou des données effectivement anonymisées.
Une simple pseudonymisation n'autorise pas à présenter les données comme
anonymes. Ce document fixe un contrat produit ; le replay générique et la
purge de production ne sont pas implémentés.

## Bloqueurs avant ouverture

1. Adresse postale et mentions légales complètes, revue juridique de la notice,
   des CGU, des bases et des durées.
2. Création de `confidentialite@mobsante.fr` et essai de réception humain.
3. Liste contractuelle des prestataires, lieux de traitement et éventuels
   transferts ; confirmation des responsabilités avec les institutions.
4. Réception humaine d'un e-mail d'invitation Resend contrôlé.
5. Alignement prouvé des Rules, Functions, index et client de production,
   puis cutover `invitation_only` et recette du compte B au checkpoint distinct.
