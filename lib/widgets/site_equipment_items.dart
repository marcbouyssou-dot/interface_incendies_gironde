import 'package:flutter/material.dart';

import '../models/site_equipment.dart';

/// Presentation of a site inventory or a mission's publication snapshot.
class SiteEquipmentItems extends StatelessWidget {
  const SiteEquipmentItems({super.key, required this.equipment});

  final List<String>? equipment;

  @override
  Widget build(BuildContext context) {
    final values = equipment;
    if (values == null) {
      return const Text('Matériel disponible sur site non renseigné');
    }
    if (values.isEmpty) {
      return const Text('Aucun matériel disponible sur site');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final label in SiteEquipment.labels(values)) Text('• $label'),
      ],
    );
  }
}
