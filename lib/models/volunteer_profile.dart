import 'need.dart';

class VolunteerProfile {
  const VolunteerProfile({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.profession,
    this.email,
    this.equipment = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final VolunteerProfession profession;
  final List<String> equipment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName => '$firstName $lastName'.trim();

  VolunteerProfile copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    VolunteerProfession? profession,
    List<String>? equipment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VolunteerProfile(
      uid: uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      profession: profession ?? this.profession,
      equipment: equipment ?? this.equipment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
