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
    this.acceptedUid,
    this.provisionedAt,
    this.activationLinkGeneratedAt,
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
  final String? acceptedUid;
  final DateTime? provisionedAt;
  final DateTime? activationLinkGeneratedAt;

  bool get isPending => status == AdminInvitationStatus.pending;
  bool get isExpired =>
      status == AdminInvitationStatus.expired ||
      (isPending && !expiresAt.isAfter(DateTime.now()));

  AdminInvitation copyWith({
    AdminInvitationStatus? status,
    DateTime? acceptedAt,
    String? acceptedUid,
    DateTime? provisionedAt,
    DateTime? activationLinkGeneratedAt,
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
      acceptedUid: acceptedUid ?? this.acceptedUid,
      provisionedAt: provisionedAt ?? this.provisionedAt,
      activationLinkGeneratedAt:
          activationLinkGeneratedAt ?? this.activationLinkGeneratedAt,
    );
  }
}

class AdminInvitationDraft {
  AdminInvitationDraft({
    required String email,
    required String displayName,
    required Iterable<Object?> locationIds,
    required this.expiresAt,
    Object? role = siteManagerRole,
  }) : email = email.trim().toLowerCase(),
       displayName = displayName.trim(),
       _role = role,
       _locationIds = List<Object?>.unmodifiable(locationIds);

  static const siteManagerRole = 'site_manager';
  static const coordinatorRole = 'coordinator';
  static const maxLocationIds = 65;
  static const _rulesListSeparator = '\u001f';

  final String email;
  final String displayName;
  final Object? _role;
  final List<Object?> _locationIds;
  final DateTime expiresAt;

  String get role {
    final value = _role;
    if (value is! String) throw _invalidRole;
    return value;
  }

  List<String> get locationIds {
    if (_locationIds.any((id) => id is! String)) throw _invalidLocations;
    return List<String>.unmodifiable(_locationIds.cast<String>());
  }

  void validate({required DateTime now}) {
    if (!_emailPattern.hasMatch(email)) {
      throw const FormatException('Adresse e-mail invalide.');
    }
    if (displayName.isEmpty) {
      throw const FormatException('Le nom du responsable est obligatoire.');
    }
    if (_role != siteManagerRole && _role != coordinatorRole) {
      throw _invalidRole;
    }
    if (_locationIds.length > maxLocationIds) {
      throw const FormatException(
        'Une invitation ne peut contenir plus de 65 centres.',
      );
    }
    if (_locationIds.any((id) => id is! String)) throw _invalidLocations;
    final locations = _locationIds.cast<String>();
    if (locations.any(
      (id) =>
          id.isEmpty ||
          id.trim().isEmpty ||
          id == '*' ||
          id.contains(_rulesListSeparator),
    )) {
      throw _invalidLocations;
    }
    if (locations.toSet().length != locations.length) {
      throw _invalidLocations;
    }
    if (_role == siteManagerRole && locations.isEmpty) {
      throw const FormatException(
        'Un responsable de site doit être associé à au moins un centre.',
      );
    }
    if (_role == coordinatorRole && locations.isNotEmpty) {
      throw const FormatException(
        'Un coordinateur ne doit pas être limité à des centres.',
      );
    }
    if (!expiresAt.isAfter(now)) {
      throw const FormatException('La date d’expiration doit être future.');
    }
  }
}

const FormatException _invalidRole = FormatException(
  'Rôle d’invitation invalide.',
);
const FormatException _invalidLocations = FormatException(
  'La sélection des centres est invalide. '
  'Vérifiez votre choix puis réessayez.',
);

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
