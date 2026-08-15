# Notifications V1 — recette PWA iPhone

Cette recette ne doit être exécutée qu’après autorisation explicite de déployer
Notifications V1. Elle utilise un projet Firebase de recette isolé, une
mobilisation de test et des comptes dédiés. Aucun compte ni token réel ne doit
être présent dans ce projet.

## Préconditions avant le premier test réel

1. Créer ou sélectionner un projet Firebase de recette distinct de la
   production.
2. Y configurer une application Web, Authentication anonyme/e-mail, Firestore,
   Functions et Cloud Messaging.
3. Générer une paire Web Push dans Firebase Cloud Messaging et conserver
   uniquement la clé VAPID **publique** pour le build Flutter. Ne jamais placer
   de clé privée dans le dépôt ou dans `--dart-define`.
4. Créer dans ce projet une mobilisation active, un centre et une mission
   entièrement fictifs. Utiliser trois comptes dédiés : professionnel,
   responsable et coordinateur.
5. Vérifier que le projet ne contient aucun utilisateur, abonnement, mission ou
   donnée de production.
6. Rejouer localement avant tout déploiement :

   ```sh
   flutter test
   npm --prefix functions test
   npm --prefix firebase_tests test
   flutter analyze
   git diff --check
   ```

7. Après autorisation, déployer une seule fois les Rules et Functions sur le
   projet de recette, puis publier la PWA de recette avec :

   ```sh
   flutter build web \
     --dart-define=FIREBASE_WEB_PUSH_VAPID_KEY=<CLE_VAPID_PUBLIQUE>
   ```

   La cible Web de recette doit être en HTTPS. Ne pas réutiliser l’URL de
   production pour cette validation.

## Scénario iPhone

1. Sur un iPhone compatible, ouvrir l’URL HTTPS de recette dans Safari.
2. Utiliser **Partager → Sur l’écran d’accueil**, puis ouvrir MobSanté depuis
   l’icône installée. Le Push iPhone n’est pas testé depuis un simple onglet
   Safari.
3. Se connecter avec le compte professionnel de recette, ouvrir
   **Notifications**, activer **Missions compatibles**, puis toucher
   **Activer les notifications**. Accepter la demande système.
4. Vérifier dans Firestore que `pushSubscriptions` contient un document actif
   pour cet utilisateur et cet appareil, sans modifier le profil professionnel.
5. Fermer la PWA.
6. Depuis le projet de recette uniquement, publier la mission fictive avec la
   profession du compte test. Ce changement doit produire exactement un
   `mission.published`, une notification in-app et une livraison Push.
7. Vérifier la réception d’un seul Push, son texte court et l’absence de donnée
   personnelle.
8. Toucher le Push : MobSanté doit restaurer la session, ouvrir le centre puis
   la mission fictive. Retirer ensuite l’accès du compte et répéter le lien :
   l’écran doit expliquer que la mission est inaccessible.
9. Rejouer une livraison avec le même `eventId` dans l’émulateur : aucun second
   Push ne doit être envoyé. Ne jamais rejouer cet événement dans le projet
   réel.
10. Désactiver ou supprimer le projet de recette après conservation des seuls
    résultats non sensibles (statuts, identifiants techniques tronqués et
    captures sans token).

## Contrôles complémentaires

- Refuser la permission puis confirmer que tout MobSanté reste utilisable.
- Tester un second appareil avec le même compte : deux abonnements séparés sont
  attendus.
- Révoquer un token de recette et vérifier sa désactivation automatique après
  un échec FCM permanent.
- Vérifier les heures calmes avec un événement non critique, puis une mission
  critique qui ne doit pas être différée.
- Confirmer que l’Administrateur plateforme ne reçoit rien en V1.

La recette s’arrête immédiatement si le projet contient une donnée réelle ou
si la cible de déploiement n’est pas explicitement le projet de recette.
