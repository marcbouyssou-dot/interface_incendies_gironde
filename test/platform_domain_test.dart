import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/mobilization_context.dart';
import 'package:interface_incendies_gironde/models/territory.dart';
import 'package:interface_incendies_gironde/repositories/platform_read_repository.dart';

void main() {
  final createdAt = DateTime.utc(2026, 8, 9, 8);
  final updatedAt = DateTime.utc(2026, 8, 9, 9);

  group('Territory', () {
    test('serializes and deserializes every domain field', () {
      final territory = Territory(
        id: 'gironde',
        name: 'Gironde',
        code: '33',
        active: true,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final data = territory.toMap();
      final restored = Territory.fromMap(data);

      expect(data.keys, {
        'id',
        'name',
        'code',
        'active',
        'createdAt',
        'updatedAt',
      });
      expect(restored.id, territory.id);
      expect(restored.name, territory.name);
      expect(restored.code, territory.code);
      expect(restored.active, territory.active);
      expect(restored.createdAt, territory.createdAt);
      expect(restored.updatedAt, territory.updatedAt);
    });

    test('rejects malformed serialized data', () {
      expect(
        () => Territory.fromMap({
          'id': 'gironde',
          'name': '',
          'code': '33',
          'active': true,
          'createdAt': createdAt,
          'updatedAt': updatedAt,
        }),
        throwsFormatException,
      );
    });
  });

  group('Mobilization enums', () {
    test('context types use stable serialized values', () {
      expect(
        MobilizationContextType.values.map((value) => value.serializedValue),
        ['fire', 'flood', 'heatwave', 'event', 'white_plan', 'other'],
      );
      for (final value in MobilizationContextType.values) {
        expect(mobilizationContextTypeFromValue(value.serializedValue), value);
      }
      expect(
        () => mobilizationContextTypeFromValue('wildfire'),
        throwsFormatException,
      );
    });

    test('statuses use stable serialized values', () {
      expect(MobilizationStatus.values.map((value) => value.serializedValue), [
        'draft',
        'active',
        'inactive',
        'archived',
      ]);
      for (final value in MobilizationStatus.values) {
        expect(mobilizationStatusFromValue(value.serializedValue), value);
      }
      expect(
        () => mobilizationStatusFromValue('deleted'),
        throwsFormatException,
      );
    });
  });

  group('Mobilization transitions', () {
    test('allows the planned standard transitions', () {
      expect(
        MobilizationStatus.draft.canTransitionTo(MobilizationStatus.active),
        isTrue,
      );
      expect(
        MobilizationStatus.draft.canTransitionTo(MobilizationStatus.archived),
        isTrue,
      );
      expect(
        MobilizationStatus.active.canTransitionTo(MobilizationStatus.inactive),
        isTrue,
      );
      expect(
        MobilizationStatus.inactive.canTransitionTo(MobilizationStatus.active),
        isTrue,
      );
      expect(
        MobilizationStatus.inactive.canTransitionTo(
          MobilizationStatus.archived,
        ),
        isTrue,
      );
    });

    test('keeps active archiving behind an explicit future policy flag', () {
      expect(
        MobilizationStatus.active.canTransitionTo(MobilizationStatus.archived),
        isFalse,
      );
      expect(
        MobilizationStatus.active.canTransitionTo(
          MobilizationStatus.archived,
          allowActiveArchiving: true,
        ),
        isTrue,
      );
    });

    test('rejects unsupported and idempotent transitions', () {
      expect(
        MobilizationStatus.draft.canTransitionTo(MobilizationStatus.inactive),
        isFalse,
      );
      expect(
        MobilizationStatus.archived.canTransitionTo(MobilizationStatus.active),
        isFalse,
      );
      for (final status in MobilizationStatus.values) {
        expect(status.canTransitionTo(status), isFalse);
      }
    });
  });

  group('Mobilization', () {
    test('serializes and deserializes every domain field', () {
      final activatedAt = DateTime.utc(2026, 8, 10, 8);
      final deactivatedAt = DateTime.utc(2026, 8, 11, 8);
      final archivedAt = DateTime.utc(2026, 8, 12, 8);
      final mobilization = Mobilization(
        id: 'incendies-gironde-2026',
        territoryId: 'gironde',
        name: 'Mobilisation santé',
        subtitle: 'Incendies Gironde',
        contextType: MobilizationContextType.fire,
        status: MobilizationStatus.archived,
        createdBy: 'platform-admin',
        createdAt: createdAt,
        updatedAt: updatedAt,
        activatedBy: 'platform-admin',
        activatedAt: activatedAt,
        deactivatedBy: 'platform-admin',
        deactivatedAt: deactivatedAt,
        archivedBy: 'platform-admin',
        archivedAt: archivedAt,
        schemaVersion: 1,
      );

      final data = mobilization.toMap();
      final restored = Mobilization.fromMap(data);

      expect(data.keys, {
        'id',
        'territoryId',
        'name',
        'subtitle',
        'contextType',
        'status',
        'createdBy',
        'createdAt',
        'updatedAt',
        'activatedBy',
        'activatedAt',
        'deactivatedBy',
        'deactivatedAt',
        'archivedBy',
        'archivedAt',
        'schemaVersion',
      });
      expect(restored.id, mobilization.id);
      expect(restored.territoryId, mobilization.territoryId);
      expect(restored.name, mobilization.name);
      expect(restored.subtitle, mobilization.subtitle);
      expect(restored.contextType, mobilization.contextType);
      expect(restored.status, mobilization.status);
      expect(restored.createdBy, mobilization.createdBy);
      expect(restored.createdAt, mobilization.createdAt);
      expect(restored.updatedAt, mobilization.updatedAt);
      expect(restored.activatedBy, mobilization.activatedBy);
      expect(restored.activatedAt, mobilization.activatedAt);
      expect(restored.deactivatedBy, mobilization.deactivatedBy);
      expect(restored.deactivatedAt, mobilization.deactivatedAt);
      expect(restored.archivedBy, mobilization.archivedBy);
      expect(restored.archivedAt, mobilization.archivedAt);
      expect(restored.schemaVersion, mobilization.schemaVersion);
    });

    test('accepts absent lifecycle audit values', () {
      final restored = Mobilization.fromMap({
        'id': 'draft',
        'territoryId': 'gironde',
        'name': 'Brouillon',
        'subtitle': 'Préparation',
        'contextType': 'other',
        'status': 'draft',
        'createdBy': 'platform-admin',
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'schemaVersion': 1,
      });

      expect(restored.activatedAt, isNull);
      expect(restored.deactivatedAt, isNull);
      expect(restored.archivedAt, isNull);
    });
  });

  group('MobilizationContext and read contract', () {
    test('projects the current identifiers and status', () {
      final mobilization = Mobilization(
        id: 'current',
        territoryId: 'gironde',
        name: 'Mobilisation',
        subtitle: 'Incendies Gironde',
        contextType: MobilizationContextType.fire,
        status: MobilizationStatus.active,
        createdBy: 'platform-admin',
        createdAt: createdAt,
        updatedAt: updatedAt,
        schemaVersion: 1,
      );

      final context = MobilizationContext.fromMobilization(mobilization);

      expect(context.mobilizationId, 'current');
      expect(context.territoryId, 'gironde');
      expect(context.status, MobilizationStatus.active);
      expect(context.isActive, isTrue);
    });

    test('read contract can expose territories and mobilizations', () async {
      final repository = _MemoryPlatformReadRepository(
        territory: Territory(
          id: 'gironde',
          name: 'Gironde',
          code: '33',
          active: true,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
        mobilization: Mobilization(
          id: 'current',
          territoryId: 'gironde',
          name: 'Mobilisation',
          subtitle: 'Incendies Gironde',
          contextType: MobilizationContextType.fire,
          status: MobilizationStatus.active,
          createdBy: 'platform-admin',
          createdAt: createdAt,
          updatedAt: updatedAt,
          schemaVersion: 1,
        ),
      );

      expect(await repository.watchTerritories().first, hasLength(1));
      expect(
        await repository.watchMobilizations(territoryId: 'gironde').first,
        hasLength(1),
      );
      expect((await repository.watchActiveMobilization().first)?.id, 'current');
    });
  });
}

class _MemoryPlatformReadRepository implements PlatformReadRepository {
  const _MemoryPlatformReadRepository({
    required this.territory,
    required this.mobilization,
  });

  final Territory territory;
  final Mobilization mobilization;

  @override
  Stream<Mobilization?> watchActiveMobilization() => Stream.value(mobilization);

  @override
  Stream<List<Mobilization>> watchMobilizations({String? territoryId}) {
    return Stream.value([
      if (territoryId == null || territoryId == mobilization.territoryId)
        mobilization,
    ]);
  }

  @override
  Stream<List<Territory>> watchTerritories() => Stream.value([territory]);
}
