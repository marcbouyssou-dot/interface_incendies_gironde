import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/repositories/professional_targeting_repository.dart';
import 'package:interface_incendies_gironde/services/reference_geocoding_service.dart';
import 'package:interface_incendies_gironde/widgets/professional_targeting_section.dart';

class _TargetingRepository implements ProfessionalTargetingRepository {
  _TargetingRepository(this.current);

  ProfessionalTargetingPreference current;
  final changes = StreamController<ProfessionalTargetingPreference>.broadcast();
  final saved = <ProfessionalTargetingPreference>[];

  @override
  Stream<ProfessionalTargetingPreference> watchProfessionalTargeting() async* {
    yield current;
    yield* changes.stream;
  }

  @override
  Future<void> saveProfessionalTargeting(
    ProfessionalTargetingPreference preference,
  ) async {
    current = preference;
    saved.add(preference);
    changes.add(preference);
  }

  @override
  Future<void> disableLegacyProfessionalSolicitations() async {
    current = ProfessionalTargetingPreference(
      enabled: current.enabled,
      radiusKm: current.radiusKm,
      latitude: current.latitude,
      longitude: current.longitude,
      source: current.source,
      geocodingProvider: current.geocodingProvider,
      geocodingPrecision: current.geocodingPrecision,
    );
    changes.add(current);
  }

  Future<void> dispose() => changes.close();
}

class _GeocodingService implements ReferenceGeocodingService {
  _GeocodingService({this.results = const [], this.failure});

  final List<ReferenceAddressCandidate> results;
  final ReferenceGeocodingFailure? failure;
  String? lastQuery;

  @override
  Future<List<ReferenceAddressCandidate>> searchAddress(String query) async {
    lastQuery = query;
    if (failure != null) throw ReferenceGeocodingException(failure!);
    return results;
  }

  @override
  Future<ReferenceAddressCandidate> resolveAddress(
    ReferenceAddressCandidate selection,
  ) async {
    if (!results.contains(selection)) {
      throw const ReferenceGeocodingException(
        ReferenceGeocodingFailure.invalidSelection,
      );
    }
    return selection;
  }
}

