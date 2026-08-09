import 'mobilization.dart';

class MobilizationContext {
  const MobilizationContext({
    required this.mobilizationId,
    required this.territoryId,
    required this.status,
  });

  factory MobilizationContext.fromMobilization(Mobilization mobilization) {
    return MobilizationContext(
      mobilizationId: mobilization.id,
      territoryId: mobilization.territoryId,
      status: mobilization.status,
    );
  }

  final String mobilizationId;
  final String territoryId;
  final MobilizationStatus status;

  bool get isActive => status == MobilizationStatus.active;
}
