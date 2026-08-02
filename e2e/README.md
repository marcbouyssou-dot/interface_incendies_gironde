# Smoke tests MobSanté en lecture seule

Ce harnais vérifie la PWA publiée sans effectuer d’écriture métier. L’URL cible
est `https://mobsante.netlify.app` par défaut et peut être remplacée avec
`MOBSANTE_E2E_BASE_URL`.

## Première authentification

Exécuter `npm run e2e:auth`, puis se connecter manuellement avec les trois
profils demandés. Les états de session, y compris IndexedDB utilisé par Firebase
Auth, sont enregistrés sous `e2e/.auth/`. Ce dossier est ignoré par Git.

Une autre possibilité consiste à copier `e2e/.env.example` vers `e2e/.env` et à
renseigner les variables localement. Le fichier réel est ignoré par Git et les
secrets ne sont jamais consignés dans les rapports.

## Commandes

- `npm run e2e:install` : installe Chromium pour Playwright ;
- `npm run e2e:auth` : enregistre interactivement les sessions locales ;
- `npm run e2e:public` : exécute le public et les tests du harnais ;
- `npm run e2e:harness` : teste uniquement les garde-fous ;
- `npm run e2e:smoke` : exécute tous les rôles disponibles ;
- `npm run e2e:smoke:headed` : même parcours avec navigateur visible ;
- `npm run e2e:report` : ouvre le dernier rapport HTML.

## Protection anti-écriture

Toutes les requêtes POST vers une Function sont interceptées. Seules
`listResponsibleAccess` et `listAdminLocations` sont autorisées. Les callables
d’écriture connues et toute Function POST inconnue sont bloquées et font échouer
le test. Les parcours ne cliquent jamais sur une action terminale telle que
Enregistrer, Supprimer, Confirmer, Envoyer, Renvoyer, Désactiver, Réactiver ou
Publier.

Les captures sont limitées aux échecs et masquent les champs de saisie. Les
parcours authentifiés sont ignorés avec une instruction claire tant qu’aucune
session ou paire de variables n’est disponible.
