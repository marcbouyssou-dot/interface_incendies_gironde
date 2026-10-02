import 'professional_equipment.dart';

/// Physical equipment that can be available at a site.
/// Null inventory means not provided; an empty list means explicitly none.
abstract final class SiteEquipment {
  static const _ambiguousIds = {
    ProfessionalEquipmentId.otherEquipment,
    ProfessionalEquipmentId.otherVeterinaryEquipment,
    ProfessionalEquipmentId.professionSpecificEquipment,
  };

  static List<ProfessionalEquipmentDefinition> get catalog =>
      ProfessionalEquipmentRegistry.values
          .where((item) => !_ambiguousIds.contains(item.id))
          .toList(growable: false);

  static List<String> normalize(Iterable<String> values) {
    final allowed = catalog.map((item) => item.id).toSet();
    final selected = <String>{};
    for (final value in values) {
      if (!allowed.contains(value)) {
        throw const FormatException('Matériel du site invalide.');
      }
      selected.add(value);
    }
    return List.unmodifiable([
      for (final item in catalog)
        if (selected.contains(item.id)) item.id,
    ]);
  }

  static List<String>? fromFirestore(Object? value) {
    if (value == null) return null;
    if (value is! List || value.any((item) => item is! String)) {
      throw const FormatException('Matériel du site invalide.');
    }
    return normalize(value.cast<String>());
  }

  static List<String> labels(Iterable<String> values) => List.unmodifiable(
    normalize(
      values,
    ).map((id) => ProfessionalEquipmentRegistry.byId(id)!.label),
  );
}
