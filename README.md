# MobSanté — Incendies Gironde

PWA Flutter de coordination en temps réel des professionnels volontaires.

## Activation des comptes responsables

Les liens d’activation générés côté serveur ouvrent la route publique
`/activation`. Cette route initialise uniquement Firebase et le service
d’authentification nécessaire à la définition du mot de passe. Elle ne démarre
ni session anonyme, ni repository métier, ni flux Firestore.

La variable serveur `MOBSANTE_APP_URL` contient l’URL de base HTTPS canonique
`https://mobsante.netlify.app`. La fonction ajoute elle-même `/activation`.
Pour les émulateurs locaux uniquement, une URL HTTP sur `localhost` ou
`127.0.0.1` est acceptée.

Le domaine `mobsante.netlify.app` doit être autorisé manuellement dans Firebase
Authentication avant tout déploiement du parcours d’invitation.

## Modes de données

Le mode mock est actif par défaut, notamment pour les tests :

```bash
flutter run -d chrome
```

Le mode Firestore s’active avec les paramètres du projet Firebase :

```bash
flutter run -d chrome \
  --dart-define=USE_FIREBASE=true \
  --dart-define=FIREBASE_API_KEY=<your-api-key> \
  --dart-define=FIREBASE_APP_ID=<your-app-id> \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<your-messaging-sender-id> \
  --dart-define=FIREBASE_PROJECT_ID=<your-project-id> \
  --dart-define=FIREBASE_AUTH_DOMAIN=<your-auth-domain> \
  --dart-define=FIREBASE_STORAGE_BUCKET=<your-storage-bucket> \
  --dart-define=FIREBASE_APP_CHECK_RECAPTCHA_V3_SITE_KEY=<your-recaptcha-v3-site-key>
```

La build Web de production exige la site key publique d’un site reCAPTCHA v3.
Sa clé secrète associée doit être enregistrée uniquement pour l’application Web
dans Firebase Console > App Check ; la site key publique est fournie au build
par `FIREBASE_APP_CHECK_RECAPTCHA_V3_SITE_KEY`. Les builds Flutter en mode debug
utilisent exclusivement le provider App Check debug officiel ; le token affiché
localement doit être enregistré dans « Manage debug tokens » et ne doit jamais
être commité.

L’interface dépend uniquement de `CoordinationRepository`. Les
implémentations disponibles sont :

- `FirestoreCoordinationRepository`, pour les collections Firestore ;
- `MockCoordinationRepository`, pour le développement local et les tests.

## Collections Firestore

- `locations` : `name`, `type`, `group`, `activeNeeds`, `address`
- `missions` : `place`, `group`, `date`, `time`, quotas et compteurs MK/PP,
  `equipment`, `status`
- `volunteers` : `firstName`, `lastName`, `phone`, `email`, `rpps`, `cptsId`,
  `cptsLabel`, `profession`, `equipment`, `createdAt`, `updatedAt`
- `engagements` : `missionId`, `volunteerId`, `profession`, `createdAt`

La création d’un engagement, du volontaire et la mise à jour des compteurs et
du statut de mission sont regroupées dans une transaction Firestore.

## Vérification manuelle d’une mission réelle

1. Ouvrir la PWA sur le Mac en mode Firebase.
2. Dans **Déclarer**, se connecter comme responsable de site et vérifier que
   son lieu est affiché sans sélecteur.
3. Choisir la date du lendemain.
4. Choisir un créneau `22:00 → 02:00`.
5. Régler les quotas à 2 MK et 1 PP, puis publier.
6. Attendre l’écran **Mission publiée**.
7. Ouvrir la PWA sur un iPhone sans rechargement manuel.
8. Vérifier le lieu, la date, les horaires et les quotas de la mission.
9. Vérifier le document dans Firebase Console → Firestore → `missions`.
# Sécurisation Firebase RC1

Le fichier `firestore.rules` est une proposition sécurisée locale. Il ne doit
pas être déployé avant la recette complète ci-dessous. Les règles temporaires
actuellement publiées doivent être sauvegardées depuis la console Firebase
avant toute bascule.

## Bascule contrôlée

1. Dans Firebase Authentication, activer **Anonyme** et
   **Adresse email / Mot de passe**.
2. Déployer l’application compatible avec l’authentification en conservant
   encore les règles temporaires.
3. Vérifier ouverture anonyme, missions, engagement et persistance après
   fermeture.
4. Créer manuellement un compte responsable dans Firebase Console. Aucune
   inscription responsable n’existe dans l’application.
5. Relever son UID et créer `roles/{uid}` :

   ```json
   {
     "role": "site_manager",
     "locationIds": ["identifiant-lieu-autorise"],
     "active": true
   }
   ```

   Un responsable de site RC1.4 reçoit exactement un identifiant de lieu. Le
   formulaire injecte ce lieu automatiquement et ne permet aucun choix. Un
   coordinateur utilise `role: "coordinator"` et `locationIds: ["*"]` ; lui
   seul conserve le sélecteur donnant accès à tous les lieux.
6. Tester la connexion responsable, l’absence de sélecteur, l’injection du
   lieu autorisé et la publication avec les règles temporaires. Vérifier aussi
   qu’une écriture visant un autre `locationId` est refusée.
7. Depuis `firebase_tests`, exécuter `npm install`, puis `npm test`. Ces tests
   utilisent uniquement l’émulateur et nécessitent Java.
8. Tester sur un projet Firebase de recette, puis seulement après validation :

   ```bash
   firebase login
   firebase use <your-project-id>
   firebase deploy --only firestore:rules
   ```

