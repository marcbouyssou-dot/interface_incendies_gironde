import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/diffusion_read_model.dart';
import 'package:interface_incendies_gironde/repositories/diffusion_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/firestore_diffusion_read_mapper.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/responsible_diffusion_summary.dart';

void main() {
  Future<void> pumpSummary(
    WidgetTester tester,
    DiffusionReadRepository repository,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            children: [
              const Text('Besoin Bassens'),
              ResponsibleDiffusionSummary(
                needId: 'need-bassens',
                repository: repository,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('affiche la Diffusion et le Snapshot réels', (tester) async {
    final repository = _DiffusionRepository(
      result: _model(populationCount: 84, snapshotAvailable: true),
    );

    await pumpSummary(tester, repository);

    expect(find.text('Diffusion'), findsOneWidget);
    expect(find.text('READY'), findsOneWidget);
    expect(find.text('lundi 24 août 2026 · 10:30'), findsOneWidget);
    expect(find.text('84 professionnels'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(
      repository.lastDiffusionId,
      '9572ede747e12cddac2c22e49e961591767732da844f5029ae6b6d1946118e14',
    );
  });

  testWidgets(
    'la lecture immédiate affiche une Diffusion avec Snapshot présent',
    (tester) async {
      await pumpSummary(
        tester,
        FirestoreDiffusionReadRepository(
          _ImmediateDiffusionDataSource(snapshotAvailable: true),
        ),
      );

      expect(find.text('READY'), findsOneWidget);
      expect(find.text('7 professionnels'), findsOneWidget);
      expect(find.text('Disponible'), findsOneWidget);
      expect(find.text('État temporairement indisponible.'), findsNothing);
    },
  );

  testWidgets(
    'la lecture immédiate garde la Diffusion si le Snapshot est absent',
    (tester) async {
      await pumpSummary(
        tester,
        FirestoreDiffusionReadRepository(
          _ImmediateDiffusionDataSource(snapshotAvailable: false),
        ),
      );

      expect(find.text('READY'), findsOneWidget);
      expect(find.text('Population non encore disponible'), findsOneWidget);
      expect(find.text('Calcul en cours'), findsOneWidget);
      expect(find.text('État temporairement indisponible.'), findsNothing);
    },
  );

  testWidgets('garde une population inconnue lorsque le Snapshot est absent', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      _DiffusionRepository(
        result: _model(populationCount: null, snapshotAvailable: false),
      ),
    );

    expect(find.text('Population non encore disponible'), findsOneWidget);
    expect(find.text('Calcul en cours'), findsOneWidget);
    expect(find.text('0 professionnel'), findsNothing);
    expect(find.text('0 professionnels'), findsNothing);
  });

  testWidgets('la Diffusion absente ne masque pas le Besoin', (tester) async {
    await pumpSummary(tester, _DiffusionRepository(result: null));

    expect(find.text('Besoin Bassens'), findsOneWidget);
    expect(find.text('En attente de diffusion.'), findsOneWidget);
  });

  testWidgets('affiche exactement une population réelle égale à zéro', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      _DiffusionRepository(
        result: _model(populationCount: 0, snapshotAvailable: true),
      ),
    );

    expect(find.text('0 professionnels'), findsOneWidget);
    expect(find.text('Population non encore disponible'), findsNothing);
  });

  testWidgets('affiche exactement une population réelle positive', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      _DiffusionRepository(
        result: _model(populationCount: 12, snapshotAvailable: true),
      ),
    );

    expect(find.text('12 professionnels'), findsOneWidget);
  });

  testWidgets('une erreur de lecture ne masque pas le Besoin', (tester) async {
    await pumpSummary(tester, _DiffusionRepository(error: StateError('read')));

    expect(find.text('Besoin Bassens'), findsOneWidget);
    expect(find.text('État temporairement indisponible.'), findsOneWidget);
  });
}

DiffusionReadModel _model({
  required int? populationCount,
  required bool snapshotAvailable,
}) => DiffusionReadModel(
  diffusionId: 'diffusion-a',
  needId: 'need-bassens',
  status: 'READY',
  createdAt: DateTime(2026, 8, 24, 10, 30),
  populationCount: populationCount,
  snapshotAvailable: snapshotAvailable,
);

class _DiffusionRepository implements DiffusionReadRepository {
  _DiffusionRepository({this.result, this.error});

  final DiffusionReadModel? result;
  final Object? error;
  String? lastDiffusionId;

  @override
  Future<DiffusionReadModel?> readDiffusion(String diffusionId) async {
    lastDiffusionId = diffusionId;
    if (error case final value?) throw value;
    return result;
  }
}

class _ImmediateDiffusionDataSource implements DiffusionReadDataSource {
  _ImmediateDiffusionDataSource({required this.snapshotAvailable});

  final bool snapshotAvailable;

  @override
  Future<DiffusionReadDocument?> getDiffusion(String diffusionId) async =>
      DiffusionReadDocument(
        id: diffusionId,
        data: {
          'id': diffusionId,
          'needId': 'need-bassens',
          'status': 'READY',
          'createdAt': DateTime(2026, 8, 24, 10, 30),
        },
      );

  @override
  Future<DiffusionReadDocument?> getSnapshot(String diffusionId) async {
    if (!snapshotAvailable) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return DiffusionReadDocument(
      id: diffusionId,
      data: {
        'diffusionId': diffusionId,
        'needId': 'need-bassens',
        'populationCount': 7,
      },
    );
  }
}
