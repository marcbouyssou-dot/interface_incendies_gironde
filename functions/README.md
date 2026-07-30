# Provisionnement des responsables

RC2.3A.3 introduit une Function callable `provisionAdminInvitation`. Elle est
la seule couche autorisée à créer un compte Firebase Auth et un document
`roles/{uid}`. Flutter ne possède jamais de privilège Admin SDK.

## Flux

1. Le coordinateur crée une invitation `pending` depuis Flutter.
2. La callable vérifie l’identité Firebase du demandeur puis son rôle
   `coordinator` actif.
3. Elle valide l’invitation, son expiration, le rôle et les centres.
4. Elle crée le compte Auth sans mot de passe, ou réutilise un compte existant
   compatible et non désactivé.
5. Elle génère un lien officiel Firebase de définition/réinitialisation du mot
   de passe.
6. Une transaction crée ou contrôle `roles/{uid}` puis marque l’invitation
   `accepted`.

Le lien complet n’est ni renvoyé au client, ni stocké dans Firestore, ni
journalisé. Seuls les timestamps de provisionnement sont conservés.

## Idempotence et erreurs partielles

- Une invitation déjà acceptée avec `acceptedUid` retourne un succès
  idempotent sans recréer de compte ni de lien.
- Un rôle existant doit correspondre exactement au rôle et aux centres
  demandés.
- Si Firestore échoue après la création d’un nouveau compte Auth, la Function
  tente de supprimer uniquement ce compte nouvellement créé. Un compte
  préexistant n’est jamais supprimé.
- L’invitation reste `pending` tant que la transaction finale n’a pas réussi.

## Variable requise

`MOBSANTE_APP_URL` doit contenir l’URL de base HTTPS de MobSanté, sans
paramètres, fragment ni identifiants intégrés. La Function ajoute elle-même le
chemin `/activation`. Une URL HTTP est acceptée uniquement sur `localhost`,
`127.0.0.1` ou `::1` pour les tests locaux.

Deux environnements dotenv Firebase sont suivis :

- `.env.demo-mobsante` : `http://127.0.0.1:5000`, réservé aux émulateurs ;
- `.env.mobilisation-sante` : `https://mobsante.netlify.app`, URL publique de
  production.

La destination de production normalisée est donc
`https://mobsante.netlify.app/activation`. Le domaine
`mobsante.netlify.app` doit être ajouté manuellement dans Firebase
Authentication > Settings > Authorized domains.

Les tests utilisent :

```text
http://127.0.0.1:5000
```

Le lien généré utilise alors
`http://127.0.0.1:5000/activation`. L’écran Flutter associé vérifie le code
d’action, permet de choisir le mot de passe puis propose explicitement d’ouvrir
la connexion responsable existante.

## Transport d’e-mail

`PendingAdminInvitationMailer` est volontairement passif. Il n’envoie aucun
e-mail et le résultat public indique toujours `emailDelivery: pending`.
RC2.3A.4 devra choisir et configurer un transport transactionnel avant de
présenter un envoi comme effectif.

## Développement local

Le runtime de référence est Node.js 20. Le fichier `.nvmrc` permet de le
sélectionner avec `nvm use`; sur macOS, une installation Homebrew non liée peut
être utilisée en préfixant temporairement le `PATH`.

```bash
npm ci --prefix functions
npm --prefix functions test
npm --prefix functions run test:emulator
```

La suite intégrée démarre Auth (9099), Firestore (8080), Functions (5001) et
l’interface Emulator (4000) via `firebase emulators:exec`. Elle impose le projet
fictif `demo-mobsante`. Le fichier `.env.demo-mobsante` ne contient que l’URL
locale non sensible. La panne de transaction est injectable uniquement quand
`FUNCTIONS_EMULATOR=true`; aucune donnée fournie par un appelant ne peut
l’activer en production.

Règle absolue : ne jamais lancer ces tests avec `mobilisation-sante`, un compte
réel ou une ressource distante.

## Garanties de sécurité

- La réponse callable est limitée à `accountProvisioned`, `emailDelivery`,
  `invitationStatus` et `alreadyProvisioned`.
- Le lien d’activation, son `oobCode` et les données Admin SDK ne sont ni
  renvoyés, ni persistés, ni journalisés.
- L’ordre est : validation, compte Auth, génération du lien, puis transaction
  rôle + invitation.
- En cas d’échec avant la transaction, seul un compte créé par cet appel est
  compensé. Un compte préexistant n’est jamais supprimé.
- Le transport d’e-mail reste passif et n’annonce aucun envoi.

## Audit des dépendances

À exécuter sous Node.js 20 sans correction forcée :

```bash
npm --prefix functions audit
npm --prefix functions audit --omit=dev
npm --prefix functions outdated
```

Les alertes de développement liées au CLI et aux émulateurs doivent être
distinguées des dépendances réellement embarquées. Ne jamais exécuter
`npm audit fix --force` sans étude des ruptures et validation complète.

## Déploiement futur

Avant tout déploiement :

1. vérifier manuellement que le projet cible est sur le plan Blaze, requis pour
   déployer Cloud Functions ;
2. valider explicitement la cible Firebase `mobilisation-sante` et la région
   `europe-west1` ;
3. vérifier que `https://mobsante.netlify.app` reste l’URL canonique publiée et
   autoriser `mobsante.netlify.app` dans Firebase Auth ;
4. vérifier le modèle d’e-mail Firebase de réinitialisation, son domaine
   d’action et le lien reçu sur Safari iPhone et Chrome Desktop ;
5. choisir le transport d’e-mail ; stocker ses identifiants avec
   `defineSecret`/Google Cloud Secret Manager et les lier uniquement à la
   Function concernée ;
6. vérifier les services de déploiement de 2e génération : Cloud Functions,
   Cloud Run, Cloud Build, Artifact Registry et Cloud Storage pour les sources ;
7. examiner les coûts à l’usage et la rétention Artifact Registry ; aucun coût
   nul n’est supposé ;
8. exécuter toutes les suites sous Node.js 20 ;
9. déployer explicitement la seule Function et les seules règles autorisées.

Références officielles :

- https://firebase.google.com/docs/functions/get-started
- https://firebase.google.com/docs/functions/manage-functions
- https://firebase.google.com/docs/functions/config-env
- https://firebase.google.com/docs/auth/web/passing-state-in-email-actions