Future<void> _pumpSection(
  WidgetTester tester,
  _TargetingRepository repository,
  Size size, {
  ReferenceGeocodingService? geocodingService,
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ProfessionalTargetingSection(
              repository: repository,
              geocodingService: geocodingService,
              hasProfile: true,
              professionalAddress: '10 rue du Test',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final size in const [Size(320, 568), Size(390, 844)]) {
    testWidgets(
      'disabled by default with four radii and no overflow at $size',
      (tester) async {
        final repository = _TargetingRepository(
          const ProfessionalTargetingPreference(),
        );
        addTearDown(repository.dispose);
        await _pumpSection(tester, repository, size);

        expect(find.text('Non configurée'), findsOneWidget);
        expect(find.text('Aucun point de référence défini.'), findsOneWidget);
        expect(
          find.byKey(const Key('professional-targeting-privacy')),
          findsOneWidget,
        );
        for (final radius in ProfessionalTargetingPreference.radiusChoices) {
          expect(
            find.byKey(Key('professional-targeting-radius-$radius')),
            findsOneWidget,
          );
        }
        expect(ProfessionalTargetingPreference.radiusChoices, [10, 20, 30, 50]);
        final control = tester.widget<Switch>(
          find.byKey(const Key('professional-targeting-enabled')),
        );
        expect(control.value, false);
        expect(control.onChanged, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('legacy subscriber keeps alerts until an explicit opt-out', (
    tester,
  ) async {
    final repository = _TargetingRepository(
      const ProfessionalTargetingPreference(legacyOptIn: true),
    );
    addTearDown(repository.dispose);
    await _pumpSection(tester, repository, const Size(320, 568));

    final switchFinder = find.byKey(
      const Key('professional-targeting-enabled'),
    );
    expect(tester.widget<Switch>(switchFinder).value, true);
    expect(
      find.text('Anciennes alertes actives pendant la transition'),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const Key('professional-targeting-radius-30')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('professional-targeting-radius-30')));
    await tester.pumpAndSettle();
    expect(repository.saved, isEmpty);
    expect(tester.widget<Switch>(switchFinder).value, true);

    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(repository.current.legacyOptIn, false);
    expect(repository.saved, isEmpty);
    expect(tester.widget<Switch>(switchFinder).value, false);
    expect(find.text('Non configurée'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one explicit switch activates a confirmed point', (
    tester,
  ) async {
    final repository = _TargetingRepository(
      const ProfessionalTargetingPreference(
        latitude: 44.84,
        longitude: -0.58,
        source: 'selected_point',
      ),
    );
    addTearDown(repository.dispose);
    await _pumpSection(tester, repository, const Size(390, 844));

    await tester.ensureVisible(
      find.byKey(const Key('professional-targeting-radius-30')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('professional-targeting-radius-30')));
    await tester.pumpAndSettle();
    expect(repository.saved.last.radiusKm, 30);
    expect(repository.saved.last.enabled, false);

    await tester.tap(find.byKey(const Key('professional-targeting-enabled')));
    await tester.pumpAndSettle();
    expect(repository.saved.last.enabled, true);
    expect(find.text('Activée'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('professional-targeting-clear-point')),
    );
    await tester.pumpAndSettle();
    expect(repository.saved.last.enabled, false);
    expect(repository.saved.last.hasReferencePoint, false);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 568), Size(390, 844)]) {
    testWidgets('search, select and confirm a private point at $size', (
      tester,
    ) async {
      final repository = _TargetingRepository(
        const ProfessionalTargetingPreference(),
      );
      addTearDown(repository.dispose);
      const candidate = ReferenceAddressCandidate(
        displayLabel: '10 Rue de la Paix 75002 Paris',
        latitude: 48.868989,
        longitude: 2.33115,
        provider: 'ign_geoplateforme',
        precision: 'housenumber',
      );
      final geocoding = _GeocodingService(results: [candidate]);
      await _pumpSection(tester, repository, size, geocodingService: geocoding);

      await tester.ensureVisible(
        find.byKey(const Key('professional-targeting-radius-30')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('professional-targeting-radius-30')),
      );
      await tester.pumpAndSettle();
      expect(repository.saved, isEmpty);

      await tester.tap(
        find.byKey(const Key('professional-targeting-edit-point')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Ne saisissez aucune donnée permettant'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('professional-targeting-address-query')),
        '10 rue de la Paix Paris',
      );
      await tester.ensureVisible(
        find.byKey(const Key('professional-targeting-search')),
      );
      await tester.tap(find.byKey(const Key('professional-targeting-search')));
      await tester.pumpAndSettle();
      expect(geocoding.lastQuery, '10 rue de la Paix Paris');
      expect(repository.saved, isEmpty);

      await tester.ensureVisible(
        find.byKey(const Key('professional-targeting-candidate-0')),
      );
      await tester.tap(
        find.byKey(const Key('professional-targeting-candidate-0')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('professional-targeting-confirmation')),
        findsOneWidget,
      );
      expect(repository.saved, isEmpty);

      await tester.ensureVisible(
        find.byKey(const Key('professional-targeting-confirm-point')),
      );
      await tester.tap(
        find.byKey(const Key('professional-targeting-confirm-point')),
      );
      await tester.pumpAndSettle();
      expect(repository.saved.single.hasReferencePoint, true);
      expect(repository.saved.single.enabled, false);
      expect(repository.saved.single.radiusKm, 30);
      expect(repository.saved.single.latitude, 48.868989);
      expect(repository.saved.single.geocodingProvider, 'ign_geoplateforme');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('provider failure keeps targeting disabled', (tester) async {
    final repository = _TargetingRepository(
      const ProfessionalTargetingPreference(),
    );
    addTearDown(repository.dispose);
    await _pumpSection(
      tester,
      repository,
      const Size(320, 568),
      geocodingService: _GeocodingService(
        failure: ReferenceGeocodingFailure.unavailable,
      ),
    );
    await tester.tap(
      find.byKey(const Key('professional-targeting-edit-point')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('professional-targeting-address-query')),
      '10 rue de la Paix Paris',
    );
    await tester.ensureVisible(
      find.byKey(const Key('professional-targeting-search')),
    );
    await tester.tap(find.byKey(const Key('professional-targeting-search')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('professional-targeting-search-error')),
      findsOneWidget,
    );
    expect(repository.saved, isEmpty);
    expect(find.text('Non configurée'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiple results never activate automatically', (tester) async {
    final repository = _TargetingRepository(
      const ProfessionalTargetingPreference(),
    );
    addTearDown(repository.dispose);
    const results = [
      ReferenceAddressCandidate(
        displayLabel: 'Rue Exemple 33000 Bordeaux',
        latitude: 44.84,
        longitude: -0.58,
        provider: 'ign_geoplateforme',
        precision: 'street',
      ),
      ReferenceAddressCandidate(
        displayLabel: 'Rue Exemple 33100 Bordeaux',
        latitude: 44.85,
        longitude: -0.57,
        provider: 'ign_geoplateforme',
        precision: 'street',
      ),
    ];
    await _pumpSection(
      tester,
      repository,
      const Size(390, 844),
      geocodingService: _GeocodingService(results: results),
    );
    await tester.tap(
      find.byKey(const Key('professional-targeting-edit-point')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('professional-targeting-address-query')),
      'Rue Exemple Bordeaux',
    );
    await tester.ensureVisible(
      find.byKey(const Key('professional-targeting-search')),
    );
    await tester.tap(find.byKey(const Key('professional-targeting-search')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('professional-targeting-candidate-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('professional-targeting-candidate-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('professional-targeting-confirmation')),
      findsNothing,
    );
    expect(repository.saved, isEmpty);
  });

  testWidgets('no result is explained without changing the preference', (
    tester,
  ) async {
    final repository = _TargetingRepository(
      const ProfessionalTargetingPreference(),
    );
    addTearDown(repository.dispose);
    await _pumpSection(
      tester,
      repository,
      const Size(320, 568),
      geocodingService: _GeocodingService(),
    );
    await tester.tap(
      find.byKey(const Key('professional-targeting-edit-point')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('professional-targeting-address-query')),
      'Lieu introuvable',
    );
    await tester.ensureVisible(
      find.byKey(const Key('professional-targeting-search')),
    );
    await tester.tap(find.byKey(const Key('professional-targeting-search')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucun résultat'), findsOneWidget);
    expect(repository.saved, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
