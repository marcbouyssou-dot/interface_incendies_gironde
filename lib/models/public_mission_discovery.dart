import 'health_profession.dart';
import '../utils/french_date_time.dart';

/// Deliberately smaller than an operational mission. No site document is used.
class PublicMissionDiscovery {
  const PublicMissionDiscovery({
    required this.publicId,
    required this.day,
    required this.sectorLabel,
    required this.professions,
  });

  static const allowedFields = {
    'publicId',
    'day',
    'sectorLabel',
    'professions',
    'status',
  };

  final String publicId;
  final String day;
  final String sectorLabel;
  final List<String> professions;

  String get dateLabel {
    final date = DateTime.parse(day);
    return FrenchDateTime.relativeDate(date);
  }

  List<String> get professionLabels => professions
      .map((id) => HealthProfessionRegistry.byId(id)?.missionLabel)
      .whereType<String>()
      .toList(growable: false);

  factory PublicMissionDiscovery.fromMap({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final publicId = data['publicId'];
    final day = data['day'];
    final sector = data['sectorLabel'];
    final professions = data['professions'];
    if (data.keys.toSet().difference(allowedFields).isNotEmpty ||
        publicId != documentId ||
        publicId is! String ||
        day is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) ||
        DateTime.tryParse(day) == null ||
        sector is! String ||
        sector.trim().isEmpty ||
        professions is! List ||
        professions.isEmpty ||
        professions.any(
          (value) =>
              value is! String || !HealthProfessionId.canonical.contains(value),
        ) ||
        data['status'] != 'open') {
      throw const FormatException('Projection publique de mission invalide.');
    }
    return PublicMissionDiscovery(
      publicId: publicId,
      day: day,
      sectorLabel: sector,
      professions: List<String>.unmodifiable(professions.cast<String>()),
    );
  }
}