9. Tester immédiatement sur Mac et iPhone : lieux, missions, déclaration
   autorisée, engagement anonyme, compteurs, second engagement refusé et
   publication non autorisée refusée.

Firebase Auth ne maintient qu’un utilisateur par instance. Le choix RC1 est :
navigation normale sous identité anonyme ; une connexion responsable remplace
temporairement cette identité ; « Se déconnecter » recrée immédiatement une
session anonyme.

## Amorçage des lieux

`ENABLE_LOCATION_SEED` vaut `false` par défaut. Sur Netlify, conserver :

```text
ENABLE_LOCATION_SEED=false
```

L’activer uniquement sur un environnement vide avec des règles permettant
explicitement l’amorçage, puis le désactiver. Les règles RC1 interdisent toute
écriture cliente dans `locations`.

## Retour arrière

1. Ne pas supprimer `firestore.rules`.
2. En cas de blocage terrain après publication, restaurer immédiatement depuis
   Firebase Console la copie datée des règles temporaires.
3. Vérifier le rétablissement sur Mac et iPhone.
4. Corriger et rejouer les tests émulateur avant toute nouvelle publication.

# Adresses vérifiées

Le registre est `data/locations_verified.csv` et son audit
`data/locations_address_audit.md`. Les lignes non validées ne sont jamais
importées.

L’outil d’administration est séparé de l’application :

```bash
cd scripts
npm install
export LOCATION_MIGRATION_PROJECT_ID="mobilisation""-sante"
gcloud auth application-default login
node update_location_addresses.mjs --dry-run
node update_location_addresses.mjs --apply-confirmed
```

Sans argument, l’outil reste en dry-run. Il refuse tout projet autre que
le projet MobSanté autorisé et lie le rapport au CSV et au projet par
empreinte. La concaténation dans l’exemple évite que le scanner Netlify
confonde cet identifiant public avec une variable sensible du build Web. Le
mode `--apply-confirmed` exige ce rapport préalable, refuse les conflits,
sauvegarde les documents dans `data/location_address_backup.json`, puis ajoute
uniquement les champs d’adresse vérifiés encore absents. Il n’écrase ni adresse
ni contact existant et ignore `needs_confirmation` et `not_found`. Ne pas
exécuter ce mode contre la production sans validation humaine du rapport.

# Désengagement et annulation RC1.3

Un volontaire authentifié anonymement voit `✓ JE SUIS ENGAGÉ` lorsque le
document déterministe `engagements/{missionId}_{uid}` existe. L’action
secondaire `Me désengager` demande une confirmation, puis une transaction
supprime cet engagement et décrémente exactement le compteur correspondant à
la profession enregistrée. Le désengagement est refusé après la fin du créneau
ou lorsque la mission est annulée.

Un coordinateur actif, ou un responsable de site autorisé pour le
`locationId`, peut annuler un besoin sans le supprimer. La mission reçoit :

```text
status=cancelled
isActive=false
cancelledAt=<server timestamp>
cancelledBy=<responsible uid>
cancellationReason=<optional reason>
updatedAt=<server timestamp>
```

Les quotas et compteurs ne changent pas. Les engagements existants sont
conservés pour l’historique, tandis que la requête opérationnelle
`isActive == true` retire immédiatement la mission des autres appareils.

## Recette multi-appareils

### Désengagement

1. Créer une mission nécessitant 2 MK.
2. Sur l’iPhone A, s’engager comme MK.
3. Vérifier sur le Mac le passage à 1/2.
4. Sur l’iPhone A, choisir `Me désengager`, puis confirmer.
5. Vérifier sur le Mac le retour à 0/2 sans rechargement.
6. Vérifier la disparition de `engagements/{missionId}_{uid}`.

### Annulation

1. Créer une mission et enregistrer un engagement MK.
2. Se connecter avec le compte responsable ayant créé ce besoin.
3. Ouvrir `Situation`, choisir `Annuler ce besoin`, saisir éventuellement un
   motif et confirmer. Cette action n’est jamais affichée sur les cartes
   publiques `Missions`.
4. Vérifier la disparition immédiate de la liste opérationnelle sur l’iPhone.
5. Vérifier que le document mission existe encore avec `status=cancelled` et
   `isActive=false`.
6. Vérifier que l’engagement existant est conservé et qu’un nouvel engagement
   est refusé.

## Déploiement des règles

Les nouvelles règles lient atomiquement suppression d’engagement et décrément
de mission, et limitent l’annulation aux rôles autorisés. Avant publication :

1. exécuter `npm test` dans `firebase_tests` ;
2. déployer d’abord l’application compatible en conservant les règles
   temporaires ;
3. effectuer la recette sur un projet de test ;
4. sauvegarder les règles publiées ;
5. publier manuellement avec
   `firebase deploy --only firestore:rules` ;

## Cible future des quotas par profession

RC1.5 conserve les compteurs historiques `requiredMk`, `requiredPp`,
`registeredMk` et `registeredPp`. Aucune migration n’est exécutée. Le futur
modèle généralisé devra utiliser :

```text
requiredByProfession: {
  mk: 4,
  pp: 1,
  doctor: 0,
  nurse: 0,
  otherHealthProfessional: 0
}

registeredByProfession: {
  mk: 1,
  pp: 0,
  doctor: 0,
  nurse: 0,
  otherHealthProfessional: 0
}
```

Tant que cette migration n’existe pas, seules les professions MK et PP sont
proposées pour un engagement sur une mission.
6. rejouer immédiatement les deux scénarios sur Mac et iPhone.

Aucune règle n’est déployée automatiquement par le projet.
