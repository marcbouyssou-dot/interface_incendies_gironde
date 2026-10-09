# Runbooks opérateur — Beta V1 contrôlée

Ces procédures sont locales et destinées à un opérateur habilité. Elles ne
constituent pas une autorisation de modifier la production. Le contact
`confidentialite@mobsante.fr` doit être créé et testé par le propriétaire avant
l'ouverture de la Beta. Les bases légales et durées ci-dessous restent à valider.
Le dossier individuel inclut le reçu de CGU `termsAcceptances/{uid}` ;
l'effacement borné le supprime avant le compte Auth et sa revendication de
version CGU.

## Passage contrôlé à l'admission sur invitation

1. Vérifier les règles, Functions, index, client Web et configuration réellement
   actifs. Conserver les empreintes et un backup restaurable, puis refaire le
   contrôle de dérive juste avant toute mutation.
2. Choisir ou créer l'Action Beta contrôlée et vérifier organisation,
   profession, visibilité et administrateur habilité.
3. Préparer l'invitation du compte B pendant `admissionMode=open`. Vérifier
   l'adresse, l'Action, la profession, l'expiration et le code remis une fois.
4. Faire confirmer la réception d'un e-mail Resend réel par le propriétaire.
   Ne pas envoyer à un autre destinataire pendant cette qualification.
5. À un checkpoint humain distinct, basculer `platform/config.admissionMode`
   sur `invitation_only`. Vérifier immédiatement la découverte publique et le
   refus d'une inscription professionnelle libre.
6. Faire accepter les CGU Beta en vigueur au compte B, puis consommer
   l'invitation. Vérifier UID et RPPS inchangés, admission de la seule Action
   prévue, refus des autres Actions et des coordonnées privées.
7. Contrôler l'accès Admin A, Responsable et Coordinateur. Suspendre les
   admissions si un contrôle échoue ; analyser la dérive avant tout retour.

## Droits des personnes

1. Ouvrir un dossier de demande avec identifiant de cas sans donnée personnelle. Vérifier l’identité du demandeur et son autorité sur l’UID Auth par un canal déjà connu ; consigner le résultat hors du rapport technique. Pour un e-mail, le changement dans Auth et sa vérification sont une opération distincte du champ profil.
2. Sur un poste habilité, placer la clé AES-256 de sauvegarde issue du coffre opérateur dans `MOBSANTE_RIGHTS_BACKUP_KEY_HEX` et choisir un répertoire privé chiffré. Exécuter `node scripts/privacy_operator_rights.mjs --action review --project PROJECT --uid UID --case CASE --out PRIVATE_DIR --identity-verified yes`. Le script écrit un manifeste et une préimage chiffrée, avec hash des documents et `updateTime`. Il n’écrit pas en production lors de cette étape.
3. Pour accès/export, répéter avec `--action access` ou `--action export`. Remettre uniquement l’export chiffré après revue humaine des champs omis, documents partagés et données de tiers. L’outil annonce `partial: true` : compléter l’inventaire des éventuelles collections nouvelles avant réponse finale.
4. Pour rectification d’un champ autorisé, ou pour effacement/fermeture, produire d’abord un dry-run avec `--action rectify|erase|close` et conserver son `fingerprint`. Après validation humaine du dossier, relancer la même commande avec `--confirm FINGERPRINT` et `MOBSANTE_RIGHTS_APPLY_AUTHORIZED=yes`. Pour `rectify`, ajouter `--field FIELD --value VALUE`. Le script recalcule le manifeste : tout drift bloque l’application. Chaque passage écrit une sauvegarde chiffrée. Ne transmettre ni clé, ni préimage, ni code d’invitation dans le rapport.
5. `erase` refuse les engagements, références partagées ou documents non classés. L’opérateur doit alors traiter les quotas et la traçabilité avec le propriétaire produit/juridique, refaire un inventaire, puis appliquer un plan spécifique. Pour un cas borné sans référence partagée, les documents sont supprimés avant Auth. `close` révoque admissions et abonnements push, puis désactive Auth en dernier. Conserver le rapport de cas sans données personnelles.

