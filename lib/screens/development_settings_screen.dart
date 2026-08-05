import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../dev/role_preview.dart';
import '../theme/v5_foundation.dart';

class DevelopmentSettingsScreen extends StatelessWidget {
  const DevelopmentSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final controller = RolePreviewScope.of(context);
    final mode = kDebugMode ? controller.mode : RolePreviewMode.automatic;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(V5Spacing.xl),
          children: [
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
            if (kDebugMode)
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
              )
            else
              const Text('Disponible uniquement dans une build de debug.'),
          ],
        ),
      ),
    );
  }
}
