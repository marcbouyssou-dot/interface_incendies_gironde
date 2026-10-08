/// Projection Flutter minimale d'une Diffusion et de son Snapshot éventuel.
class DiffusionReadModel {
  const DiffusionReadModel({
    required this.diffusionId,
    required this.needId,
    required this.status,
    required this.createdAt,
    required this.populationCount,
    required this.snapshotAvailable,
    this.targetingStatus,
  });

  final String diffusionId;
  final String needId;
  final String status;
  final DateTime createdAt;
  final int? populationCount;
  final bool snapshotAvailable;
  final String? targetingStatus;
}
