# Audit des adresses des lieux

Date de consultation : 29 juillet 2026.

## Synthèse

- Lieux du catalogue : 65
- `verified_official` : 1
- `verified_cross_source` : 0
- `needs_confirmation` : 1
- `not_found` : 63
- Doublons détectés : 0
- Incohérences de commune ou code postal confirmées : 0

La recherche n’a pas permis d’identifier un annuaire officiel SDIS 33
consolidé associant sans ambiguïté chacun des centres du catalogue à une
adresse. Ces 63 lignes restent volontairement sans adresse.

## Cas contrôlés

### Pauillac

Une seule occurrence, identifiant `medoc-pauillac`, groupe `medoc`. L’adresse
du centre reste `not_found` : aucune adresse officielle suffisamment probante
n’a été retenue.

### Parc des Expositions de Bordeaux

Adresse publique officielle publiée par la Ville de Bordeaux :
`Cours Jules Ladoumègue, 33300 Bordeaux`. Statut `verified_official`.
L’entrée opérationnelle/logistique du dispositif reste à confirmer avant tout
déploiement terrain.

Source :
https://www.bordeaux.fr/agenda/le-triathlon-de-bordeaux

### Croix-Rouge Bordeaux

Le site officiel indique l’Unité locale de Bordeaux au `50 rue Ferrère,
33000 Bordeaux`, mais précise que certaines activités, notamment de secours,
se déroulent aussi quartier Bastide. La délégation territoriale se trouve à
Artigues-près-Bordeaux. Le libellé applicatif ne permet donc pas de choisir
l’implantation opérationnelle : statut `needs_confirmation`, sans adresse
publiable.

Sources :

- https://www.croix-rouge.fr/unite-locale-de-bordeaux
- https://as.croix-rouge.fr/fichesynthese/38

## Vérifications humaines nécessaires

- Demander au SDIS 33 la liste officielle des adresses des 63 centres et
  vérifier les centres multi-communes.
- Confirmer avec l’URPS/coordinateur l’entrée opérationnelle du Parc des
  Expositions.
- Confirmer si « Croix-Rouge Bordeaux » désigne l’unité locale rue Ferrère,
  le site Bastide, la délégation territoriale ou une base temporaire.
- Recontrôler en priorité les cinq centres bordelais afin d’éviter d’utiliser
  l’adresse administrative générale du SDIS.

Les URL de source et coordonnées restent des données d’audit ; l’interface
publique ne les affiche pas.
