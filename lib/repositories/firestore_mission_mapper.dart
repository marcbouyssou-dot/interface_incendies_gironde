import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/need.dart';
import 'coordination_repository.dart';

abstract final class FirestoreMissionMapper {
  static Map<String, dynamic> cancellationUpdate({
    required String cancelledBy,
    required String reason,
    required Object serverTimestamp,
  }) {
    return {
      'status': 'cancelled',
      'isActive': false,
      'cancelledAt': serverTimestamp,
      'cancelledBy': cancelledBy,
      'cancellationReason': reason.trim(),
      'updatedAt': serverTimestamp,
    };
  }

  static Map<String, dynamic> toFirestore({
    required String id,
    required MissionDraft draft,
    required Object serverTimestamp,
    required String createdBy,
  }) {
    return {
      'id': id,
      'locationId': draft.location.id,
      'locationName': draft.location.name,
      'territorialGroup': draft.location.group.name,
      'startAt': Timestamp.fromDate(draft.startAt),
      'endAt': Timestamp.fromDate(draft.endAt),
      'requiredMk': draft.requiredPhysiotherapists,
      'requiredPp': draft.requiredPodiatrists,
      'registeredMk': 0,
      'registeredPp': 0,
      'requestedEquipment': List<String>.of(draft.equipment),
      'details': draft.details.trim(),
      'status': NeedStatus.critical.name,
      'createdAt': serverTimestamp,
      'updatedAt': serverTimestamp,
      'isActive': true,
      'createdBy': createdBy,
    };
  }

  static CoordinationNeed fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final startAt = _dateTime(data['startAt']);
    final endAt = _dateTime(data['endAt']);
    return CoordinationNeed(
      id: id,
      locationId: data['locationId'] as String?,
      place:
          data['locationName'] as String? ??
          data['place'] as String? ??
          'À renseigner',
      group: _enumByName(
        TerritorialGroup.values,
        data['territorialGroup'] as String? ?? data['group'] as String?,
        TerritorialGroup.partnerSites,
      ),
      date: startAt == null
          ? data['date'] as String? ?? 'À renseigner'
          : _dateLabel(startAt),
      time: startAt == null || endAt == null
          ? data['time'] as String? ?? 'À renseigner'
          : '${_timeLabel(startAt)} — ${_timeLabel(endAt)}',
      startAt: startAt,
      endAt: endAt,
      requiredPhysiotherapists: _int(
        data['requiredMk'] ?? data['requiredPhysiotherapists'],
      ),
      registeredPhysiotherapists: _int(
        data['registeredMk'] ?? data['registeredPhysiotherapists'],
      ),
      requiredPodiatrists: _int(
        data['requiredPp'] ?? data['requiredPodiatrists'],
      ),
      registeredPodiatrists: _int(
        data['registeredPp'] ?? data['registeredPodiatrists'],
      ),
      equipment: List<String>.from(
        data['requestedEquipment'] as List? ??
            data['equipment'] as List? ??
            const [],
      ),
      details: data['details'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      isCancelled: data['status'] == 'cancelled',
      cancelledAt: _dateTime(data['cancelledAt']),
      cancelledBy: data['cancelledBy'] as String?,
      cancellationReason: data['cancellationReason'] as String?,
      createdBy: data['createdBy'] as String?,
    );
  }

  static DateTime? _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _dateLabel(DateTime value) {
    return '${_two(value.day)}/${_two(value.month)}/${value.year}';
  }

  static String _timeLabel(DateTime value) {
    return '${_two(value.hour)}:${_two(value.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
