class UserDisplayIdentity {
  const UserDisplayIdentity({
    required this.uid,
    required this.displayName,
    required this.professionLabel,
    this.organizationLabel,
  });

  const UserDisplayIdentity.professionalFallback(String uid)
    : this(
        uid: uid,
        displayName: 'Professionnel',
        professionLabel: 'Profession non renseignée',
      );

  const UserDisplayIdentity.coordinatorFallback(String uid)
    : this(
        uid: uid,
        displayName: 'Coordinateur',
        professionLabel: 'Coordinateur',
      );

  final String uid;
  final String displayName;
  final String professionLabel;
  final String? organizationLabel;

  factory UserDisplayIdentity.fromMap(
    Map<String, Object?> data, {
    required String fallbackLabel,
    required String fallbackProfessionLabel,
  }) {
    final uid = _requiredText(data['uid']);
    return UserDisplayIdentity(
      uid: uid,
      displayName: _optionalText(data['displayName']) ?? fallbackLabel,
      professionLabel:
          _optionalText(data['professionLabel']) ?? fallbackProfessionLabel,
      organizationLabel: _optionalText(data['organizationLabel']),
    );
  }
}

String _requiredText(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Identité utilisateur invalide.');
  }
  return value.trim();
}

String? _optionalText(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
