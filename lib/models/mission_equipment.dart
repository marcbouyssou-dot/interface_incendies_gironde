import 'health_profession.dart';
import 'professional_equipment.dart';

/// A null selection denotes a legacy mission with globally requested equipment.
/// An empty map denotes a new mission with no equipment selected.
abstract final class MissionEquipment {
  static Map<String, List<String>> normalize(
    Map<String, List<String>> source,
    Map<String, int> requiredByProfession,
  ) {
    if (source.keys.any((id) => !HealthProfessionId.isCanonical(id))) {
      throw const FormatException('Profession de matériel inconnue.');
    }
    final normalized = <String, List<String>>{};
    for (final profession in HealthProfessionRegistry.values) {
      final selected = source[profession.id];
      if (selected == null) continue;
      if (selected.isEmpty) {
        throw const FormatException('Sélection de matériel vide.');
      }
      if ((requiredByProfession[profession.id] ?? 0) <= 0) {
        throw const FormatException('Matériel sans quota professionnel.');
      }
      final allowed = ProfessionalEquipmentRegistry.forProfession(
        profession.id,
      );
      final allowedIds = allowed.map((item) => item.id).toSet();
      if (selected.any((id) => !allowedIds.contains(id))) {
        throw const FormatException(
          'Matériel incompatible avec la profession.',
        );
      }
      final selectedIds = selected.toSet();
      normalized[profession.id] = List.unmodifiable(
        allowed
            .where((item) => selectedIds.contains(item.id))
            .map((item) => item.id),
      );
    }
    return Map.unmodifiable(normalized);
  }

  static Map<String, List<String>> fromFirestore(
    Object? value,
    Map<String, int> requiredByProfession,
  ) {
    if (value is! Map) {
      throw const FormatException('Matériel par profession invalide.');
    }
    final selected = <String, List<String>>{};
    for (final entry in value.entries) {
      if (entry.key is! String ||
          entry.value is! List ||
          (entry.value as List).any((item) => item is! String)) {
        throw const FormatException('Matériel par profession invalide.');
      }
      selected[entry.key as String] = List<String>.from(entry.value as List);
    }
    return normalize(selected, requiredByProfession);
  }

  static List<String> globalLabels(Map<String, List<String>> byProfession) {
    final seen = <String>{};
    return List.unmodifiable([
      for (final profession in HealthProfessionRegistry.values)
        for (final id in byProfession[profession.id] ?? const <String>[])
          if (seen.add(id)) ProfessionalEquipmentRegistry.byId(id)!.label,
    ]);
  }

  static List<String> labelsFor(
    Map<String, List<String>> byProfession,
    String professionId,
  ) => List.unmodifiable([
    for (final id in byProfession[professionId] ?? const <String>[])
      ProfessionalEquipmentRegistry.byId(id)!.label,
  ]);
}
