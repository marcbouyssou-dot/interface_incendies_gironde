enum AdminInvitationStatus { pending, accepted, expired, cancelled }

extension AdminInvitationStatusValue on AdminInvitationStatus {
  String get firestoreValue => name;
}

AdminInvitationStatus adminInvitationStatusFromValue(Object? value) {
  return AdminInvitationStatus.values.firstWhere(
    (status) => status.firestoreValue == value,
    orElse: () => throw const FormatException(
      'Statut d’invitation administrateur invalide.',
    ),
  );
}

class AdminInvitation {
  const AdminInvitation({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.locationIds,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.acceptedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;
  final Set<String> locationIds;
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final AdminInvitationStatus status;
  final DateTime? acceptedAt;

  bool get isPending => status == AdminInvitationStatus.pending;
  bool get isExpired =>
      status == AdminInvitationStatus.expired ||
      (isPending && !expiresAt.isAfter(DateTime.now()));

  AdminInvitation copyWith({
    AdminInvitationStatus? status,
    DateTime? acceptedAt,
  }) {
    return AdminInvitation(
      id: id,
      email: email,
      displayName: displayName,
      role: role,
      locationIds: locationIds,
      createdBy: createdBy,
      createdAt: createdAt,
      expiresAt: expiresAt,
      status: status ?? this.status,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }
}

class AdminInvitationDraft {
  AdminInvitationDraft({
    required String email,
    required String displayName,
    required Set<String> locationIds,
    required this.expiresAt,
    this.role = siteManagerRole,
  }) : email = email.trim().toLowerCase(),
       displayName = displayName.trim(),
       locationIds = Set.unmodifiable(
         locationIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
       );

  static const siteManagerRole = 'site_manager';
  static const coordinatorRole = 'coordinator';

  final String email;
  final String displayName;
  final String role;
  final Set<String> locationIds;
  final DateTime expiresAt;

  void validate({required DateTime now}) {
    if (!_emailPattern.hasMatch(email)) {
      throw const FormatException('Adresse e-mail invalide.');
    }
    if (displayName.isEmpty) {
      throw const FormatException('Le nom du responsable est obligatoire.');
    }
    if (role != siteManagerRole && role != coordinatorRole) {
      throw const FormatException('Rôle d’invitation invalide.');
    }
    if (role == siteManagerRole && locationIds.isEmpty) {
      throw const FormatException('Sélectionnez au moins un lieu.');
    }
    if (role == coordinatorRole && locationIds.isNotEmpty) {
      throw const FormatException(
        'Un coordinateur départemental ne doit pas être limité à un lieu.',
      );
    }
    if (!expiresAt.isAfter(now)) {
      throw const FormatException('La date d’expiration doit être future.');
    }
  }
}

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
