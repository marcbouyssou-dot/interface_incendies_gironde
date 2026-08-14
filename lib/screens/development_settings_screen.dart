import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../dev/role_preview.dart';
import '../theme/v5_foundation.dart';
import '../widgets/v5_secondary_navigation.dart';

class DevelopmentSettingsScreen extends StatelessWidget {
  const DevelopmentSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final controller = RolePreviewScope.of(context);
    final mode = kDebugMode ? controller.mode : RolePreviewMode.automatic;
    return Scaffold(
      appBar: const V5SecondaryNavigationBar(title: 'Réglages'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(V5Spacing.xl),
          children: [
            if (kDebugMode) ...[
              Text(
                'Mode Développement',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: V5Spacing.sm),
              Text(
                'Force uniquement le shell affiché. Les rôles, permissions et '
                'contrôles d’autorisation réels restent inchangés.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: V5Spacing.xl),
              DropdownButtonFormField<RolePreviewMode>(
                key: const Key('role-preview-selector'),
                initialValue: mode,
                decoration: const InputDecoration(
                  labelText: 'Parcours affiché',
                ),
                items: [
                  for (final option in RolePreviewMode.values)
                    DropdownMenuItem(value: option, child: Text(option.label)),
                ],
                onChanged: (value) {
                  if (value != null) controller.select(value);
                },
              ),
              const SizedBox(height: V5Spacing.xxl),
            ],
            if (!kDebugMode)
              Text(
                'Aucun réglage supplémentaire n’est disponible pour le moment.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}
