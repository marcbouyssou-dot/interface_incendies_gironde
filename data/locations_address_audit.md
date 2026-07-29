# Audit des adresses des lieux

Source intégrée : `Base vérifiée des 66 lieux — tableau complet.md`.

Date de vérification des données : 29 juillet 2026.

## Synthèse

- Lignes source analysées : 66
- Lieux applicatifs conservés : 65
- `verified_official` : 32
- `verified_cross_source` : 11
- `needs_confirmation` : 16
- `not_found` : 6
- Secteurs sans CIS autonome ou entrées obsolètes requalifiées : 18
- Doublon exclu : Pauillac dans Haute Gironde

Les identifiants Firestore existants sont conservés. Aucun lieu n’est supprimé :
les communes sans CIS autonome restent consultables comme secteurs, mais ne
sont plus proposées lors de la création d’une mission.

## Anomalies structurantes conservées

- **Bordeaux Benauge** : caserne historique fermée le 2 avril 2024, activité
  transférée à Bordeaux Bastide. Le lieu reste référencé comme secteur non
  opérationnel avec le statut `needs_confirmation`.
- **Bordeaux Caudéran, Bordeaux Nord, Bègles, Carbon-Blanc, Cenon, Eysines,
  Floirac, Le Haillan, Lormont, Pessac et Talence** : aucun CIS autonome
  confirmé. Ces entrées sont des secteurs et non des casernes.
- **Podensac, Pujols, Saint-Denis-de-Pile, Saint-Émilion,
  Saint-Seurin-sur-l'Isle et Cavignac** : aucun CIS trouvé dans les sources
  officielles contrôlées. Ces entrées `not_found` sont conservées sans adresse
  et rendues non opérationnelles.
- **Pauillac** : une seule entrée, rattachée au Médoc. La ligne dupliquée dans
  Haute Gironde n’est jamais importée.
- **Castillon-la-Bataille** : le CIS est implanté à
  Saint-Magne-de-Castillon.
- **Cadillac** : le CIS Cadillac-Béguey est implanté à Béguey.
- **Arès / Lège-Cap-Ferret** : l’implantation retenue est à
  Lège-Cap-Ferret.
- **Parc des Expositions** : adresse générale cours Charles Bricaud ; entrée
  opérationnelle Porte M/cours Jules Ladoumègue explicitement à confirmer.
- **Croix-Rouge** : le lieu correspond désormais sans ambiguïté à la
  Délégation territoriale de la Gironde, 5 avenue Gay-Lussac,
  Artigues-près-Bordeaux. Les autres implantations citées dans les notes ne
  sont pas utilisées.

## Réversibilité

`data/locations_verified.csv` est la source structurée suivie dans Git.
`lib/data/location_address_registry.dart` est généré depuis ce CSV.

La mise à jour d’une collection Firestore existante passe exclusivement par :

1. `node scripts/update_location_addresses.mjs --dry-run`
2. contrôle du rapport et de son checksum ;
3. `node scripts/update_location_addresses.mjs --apply`

Le script refuse les identifiants inconnus et les métadonnées divergentes,
produit une sauvegarde avant toute écriture et ne touche ni aux missions ni aux
engagements.
