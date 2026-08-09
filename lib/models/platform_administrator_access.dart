class PlatformAdministratorAccess {
  const PlatformAdministratorAccess({required this.uid, required this.active});

  factory PlatformAdministratorAccess.fromMap({
    required String uid,
    required Map<String, Object?> data,
  }) {
    final active = data['active'];
    if (uid.trim().isEmpty || active is! bool) {
      throw const FormatException('Administrateur plateforme invalide.');
    }
    return PlatformAdministratorAccess(uid: uid, active: active);
  }

  final String uid;
  final bool active;
}

class MobilizationCoordinatorAssignment {
  const MobilizationCoordinatorAssignment({
    required this.id,
    required this.uid,
    required this.mobilizationId,
    required this.active,
  });

  factory MobilizationCoordinatorAssignment.fromMap({
    required String id,
    required Map<String, Object?> data,
  }) {
    final uid = data['uid'];
    final mobilizationId = data['mobilizationId'];
    final role = data['role'];
    final active = data['active'];
    if (id.trim().isEmpty ||
        uid is! String ||
        uid.trim().isEmpty ||
        mobilizationId is! String ||
        mobilizationId.trim().isEmpty ||
        role != 'coordinator' ||
        active is! bool) {
      throw const FormatException('Affectation coordinateur invalide.');
    }
    if (id != '${mobilizationId}_$uid') {
      throw const FormatException('Affectation coordinateur incohérente.');
    }
    return MobilizationCoordinatorAssignment(
      id: id,
      uid: uid,
      mobilizationId: mobilizationId,
      active: active,
    );
  }

  final String id;
  final String uid;
  final String mobilizationId;
  final bool active;
}

class ActivePlatformCoordinator {
  const ActivePlatformCoordinator({required this.uid});

  factory ActivePlatformCoordinator.fromMap({
    required String uid,
    required Map<String, Object?> data,
  }) {
    final active = data['active'];
    final role = data['role'];
    final roles = data['roles'];
    final hasCoordinatorRole =
        role == 'coordinator' ||
        (roles is List && roles.contains('coordinator'));
    if (uid.trim().isEmpty || active != true || !hasCoordinatorRole) {
      throw const FormatException('Coordinateur plateforme invalide.');
    }
    return ActivePlatformCoordinator(uid: uid);
  }

  final String uid;
}
