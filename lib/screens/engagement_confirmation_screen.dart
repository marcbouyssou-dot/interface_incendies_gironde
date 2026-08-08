import 'package:flutter/material.dart';

import '../models/need.dart';
import '../repositories/coordination_repository.dart';
import '../widgets/mission_location_details.dart';
import '../widgets/v5_controls.dart';

abstract final class _ConfirmationVisuals {
  static const background = Color(0xFFF6F7F8);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF7C817F);
  static const orange = Color(0xFFF25C05);
  static const orangeSoft = Color(0xFFFFE8D9);
}

class EngagementConfirmationScreen extends StatelessWidget {
  const EngagementConfirmationScreen({
    super.key,
    required this.need,
    this.location,
    this.result = EngagementCreationResult.created,
  });

  final CoordinationNeed need;
  final ResponsePlace? location;
  final EngagementCreationResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ConfirmationVisuals.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth <= 556
                ? 18.0
                : (constraints.maxWidth - 520) / 2;
            return CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      22,
                      horizontalPadding,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _ConfirmationVisuals.orangeSoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '❤️',
                              style: TextStyle(fontSize: 31),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Merci !',
                          style: TextStyle(
                            color: _ConfirmationVisuals.navy,
                            fontSize: 29,
                            height: 1.08,
                            letterSpacing: -0.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          result.existingMessage ??
                              'Votre engagement est confirmé.',
                          style: const TextStyle(
                            color: _ConfirmationVisuals.navy,
                            fontSize: 15,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (result ==
                            EngagementCreationResult.alreadyPending) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Une ancienne demande est encore en attente.',
                            style: TextStyle(
                              color: _ConfirmationVisuals.textMuted,
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 26),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(17),
                          decoration: BoxDecoration(
                            color: _ConfirmationVisuals.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _ConfirmationVisuals.border,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x08173052),
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ConfirmationDetail(
                                icon: Icons.location_on_outlined,
                                label: 'Lieu',
                                value: need.place,
                              ),
                              if (location?.verifiedAddress != null) ...[
                                const SizedBox(height: 9),
                                Padding(
                                  padding: const EdgeInsets.only(left: 52),
                                  child: LocationAddressLine(
                                    location: location,
                                  ),
                                ),
                              ],
                              const _ConfirmationDivider(),
                              _ConfirmationDetail(
                                icon: Icons.schedule_rounded,
                                label: 'Horaires',
                                value: need.time,
                              ),
                              const _ConfirmationDivider(),
                              _ConfirmationDetail(
                                icon: Icons.medical_services_outlined,
                                label: 'Matériel demandé',
                                value: need.equipment.join(' • '),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 24),
                        V5Button(
                          expanded: true,
                          onPressed: () => Navigator.pop(context),
                          backgroundColor: _ConfirmationVisuals.orange,
                          foregroundColor: Colors.white,
                          label: 'Retour aux interventions',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
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
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _ConfirmationVisuals.fieldBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _ConfirmationVisuals.navy, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: _ConfirmationVisuals.textMuted,
                  fontSize: 12,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: _ConfirmationVisuals.navy,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfirmationDivider extends StatelessWidget {
  const _ConfirmationDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 1, color: _ConfirmationVisuals.border),
    );
  }
}
