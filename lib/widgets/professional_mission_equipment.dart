import 'package:flutter/material.dart';

import '../models/health_profession.dart';
import '../models/mission_equipment.dart';
import '../models/need.dart';
import '../models/site_equipment.dart';
import '../theme/v5_foundation.dart';

/// Operational equipment for one Professional, without exposing other
/// professions' requested items.
class ProfessionalMissionEquipment extends StatelessWidget {
  const ProfessionalMissionEquipment({
    super.key,
    required this.mission,
    required this.profession,
    this.showTeam = false,
  });

  final CoordinationNeed mission;
  final VolunteerProfession profession;
  final bool showTeam;

  @override
  Widget build(BuildContext context) {
    final byProfession = mission.equipmentByProfession;
    final requested = byProfession == null
        ? mission.equipment.where((item) => item.trim().isNotEmpty).toList()
        : MissionEquipment.labelsFor(byProfession, profession.canonicalId!);
    final available = mission.availableEquipmentOnSite;
    final siteLabels = available == null || available.isEmpty
        ? const <String>[]
        : SiteEquipment.labels(available);
    final team = HealthProfessionRegistry.values
        .where((item) => mission.professionQuotas.quotaFor(item.id).hasActivity)
        .map((item) => item.shortLabel)
        .join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTeam && team.isNotEmpty) ...[
          _EquipmentSection(title: 'Équipe mobilisée', values: [team]),
          const SizedBox(height: V5Spacing.sm),
        ],
        _EquipmentSection(
          title: 'Matériel disponible sur place',
          values: siteLabels,
          emptyMessage: 'Matériel disponible sur place non renseigné.',
        ),
        const SizedBox(height: V5Spacing.sm),
        if (byProfession == null)
          _EquipmentSection(
            title: 'Matériel demandé pour cette mission',
            values: requested,
            emptyMessage: 'Matériel demandé non renseigné.',
          )
        else
          _EquipmentSection(
            title: 'À apporter',
            values: requested,
            emptyMessage: 'Aucun matériel spécifique à apporter.',
          ),
      ],
    );
  }
}

class _EquipmentSection extends StatelessWidget {
  const _EquipmentSection({
    required this.title,
    required this.values,
    this.emptyMessage,
  });

  final String title;
  final List<String> values;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: V5Spacing.xxs),
      if (values.isEmpty)
        Text(emptyMessage!, style: Theme.of(context).textTheme.bodySmall)
      else
        for (final value in values)
          Text(value, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
