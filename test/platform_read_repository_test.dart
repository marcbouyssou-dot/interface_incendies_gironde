import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/repositories/firestore_platform_read_repository.dart';
import 'package:interface_incendies_gironde/services/current_mobilization_provider.dart';

void main() {
  final createdAt = DateTime.utc(2026, 8, 10, 8);
  final updatedAt = DateTime.utc(2026, 8, 10, 9);

  group('FirestorePlatformReadRepository', () {
    test('returns empty values when future collections are empty', () async {
      final repository = FirestorePlatformReadRepository(
        dataSource: _FakePlatformReadDataSource(),
      );

      expect(await repository.watchPlatformConfig().first, isNull);
      expect(await repository.watchTerritories().first, isEmpty);
      expect(await repository.watchMobilizations().first, isEmpty);
      expect(await repository.watchActiveMobilization().first, isNull);
    });

    test(
      'returns null when the configured active mobilization is absent',
      () async {
        final repository = FirestorePlatformReadRepository(
          dataSource: _FakePlatformReadDataSource(
            config: const {'activeMobilizationId': 'missing'},
          ),
        );

        expect(await repository.watchActiveMobilization().first, isNull);
      },
    );

    test(
      'active mobilization reads config and one document without listing',
      () async {
        final source = _FakePlatformReadDataSource(
          config: const {'activeMobilizationId': 'legacy-active'},
          mobilizations: [
            _mobilizationDocument(
              id: 'legacy-active',
              territoryId: 'gironde',
              status: 'active',
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          ],
        );
        final repository = FirestorePlatformReadRepository(dataSource: source);

        expect(
          (await repository.watchActiveMobilization().first)?.id,
          'legacy-active',
        );
        expect(source.configReads, 1);
        expect(source.mobilizationDocumentReads, 1);
        expect(source.mobilizationListReads, 0);
      },
    );

    test(
      'reads several mobilizations and excludes inactive ones by default',
      () async {
        final source = _FakePlatformReadDataSource(
          mobilizations: [
            _mobilizationDocument(
              id: 'active-gironde',
              territoryId: 'gironde',
              status: 'active',
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
            _mobilizationDocument(
              id: 'inactive-gironde',
              territoryId: 'gironde',
              status: 'inactive',
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
            _mobilizationDocument(
              id: 'draft-landes',
              territoryId: 'landes',
              status: 'draft',
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          ],
        );
        final repository = FirestorePlatformReadRepository(dataSource: source);

        final active = await repository.watchMobilizations().first;
        final all = await repository
            .watchMobilizations(includeInactive: true)
            .first;

        expect(active.map((item) => item.id), ['active-gironde']);
        expect(all.map((item) => item.id), [
          'active-gironde',
          'inactive-gironde',
          'draft-landes',
        ]);
        expect(source.lastIncludeInactive, isTrue);
      },
    );

    test('forwards and applies the territory filter', () async {
      final source = _FakePlatformReadDataSource(
        mobilizations: [
          _mobilizationDocument(
            id: 'gironde',
            territoryId: 'gironde',
            status: 'active',
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          _mobilizationDocument(
            id: 'landes',
            territoryId: 'landes',
            status: 'active',
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        ],
      );
      final repository = FirestorePlatformReadRepository(dataSource: source);

      final mobilizations = await repository
          .watchMobilizations(territoryId: 'gironde')
          .first;

      expect(source.lastTerritoryId, 'gironde');
      expect(source.lastIncludeInactive, isFalse);
      expect(mobilizations.single.id, 'gironde');
    });

    test('deserializes Firestore timestamps and domain values', () async {
      final activatedAt = DateTime.utc(2026, 8, 10, 10);
      final source = _FakePlatformReadDataSource(
        config: const {'activeMobilizationId': 'heatwave'},
        territories: [
          PlatformReadDocument(
            id: 'gironde',
            data: {
              'id': 'gironde',
              'name': 'Gironde',
              'code': '33',
              'active': true,
              'createdAt': Timestamp.fromDate(createdAt),
              'updatedAt': Timestamp.fromDate(updatedAt),
            },
          ),
        ],
        mobilizations: [
          _mobilizationDocument(
            id: 'heatwave',
            territoryId: 'gironde',
            status: 'active',
            contextType: 'heatwave',
            createdAt: createdAt,
            updatedAt: updatedAt,
            activatedAt: activatedAt,
          ),
        ],
      );
      final repository = FirestorePlatformReadRepository(dataSource: source);

      final territory = (await repository.watchTerritories().first).single;
      final mobilization = await repository.watchActiveMobilization().first;

      expect(territory.id, 'gironde');
      expect(territory.createdAt.isAtSameMomentAs(createdAt), isTrue);
      expect(mobilization?.contextType, MobilizationContextType.heatwave);
      expect(mobilization?.status, MobilizationStatus.active);
      expect(mobilization?.activatedAt?.isAtSameMomentAs(activatedAt), isTrue);
    });
  });

  group('CurrentMobilizationProvider', () {
    test('exposes the active id and builds a MobilizationContext', () async {
      final repository = FirestorePlatformReadRepository(
        dataSource: _FakePlatformReadDataSource(
          config: const {'activeMobilizationId': 'current'},
          mobilizations: [
            _mobilizationDocument(
              id: 'current',
              territoryId: 'gironde',
              status: 'active',
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          ],
        ),
      );
      final provider = CurrentMobilizationProvider(repository: repository);

      expect(await provider.watchActiveMobilizationId().first, 'current');
      final context = await provider.watchContext().first;
      expect(context?.mobilizationId, 'current');
      expect(context?.territoryId, 'gironde');
      expect(context?.status, MobilizationStatus.active);
      expect(context?.isActive, isTrue);
    });

    test('exposes no context when no mobilization is active', () async {
      final provider = CurrentMobilizationProvider(
        repository: FirestorePlatformReadRepository(
          dataSource: _FakePlatformReadDataSource(),
        ),
      );

      expect(await provider.watchActiveMobilizationId().first, isNull);
      expect(await provider.watchContext().first, isNull);
    });
  });
}

class _FakePlatformReadDataSource implements PlatformReadDataSource {
  _FakePlatformReadDataSource({
    this.config,
    this.territories = const [],
    this.mobilizations = const [],
  });

  final Map<String, Object?>? config;
  final List<PlatformReadDocument> territories;
  final List<PlatformReadDocument> mobilizations;

  String? lastTerritoryId;
  bool? lastIncludeInactive;
  int configReads = 0;
  int mobilizationDocumentReads = 0;
  int mobilizationListReads = 0;

  @override
  Stream<PlatformReadDocument?> watchMobilizationDocument(String id) {
    mobilizationDocumentReads++;
    PlatformReadDocument? result;
    for (final document in mobilizations) {
      if (document.id == id) {
        result = document;
        break;
      }
    }
    return _openValue(result);
  }

  @override
  Stream<List<PlatformReadDocument>> watchMobilizationDocuments({
    String? territoryId,
    required bool includeInactive,
  }) {
    mobilizationListReads++;
    lastTerritoryId = territoryId;
    lastIncludeInactive = includeInactive;
    final result = mobilizations
        .where((document) {
          if (territoryId != null &&
              document.data['territoryId'] != territoryId) {
            return false;
          }
          return includeInactive || document.data['status'] == 'active';
        })
        .toList(growable: false);
    return _openValue(result);
  }

  @override
  Stream<Map<String, Object?>?> watchPlatformConfigDocument() {
    configReads++;
    return _openValue(config);
  }

  @override
  Stream<List<PlatformReadDocument>> watchTerritoryDocuments() {
    return _openValue(territories);
  }
}

PlatformReadDocument _mobilizationDocument({
  required String id,
  required String territoryId,
  required String status,
  required DateTime createdAt,
  required DateTime updatedAt,
  String contextType = 'fire',
  DateTime? activatedAt,
}) {
  return PlatformReadDocument(
    id: id,
    data: {
      'id': id,
      'territoryId': territoryId,
      'name': 'Mobilisation $id',
      'subtitle': 'Contexte $id',
      'contextType': contextType,
      'status': status,
      'createdBy': 'platform-admin',
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'activatedBy': activatedAt == null ? null : 'platform-admin',
      'activatedAt': activatedAt == null
          ? null
          : Timestamp.fromDate(activatedAt),
      'schemaVersion': 1,
    },
  );
}

Stream<T> _openValue<T>(T value) {
  return Stream<T>.multi((controller) => controller.add(value));
}
