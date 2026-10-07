import '../models/need.dart';
import 'location_slug.dart';

/// Identifiant des 65 documents créés par le seed historique Gironde.
String legacyLocationDocumentId(ResponsePlace location) {
  if (location.type == ResponsePlaceType.redCross) {
    return 'partnersites-croix-rouge-bordeaux';
  }
  return locationSlug('${location.group.name}-${location.name}');
}
