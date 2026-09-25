import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/services/firestore_seed_service.dart';
import 'package:interface_incendies_gironde/utils/location_slug.dart';

void main() {
  group('locationSlug', () {
    test('reproduces the reported bug case cleanly', () {
      expect(
        locationSlug('northBasin-Andernos-les-Bains / Nord Bassin'),
        'northbasin-andernos-les-bains-nord-bassin',
      );
    });

    test('slash-separated commune names never keep the slash', () {
      expect(
        locationSlug('northBasin-Andernos-les-Bains / Lanton'),
        'northbasin-andernos-les-bains-lanton',
      );
    });

    test('transliterates French accents instead of dropping the letter', () {
      expect(
        locationSlug('bordeauxMetropole-Bordeaux Caudéran'),
        'bordeauxmetropole-bordeaux-cauderan',
      );
      expect(
        locationSlug('northBasin-Arès / Lège-Cap-Ferret'),
        'northbasin-ares-lege-cap-ferret',
      );
    });

    test('apostrophes collapse to a single hyphen', () {
      expect(
        locationSlug("bordeauxMetropole-Villenave-d'Ornon"),
        'bordeauxmetropole-villenave-d-ornon',
      );
      expect(
        locationSlug("libournais-Saint-Seurin-sur-l'Isle"),
        'libournais-saint-seurin-sur-l-isle',
      );
    });

    test('multiple consecutive spaces collapse to one hyphen', () {
      expect(locationSlug('medoc-Lacanau   Océan'), 'medoc-lacanau-ocean');
    });

    test('backslashes never survive into the slug', () {
      expect(locationSlug(r'medoc-Le\Verdon'), 'medoc-le-verdon');
    });

    test('mixed punctuation collapses to a single hyphen', () {
      expect(
        locationSlug('southGironde-Saint-Symphorien !? (secteur)'),
        'southgironde-saint-symphorien-secteur',
      );
    });

    test('an already-clean slug is returned unchanged', () {
      expect(locationSlug('bordeauxmetropole-pessac'), 'bordeauxmetropole-pessac');
    });

    test('never starts or ends with a hyphen', () {
      expect(locationSlug('  /Lacanau/  '), 'lacanau');
      expect(locationSlug(''), '');
    });

    test('is deterministic for the same input', () {
      const input = "northBasin-Andernos-les-Bains / Nord Bassin";
      expect(locationSlug(input), locationSlug(input));
    });

    test('output never contains a disallowed character', () {
      const inputs = [
        'northBasin-Andernos-les-Bains / Nord Bassin',
        "bordeauxMetropole-Villenave-d'Ornon",
        r'medoc-Le\Verdon',
        'southGironde-Saint-Symphorien !? (secteur)',
        'medoc-Lacanau   Océan',
      ];
      for (final input in inputs) {
        final slug = locationSlug(input);
        expect(slug, isNot(contains('/')));
        expect(slug, isNot(contains(r'\')));
        expect(slug, isNot(contains(' ')));
        expect(slug, matches(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$')));
      }
    });
  });

  group('seeded location ids (real production path)', () {
    test('no seeded location id contains a slash, backslash or space', () {
      final service = FirestoreSeedService(store: _NoopSeedStore());
      for (final place in places) {
        final id = service.stableLocationId(place);
        expect(
          id,
          isNot(contains('/')),
          reason: 'id for "${place.name}" is "$id"',
        );
        expect(
          id,
          isNot(contains(r'\')),
          reason: 'id for "${place.name}" is "$id"',
        );
        expect(
          id,
          matches(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$')),
          reason: 'id for "${place.name}" is "$id"',
        );
      }
    });

    test('the previously slash-broken commune names now produce clean ids', () {
      final service = FirestoreSeedService(store: _NoopSeedStore());
      final byName = {for (final place in places) place.name: place};

      expect(
        service.stableLocationId(byName['Andernos-les-Bains / Lanton']!),
        'northbasin-andernos-les-bains-lanton',
      );
      expect(
        service.stableLocationId(byName['Arès / Lège-Cap-Ferret']!),
        'northbasin-ares-lege-cap-ferret',
      );
      expect(
        service.stableLocationId(byName["Villenave-d'Ornon"]!),
        'bordeauxmetropole-villenave-d-ornon',
      );
    });
  });
}

class _NoopSeedStore implements LocationSeedStore {
  @override
  Future<bool> hasLocations() async => true;

  @override
  Future<void> writeLocationBatch(List<LocationSeedDocument> documents) async {}
}
