import 'package:flutter/material.dart';

import '../models/need.dart';
import '../repositories/coordination_repository.dart';
import '../theme/app_theme.dart';

class EngagementConfirmationScreen extends StatelessWidget {
  const EngagementConfirmationScreen({
    super.key,
    required this.need,
    this.result = EngagementCreationResult.created,
  });

  final CoordinationNeed need;
  final EngagementCreationResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  const Text('❤️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(
                    'Merci !',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.existingMessage ?? 'Votre engagement est confirmé.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (result == EngagementCreationResult.alreadyPending) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Une ancienne demande est encore en attente.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ConfirmationDetail(
                            icon: Icons.location_on_outlined,
                            label: 'Lieu',
                            value: need.place,
                          ),
                          const SizedBox(height: 18),
                          _ConfirmationDetail(
                            icon: Icons.schedule_rounded,
                            label: 'Horaires',
                            value: need.time,
                          ),
                          const SizedBox(height: 18),
                          _ConfirmationDetail(
                            icon: Icons.medical_services_outlined,
                            label: 'Matériel demandé',
                            value: need.equipment.join(' • '),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Retour aux interventions'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmationDetail extends StatelessWidget {
  const _ConfirmationDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.orange, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 3),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}
