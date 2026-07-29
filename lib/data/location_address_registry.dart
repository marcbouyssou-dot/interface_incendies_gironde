// GENERATED FILE — DO NOT EDIT BY HAND.
// Source: data/locations_verified.csv

import '../models/need.dart';

class VerifiedLocationRecord {
  const VerifiedLocationRecord({
    required this.currentName,
    required this.displayName,
    required this.type,
    required this.isOperational,
    required this.address,
  });
  final String currentName;
  final String displayName;
  final ResponsePlaceType type;
  final bool isOperational;
  final LocationAddress address;
}

final verifiedLocationRegistry = <String, VerifiedLocationRecord>{
  "Bordeaux Bastide": VerifiedLocationRecord(
    currentName: "Bordeaux Bastide",
    displayName: "Bordeaux Bastide",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "56 rue de la Garonne",
      addressLine2: null,
      postalCode: "33100",
      city: "Bordeaux",
      country: "France",
      storedFullAddress: "56 rue de la Garonne, 33100 Bordeaux, France",
      latitude: 44.835426,
      longitude: -0.550024,
      status: AddressStatus.verifiedCrossSource,
      sourceLabel:
          "actu.fr (Bordeaux, demenagement des pompiers de la Benauge vers le CSP Bordeaux-Bastide)",
      sourceUrl:
          "https://actu.fr/nouvelle-aquitaine/bordeaux_33063/bordeaux-les-pompiers-de-la-benauge-quittent-la-caserne-apres-70-ans-et-vont-defiler-dans-les-rues_60890589.html",
      secondSourceLabel:
          "Base Adresse Nationale via Geoplateforme IGN (geocodage BAN)",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search?index=address&limit=2&q=56%20rue%20de%20la%20Garonne%20Bordeaux",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "CSP Bordeaux-Bastide (quartier Belvedere), operationnel depuis le 2 avril 2024, remplace la caserne historique de la Benauge. Existence confirmee dans OSM : way 1374788827 'Centre d'incendie et de secours Bordeaux-Bastide', operator SDIS 33, groupement Centre-Est (44.83609 / -0.54875 = emprise du batiment). Donnees OSM recuperees via l'API Overpass (https://overpass-api.de/api/interpreter) dans cette session. Coordonnees indiquees = point adresse BAN du 56 rue de la Garonne. Pas de fiche officielle SDIS 33 en ligne : statut cross-source.",
    ),
  ),
  "Bordeaux Benauge": VerifiedLocationRecord(
    currentName: "Bordeaux Benauge",
    displayName: "Bordeaux Benauge",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: "1 rue de la Benauge (site historique, desaffecte)",
      addressLine2: null,
      postalCode: "33100",
      city: "Bordeaux",
      country: "France",
      storedFullAddress:
          "1 rue de la Benauge, 33100 Bordeaux, France (caserne historique fermee le 2 avril 2024)",
      latitude: 44.839483,
      longitude: -0.558618,
      status: AddressStatus.needsConfirmation,
      sourceLabel:
          "Ministere de la Culture - Journees du patrimoine (fiche caserne des pompiers de la Benauge)",
      sourceUrl:
          "https://journeesdupatrimoine.culture.gouv.fr/w/377623/evenement/18805749/visite-bordeaux-euratlantique-bordeaux-rive-droite-un-patrimoine-en-mouvement-",
      secondSourceLabel:
          "actu.fr (depart definitif des pompiers de la Benauge le 2 avril 2024)",
      secondSourceUrl:
          "https://actu.fr/nouvelle-aquitaine/bordeaux_33063/bordeaux-les-pompiers-de-la-benauge-quittent-la-caserne-apres-70-ans-et-vont-defiler-dans-les-rues_60890589.html",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "L'unite 'CIS LA BENAUGE' figure encore dans l'annuaire SDIS 33 (groupement Centre-Est, mise a jour 22/05/2023 : https://www.annuaire-sdis.fr/sdis/gironde/groupements) mais son implantation au 1 rue de la Benauge est fermee depuis le 2 avril 2024 , l'activite est transferee au CSP Bordeaux-Bastide, 56 rue de la Garonne. Adresse postale operationnelle actuelle = celle de SDIS33-BM-BASTIDE - a confirmer directement avec le SDIS 33. Coordonnees = point adresse BAN du 1 rue de la Benauge (https://data.geopf.fr/geocodage/search?index=address&limit=2&q=1%20rue%20de%20la%20Benauge%20Bordeaux).",
    ),
  ),
  "Bordeaux Caudéran": VerifiedLocationRecord(
    currentName: "Bordeaux Caudéran",
    displayName: "Bordeaux Caudéran",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Bordeaux",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.needsConfirmation,
      sourceLabel:
          "Annuaire SDIS 33 - unites territoriales (aucun CIS Caudéran dans les groupements Centre-Centre / Centre-Est / Centre-Ouest)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "OpenStreetMap - inventaire des amenity=fire_station operator SDIS 33 de la metropole bordelaise (aucune caserne a Caudéran)",
      secondSourceUrl: "https://overpass-api.de/api/interpreter",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Pas de CIS autonome identifie dans l'annuaire officiel SDIS 33 , secteur potentiellement couvert par CIS Ornano, 56 cours du Marechal Juin, 33000 Bordeaux (le plus proche , CIS Bruges et CIS Merignac egalement limitrophes) - a confirmer directement avec le SDIS 33. Donnees OSM recuperees via l'API Overpass (https://overpass-api.de/api/interpreter) dans cette session.",
    ),
  ),
  "Bordeaux Nord": VerifiedLocationRecord(
    currentName: "Bordeaux Nord",
    displayName: "Bordeaux Nord",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Bordeaux",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.needsConfirmation,
      sourceLabel:
          "Annuaire SDIS 33 - unites territoriales (aucun CIS 'Bordeaux Nord')",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "Sud Ouest - secteur de premier appel du CIS de Bruges (Le Bouscat, Bruges, Blanquefort, Parempuyre et une partie de Bordeaux : Aubiers, Grand-Parc, bassins a flot, Bordeaux-Lac)",
      secondSourceUrl:
          "https://www.sudouest.fr/gironde/bruges/bruges-le-bouscat-la-caserne-des-pompiers-va-feter-ses-20-ans-cette-annee-23649334.php",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Pas de CIS autonome identifie dans l'annuaire officiel SDIS 33 , secteur potentiellement couvert par CIS Bruges, 3 rue des Aulnes, 33520 Bruges - dont le secteur de premier appel couvre le nord de Bordeaux (Aubiers, Grand-Parc, Bordeaux-Lac) - a confirmer directement avec le SDIS 33.",
    ),
  ),
  "Bordeaux Ornano": VerifiedLocationRecord(
    currentName: "Bordeaux Ornano",
    displayName: "Bordeaux Ornano",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "56 cours du Maréchal Juin",
      addressLine2: null,
      postalCode: "33000",
      city: "Bordeaux",
      country: "France",
      storedFullAddress: "56 cours du Maréchal Juin, 33000 Bordeaux, France",
      latitude: 44.835080,
      longitude: -0.584940,
      status: AddressStatus.verifiedCrossSource,
      sourceLabel:
          "Annuaire SDIS 33 - unites territoriales, CIS ORNANO (groupement Centre-Centre)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "Base Adresse Nationale via Geoplateforme IGN (56 Cours Marechal Juin 33000 Bordeaux)",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search?index=address&limit=2&q=56%20cours%20du%20Marechal%20Juin%20Bordeaux",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "L'annuaire indique '33062 BORDEAUX' (code CEDEX administratif) , la BAN retient le code postal 33000 pour le 56 cours Marechal Juin - c'est le code postal a utiliser. Coordonnees = emprise OSM way 178167392 (CSP Ornano, operator SDIS 33). Donnees OSM recuperees via l'API Overpass (https://overpass-api.de/api/interpreter) dans cette session. Ne pas confondre avec l'adresse de la direction du SDIS 33 (22 bd Pierre 1er, 33081 Bordeaux Cedex).",
    ),
  ),
  "Bègles": VerifiedLocationRecord(
    currentName: "Bègles",
    displayName: "Bègles",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Bègles",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.needsConfirmation,
      sourceLabel: "Annuaire SDIS 33 - unites territoriales (aucun CIS Begles)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "OpenStreetMap - inventaire des amenity=fire_station operator SDIS 33 de la metropole bordelaise (aucune caserne a Begles)",
      secondSourceUrl: "https://overpass-api.de/api/interpreter",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Pas de CIS autonome identifie dans l'annuaire officiel SDIS 33 , secteur potentiellement couvert par CIS Villenave-d'Ornon, Impasse de Benedigues, 33140 Villenave-d'Ornon (limitrophe au sud) ou CSP Bordeaux-Bastide - a confirmer directement avec le SDIS 33. Donnees OSM recuperees via l'API Overpass (https://overpass-api.de/api/interpreter) dans cette session.",
    ),
  ),
  "Bassens": VerifiedLocationRecord(
    currentName: "Bassens",
    displayName: "Bassens",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "2 rue de Beauval",
      addressLine2: null,
      postalCode: "33530",
      city: "Bassens",
      country: "France",
      storedFullAddress: "2 rue de Beauval, 33530 Bassens, France",
      latitude: 44.906040,
      longitude: -0.503940,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "Mairie d'Ambes - bulletin municipal 'L'Ambesien' (site du CIS Bassens, 2 rue de Beauval, Bassens)",
      sourceUrl:
          "https://www.villeambes.fr/wp-content/uploads/2022/11/Ambesien-2.pdf",
      secondSourceLabel:
          "Annuaire SDIS 33 - groupement territorial Centre-Est, 'rue beauval 33530 BASSENS' (etat-major co-implante)",
      secondSourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "CIS Bassens confirme : OSM way 968595753 (operator SDIS 33, groupement Centre-Est) et fiche du centre dans la carte des centres du SDIS 33 (https://unsa-sdis33.fr/wp-content/uploads/2022/05/Centres-du-SDIS-33-.pdf). Donnees OSM recuperees via l'API Overpass (https://overpass-api.de/api/interpreter) dans cette session. La BAN indexe la voie 'Rue de Beauval 33530 Bassens' (44.908209 / -0.50307) mais pas le numero 2 : https://data.geopf.fr/geocodage/search?index=address&limit=3&q=2%20rue%20de%20Beauval%20Bassens. Le site est situe a la limite communale Bassens / Carbon-Blanc (le geocodage inverse renvoie 'rue de Beau Val 33560 Carbon-Blanc' a 72 m). Coordonnees = emprise OSM du batiment.",
    ),
  ),
  "Bruges": VerifiedLocationRecord(
    currentName: "Bruges",
    displayName: "Bruges",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "3 rue des Aulnes",
      addressLine2: null,
      postalCode: "33520",
      city: "Bruges",
      country: "France",
      storedFullAddress: "3 rue des Aulnes, 33520 Bruges, France",
      latitude: 44.872770,
      longitude: -0.577830,
      status: AddressStatus.verifiedCrossSource,
      sourceLabel:
          "Annuaire SDIS 33 - unites territoriales, CIS BRUGES (groupement Centre-Centre)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "Base Adresse Nationale via Geoplateforme IGN (voie 'Rue des Aulnes 33520 Bruges')",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search?index=address&limit=2&q=3%20rue%20des%20Aulnes%20Bruges",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Voie confirmee par la BAN , le numero 3 n'est pas indexe dans la BAN (le geocodage inverse sur l'emprise OSM renvoie '8 Rue des Aulnes' a 36 m, et l'amicale des sapeurs-pompiers de Bruges est declaree au 6 rue des Aulnes) : numero de voirie a reconfirmer aupres du SDIS 33. CIS confirme : OSM way 459195327 (CSP Bruges, operator SDIS 33). Donnees OSM recuperees via l'API Overpass (https://overpass-api.de/api/interpreter) dans cette session. Secteur de premier appel : Le Bouscat, Bruges, Blanquefort, Parempuyre et une partie de Bordeaux (Sud Ouest, 17/03/2025).",
    ),
  ),
  "Carbon-Blanc": VerifiedLocationRecord(
    currentName: "Carbon-Blanc",
    displayName: "Carbon-Blanc",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Carbon-Blanc",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.needsConfirmation,
      sourceLabel:
          "Annuaire SDIS 33 - unites territoriales (aucun CIS Carbon-Blanc)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "Mairie d'Ambes - bulletin municipal (CIS Bassens, 2 rue de Beauval)",
      secondSourceUrl:
          "https://www.villeambes.fr/wp-content/uploads/2022/11/Ambesien-2.pdf",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Pas de CIS autonome identifie dans l'annuaire officiel SDIS 33 , secteur potentiellement couvert par CIS Bassens, 2 rue de Beauval, 33530 Bassens - implante en limite immediate de Carbon-Blanc (le geocodage inverse de l'emprise renvoie meme 'rue de Beau Val 33560 Carbon-Blanc' a 72 m) - a confirmer directement avec le SDIS 33.",
    ),
  ),
  "Cenon": VerifiedLocationRecord(
    currentName: "Cenon",
    displayName: "Cenon",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Cenon",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.needsConfirmation,
      sourceLabel: "Annuaire SDIS 33 - unites territoriales (aucun CIS Cenon)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "OpenStreetMap - inventaire des amenity=fire_station operator SDIS 33 de la metropole bordelaise (aucune caserne a Cenon)",
      secondSourceUrl: "https://overpass-api.de/api/interpreter",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Pas de CIS autonome identifie dans l'annuaire officiel SDIS 33 , secteur potentiellement couvert par CSP Bordeaux-Bastide, 56 rue de la Garonne, 33100 Bordeaux ou CIS Bassens, 2 rue de Beauval, 33530 Bassens - a confirmer directement avec le SDIS 33. Donnees OSM recuperees via l'API Overpass (https://overpass-api.de/api/interpreter) dans cette session.",
    ),
  ),
  "Eysines": VerifiedLocationRecord(
    currentName: "Eysines",
    displayName: "Eysines",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Eysines",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.needsConfirmation,
      sourceLabel:
          "Annuaire SDIS 33 - unites territoriales (aucun CIS Eysines)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "Association des JSP de Saint-Medard - page du CIS de St Medard : secteur de premier appel incluant Eysines",
      secondSourceUrl: "https://jspstmedard.wordpress.com/cis/",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Pas de CIS autonome identifie dans l'annuaire officiel SDIS 33 , secteur potentiellement couvert par CIS Saint-Medard-en-Jalles, Rue Antonin Larroque, 33160 Saint-Medard-en-Jalles - dont le secteur de premier appel comprend explicitement Eysines - a confirmer directement avec le SDIS 33.",
    ),
  ),
  "Floirac": VerifiedLocationRecord(
    currentName: "Floirac",
    displayName: "Floirac",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Floirac",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.needsConfirmation,
      sourceLabel:
          "Annuaire SDIS 33 - unites territoriales (aucun CIS Floirac)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "OpenStreetMap - inventaire des amenity=fire_station operator SDIS 33 de la metropole bordelaise (aucune caserne a Floirac)",
      secondSourceUrl: "https://overpass-api.de/api/interpreter",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Pas de CIS autonome identifie dans l'annuaire officiel SDIS 33 , secteur potentiellement couvert par CSP Bordeaux-Bastide, 56 rue de la Garonne, 33100 Bordeaux - a confirmer directement avec le SDIS 33. Donnees OSM recuperees via l'API Overpass (https://overpass-api.de/api/interpreter) dans cette session.",
    ),
  ),
  "Le Haillan": VerifiedLocationRecord(
    currentName: "Le Haillan",
    displayName: "Le Haillan",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Le Haillan",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.needsConfirmation,
      sourceLabel:
          "Annuaire SDIS 33 - unites territoriales (aucun CIS Le Haillan)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "Association des JSP de Saint-Medard - page du CIS de St Medard : secteur de premier appel incluant le Haillan",
      secondSourceUrl: "https://jspstmedard.wordpress.com/cis/",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Pas de CIS autonome identifie dans l'annuaire officiel SDIS 33 , secteur potentiellement couvert par CIS Saint-Medard-en-Jalles, Rue Antonin Larroque, 33160 Saint-Medard-en-Jalles - dont le secteur de premier appel comprend explicitement le Haillan - a confirmer directement avec le SDIS 33.",
    ),
  ),
  "Lormont": VerifiedLocationRecord(
    currentName: "Lormont",
    displayName: "Lormont",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Lormont",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.needsConfirmation,
      sourceLabel:
          "Annuaire SDIS 33 - unites territoriales (aucun CIS Lormont)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "OpenStreetMap - inventaire des amenity=fire_station operator SDIS 33 de la metropole bordelaise (aucune caserne a Lormont)",
      secondSourceUrl: "https://overpass-api.de/api/interpreter",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Pas de CIS autonome identifie dans l'annuaire officiel SDIS 33 , secteur potentiellement couvert par CIS Bassens, 2 rue de Beauval, 33530 Bassens (limitrophe) ou CSP Bordeaux-Bastide - a confirmer directement avec le SDIS 33. Donnees OSM recuperees via l'API Overpass (https://overpass-api.de/api/interpreter) dans cette session.",
    ),
  ),
  "Mérignac": VerifiedLocationRecord(
    currentName: "Mérignac",
    displayName: "Mérignac",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "100 avenue Bon Air",
      addressLine2: "Centre de secours Paul Saldou",
      postalCode: "33700",
      city: "Mérignac",
      country: "France",
      storedFullAddress:
          "Centre de secours Paul Saldou, 100 avenue Bon Air, 33700 Mérignac, France",
      latitude: 44.818850,
      longitude: -0.648050,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "Ville de Merignac - agenda officiel, lieu 'Centre de secours Paul Saldou, 100 Av. Bon air, 33700 Merignac'",
      sourceUrl: "https://www.merignac.com/agenda/bal-des-pompiers",
      secondSourceLabel:
          "Base Adresse Nationale via Geoplateforme IGN (100 Avenue Bon Air 33700 Merignac)",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search?index=address&limit=2&q=100%20avenue%20Bon%20Air%20Merignac",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "CIS confirme par l'annuaire SDIS 33 (CIS MERIGNAC, groupement Centre-Ouest : https://www.annuaire-sdis.fr/sdis/gironde/groupements) et par OSM way 548232908 (CSP Merignac, alt_name 'Caserne Paul Saldou', operator SDIS 33). Donnees OSM recuperees via l'API Overpass (https://overpass-api.de/api/interpreter) dans cette session. Coordonnees = emprise OSM du batiment , point adresse BAN du 100 avenue Bon Air : 44.818479 / -0.648744.",
    ),
  ),
  "Pessac": VerifiedLocationRecord(
    currentName: "Pessac",
    displayName: "Pessac",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Pessac",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.needsConfirmation,
      sourceLabel:
          "Annuaire SDIS 33 - unites territoriales (aucun CIS Pessac dans le groupement Centre-Ouest)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "OpenStreetMap - inventaire des amenity=fire_station operator SDIS 33 de la metropole bordelaise (aucune caserne a Pessac)",
      secondSourceUrl: "https://overpass-api.de/api/interpreter",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Pas de CIS autonome identifie dans l'annuaire officiel SDIS 33 , secteur potentiellement couvert par CIS Merignac (100 avenue Bon Air, 33700 Merignac), CIS Villenave-d'Ornon ou CIS Cestas, tous trois du groupement Centre-Ouest - a confirmer directement avec le SDIS 33. Donnees OSM recuperees via l'API Overpass (https://overpass-api.de/api/interpreter) dans cette session.",
    ),
  ),
  "Saint-Médard-en-Jalles": VerifiedLocationRecord(
    currentName: "Saint-Médard-en-Jalles",
    displayName: "Saint-Médard-en-Jalles",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "Rue Antonin Larroque",
      addressLine2: null,
      postalCode: "33160",
      city: "Saint-Médard-en-Jalles",
      country: "France",
      storedFullAddress:
          "Rue Antonin Larroque, 33160 Saint-Médard-en-Jalles, France (numero de voirie a confirmer)",
      latitude: 44.895120,
      longitude: -0.721570,
      status: AddressStatus.needsConfirmation,
      sourceLabel:
          "Annuaire SDIS 33 - unites territoriales, CIS ST MEDARD EN JALLES (groupement Centre-Ouest, sans adresse publiee)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "Base Adresse Nationale via Geoplateforme IGN (voie 'Rue Antonin Larroque 33160 Saint-Medard-en-Jalles')",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search?index=address&limit=3&q=Rue%20Antonin%20Larroque%20Saint-Medard-en-Jalles",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "CIS autonome confirme (annuaire SDIS 33 , OSM way 62105397 'Centre d'incendie et de secours de Saint-Medard-en-Jalles', operator SDIS 33, groupement Centre-Ouest , page du CIS par l'association des JSP : https://jspstmedard.wordpress.com/cis/ - secteur de premier appel Blanquefort, Eysines, le Haillan, le Taillan-Medoc, Saint-Aubin-de-Medoc, Saint-Medard-en-Jalles). Voie confirmee : le geocodage inverse BAN de l'emprise OSM renvoie '7 Rue Antonin Larroque' a 21 m. NUMERO DE VOIRIE NON CONFIRME par source officielle (un annuaire associatif non officiel mentionne '2 rue Antonin Larroque') - a confirmer avec le SDIS 33 (tel. de la caserne publie par la ville : 05 56 70 89 00, https://www.saint-medard-en-jalles.fr/demarches-administratives/numeros-durgences/). Donnees OSM recuperees via l'API Overpass (https://overpass-api.de/api/interpreter) dans cette session.",
    ),
  ),
  "Talence": VerifiedLocationRecord(
    currentName: "Talence",
    displayName: "Talence",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Talence",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.needsConfirmation,
      sourceLabel:
          "Annuaire SDIS 33 - unites territoriales (aucun CIS Talence)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "OpenStreetMap - inventaire des amenity=fire_station operator SDIS 33 de la metropole bordelaise (aucune caserne a Talence)",
      secondSourceUrl: "https://overpass-api.de/api/interpreter",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Pas de CIS autonome identifie dans l'annuaire officiel SDIS 33 , secteur potentiellement couvert par CIS Villenave-d'Ornon (Impasse de Benedigues, 33140) ou CIS Ornano (56 cours du Marechal Juin, 33000 Bordeaux) - a confirmer directement avec le SDIS 33. Donnees OSM recuperees via l'API Overpass (https://overpass-api.de/api/interpreter) dans cette session.",
    ),
  ),
  "Villenave-d'Ornon": VerifiedLocationRecord(
    currentName: "Villenave-d'Ornon",
    displayName: "Villenave-d'Ornon",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "Impasse de Bénédigues",
      addressLine2: "Centre de Madère",
      postalCode: "33140",
      city: "Villenave-d'Ornon",
      country: "France",
      storedFullAddress:
          "Impasse de Bénédigues, 33140 Villenave-d'Ornon, France",
      latitude: 44.784510,
      longitude: -0.581580,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "Ville de Villenave d'Ornon - fiche officielle 'Centre d'incendie et de secours de Villenave-d'Ornon, Impasse de Benedigues - 33140 Villenave-d'Ornon'",
      sourceUrl:
          "https://www.villenavedornon.fr/13-841/actualites/fiche/la-section-de-jeunes-sapeurs-pompiers-de-madere-recrute.htm",
      secondSourceLabel:
          "Base Adresse Nationale via Geoplateforme IGN (voie 'Impasse de Benedigues 33140 Villenave-d'Ornon')",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search?index=address&limit=3&q=Impasse%20de%20Benedigues%20Villenave-d'Ornon",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "CIS confirme par l'annuaire SDIS 33 (CIS VILLENAVE D'ORNON, groupement Centre-Ouest : https://www.annuaire-sdis.fr/sdis/gironde/groupements) et OSM way 744204063 (alt_name 'Centre de Madere', operator SDIS 33). Donnees OSM recuperees via l'API Overpass (https://overpass-api.de/api/interpreter) dans cette session. La source municipale officielle ne publie pas de numero de voirie , OSM et des annuaires associatifs indiquent '1 impasse de Benedigues' (point adresse BAN existant : 44.784475 / -0.582342) - numero a confirmer avec le SDIS 33. Coordonnees = emprise OSM du batiment. Tel. publie : 05 56 84 80 90.",
    ),
  ),
  "Arès / Lège-Cap-Ferret": VerifiedLocationRecord(
    currentName: "Arès / Lège-Cap-Ferret",
    displayName: "Arès / Lège-Cap-Ferret",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "40 avenue du Médoc",
      addressLine2:
          "Route départementale D3 - CIS ARÈS/LÈGE (caserne implantée sur la commune de Lège-Cap-Ferret, secteur Arès-Lège)",
      postalCode: "33950",
      city: "Lège-Cap-Ferret",
      country: "France",
      storedFullAddress: "40 avenue du Médoc, 33950 Lège-Cap-Ferret, France",
      latitude: 44.798527,
      longitude: -1.141416,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Ville de Lège-Cap-Ferret - fiche Amicale des sapeurs-pompiers d'Arès-Lège (Centre de Secours, avenue du Médoc, 33950)",
      secondSourceUrl:
          "https://www.ville-lege-capferret.fr/association/amicale-sapeurs-pompiers-dares-lege/",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Le CIS officiel du SDIS 33 s'appelle ARÈS/LÈGE et se situe 40 avenue du Médoc à Lège-Cap-Ferret (et non sur la commune d'Arès). Adresse validée par la BAN (40 Avenue du Médoc 33950 Lège-Cap-Ferret) et par le registre officiel des associations (Amicale des sapeurs-pompiers d'Arès-Lège, CASERNE DE LEGE 40 AVENUE DU MEDOC 33950). À ne pas confondre avec le CIS LE CAP FERRET, distinct, situé 113 avenue de Bordeaux à Lège-Cap-Ferret.",
    ),
  ),
  "Andernos-les-Bains / Lanton": VerifiedLocationRecord(
    currentName: "Andernos-les-Bains / Lanton",
    displayName: "Andernos-les-Bains / Lanton",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "1 avenue de la Source",
      addressLine2: "CIS ANDERNOS",
      postalCode: "33510",
      city: "Andernos-les-Bains",
      country: "France",
      storedFullAddress:
          "1 avenue de la Source, 33510 Andernos-les-Bains, France",
      latitude: 44.740558,
      longitude: -1.090543,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Annuaire officiel des entreprises et associations (recherche-entreprises.api.gouv.fr) - Association de jeunes sapeurs-pompiers section d'Andernos-Lanton, CASERNE DES SAPEURS-POMPIERS ANDERNOS 1 AVENUE DE LA SOURCE 33510",
      secondSourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=pompiers&code_commune=33005",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse du CIS principal (Andernos). Confirmée par la BAN (1 Avenue de la Source 33510 Andernos-les-Bains) et par OpenStreetMap (way 70634893, Centre d'incendie et de secours d'Andernos/Lanton). Le SDIS 33 exploite aussi un CIS LANTON distinct, 25 route de Blagon 33138 Lanton - une seule adresse retenue ici, celle du CIS cité en premier. Le registre des associations mentionne aussi le n°3 avenue de la Source pour l'amicale, même emprise.",
    ),
  ),
  "Arcachon": VerifiedLocationRecord(
    currentName: "Arcachon",
    displayName: "Arcachon",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1:
          "13 rue des Anciens Combattants d'AFN et de l'Union Française",
      addressLine2:
          "CIS ARCACHON - accès également référencé au 34 avenue Nelly Deganne",
      postalCode: "33120",
      city: "Arcachon",
      country: "France",
      storedFullAddress:
          "13 rue des Anciens Combattants d'AFN et de l'Union Française, 33120 Arcachon, France",
      latitude: 44.659026,
      longitude: -1.16084,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Base Adresse Nationale (api-adresse.data.gouv.fr) - 13 Rue a C a Nord Union Francaise 33120 Arcachon",
      secondSourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=13+rue+des+Anciens+Combattants+AFN+Union+Francaise+Arcachon",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Le même site est référencé au 34 avenue Nelly Deganne par le registre officiel des associations (Amicale du centre des sapeurs-pompiers d'Arcachon, CASERNE DES SAPEURS POMPIERS 34 AVENUE NELLY DEGANNE 33120) et par la section SNSPP-PATS 33 : il s'agit de la seconde façade de la même caserne. Adresse retenue : celle publiée par le SDIS 33.",
    ),
  ),
  "Biganos": VerifiedLocationRecord(
    currentName: "Biganos",
    displayName: "Biganos",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "395 rue Joseph-Marie Jacquard",
      addressLine2: "CIS BIGANOS - caserne mise en service en 2023",
      postalCode: "33380",
      city: "Biganos",
      country: "France",
      storedFullAddress: "395 rue Joseph-Marie Jacquard, 33380 Biganos, France",
      latitude: 44.639195,
      longitude: -0.952198,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Annuaire officiel des entreprises et associations (recherche-entreprises.api.gouv.fr) - Amicale des sapeurs pompiers de Biganos, 395 RUE JOSEPH MARIE JACQUARD 33380 BIGANOS",
      secondSourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=amicale+sapeurs+pompiers+Biganos",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse validée par la BAN (395 Rue Joseph Marie Jacquard 33380 Biganos). Le fichier du SDIS 33 orthographie la voie 'Jacquart' - orthographe officielle BAN retenue : 'Jacquard'.",
    ),
  ),
  "Gujan-Mestras / Le Teich": VerifiedLocationRecord(
    currentName: "Gujan-Mestras / Le Teich",
    displayName: "Gujan-Mestras / Le Teich",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "65 avenue de Césarée",
      addressLine2: "Route départementale D650E3 - CIS GUJAN-MESTRAS",
      postalCode: "33470",
      city: "Gujan-Mestras",
      country: "France",
      storedFullAddress: "65 avenue de Césarée, 33470 Gujan-Mestras, France",
      latitude: 44.626027,
      longitude: -1.072437,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Annuaire officiel des entreprises et associations (recherche-entreprises.api.gouv.fr) - Section des jeunes sapeurs pompiers du Sud Bassin, CENTRE DE SECOURS 65 AVENUE DE CESAREE 33470 GUJAN-MESTRAS",
      secondSourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=pompiers&code_commune=33199",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse validée par la BAN (65 Avenue de Césarée 33470 Gujan-Mestras). Le SDIS 33 exploite un CIS LE TEICH distinct, 5 rue Saint-Louis 33470 Le Teich - une seule adresse retenue ici, celle du CIS cité en premier (Gujan-Mestras).",
    ),
  ),
  "La Teste-de-Buch / Pyla-sur-Mer": VerifiedLocationRecord(
    currentName: "La Teste-de-Buch / Pyla-sur-Mer",
    displayName: "La Teste-de-Buch / Pyla-sur-Mer",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "12 rue Augustin Fresnel",
      addressLine2:
          "CIS LA TESTE - nouvelle caserne (zone d'activités, secteur avenue Vulcain), mise en service début 2022",
      postalCode: "33260",
      city: "La Teste-de-Buch",
      country: "France",
      storedFullAddress:
          "12 rue Augustin Fresnel, 33260 La Teste-de-Buch, France",
      latitude: 44.615974,
      longitude: -1.123796,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Base Adresse Nationale (api-adresse.data.gouv.fr) - 12 Rue Augustin Fresnel 33260 La Teste-de-Buch",
      secondSourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=12+rue+Augustin+Fresnel+33260+La+Teste-de-Buch",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Attention : l'ancienne caserne se trouvait 16 rue Jules-Favre (centre-ville), le déménagement a eu lieu début 2022 (Sud Ouest, 24/11/2021 : https://www.sudouest.fr/gironde/la-teste-de-buch/bassin-d-arcachon-la-nouvelle-caserne-des-pompiers-de-la-teste-de-buch-est-presque-terminee-7072987.php). Le registre des associations liste encore l'amicale rue Jules Favre : adresse obsolète, ne pas utiliser. Le SDIS 33 exploite un CIS LE PYLA distinct, 1-3-5-7-9 avenue du Colonel Saldou 33115 La Teste-de-Buch - une seule adresse retenue ici, celle du CIS cité en premier.",
    ),
  ),
  "Marcheprime": VerifiedLocationRecord(
    currentName: "Marcheprime",
    displayName: "Marcheprime",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "1 rue Francis Chevalier",
      addressLine2: "CIS MARCHEPRIME",
      postalCode: "33380",
      city: "Marcheprime",
      country: "France",
      storedFullAddress: "1 rue Francis Chevalier, 33380 Marcheprime, France",
      latitude: 44.689469,
      longitude: -0.857497,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Ville de Marcheprime - communication officielle : 'Centre de Secours de Marcheprime (1 Rue Francis Chevalier)'",
      secondSourceUrl:
          "https://www.facebook.com/ville.marcheprime/posts/-alerte-%C3%A9vacuation-imminente-le-feu-est-%C3%A0-hauteur-de-blagon-et-compte-tenu-de-la/1651303643666498/",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Point de vigilance : la voie 'rue Francis Chevalier' n'est pas encore présente dans la Base Adresse Nationale pour Marcheprime (recherche BAN sans correspondance). OpenStreetMap (way 967092871) et le registre des associations (Sapeurs pompiers de Marcheprime) indiquent 'rue de la Gare', voie contiguë au même site - dénomination probablement antérieure. Adresse retenue : celle publiée par le SDIS 33 et confirmée par la commune.",
    ),
  ),
  "Mios": VerifiedLocationRecord(
    currentName: "Mios",
    displayName: "Mios",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "10 rue du Maréchal Leclerc",
      addressLine2: "CIS MIOS",
      postalCode: "33380",
      city: "Mios",
      country: "France",
      storedFullAddress: "10 rue du Maréchal Leclerc, 33380 Mios, France",
      latitude: 44.601024,
      longitude: -0.932201,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Base Adresse Nationale (api-adresse.data.gouv.fr) - 10 Rue du Maréchal Leclerc 33380 Mios",
      secondSourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=10+rue+du+Mar%C3%A9chal+Leclerc+33380+Mios",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse validée par la BAN (score 0,97) et cohérente avec l'emprise OpenStreetMap du CIS (way 208710318, à environ 90 m du point adresse).",
    ),
  ),
  "Castelnau-de-Médoc": VerifiedLocationRecord(
    currentName: "Castelnau-de-Médoc",
    displayName: "Castelnau-de-Médoc",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "18 rue de la Fontaine",
      addressLine2: "CIS CASTELNAU MÉDOC",
      postalCode: "33480",
      city: "Castelnau-de-Médoc",
      country: "France",
      storedFullAddress:
          "18 rue de la Fontaine, 33480 Castelnau-de-Médoc, France",
      latitude: 45.027783,
      longitude: -0.796398,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Mairie de Castelnau-de-Médoc - annuaire : Amicale des sapeurs pompiers, rue de la Fontaine, 33480 Castelnau-de-Médoc",
      secondSourceUrl: "https://www.mairie-castelnau-medoc.fr/annuaires/",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Numéro 18 confirmé par la BAN (18 Rue de la Fontaine 33480 Castelnau-de-Médoc) , voie confirmée par la mairie et par OpenStreetMap (way 192517856).",
    ),
  ),
  "Carcans / Hourtin": VerifiedLocationRecord(
    currentName: "Carcans / Hourtin",
    displayName: "Carcans / Hourtin",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "2 route de Hourtin",
      addressLine2: "Route départementale D3 - CIS CARCANS",
      postalCode: "33121",
      city: "Carcans",
      country: "France",
      storedFullAddress: "2 route de Hourtin, 33121 Carcans, France",
      latitude: 45.079919,
      longitude: -1.045729,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Annuaire officiel des entreprises et associations (recherche-entreprises.api.gouv.fr) - Amicale des sapeurs-pompiers de Carcans, CASERNE 2 ROUTE D'HOURTIN 33121 CARCANS",
      secondSourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=amicale+sapeurs+pompiers+Carcans",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse validée par la BAN (2 Route d'Hourtin 33121 Carcans, à 19 m de l'emprise OSM). Le groupement territorial Nord-Ouest désigne l'unité 'CIS HOURTIN/CARCANS' , le SDIS 33 publie deux implantations distinctes : Carcans (2 route de Hourtin 33121) et Hourtin (1 rue Alain Cassagne 33990). Adresse retenue : celle du CIS cité en premier dans la liste de l'application (Carcans).",
    ),
  ),
  "Lacanau": VerifiedLocationRecord(
    currentName: "Lacanau",
    displayName: "Lacanau",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "24 avenue du Lac",
      addressLine2:
          "CIS LACANAU - second accès référencé 9 rue Pierre Lavergne",
      postalCode: "33680",
      city: "Lacanau",
      country: "France",
      storedFullAddress: "24 avenue du Lac, 33680 Lacanau, France",
      latitude: 44.978772,
      longitude: -1.082872,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Base Adresse Nationale (api-adresse.data.gouv.fr) - 24 Avenue du Lac 33680 Lacanau",
      secondSourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=24+avenue+du+Lac+33680+Lacanau",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Le SDIS 33 précise deux accès pour la même caserne : 24 avenue du Lac (DK 138) et 9 rue Pierre Lavergne (DK 132), les deux adresses existant en BAN. OpenStreetMap confirme la voie (way 106330729, Avenue du Lac). Le registre des associations mentionne '24 bd du Lac' pour les JSP : la BAN ne connaît que 'Avenue du Lac' à ce numéro.",
    ),
  ),
  "Lesparre-Médoc": VerifiedLocationRecord(
    currentName: "Lesparre-Médoc",
    displayName: "Lesparre-Médoc",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "72-74 rue du Docteur Schweitzer",
      addressLine2:
          "CIS LESPARRE-MÉDOC - site également occupé par l'état-major du Groupement Territorial Nord-Ouest",
      postalCode: "33340",
      city: "Lesparre-Médoc",
      country: "France",
      storedFullAddress:
          "72-74 rue du Docteur Schweitzer, 33340 Lesparre-Médoc, France",
      latitude: 45.310413,
      longitude: -0.922122,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Annuaire SDIS - SDIS Gironde (33) unités territoriales : GROUPEMENT TERRITORIAL NORD-OUEST, 72 rue du docteur Schweitzer, 33340 LESPARRE",
      secondSourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse validée par la BAN (72 Rue du Docteur Schweitzer 33340 Lesparre-Médoc, à 43 m de l'emprise OSM way 925703829). Le SDIS 33 publie '72/74 rue du Docteur Schweitzer'.",
    ),
  ),
  "Pauillac": VerifiedLocationRecord(
    currentName: "Pauillac",
    displayName: "Pauillac",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "31 avenue du Maréchal Leclerc",
      addressLine2: "Route départementale D206E1 - CIS PAUILLAC",
      postalCode: "33250",
      city: "Pauillac",
      country: "France",
      storedFullAddress:
          "31 avenue du Maréchal Leclerc, 33250 Pauillac, France",
      latitude: 45.197832,
      longitude: -0.757017,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Annuaire officiel des entreprises et associations (recherche-entreprises.api.gouv.fr) - Association des jeunes sapeurs pompiers du Centre Médoc, CENTRE DE SECOURS DE PAUILLAC 31 RUE DU GEN LECLERC 33250 PAUILLAC",
      secondSourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=pompiers&code_commune=33314",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "DOUBLON DÉTECTÉ dans la liste source de l'application : Pauillac apparaît aussi dans le groupe Haute Gironde - un seul CIS Pauillac existe réellement, rattaché au groupe Médoc/Groupement Nord-Ouest , l'entrée Haute Gironde est probablement une erreur de saisie à corriger dans l'app. Rattachement au Groupement Territorial Nord-Ouest (état-major à Lesparre) confirmé par l'Annuaire SDIS (https://www.annuaire-sdis.fr/sdis/gironde/groupements). Variante d'odonyme : la mairie de Pauillac et le registre des associations écrivent '31 rue du Général Leclerc' , la BAN et le SDIS 33 retiennent '31 Avenue du Maréchal Leclerc' (même bâtiment, coordonnées identiques). Source communale : https://www.pauillac-medoc.com/fr/pauillac-ma-ville/commerces-zone-dactivites/secours/",
    ),
  ),
  "Soulac-sur-Mer / Le Verdon": VerifiedLocationRecord(
    currentName: "Soulac-sur-Mer / Le Verdon",
    displayName: "Soulac-sur-Mer / Le Verdon",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "1-3 rue Olivier Guinet",
      addressLine2: "CIS SOULAC",
      postalCode: "33780",
      city: "Soulac-sur-Mer",
      country: "France",
      storedFullAddress: "1-3 rue Olivier Guinet, 33780 Soulac-sur-Mer, France",
      latitude: 45.507973,
      longitude: -1.121367,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Annuaire officiel des entreprises et associations (recherche-entreprises.api.gouv.fr) - Section des jeunes sapeurs-pompiers de la Pointe du Médoc, CENTRE DE SECOURS 1 RUE OLIVIER GUINET 33780 SOULAC-SUR-MER",
      secondSourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=pompiers&code_commune=33514",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresses 1 et 3 rue Olivier Guinet validées en BAN , emprise confirmée par OpenStreetMap (way 192406592, Centre d'incendie et de secours de Soulac/Le Verdon). Le SDIS 33 exploite un CIS LE VERDON distinct, 70 cours de la République 33123 Le Verdon-sur-Mer - une seule adresse retenue ici, celle du CIS cité en premier (Soulac).",
    ),
  ),
  "Vendays-Montalivet": VerifiedLocationRecord(
    currentName: "Vendays-Montalivet",
    displayName: "Vendays-Montalivet",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "3 passage des Pompiers",
      addressLine2: "CIS VENDAYS MONTALIVET",
      postalCode: "33930",
      city: "Vendays-Montalivet",
      country: "France",
      storedFullAddress:
          "3 passage des Pompiers, 33930 Vendays-Montalivet, France",
      latitude: 45.354594,
      longitude: -1.059399,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - donnees officielles de la carte des CIS (cartes.pompiers33.fr)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Annuaire officiel des entreprises et associations (recherche-entreprises.api.gouv.fr) - Amicale sapeurs pompiers Vendays Montalivet, CASERNE DES POMPIERS 3 PAS POMPIERS 33930 VENDAYS-MONTALIVET",
      secondSourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=amicale+sapeurs+pompiers+Vendays",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse validée par la BAN (3 Passage des Pompiers 33930 Vendays-Montalivet, à 14 m de l'emprise OSM way 258524163).",
    ),
  ),
  "Belin-Béliet": VerifiedLocationRecord(
    currentName: "Belin-Béliet",
    displayName: "Belin-Béliet",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "8 place de l'Église",
      addressLine2: "Caserne des pompiers (CIS Belin-Béliet)",
      postalCode: "33830",
      city: "Belin-Béliet",
      country: "France",
      storedFullAddress: "8 place de l'Église, 33830 Belin-Béliet, France",
      latitude: 44.49363,
      longitude: -0.79066,
      status: AddressStatus.verifiedCrossSource,
      sourceLabel:
          "Annuaire des Entreprises / API recherche-entreprises (données SIRENE-RNA) - AMICALE DES SAPEURS-POMPIERS DU CENTRE DE SECOURS DE BELIN, siège \"CASERNE DES POMPIERS 8 PLACE DE L'EGLISE 33830 BELIN-BELIET\"",
      sourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=amicale%20sapeurs%20pompiers%20Belin-Beliet&departement=33",
      secondSourceLabel:
          "Base Adresse Nationale (géocodage IGN/BAN) - 8 Place de l'Eglise 33830 Belin-Béliet",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search/?q=8%20place%20de%20l%20Eglise%2033830%20Belin-Beliet",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Recoupement OSM way 968595774 \"Centre d'incendie et de secours de Belin-Beliet\" (operator SDIS 33), centroïde à 33 m du point BAN. Groupement officiel SDIS 33 = GT Sud-Ouest (le libellé \"Sud Gironde\" est un regroupement propre à InterfaceRecup33).",
    ),
  ),
  "Cestas": VerifiedLocationRecord(
    currentName: "Cestas",
    displayName: "Cestas",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "2 chemin de la Croix d'Hins",
      addressLine2: "Centre d'incendie et de secours de Cestas",
      postalCode: "33610",
      city: "Cestas",
      country: "France",
      storedFullAddress: "2 chemin de la Croix d'Hins, 33610 Cestas, France",
      latitude: 44.74337,
      longitude: -0.68797,
      status: AddressStatus.verifiedCrossSource,
      sourceLabel:
          "Annuaire des Entreprises / API recherche-entreprises (SIRENE-RNA) - AMICALE DES SAPEURS POMPIERS DU CENTRE DE SECOURS DE CESTAS, siège \"CENTRE DE SECOURS 2 CHEMIN DE LA CROIX D'HINS 33610 CESTAS\"",
      sourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=amicale%20sapeurs%20pompiers%20Cestas&departement=33",
      secondSourceLabel:
          "Base Adresse Nationale - 2 Chemin de la Croix d'Hins 33610 Cestas",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search/?q=2%20chemin%20de%20la%20Croix%20d%27Hins%2033610%20Cestas",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Recoupement OSM way 179274982 (operator SDIS 33), centroïde à 19 m de l'adresse BAN. Groupement officiel SDIS 33 = GT Centre-Ouest.",
    ),
  ),
  "Créon": VerifiedLocationRecord(
    currentName: "Créon",
    displayName: "Créon",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "5 allée Georges Brassens",
      addressLine2: "Centre de secours de Créon",
      postalCode: "33670",
      city: "Créon",
      country: "France",
      storedFullAddress: "5 allée Georges Brassens, 33670 Créon, France",
      latitude: 44.77111,
      longitude: -0.34829,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "Mairie de Créon - guide municipal \"Créon bouge 2023-2024\" (rubrique Pompiers : 5, allée Georges Brassens - 33670 Créon, tél 05 57 34 50 50)",
      sourceUrl:
          "https://files.appli-intramuros.com/website/uploads/5800/publications/creonbouge_2023-2024.pdf",
      secondSourceLabel:
          "Base Adresse Nationale - 5 Allée Georges Brassens 33670 Créon (44.771269, -0.347760)",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search/?q=5%20allee%20Georges%20Brassens%20Creon",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Le registre associatif (SIRENE-RNA) mentionne l'adresse historique \"CENTRE DE SECOURS 5 CITE MILLAS 33670 CREON\" pour l'AMICALE DES SAPEURS POMPIERS DE CREON : même site, ancienne dénomination (lotissement/cité Millas). Recoupement OSM way 808788184 (check_date 2026-01-05), à 44 m du point BAN. Groupement officiel SDIS 33 = GT Centre-Est.",
    ),
  ),
  "La Brède": VerifiedLocationRecord(
    currentName: "La Brède",
    displayName: "La Brède",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "18 chemin du Stade",
      addressLine2: "Centre d'incendie et de secours de La Brède",
      postalCode: "33650",
      city: "La Brède",
      country: "France",
      storedFullAddress: "18 chemin du Stade, 33650 La Brède, France",
      latitude: 44.68841,
      longitude: -0.51053,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "Mairie de La Brède-Montesquieu - page \"Jeunes sapeurs pompiers\" (18 chemin du stade - 33650 LA BREDE)",
      sourceUrl:
          "https://www.labrede-montesquieu.fr/associations/jeunes-sapeurs-pompiers/",
      secondSourceLabel:
          "Base Adresse Nationale - 18 Chemin du Stade 33650 La Brède (44.688256, -0.510276)",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search/?q=18%20chemin%20du%20Stade%2033650%20La%20Brede",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Recoupement OSM way 967066304 (operator SDIS 33), centroïde à 26 m du point BAN. Attention, il existe aussi un \"Chemin des Pompiers\" à La Brède situé à ~1,9 km de la caserne : ne pas confondre. Groupement officiel SDIS 33 = GT Sud-Est.",
    ),
  ),
  "Langon": VerifiedLocationRecord(
    currentName: "Langon",
    displayName: "Langon",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "30 boulevard Jean Moulin",
      addressLine2:
          "Centre d'incendie et de secours Langon - Saint-Macaire (site de Langon)",
      postalCode: "33210",
      city: "Langon",
      country: "France",
      storedFullAddress: "30 boulevard Jean Moulin, 33210 Langon, France",
      latitude: 44.54613,
      longitude: -0.25358,
      status: AddressStatus.verifiedCrossSource,
      sourceLabel:
          "Annuaire des Entreprises / API recherche-entreprises (SIRENE-RNA) - ASSOCIATION DES JEUNES SAPEURS POMPIERS DE LANGON - SAINT-MACAIRE, siège \"30 BOULEVARD JEAN MOULIN 33210 LANGON\" (également AMICALE DES SAPEURS POMPIERS DU SECTEUR DE LANGON, boulevard Jean Moulin)",
      sourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=sapeurs%20pompiers%20Langon&departement=33",
      secondSourceLabel:
          "Base Adresse Nationale - 30 Boulevard Jean Moulin 33210 Langon (44.546435, -0.253451)",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search/?q=30%20boulevard%20Jean%20Moulin%2033210%20Langon",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "CIS officiellement libellé \"CIS LANGON - ST MACAIRE\" dans l'annuaire des unités territoriales du SDIS 33 : un même CIS avec deux implantations, Langon (30 bd Jean Moulin) et Saint-Macaire (secteur rue François Bergoeing, OSM way 967100658, adresse exacte non confirmée). Locaux de Langon signalés vétustes avec projet de nouvelle caserne (actu.fr, janvier 2025) : vérifier avant impression de documents. Recoupement OSM way 830858092 (addr:full \"30 boulevard Jean Moulin 33210 Langon\").",
    ),
  ),
  "Le Barp": VerifiedLocationRecord(
    currentName: "Le Barp",
    displayName: "Le Barp",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "9 chemin de la Scierie",
      addressLine2: "Centre d'incendie et de secours du Barp",
      postalCode: "33114",
      city: "Le Barp",
      country: "France",
      storedFullAddress: "9 chemin de la Scierie, 33114 Le Barp, France",
      latitude: 44.59504,
      longitude: -0.75796,
      status: AddressStatus.needsConfirmation,
      sourceLabel:
          "OpenStreetMap - way 192793530 \"Centre d'incendie et de secours du Barp\", operator SDIS 33, addr:street \"Chemin de la Scierie\"",
      sourceUrl: "https://www.openstreetmap.org/way/192793530",
      secondSourceLabel:
          "Base Adresse Nationale - géocodage inverse du bâtiment : 9 Chemin de la Scierie 33114 Le Barp à 32 m",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search/?q=9%20chemin%20de%20la%20Scierie%2033114%20Le%20Barp",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "La voie (chemin de la Scierie) est confirmée par OSM et la BAN, mais le numéro 9 provient du géocodage inverse BAN et n'est corroboré par aucune source institutionnelle (aucune fiche mairie du Barp ni association enregistrée trouvée). À faire confirmer par la mairie du Barp ou le SDIS 33. Groupement officiel SDIS 33 = GT Sud-Ouest.",
    ),
  ),
  "Podensac": VerifiedLocationRecord(
    currentName: "Podensac",
    displayName: "Podensac",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Podensac",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.notFound,
      sourceLabel:
          "Annuaire SDIS - liste officielle des unités territoriales / CIS du SDIS 33 (aucun CIS Podensac : GT Sud-Est comprend Barsac, Cadillac-Béguey, La Brède, Langon-St Macaire, etc.)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "Commune de Podensac - page \"Devenir jeune sapeur-pompier\" : la section couvrant Podensac est basée \"Caserne des sapeurs-pompiers 19 ZA Boisson, 33410 Béguey\"",
      secondSourceUrl:
          "https://www.podensac.fr/actualites/citoyennete/devenir-jeune-sapeur-pompier/",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Aucune caserne SDIS 33 à Podensac : la commune n'apparaît pas dans la liste officielle des CIS et aucun équipement amenity=fire_station n'existe sur la commune dans OSM (requête Overpass sur le Sud-Gironde). Podensac est couverte par le CIS Cadillac-Béguey (19 chemin de Boisson, 33410 Béguey) et par le CIS Barsac (33720 Barsac). Entrée à supprimer ou à requalifier en secteur d'intervention.",
    ),
  ),
  "Saint-Symphorien": VerifiedLocationRecord(
    currentName: "Saint-Symphorien",
    displayName: "Saint-Symphorien",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "Chemin de la Passerelle",
      addressLine2:
          "Centre d'incendie et de secours de Saint-Symphorien (numéro de voirie non confirmé)",
      postalCode: "33113",
      city: "Saint-Symphorien",
      country: "France",
      storedFullAddress:
          "Chemin de la Passerelle, 33113 Saint-Symphorien, France",
      latitude: 44.42682,
      longitude: -0.48934,
      status: AddressStatus.needsConfirmation,
      sourceLabel:
          "OpenStreetMap - way 830853503 \"Centre d'incendie et de secours de Saint-Symphorien\", official_name \"ST SYMPHORIEN\", operator SDIS 33",
      sourceUrl: "https://www.openstreetmap.org/way/830853503",
      secondSourceLabel:
          "Base Adresse Nationale - géocodage inverse du bâtiment : Chemin de la Passerelle 33113 Saint-Symphorien à 19 m (n° 2 le plus proche)",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search/?q=chemin%20de%20la%20Passerelle%2033113%20Saint-Symphorien",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "La voie est confirmée (BAN + OSM) mais le numéro exact reste inconnu. Le registre associatif donne \"AMICALE DES SAPEURS POMPIERS DE ST SYMPHORIEN, 1 PL DE L EGLISE 33113 ST-SYMPHORIEN\", adresse située à ~150 m de la caserne (probable adresse historique de l'association et non de la caserne) : ne pas l'utiliser sans confirmation. Groupement officiel SDIS 33 = GT Sud-Est.",
    ),
  ),
  "Salles": VerifiedLocationRecord(
    currentName: "Salles",
    displayName: "Salles",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "9 route du Martinet",
      addressLine2: "Centre d'incendie et de secours de Salles",
      postalCode: "33770",
      city: "Salles",
      country: "France",
      storedFullAddress: "9 route du Martinet, 33770 Salles, France",
      latitude: 44.54897,
      longitude: -0.87996,
      status: AddressStatus.verifiedCrossSource,
      sourceLabel:
          "Annuaire des Entreprises / API recherche-entreprises (SIRENE-RNA) - AMICALE SOCIALE, SPORTIVE ET CULTURELLE DES SAPEURS POMPIERS DU CENTRE DE SECOURS DE SALLES, siège \"9 ROUTE DU MARTINET 33770 SALLES\"",
      sourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=sapeurs%20pompiers%20Salles&departement=33",
      secondSourceLabel:
          "Base Adresse Nationale - 9 Route du Martinet 33770 Salles (44.548365, -0.880326)",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search/?q=9%20route%20du%20Martinet%2033770%20Salles",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Recoupement OSM way 148694537 (operator SDIS 33) : centroïde du bâtiment à 73 m du point BAN, cohérent avec une parcelle de caserne. La Ville de Salles confirme que l'amicale a son siège \"au centre de secours de Salles\" sans donner l'adresse (guide pratique 2024). Groupement officiel SDIS 33 = GT Sud-Ouest.",
    ),
  ),
  "Bazas": VerifiedLocationRecord(
    currentName: "Bazas",
    displayName: "Bazas",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "2 avenue du Général Leclerc",
      addressLine2:
          "Centre d'incendie et de secours de Bazas (site actuel, déménagement annoncé)",
      postalCode: "33430",
      city: "Bazas",
      country: "France",
      storedFullAddress: "2 avenue du Général Leclerc, 33430 Bazas, France",
      latitude: 44.43490,
      longitude: -0.21955,
      status: AddressStatus.needsConfirmation,
      sourceLabel:
          "OpenStreetMap - way 830863992 \"Centre d'incendie et de secours de Bazas\", official_name \"BAZAS\", operator SDIS 33 (recoupé par géocodage inverse BAN : 2 Avenue du General Leclerc à 16 m)",
      sourceUrl: "https://www.openstreetmap.org/way/830863992",
      secondSourceLabel:
          "actu.fr (09/05/2024) - \"l'actuel centre d'incendie et de secours de Bazas, situé au carrefour de l'avenue du général Leclerc et du cours du général De Gaulle\" + nouvelle caserne avenue de Verdun, livraison prévue en 2026",
      secondSourceUrl:
          "https://actu.fr/nouvelle-aquitaine/bazas_33036/a-bazas-la-nouvelle-caserne-des-sapeurs-pompiers-va-devenir-bientot-realite_61042917.html",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Statut à confirmer : une nouvelle caserne est en construction avenue de Verdun (travaux démarrés en septembre 2024 selon Sud Ouest, https://www.sudouest.fr/gironde/bazas/bazas-les-travaux-de-la-nouvelle-caserne-de-pompiers-ont-debute-21377297.php, livraison annoncée courant 2026) et aucune source consultée ne confirme si le déménagement est effectif au 29/07/2026. La voie \"Avenue de Verdun 33430 Bazas\" existe en BAN mais sans numéro attribué à la caserne. Le registre associatif donne pour l'ASSOCIATION DES JSP BAZAS \"CASERNE DES SAPEURS POMPIERS RTE DE LANGON 33430 BAZAS\", libellé non reconnu par la BAN : non retenu. Groupement officiel SDIS 33 = GT Sud-Est.",
    ),
  ),
  "Cadillac": VerifiedLocationRecord(
    currentName: "Cadillac",
    displayName: "Cadillac",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "19 chemin de Boisson",
      addressLine2:
          "Centre d'incendie et de secours Cadillac-Béguey (ZA Boisson) - commune d'implantation Béguey",
      postalCode: "33410",
      city: "Béguey",
      country: "France",
      storedFullAddress: "19 chemin de Boisson, 33410 Béguey, France",
      latitude: 44.65302,
      longitude: -0.33363,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "Commune de Podensac - \"Devenir jeune sapeur-pompier\" : \"Section du Mascaret, Caserne des sapeurs-pompiers 19 ZA Boisson, 33410 Béguey\"",
      sourceUrl:
          "https://www.podensac.fr/actualites/citoyennete/devenir-jeune-sapeur-pompier/",
      secondSourceLabel:
          "Annuaire des Entreprises / API recherche-entreprises (SIRENE-RNA) - AMICALE DES SAPEURS POMPIERS CENTRE DE SECOURS CADILLAC BEGUEY, siège \"CENTRE DE SECOURS CADILLAC BEGUEY 19 BOISSON 33410 BEGUEY\" + BAN 19 Chemin de Boisson 33410 Béguey (44.653128, -0.334339)",
      secondSourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=amicale%20sapeurs%20pompiers%20Cadillac&departement=33",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Incohérence de libellé à signaler : le CIS s'appelle officiellement \"CIS CADILLAC BEGUEY\" (annuaire des unités territoriales SDIS 33) mais il est physiquement implanté sur la commune de Béguey (33410), pas sur Cadillac-sur-Garonne. Ne pas écrire \"33410 Cadillac\". Recoupement OSM way 968595759, centroïde à 57 m du point BAN. Groupement officiel SDIS 33 = GT Sud-Est.",
    ),
  ),
  "La Réole": VerifiedLocationRecord(
    currentName: "La Réole",
    displayName: "La Réole",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "4 avenue du Mahon",
      addressLine2: "Centre d'incendie et de secours de La Réole",
      postalCode: "33190",
      city: "La Réole",
      country: "France",
      storedFullAddress: "4 avenue du Mahon, 33190 La Réole, France",
      latitude: 44.58210,
      longitude: -0.03219,
      status: AddressStatus.verifiedCrossSource,
      sourceLabel:
          "Annuaire des Entreprises / API recherche-entreprises (SIRENE-RNA) - SECTION DE JSP (JEUNES SAPEURS POMPIERS) DE LA REOLE, siège \"4 AVENUE DU MAHON 33190 LA REOLE\"",
      sourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=sapeurs%20pompiers%20La%20Reole&departement=33",
      secondSourceLabel:
          "Base Adresse Nationale - 4 Avenue du Mahon 33190 La Réole (44.582113, -0.032233), à 4 m du bâtiment OSM",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search/?q=4%20avenue%20du%20Mahon%2033190%20La%20Reole",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Recoupement OSM way 968595761 (operator SDIS 33). Ne pas confondre avec la brigade de gendarmerie, 1 bis avenue de Mahon. Groupement officiel SDIS 33 = GT Sud-Est.",
    ),
  ),
  "Sauveterre-de-Guyenne": VerifiedLocationRecord(
    currentName: "Sauveterre-de-Guyenne",
    displayName: "Sauveterre-de-Guyenne",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "50 boulevard du 11 Novembre 1918",
      addressLine2:
          "Centre d'incendie et de secours Sauveterre-de-Guyenne / Targon (site de Sauveterre)",
      postalCode: "33540",
      city: "Sauveterre-de-Guyenne",
      country: "France",
      storedFullAddress:
          "50 boulevard du 11 Novembre 1918, 33540 Sauveterre-de-Guyenne, France",
      latitude: 44.69095,
      longitude: -0.08945,
      status: AddressStatus.verifiedCrossSource,
      sourceLabel:
          "Annuaire des Entreprises / API recherche-entreprises (SIRENE-RNA) - AMICALE DES SAPEURS POMPIERS DU CENTRE DE SECOURS DE SAUVETERRE-DE-GUYENNE, siège \"CENTRE D'INCENDIE DE SECOURS 50 BOULEVARD DU 11 NOVEMBRE 1918 33540 SAUVETERRE-DE-GUYENNE\"",
      sourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=amicale%20sapeurs%20pompiers%20Sauveterre%20de%20Guyenne&departement=33",
      secondSourceLabel:
          "Base Adresse Nationale - 50 Boulevard du 11 novembre 1918 33540 Sauveterre-de-Guyenne (44.691122, -0.088799)",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search/?q=50%20boulevard%20du%2011%20novembre%201918%2033540%20Sauveterre-de-Guyenne",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "CIS officiellement libellé \"CIS SAUVETERRE DE GUYENNE / TARGON\" (annuaire des unités territoriales SDIS 33) : un seul CIS pour deux implantations distinctes, Sauveterre-de-Guyenne et Targon (voir ligne Targon). Recoupement OSM way 968595767 (operator SDIS 33), centroïde à 70 m du point BAN. Groupement officiel SDIS 33 = GT Sud-Est.",
    ),
  ),
  "Targon": VerifiedLocationRecord(
    currentName: "Targon",
    displayName: "Targon",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "14 allée d'Amour",
      addressLine2:
          "Centre d'incendie et de secours Sauveterre-de-Guyenne / Targon (site de Targon)",
      postalCode: "33760",
      city: "Targon",
      country: "France",
      storedFullAddress: "14 allée d'Amour, 33760 Targon, France",
      latitude: 44.73509,
      longitude: -0.26200,
      status: AddressStatus.verifiedCrossSource,
      sourceLabel:
          "Annuaire des Entreprises / API recherche-entreprises (SIRENE-RNA) - ASSOCIATION DES JEUNES SAPEURS POMPIERS DE TARGON, siège \"CENTRE DE SECOURS DE TARGON 14 ALLEE D'AMOUR 33760 TARGON\"",
      sourceUrl:
          "https://recherche-entreprises.api.gouv.fr/search?q=sapeurs%20pompiers%20Targon&departement=33",
      secondSourceLabel:
          "Base Adresse Nationale - 14 Allée d'Amour 33760 Targon (44.734616, -0.261821), à ~30 m du bâtiment OSM",
      secondSourceUrl:
          "https://data.geopf.fr/geocodage/search/?q=14%20allee%20d%27Amour%2033760%20Targon",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Incohérence à signaler : Targon est bien une caserne physique distincte (OSM way 968595762, operator SDIS 33, à 14 km de Sauveterre) mais elle n'est pas un CIS autonome dans l'annuaire officiel : elle fait partie du \"CIS SAUVETERRE DE GUYENNE / TARGON\". Existence de la caserne confirmée aussi par Sud Ouest (journée portes ouvertes du 21 juin 2025 à la caserne de Targon, https://www.sudouest.fr/lieux/gironde/targon/targon-une-journee-portes-ouvertes-a-la-caserne-des-pompiers-24846325.php). Groupement officiel SDIS 33 = GT Sud-Est.",
    ),
  ),
  "Branne": VerifiedLocationRecord(
    currentName: "Branne",
    displayName: "Branne",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "13 rue Fort Bayard",
      addressLine2: null,
      postalCode: "33420",
      city: "Branne",
      country: "France",
      storedFullAddress: "13 rue Fort Bayard, 33420 Branne, France",
      latitude: 44.828247,
      longitude: -0.185356,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - carte officielle des groupements territoriaux et CIS (couche CIS)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Base Adresse Nationale (BAN) - 13 Rue du Fort Bayard 33420 Branne",
      secondSourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=13+rue+Fort+Bayard+33420+Branne",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse issue de la couche CIS officielle du SDIS 33 (CIS BRANNE). Recoupee par la BAN (13 Rue du Fort Bayard) et par OpenStreetMap (CIS de Branne, way 967073694, 44.82823/-0.18534). Le libelle BAN officiel est 'rue du Fort Bayard'.",
    ),
  ),
  "Castillon-la-Bataille": VerifiedLocationRecord(
    currentName: "Castillon-la-Bataille",
    displayName: "Castillon-la-Bataille",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "7 chemin des Vignes",
      addressLine2: null,
      postalCode: "33350",
      city: "Saint-Magne-de-Castillon",
      country: "France",
      storedFullAddress:
          "7 chemin des Vignes, 33350 Saint-Magne-de-Castillon, France",
      latitude: 44.851324,
      longitude: -0.063153,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - carte officielle des groupements territoriaux et CIS (couche CIS)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Base Adresse Nationale (BAN) - 7 Chemin des Vignes 33350 Saint-Magne-de-Castillon",
      secondSourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=7+chemin+des+Vignes+Saint-Magne-de-Castillon",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "ATTENTION commune reelle differente du nom de l'entree: le CIS est nomme 'CASTILLON/SAINT-MAGNE' dans la couche CIS officielle du SDIS 33 et il est physiquement implante sur la commune de Saint-Magne-de-Castillon (33350), et non a Castillon-la-Bataille. Recoupe par la BAN et par OpenStreetMap (CIS de Castillon-la-Bataille, way 890842111, chemin des Vignes, 44.85129/-0.06330).",
    ),
  ),
  "Coutras": VerifiedLocationRecord(
    currentName: "Coutras",
    displayName: "Coutras",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "19 rue du Général Soulé",
      addressLine2: null,
      postalCode: "33230",
      city: "Coutras",
      country: "France",
      storedFullAddress: "19 rue du Général Soulé, 33230 Coutras, France",
      latitude: 45.044549,
      longitude: -0.123189,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - carte officielle des groupements territoriaux et CIS (couche CIS)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Base Adresse Nationale (BAN) - 19 Rue du General Soule 33230 Coutras",
      secondSourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=19+rue+du+General+Soule+Coutras",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse issue de la couche CIS officielle du SDIS 33 (CIS COUTRAS). Le centre est commande conjointement avec Lapouyade ('CIS COUTRAS / LAPOUYADE' dans l'Annuaire SDIS) mais dispose de son propre site a Coutras. Recoupee par la BAN, par OpenStreetMap (way 967065481, rue du General Soule) et par le registre officiel SIRENE/Annuaire des Entreprises (AMICALE DES SAPEURS POMPIERS DE COUTRAS, CENTRE DE SECOURS 19 RUE DU GENERAL SOULE 33230 COUTRAS).",
    ),
  ),
  "Libourne": VerifiedLocationRecord(
    currentName: "Libourne",
    displayName: "Libourne",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "26 rue du Général de Monsabert",
      addressLine2: "Acces secondaire: 11 rue de la Lamberte",
      postalCode: "33500",
      city: "Libourne",
      country: "France",
      storedFullAddress:
          "26 rue du Général de Monsabert, 33500 Libourne, France",
      latitude: 44.914606,
      longitude: -0.223062,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - carte officielle des groupements territoriaux et CIS (couche CIS)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Base Adresse Nationale (BAN) - 26 Rue du General de Monsabert 33500 Libourne",
      secondSourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=26+rue+du+General+de+Monsabert+Libourne",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "CONFIRME: le CIS Libourne partage bien l'adresse du siege du Groupement territorial Nord-Est (26 avenue/rue du General Monsabert, 33500 Libourne) donnee par l'Annuaire SDIS. La couche CIS officielle du SDIS 33 indique '26 RUE DU GENERAL DE MONSABERT (11 RUE DE LA LAMBERTE), LIBOURNE'. Le libelle officiel BAN est 'rue du General de Monsabert' (et non 'avenue'). Recoupe aussi par le registre SIRENE (AMICALE DES SAPEURS POMPIERS DE LIBOURNE, 26 RUE DU GENERAL DE MONSABERT 33500 LIBOURNE) et par OpenStreetMap (way 967073691).",
    ),
  ),
  "Pujols": VerifiedLocationRecord(
    currentName: "Pujols",
    displayName: "Pujols",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Pujols",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.notFound,
      sourceLabel:
          "Annuaire SDIS - SDIS Gironde (33) Unites territoriales (Groupement territorial Nord-Est)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "SDIS 33 - page officielle Les groupements territoriaux et centres d'incendie et de secours",
      secondSourceUrl:
          "https://www.pompiers33.fr/nous-connaitre/nos-moyens/sites/les-groupements-territoriaux-et-centres-dincendie-et-de-secours/",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Aucun centre d'incendie et de secours du SDIS 33 n'existe a cette adresse/commune dans les sources officielles verifiees: la couche CIS de la carte officielle du SDIS 33 (74 CIS) ne contient pas ce centre, et la liste des CIS du Groupement territorial Nord-Est de l'Annuaire SDIS ne le mentionne pas non plus. Entree probablement obsolete (ancien CPI communal dissous) ou erronee dans mock_data.dart. Aucun CIS a Pujols (33350) dans la liste officielle des 74 CIS du SDIS 33, ni dans OpenStreetMap. Le secteur est couvert par le CIS Castillon/Saint-Magne (7 chemin des Vignes, 33350 Saint-Magne-de-Castillon). A supprimer ou a faire confirmer par le SDIS 33.",
    ),
  ),
  "Sainte-Foy-la-Grande": VerifiedLocationRecord(
    currentName: "Sainte-Foy-la-Grande",
    displayName: "Sainte-Foy-la-Grande",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "9 boulevard Gratiolet",
      addressLine2: null,
      postalCode: "33220",
      city: "Sainte-Foy-la-Grande",
      country: "France",
      storedFullAddress:
          "9 boulevard Gratiolet, 33220 Sainte-Foy-la-Grande, France",
      latitude: 44.840310,
      longitude: 0.213881,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - carte officielle des groupements territoriaux et CIS (couche CIS)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Base Adresse Nationale (BAN) - 9 Boulevard Gratiolet 33220 Sainte-Foy-la-Grande",
      secondSourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=9+boulevard+Gratiolet+Sainte-Foy-la-Grande",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse issue de la couche CIS officielle du SDIS 33 (CIS SAINTE-FOY). Recoupee par la BAN, par le geocodage inverse BAN du batiment OSM (9 Boulevard Gratiolet, 14 m) et par le registre SIRENE (AMICALE DES SAPEURS POMPIERS, CENTRE DE SECOURS BOULEVARD GRATIOLET 33220 SAINTE-FOY-LA-GRANDE).",
    ),
  ),
  "Saint-Denis-de-Pile": VerifiedLocationRecord(
    currentName: "Saint-Denis-de-Pile",
    displayName: "Saint-Denis-de-Pile",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Saint-Denis-de-Pile",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.notFound,
      sourceLabel:
          "Annuaire SDIS - SDIS Gironde (33) Unites territoriales (Groupement territorial Nord-Est)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "SDIS 33 - page officielle Les groupements territoriaux et centres d'incendie et de secours",
      secondSourceUrl:
          "https://www.pompiers33.fr/nous-connaitre/nos-moyens/sites/les-groupements-territoriaux-et-centres-dincendie-et-de-secours/",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Aucun centre d'incendie et de secours du SDIS 33 n'existe a cette adresse/commune dans les sources officielles verifiees: la couche CIS de la carte officielle du SDIS 33 (74 CIS) ne contient pas ce centre, et la liste des CIS du Groupement territorial Nord-Est de l'Annuaire SDIS ne le mentionne pas non plus. Entree probablement obsolete (ancien CPI communal dissous) ou erronee dans mock_data.dart. Aucun CIS a Saint-Denis-de-Pile (33910) dans la liste officielle des 74 CIS du SDIS 33, ni dans OpenStreetMap, ni dans le registre SIRENE. Secteur couvert par les CIS Libourne et Coutras. A supprimer ou a faire confirmer par le SDIS 33.",
    ),
  ),
  "Saint-Émilion": VerifiedLocationRecord(
    currentName: "Saint-Émilion",
    displayName: "Saint-Émilion",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Saint-Émilion",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.notFound,
      sourceLabel:
          "Annuaire SDIS - SDIS Gironde (33) Unites territoriales (Groupement territorial Nord-Est)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "SDIS 33 - page officielle Les groupements territoriaux et centres d'incendie et de secours",
      secondSourceUrl:
          "https://www.pompiers33.fr/nous-connaitre/nos-moyens/sites/les-groupements-territoriaux-et-centres-dincendie-et-de-secours/",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Aucun centre d'incendie et de secours du SDIS 33 n'existe a cette adresse/commune dans les sources officielles verifiees: la couche CIS de la carte officielle du SDIS 33 (74 CIS) ne contient pas ce centre, et la liste des CIS du Groupement territorial Nord-Est de l'Annuaire SDIS ne le mentionne pas non plus. Entree probablement obsolete (ancien CPI communal dissous) ou erronee dans mock_data.dart. Aucun CIS a Saint-Emilion (33330) dans la liste officielle des 74 CIS du SDIS 33, ni dans OpenStreetMap, ni dans le registre SIRENE. Secteur couvert par les CIS Libourne et Castillon/Saint-Magne. A supprimer ou a faire confirmer par le SDIS 33.",
    ),
  ),
  "Saint-Seurin-sur-l'Isle": VerifiedLocationRecord(
    currentName: "Saint-Seurin-sur-l'Isle",
    displayName: "Saint-Seurin-sur-l'Isle",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Saint-Seurin-sur-l'Isle",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.notFound,
      sourceLabel:
          "Annuaire SDIS - SDIS Gironde (33) Unites territoriales (Groupement territorial Nord-Est)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "SDIS 33 - page officielle Les groupements territoriaux et centres d'incendie et de secours",
      secondSourceUrl:
          "https://www.pompiers33.fr/nous-connaitre/nos-moyens/sites/les-groupements-territoriaux-et-centres-dincendie-et-de-secours/",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Aucun centre d'incendie et de secours du SDIS 33 n'existe a cette adresse/commune dans les sources officielles verifiees: la couche CIS de la carte officielle du SDIS 33 (74 CIS) ne contient pas ce centre, et la liste des CIS du Groupement territorial Nord-Est de l'Annuaire SDIS ne le mentionne pas non plus. Entree probablement obsolete (ancien CPI communal dissous) ou erronee dans mock_data.dart. Aucun CIS a Saint-Seurin-sur-l'Isle (33660) dans la liste officielle des 74 CIS du SDIS 33, ni dans OpenStreetMap, ni dans le registre SIRENE. La page 'Securite et prevention' du site de la mairie de Saint-Seurin-sur-l'Isle ne mentionne aucune caserne. Secteur couvert par le CIS Coutras. A supprimer ou a faire confirmer par le SDIS 33.",
    ),
  ),
  "Blaye": VerifiedLocationRecord(
    currentName: "Blaye",
    displayName: "Blaye",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "23 rue Joseph Taillasson",
      addressLine2: null,
      postalCode: "33390",
      city: "Blaye",
      country: "France",
      storedFullAddress: "23 rue Joseph Taillasson, 33390 Blaye, France",
      latitude: 45.133559,
      longitude: -0.663498,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - carte officielle des groupements territoriaux et CIS (couche CIS)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Base Adresse Nationale (BAN) - 23 Rue Joseph Taillasson 33390 Blaye",
      secondSourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=23+rue+Joseph+Taillasson+Blaye",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse issue de la couche CIS officielle du SDIS 33 (CIS BLAYE). Recoupee par la BAN, par OpenStreetMap (way 666777311, 45.13367/-0.66352) et par le registre SIRENE (AMICALE DES SAPEURS POMPIERS DE BLAYE, CENTRE DE SECOURS PRINCIPAL 23 RUE JOSEPH TAILLASSON 33390 BLAYE). Commande conjointe avec Saint-Ciers ('CIS BLAYE / SAINT CIERS' dans l'Annuaire SDIS).",
    ),
  ),
  "Bourg": VerifiedLocationRecord(
    currentName: "Bourg",
    displayName: "Bourg",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "13 allée du Docteur Abadie",
      addressLine2: null,
      postalCode: "33710",
      city: "Bourg",
      country: "France",
      storedFullAddress: "13 allée du Docteur Abadie, 33710 Bourg, France",
      latitude: 45.042394,
      longitude: -0.557842,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - carte officielle des groupements territoriaux et CIS (couche CIS)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Base Adresse Nationale (BAN) - Allee du Docteur Abadie 33710 Bourg",
      secondSourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=allee+du+Docteur+Abadie+33710+Bourg",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse issue de la couche CIS officielle du SDIS 33 (CIS BOURG). La BAN confirme la voie 'Allee du Docteur Abadie 33710 Bourg' mais ne contient pas de point d'adresse au numero 13 ; le numero provient de la source SDIS 33. Recoupee par OpenStreetMap (way 967099084, Allee du Docteur Abadie, 45.04241/-0.55784) et par le registre SIRENE (AMICALE DES SAPEURS-POMPIERS DE BOURG, CENTRE DE SECOURS 33710 BOURG, 45.0424/-0.5579). Commune officielle: Bourg (dite Bourg-sur-Gironde).",
    ),
  ),
  "Cavignac": VerifiedLocationRecord(
    currentName: "Cavignac",
    displayName: "Cavignac",
    type: ResponsePlaceType.interventionSector,
    isOperational: false,
    address: LocationAddress(
      addressLine1: null,
      addressLine2: null,
      postalCode: null,
      city: "Cavignac",
      country: "France",
      storedFullAddress: null,
      latitude: null,
      longitude: null,
      status: AddressStatus.notFound,
      sourceLabel:
          "Annuaire SDIS - SDIS Gironde (33) Unites territoriales (Groupement territorial Nord-Est)",
      sourceUrl: "https://www.annuaire-sdis.fr/sdis/gironde/groupements",
      secondSourceLabel:
          "SDIS 33 - page officielle Les groupements territoriaux et centres d'incendie et de secours",
      secondSourceUrl:
          "https://www.pompiers33.fr/nous-connaitre/nos-moyens/sites/les-groupements-territoriaux-et-centres-dincendie-et-de-secours/",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Aucun centre d'incendie et de secours du SDIS 33 n'existe a cette adresse/commune dans les sources officielles verifiees: la couche CIS de la carte officielle du SDIS 33 (74 CIS) ne contient pas ce centre, et la liste des CIS du Groupement territorial Nord-Est de l'Annuaire SDIS ne le mentionne pas non plus. Entree probablement obsolete (ancien CPI communal dissous) ou erronee dans mock_data.dart. Aucun CIS a Cavignac (33620) dans la liste officielle des 74 CIS du SDIS 33, ni dans OpenStreetMap, ni dans le registre SIRENE. Secteur couvert par les CIS Saint-Savin et Lapouyade (6 route de Laruscade, 33620 Lapouyade). A supprimer ou a faire confirmer par le SDIS 33.",
    ),
  ),
  "Saint-André-de-Cubzac": VerifiedLocationRecord(
    currentName: "Saint-André-de-Cubzac",
    displayName: "Saint-André-de-Cubzac",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "8 allée de Verdun",
      addressLine2: "CIS Jean Sigo",
      postalCode: "33240",
      city: "Saint-André-de-Cubzac",
      country: "France",
      storedFullAddress:
          "8 allée de Verdun, CIS Jean Sigo, 33240 Saint-André-de-Cubzac, France",
      latitude: 44.989548,
      longitude: -0.449635,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - carte officielle des groupements territoriaux et CIS (couche CIS)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Base Adresse Nationale (BAN) - 8 Allee de Verdun 33240 Saint-Andre-de-Cubzac",
      secondSourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=8+allee+de+Verdun+Saint-Andre-de-Cubzac",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse issue de la couche CIS officielle du SDIS 33 (CIS SAINT-ANDRE). Recoupee par la BAN et par OpenStreetMap (way 968595754, 44.98959/-0.44959). Le registre SIRENE indique 'CIS JEAN SIGO 10 ALLEE DE VERDUN' pour l'amicale ; le numero officiel retenu est le 8 (source SDIS 33), le 10 correspondant vraisemblablement a un batiment annexe du meme site.",
    ),
  ),
  "Saint-Ciers-sur-Gironde": VerifiedLocationRecord(
    currentName: "Saint-Ciers-sur-Gironde",
    displayName: "Saint-Ciers-sur-Gironde",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "6 avenue Charles de Gaulle",
      addressLine2: null,
      postalCode: "33820",
      city: "Saint-Ciers-sur-Gironde",
      country: "France",
      storedFullAddress:
          "6 avenue Charles de Gaulle, 33820 Saint-Ciers-sur-Gironde, France",
      latitude: 45.296057,
      longitude: -0.613562,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - carte officielle des groupements territoriaux et CIS (couche CIS)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Base Adresse Nationale (BAN) - Avenue Charles de Gaulle 33820 Saint-Ciers-sur-Gironde",
      secondSourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=6+avenue+Charles+de+Gaulle+33820+Saint-Ciers-sur-Gironde",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse issue de la couche CIS officielle du SDIS 33 (CIS SAINT-CIERS). La BAN confirme la voie 'Avenue Charles de Gaulle 33820 Saint-Ciers-sur-Gironde' mais pas le numero 6 comme point d'adresse. OpenStreetMap indique le numero 9 pour le meme batiment (way 968595760, 45.29597/-0.61360) : ecart de numerotation entre sources, le numero 6 de la source SDIS 33 a ete retenu. Commande conjointe avec Blaye.",
    ),
  ),
  "Saint-Savin": VerifiedLocationRecord(
    currentName: "Saint-Savin",
    displayName: "Saint-Savin",
    type: ResponsePlaceType.sdisStation,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "7 rue du Château d'Eau",
      addressLine2: null,
      postalCode: "33920",
      city: "Saint-Savin",
      country: "France",
      storedFullAddress: "7 rue du Château d'Eau, 33920 Saint-Savin, France",
      latitude: 45.138638,
      longitude: -0.439273,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "SDIS 33 - carte officielle des groupements territoriaux et CIS (couche CIS)",
      sourceUrl:
          "https://cartes.pompiers33.fr/data/CentredincendieetdesecoursCIS_3.js",
      secondSourceLabel:
          "Base Adresse Nationale (BAN) - 7 Rue du Chateau d'Eau 33920 Saint-Savin",
      secondSourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=7+rue+du+Chateau+d'Eau+Saint-Savin+33920",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse issue de la couche CIS officielle du SDIS 33 (CIS SAINT-SAVIN). Recoupee par la BAN, par le registre SIRENE (AMICALE DES SAPEURS-POMPIERS DE SAINT-SAVIN, CENTRE DE SECOURS 7 RUE DU CHATEAU D'EAU 33920 SAINT-SAVIN) et par OpenStreetMap (way 163375681, 45.13866/-0.43932). Le geocodage inverse BAN renvoie aussi le lieu-dit 'Caserne des Pompiers' a 14 m, coherent avec le site.",
    ),
  ),
  "Parc des Expositions de Bordeaux": VerifiedLocationRecord(
    currentName: "Parc des Expositions de Bordeaux",
    displayName: "Parc des Expositions de Bordeaux",
    type: ResponsePlaceType.civilianReceptionSite,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "Cours Charles Bricaud",
      addressLine2:
          "Entrée opérationnelle à confirmer (Porte M, cours Jules Ladoumègue, utilisée comme entrée logistique/évacuation lors des feux de forêt de 2022)",
      postalCode: "33300",
      city: "Bordeaux",
      country: "France",
      storedFullAddress: "Cours Charles Bricaud, 33300 Bordeaux, France",
      latitude: 44.896337,
      longitude: -0.565876,
      status: AddressStatus.verifiedCrossSource,
      sourceLabel:
          "Base Adresse Nationale (géocodage IGN) - localité \"Cours Charles Bricaud, 33300 Bordeaux\"",
      sourceUrl:
          "https://api-adresse.data.gouv.fr/search/?q=cours+charles+bricaud+bordeaux",
      secondSourceLabel:
          "CCI Paris Île-de-France - fiche site \"Bordeaux Parc des Expositions\"",
      secondSourceUrl:
          "https://www.cci-paris-idf.fr/fr/evenements-salons/sites-expositions-congres/bordeaux-parc-des-expositions",
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Le site officiel bordeaux-expo.com bloque la lecture automatisée (robots.txt) et n'a pas pu être consulté directement dans cette session. Code postal en léger désaccord entre sources tierces (33030 chez CCI Paris IDF vs 33300 chez bordeaux.evous.fr) : la BAN retient 33300, valeur conservée ici. La page officielle de la mairie de Bordeaux (https://m.bordeaux.fr/fr/parc-des-expositions) ne publie pas d'adresse postale précise, seulement \"quartier Bordeaux-Lac, près du stade Matmut Atlantique\". L'entrée opérationnelle/logistique utilisée lors des feux de forêt de 2022 (Porte M, cours Jules Ladoumègue) est distincte de l'adresse postale générale et n'est pas officiellement documentée comme adresse permanente - à confirmer avec l'exploitant du site (Bordeaux Métropole / GL events).",
    ),
  ),
  "Croix-Rouge Bordeaux": VerifiedLocationRecord(
    currentName: "Croix-Rouge Bordeaux",
    displayName:
        "Croix-Rouge française - Délégation territoriale de la Gironde",
    type: ResponsePlaceType.redCross,
    isOperational: true,
    address: LocationAddress(
      addressLine1: "5 Avenue Gay-Lussac",
      addressLine2: null,
      postalCode: "33370",
      city: "Artigues-près-Bordeaux",
      country: "France",
      storedFullAddress:
          "5 Avenue Gay-Lussac, 33370 Artigues-près-Bordeaux, France",
      latitude: null,
      longitude: null,
      status: AddressStatus.verifiedOfficial,
      sourceLabel:
          "Croix-Rouge française - annuaire officiel, fiche \"Délégation territoriale de la Gironde\"",
      sourceUrl:
          "https://www.croix-rouge.fr/delegation-territoriale-de-la-gironde",
      secondSourceLabel: null,
      secondSourceUrl: null,
      verifiedAt: DateTime.utc(2026, 07, 29),
      notes:
          "Adresse du siège de la délégation territoriale (structure départementale de coordination), confirmée par la page officielle croix-rouge.fr - aucune seconde source indépendante n'a été jugée nécessaire, la source étant la plus haute priorité définie pour la Croix-Rouge. ATTENTION : plusieurs autres adresses circulent pour des entités Croix-Rouge distinctes en Gironde et NE DOIVENT PAS être confondues avec la délégation territoriale : 39 Avenue de l'Île de France, 33370 Artigues-près-Bordeaux (JeVeuxAider.gouv.fr, Facebook CRF Gironde, orienter33.fr, francebenevolat.org - probablement une base logistique ou un site secondaire de la délégation, non confirmé) ; 130 Cours d'Alsace-et-Lorraine, 33000 Bordeaux (Mairie de Cenon - probablement une antenne ou permanence locale) ; 50 Rue Ferrère, 33000 Bordeaux (Mappy, Kompass - probablement l'Unité Locale de Bordeaux, entité distincte de la délégation territoriale). Conformément à la consigne de ne jamais choisir arbitrairement la première implantation trouvée, ces adresses alternatives ne sont pas retenues comme valeurs mais signalées ici pour vérification humaine si le lieu recherché est une antenne locale plutôt que le siège départemental.",
    ),
  ),
};