**Vérification :** `scripts/privacy_operator_rights.emulator.test.mjs` exerce dry-run, sauvegarde chiffrée, effacement de fixtures, Auth en dernier et restauration Firestore dans un projet émulateur isolé. Aucun de ces tests ne touche la production.

## Sauvegarde et restauration

- Avant chaque mutation autorisée, collecter les préimages Firestore pertinentes, l’UID et les métadonnées Auth, le manifeste des chemins, les hashes et `updateTime`. Stocker la clé séparément de l’archive chiffrée, avec accès restreint et durée décidée par le responsable du traitement.
- Faire un test de déchiffrement et restauration **dans un projet émulateur isolé** ; comparer les hashes et les types Firestore. Le script de droits utilise un encodage explicite pour `Timestamp`, `GeoPoint`, date et octets. La procédure historique `scripts/gironde_004j_backup_restore.mjs` fournit déjà le précédent de préimage/rollback isolé, propre à son lot ; ne pas l’utiliser sur une autre Action sans adaptation.
- Auth ne se restaure pas par une simple écriture Firestore. Après suppression Auth, mot de passe, sessions, facteurs et état exact de vérification ne sont pas reconstituables par la préimage. Recréer éventuellement un UID seulement selon une procédure Auth validée, avec réactivation et vérification de l’utilisateur. Ne pas restaurer un accès opérationnel sans invitation/admission réévaluée.

## Incident Beta V1

| Incident | Détecter | Contenir | Contacter | Rétablir | Escalader |
|---|---|---|---|---|---|
| Auth indisponible | Connexions et récupération en échec | Arrêter la création de nouvelles invitations et révoquer les codes exposés depuis l’écran Admin ; annoncer une pause | Exploitant Firebase et propriétaire produit | Vérifier état fournisseur, connexion test et récupération | Si durée ou comptes touchés dépassent le seuil humain convenu |
| Notification en échec | Résumé `notification_observability.mjs` : événements, destinataires, tentatives, catégories | Après autorisation d’incident, mettre `platform/config.notificationDispatchPaused=true` ; les événements restent persistés | Exploitant Firebase/Resend, propriétaire produit | Corriger fournisseur/configuration, inventorier les événements créés pendant la pause, préparer leur rejeu contrôlé puis remettre le drapeau à `false` | Si perte de message critique ou fuite de données |
| Régression de permissions | Test négatif ou lecture non autorisée constatée | Bloquer l’Action ou le chemin touché et geler les invitations | Propriétaire produit, sécurité et responsable du traitement | Rétablir règles validées, rejouer tests de cloisonnement | Immédiat si coordonnées ou données de tiers exposées |
| Fuite d’accès Action | Professionnel voit une autre Action | Désactiver Action/admission concernée, révoquer l’invitation ; préserver les preuves | Propriétaire produit et responsable du traitement | Corriger règle ou admission, vérifier profils et UID touchés | Immédiat ; qualifier notification réglementaire avec conseil juridique |
| Panne fournisseur | Erreurs Firebase, Netlify ou Resend | Suspendre inscription/envoi selon le fournisseur | Support fournisseur et propriétaire produit | Reprendre après contrôle santé et test borné | Si interruption prolongée ou données compromises |

**Contact d’astreinte, délais et seuils : [À FOURNIR PAR LE PROPRIÉTAIRE].** La suspension d’Action, les révocations d’invitations et le drapeau de pause doivent être effectués par un opérateur habilité suivant la procédure de changement. Un événement créé pendant la pause ne repart pas automatiquement ; ne retirer le drapeau qu’avec un plan de rejeu vérifié.

## Observation des notifications

Commande de lecture seule : `node scripts/notification_observability.mjs --project PROJECT --event-id EVENT_ID`. Elle rapporte présence de l’événement, nombre de destinataires résolus, notifications applicatives, livraisons push, tentatives, statuts et catégories d’échec. Elle n’affiche ni UID, ni token, ni contenu, ni identifiant fournisseur. Un événement sans destinataire reste visible avec compteur zéro. La réception sur appareil exige toujours un contrôle humain séparé.
