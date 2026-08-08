import 'package:flutter/widgets.dart';

import '../models/need.dart';

/// Keeps server-confirmed publications visible until the public mission stream
/// acknowledges them.
class CoordinatorPublishedNeeds extends ValueNotifier<List<CoordinationNeed>> {
  CoordinatorPublishedNeeds() : super(const []);

  final Set<String> _pendingAcknowledgements = {};
  bool _reconciliationScheduled = false;
  bool _disposed = false;

  void publish(CoordinationNeed need) {
    value = List.unmodifiable([
      need,
      ...value.where((candidate) => candidate.id != need.id),
    ]);
  }

  List<CoordinationNeed> mergeWith(List<CoordinationNeed> serverNeeds) {
    final serverIds = serverNeeds.map((need) => need.id).toSet();
    final acknowledged = value
        .where((need) => serverIds.contains(need.id))
        .map((need) => need.id)
        .toSet();
    _reconcileAfterFrame(acknowledged);

    final merged = <String, CoordinationNeed>{
      for (final need in value) need.id: need,
      for (final need in serverNeeds) need.id: need,
    }.values.toList(growable: false);
    merged.sort((left, right) {
      final leftDate = left.startAt;
      final rightDate = right.startAt;
      if (leftDate == null && rightDate == null) {
        return left.id.compareTo(right.id);
      }
      if (leftDate == null) return 1;
      if (rightDate == null) return -1;
      return leftDate.compareTo(rightDate);
    });
    return merged;
  }

  void _reconcileAfterFrame(Set<String> acknowledged) {
    if (acknowledged.isEmpty) return;
    _pendingAcknowledgements.addAll(acknowledged);
    if (_reconciliationScheduled) return;
    _reconciliationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconciliationScheduled = false;
      if (_disposed || _pendingAcknowledgements.isEmpty) return;
      final ids = Set<String>.of(_pendingAcknowledgements);
      _pendingAcknowledgements.clear();
      value = List.unmodifiable(value.where((need) => !ids.contains(need.id)));
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _pendingAcknowledgements.clear();
    super.dispose();
  }
}
