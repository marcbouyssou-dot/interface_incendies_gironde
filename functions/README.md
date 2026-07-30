# Future fonction d’invitation des responsables

Cette fonction serveur sera la seule autorisée à créer des comptes
responsables. Le client Flutter créera uniquement un document
`adminInvitations` en attente.

## Traitement prévu

1. Détecter une invitation `pending` créée par un coordinateur actif.
2. Vérifier le rôle demandé, les lieux, l’expiration et l’absence d’un compte
   privilégié incompatible.
3. Créer l’utilisateur avec Firebase Admin SDK, sans exposer de droit de
   création de compte au client.
4. Créer `roles/{uid}` avec `role: site_manager`, les `locationIds` validés et
   `active: false` jusqu’à l’acceptation.
5. Générer un lien d’activation à usage contrôlé et envoyer l’e-mail via le
   fournisseur transactionnel retenu.
6. Lors de la consommation, permettre au responsable de définir son mot de
   passe, activer son rôle, puis passer l’invitation à `accepted` avec
   `acceptedAt`.

## Contraintes

- Admin SDK uniquement côté serveur.
- Opérations idempotentes et journalisées.
- Aucun mot de passe, token ou lien d’activation stocké en clair dans
  Firestore.
- Expiration et annulation vérifiées avant chaque étape.
- Une invitation ne peut gérer que les lieux validés par le coordinateur.
- Les erreurs ne doivent jamais laisser un compte actif sans rôle cohérent.

Cette Function n’est pas implémentée ni déployée dans RC2.3A.1.
