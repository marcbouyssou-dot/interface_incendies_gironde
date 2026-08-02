import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/need.dart';
import '../models/profession_quotas.dart';
import '../utils/french_date_time.dart';
import 'coordination_repository.dart';

abstract final class FirestoreMissionMapper {
  static Map<String, Object?> toUpdateCallableData({
    required String missionId,
    required MissionDraft draft,
  }) {
    return {
      'missionId': missionId,
      'locationId': draft.location.id,
      'startAtMillis': draft.startAt.millisecondsSinceEpoch,
      'endAtMillis': draft.endAt.millisecondsSinceEpoch,
      'requiredByProfession': draft.requiredByProfession,
      'equipment': List<String>.of(draft.equipment),
      'details': draft.details,
    };
  }

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
    final quotas = draft.professionQuotas;
    return {
      'id': id,
      'locationId': draft.location.id,
      'locationName': draft.location.name,
      'territorialGroup': draft.location.group.name,
      'startAt': Timestamp.fromDate(draft.startAt),
      'endAt': Timestamp.fromDate(draft.endAt),
      ...quotas.toMissionUpdate(),
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
    final quotas = ProfessionQuotas.fromMissionData(data);
    final mk = quotas.quotaFor('physiotherapist');
    final pp = quotas.quotaFor('podiatrist');
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
          : FrenchDateTime.date(startAt),
      time: startAt == null || endAt == null
          ? data['time'] as String? ?? 'À renseigner'
          : FrenchDateTime.timeRange(startAt, endAt),
      startAt: startAt,
      endAt: endAt,
      requiredPhysiotherapists: mk.required,
      registeredPhysiotherapists: mk.registered,
      requiredPodiatrists: pp.required,
      registeredPodiatrists: pp.registered,
      professionQuotas: quotas,
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
