import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../dev/role_preview.dart';
import '../models/need.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/coordinator_identity.dart';
import '../theme/v5_foundation.dart';
import '../widgets/perspective_switcher.dart';
import '../widgets/v5_controls.dart';
import '../widgets/v5_secondary_navigation.dart';

class DevelopmentSettingsScreen extends StatefulWidget {
  const DevelopmentSettingsScreen({super.key});

  @override
  State<DevelopmentSettingsScreen> createState() =>
      _DevelopmentSettingsScreenState();
}

class _DevelopmentSettingsScreenState extends State<DevelopmentSettingsScreen> {
  LiveCoordinationData? _liveData;
  Stream<ResponsibleAccess?>? _access;
  Stream<List<ResponsePlace>>? _locations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liveData = LiveCoordinationDataScope.of(context);
    if (identical(liveData, _liveData)) return;
    _liveData = liveData;
    _access = liveData.watchResponsibleAccess();
    _locations = liveData.watchLocations();
  }

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
            StreamBuilder<ResponsibleAccess?>(
              stream: _access,
              builder: (context, accessSnapshot) =>
                  StreamBuilder<List<ResponsePlace>>(
                    stream: _locations,
                    builder: (context, locationsSnapshot) {
                      final access = accessSnapshot.data;
                      if (access?.isCoordinator != true ||
                          !locationsSnapshot.hasData) {
                        if (!kDebugMode &&
                            (accessSnapshot.connectionState ==
                                    ConnectionState.waiting ||
                                locationsSnapshot.connectionState ==
                                    ConnectionState.waiting)) {
                          return const Center(child: V5ActivityIndicator());
                        }
                        if (!kDebugMode && access?.isSiteManager == true) {
                          return Text(
                            'Aucun réglage supplémentaire n’est disponible '
                            'pour le moment.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          );
                        }
                        return const SizedBox.shrink();
                      }
                      return CoordinatorPerspectiveSection(
                        access: access!,
                        locations: locationsSnapshot.data!,
                        accentColor: CoordinatorIdentity.of(context).accent,
                        onSelectionComplete: () => Navigator.of(context).pop(),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
