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

`MOBSANTE_APP_URL` doit contenir une URL MobSanté autorisée par Firebase Auth.
Elle est obligatoire avant tout futur déploiement. Aucune URL de production
n’est supposée dans le code.

Les tests utilisent :

```text
http://127.0.0.1:5000/activation
```

## Transport d’e-mail

`PendingAdminInvitationMailer` est volontairement passif. Il n’envoie aucun
e-mail et le résultat public indique toujours `emailDelivery: pending`.
RC2.3A.4 devra choisir et configurer un transport transactionnel avant de
présenter un envoi comme effectif.

## Développement local

```bash
npm --prefix functions install
npm --prefix functions test
```

Les tests sont unitaires, injectent Auth/Firestore/mailer et n’accèdent à
aucun projet Firebase réel. Les émulateurs Auth, Firestore et Functions sont
déclarés dans `firebase.json` pour la future validation intégrée.

## Déploiement futur

Avant tout déploiement :

1. valider la cible Firebase `mobilisation-sante` ;
2. configurer `MOBSANTE_APP_URL` avec l’URL approuvée ;
3. choisir le transport d’e-mail et ses secrets hors dépôt ;
4. exécuter les suites Flutter, Functions et Emulator ;
5. déployer explicitement Functions et règles uniquement après autorisation.
