import 'responsible_access.dart';

class ResponsibleAccount {
  const ResponsibleAccount({
    required this.access,
    this.displayName,
    this.email,
  });

  final ResponsibleAccess access;
  final String? displayName;
  final String? email;

  String get uid => access.uid;
  String get identityLabel => displayName ?? email ?? uid;

  ResponsibleAccount copyWith({ResponsibleAccess? access}) =>
      ResponsibleAccount(
        access: access ?? this.access,
        displayName: displayName,
        email: email,
      );

  factory ResponsibleAccount.fromMap(Map<String, Object?> data) {
    final uid = data['uid'];
    if (uid is! String || uid.isEmpty) {
      throw const FormatException('Compte responsable invalide.');
    }
    return ResponsibleAccount(
      access: ResponsibleAccessParser.parse(uid: uid, data: data),
      displayName: _optionalString(data['displayName']),
      email: _optionalString(data['email']),
    );
  }
}

String? _optionalString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

class ResponsibleAccessUpdate {
  ResponsibleAccessUpdate({
    required this.targetUid,
    required this.roles,
    required this.locationIds,
    required this.active,
  }) {
    ResponsibleAccess.v2(
      uid: targetUid,
      roles: roles,
      locationIds: locationIds,
      active: active,
    );
  }

  final String targetUid;
  final List<String> roles;
  final Set<String> locationIds;
  final bool active;

  Map<String, Object?> toMap() => {
    'targetUid': targetUid,
    'roles': List<String>.of(roles),
    'locationIds': locationIds.toList(growable: false)..sort(),
    'active': active,
  };
}
