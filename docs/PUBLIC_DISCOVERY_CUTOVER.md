# BETA-READY-003 — découverte publique minimale

## Contrat

`publicMissionDiscovery/{publicId}` est une vue de présentation produite par le
serveur. Ce n'est pas une mission opérationnelle. Les seules clés admises sont
`publicId`, `day` (date civile en Europe/Paris, `YYYY-MM-DD`), `sectorLabel`
(secteur issu d'une liste fermée), `professions` (identifiants canoniques des
professions demandées) et `status` (toujours `open`). Aucun quota ni horaire
précis n'est publié. `publicId` est un hachage déterministe de l'identifiant
opérationnel ; ce dernier n'est jamais transmis au visiteur. Le client refuse
les documents contenant une clé inconnue.

Il n'existe **pas** de collection `publicLocationDiscovery` : la carte visiteur
n'a besoin que du secteur large déjà présent dans la projection de mission.
Le nom, l'adresse, les coordonnées, le contact et l'équipement du site restent
dans `locations`, réservé aux lecteurs autorisés.

Une projection existe si la mission est active, publiée (`critical` ou
`toComplete`), avec un créneau valide dont la fin est future et au moins une
profession demandée. La mobilisation doit être active. Pour une nouvelle
opération, sa visibilité doit être explicitement `platform` et son statut
`planned` ou `active`. La mobilisation historique sans `operationId` est admise
uniquement si `platform/config.activeMobilizationId` la désigne. Ce repli ne
publie ni `legacy-gironde` ni une identité de site ; il ne suppose aucun
backfill d'organisation, d'opération ou de propriétaire de site.

Le projecteur canonique est
`functions/src/public_discovery/projector.js`. Il construit le document à
partir d'une liste fermée de champs et ignore tout champ opérationnel nouveau.
`firestore_projector.js` réconcilie le document avec une lecture transactionnelle
de la source courante. Cinq exports indépendants surveillent la mission, la
mobilisation, l'opération, la configuration de la mobilisation historique et
la fin des créneaux (réconciliation horaire). Aucun n'utilise les services de
notification.

L'outil `scripts/rebuild_public_mission_discovery.mjs` lit missions, sites,
mobilisations, opérations et projections, puis calcule `CREATE`, `UPDATE`,
`DELETE`, `UNCHANGED`. Exemple local :

```sh
FIRESTORE_EMULATOR_HOST=127.0.0.1:18080 \
  node scripts/rebuild_public_mission_discovery.mjs --project=demo-mobsante
```

Le mode par défaut est **DRY RUN**. `--apply` est séparé ; toute écriture
distante demande en plus `--production-write-authorized` et une autorisation
humaine future. L'outil n'écrit jamais dans les collections opérationnelles.
Les identifiants affichés sont bornés ou masqués ; aucun contenu documentaire
n'est journalisé.

## Bascule de production proposée — aucune étape exécutée dans ce lot

1. Valider humainement le contrat public et les tests, puis vérifier les
   cinq exports de projection à déployer **individuellement**. Ne pas activer
   les quatre déclencheurs de notification manquants en production.
2. Déployer uniquement les cinq exports de projection. Constater qu'ils sont
   actifs et qu'ils n'écrivent que `publicMissionDiscovery`.
3. Exécuter le dry-run de reconstruction sur `mobilisation-sante`, puis,
   après autorisation distincte, appliquer la reconstruction. Relire les
   projections et vérifier leurs clés exactes, leur nombre et leur absence de
   champs opérationnels. Répéter le dry-run : aucune différence attendue.
4. Déployer les règles préparées et tester immédiatement en production :
   lecture publique de projection, refus des lectures anonymes de
   `missions`/`locations`, refus des écritures client sur la projection,
   accès d'un professionnel vérifié et des trois rôles administratifs.
   L'ancien écran visiteur reste un état de découverte générique pendant
   cette courte transition ; il ne dépend pas d'une lecture opérationnelle.
5. Publier le lecteur Flutter de projection, vérifier l'état vide et une
   mission future contrôlée, ainsi que les parcours professionnels et
   administratifs. Surveiller refus Firestore, latence du projecteur et écarts
   entre sources et projections. Toute publication Web/Netlify nécessite sa
   propre autorisation.

À la date de l'audit, les 15 missions de production ont déjà une date de fin
passée ; le dry-run prévoit `CREATE=0`, `UPDATE=0`, `DELETE=0`,
`UNCHANGED=15`. L'état vide est donc exact jusqu'à la prochaine mission
éligible. Les 65 sites historiques ne génèrent aucun document public de site.

Avant la bascule, l'application Web courante continue à effectuer des lectures
opérationnelles de préchauffage. Les règles cibles les refuseront pour un
visiteur ; ce refus est absorbé par l'ancien écran de découverte. La nouvelle
application attend un rôle habilité ou un profil vérifié avant de préchauffer
les flux opérationnels, et lit `publicMissionDiscovery` pour le visiteur.

## Points de contrôle

- La lecture de `publicMissionDiscovery` est publique et toute écriture client
  y est refusée. L'Admin SDK reste le seul producteur.
- Les sites historiques ne sont plus publics dans les règles cibles ; un
  professionnel vérifié y conserve un accès opérationnel. Les accès des
  responsables, coordinateurs et administrateurs restent régis par leurs
  périmètres actuels.
- Le projet réel ne reçoit dans BETA-READY-003 ni règles, ni fonctions, ni
  données, ni notifications nouvelles.
