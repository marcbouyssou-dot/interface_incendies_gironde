import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/responsible_access.dart';
import '../perspective/cross_role_perspective.dart';
import '../theme/v5_foundation.dart';
import 'native_interactions.dart';

class SiteManagerPerspectiveSection extends StatelessWidget {
  const SiteManagerPerspectiveSection({super.key, this.title = 'Voir comme'});

  final String title;

  @override
  Widget build(BuildContext context) {
    final controller = CrossRolePerspectiveScope.of(context);
    final accent = context.v5Colors.accent;
    return PerspectiveSection(
      title: title,
      children: [
        PerspectiveOption(
          key: const Key('perspective-site-manager'),
          label: 'Responsable de centre',
          selected: controller.perspective != CrossRolePerspective.professional,
          onTap: controller.showActualRole,
          accentColor: accent,
        ),
        PerspectiveOption(
          key: const Key('perspective-professional'),
          label: 'Professionnel',
          selected: controller.perspective == CrossRolePerspective.professional,
          onTap: controller.showProfessional,
          accentColor: accent,
        ),
      ],
    );
  }
}

class CoordinatorPerspectiveSection extends StatelessWidget {
  const CoordinatorPerspectiveSection({
    super.key,
    required this.access,
    required this.locations,
    this.onSelectionComplete,
    this.accentColor,
    this.title = 'Changer de perspective',
  });

  final ResponsibleAccess access;
  final List<ResponsePlace> locations;
  final VoidCallback? onSelectionComplete;
  final Color? accentColor;
  final String title;

  @override
  Widget build(BuildContext context) {
    final controller = CrossRolePerspectiveScope.of(context);
    return PerspectiveSection(
      title: title,
      children: [
        PerspectiveOption(
          key: const Key('perspective-coordinator'),
          label: 'Coordinateur',
          selected: controller.perspective == CrossRolePerspective.actual,
          accentColor: accentColor,
          onTap: () {
            controller.showActualRole();
            onSelectionComplete?.call();
          },
        ),
        PerspectiveOption(
          key: const Key('perspective-responsible'),
          label: 'Responsable de centre',
          selected: controller.perspective == CrossRolePerspective.responsible,
          accentColor: accentColor,
          onTap: () => _selectResponsibleCenter(context, controller),
        ),
        PerspectiveOption(
          key: const Key('perspective-professional'),
          label: 'Professionnel',
          selected: controller.perspective == CrossRolePerspective.professional,
          accentColor: accentColor,
          onTap: () {
            controller.showProfessional();
            onSelectionComplete?.call();
          },
        ),
      ],
    );
  }

  Future<void> _selectResponsibleCenter(
    BuildContext context,
    CrossRolePerspectiveController controller,
  ) async {
    final location = await showResponsibleCenterPicker(
      context,
      access: access,
      locations: locations,
      selectedLocationId: controller.responsibleLocationId,
      accentColor: accentColor,
    );
    if (location != null) {
      controller.showResponsible(location.id);
      onSelectionComplete?.call();
    }
  }
}

class PerspectiveSection extends StatelessWidget {
  const PerspectiveSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: V5Spacing.sm),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(V5Radius.card),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: V5Spacing.lg,
                    color: colors.outline,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class PerspectiveOption extends StatelessWidget {
  const PerspectiveOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: V5Spacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: accentColor ?? colors.info,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CrossRolePreviewBanner extends StatelessWidget {
  const CrossRolePreviewBanner({
    super.key,
    required this.label,
    required this.onExit,
    this.onChange,
    this.exitLabel = 'Revenir',
    this.accentColor,
    this.containerColor,
    this.compact = false,
    this.title,
  });

  final String label;
  final VoidCallback onExit;
  final VoidCallback? onChange;
  final String exitLabel;
  final Color? accentColor;
  final Color? containerColor;
  final bool compact;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    if (compact) {
      return Container(
        key: const Key('cross-role-preview-banner'),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.fromLTRB(12, 5, 4, 5),
        decoration: BoxDecoration(
          color: containerColor ?? colors.surfaceElevated,
          borderRadius: BorderRadius.circular(V5Radius.control),
          border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 17,
              color: accentColor ?? colors.info,
            ),
            const SizedBox(width: V5Spacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title ?? 'Perspective Professionnel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Rôle réel : $label',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textSecondary,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onChange != null)
              TextButton(
                key: const Key('change-preview-center'),
                onPressed: onChange,
                style: TextButton.styleFrom(
                  foregroundColor: accentColor ?? colors.info,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Changer'),
              ),
            TextButton(
              key: const Key('exit-cross-role-preview'),
              onPressed: onExit,
              style: TextButton.styleFrom(
                foregroundColor: accentColor ?? colors.info,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(exitLabel),
            ),
          ],
        ),
      );
    }
    return ColoredBox(
      key: const Key('cross-role-preview-banner'),
      color: containerColor ?? colors.infoContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
          child: Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 16,
                color: accentColor ?? colors.info,
              ),
              const SizedBox(width: V5Spacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: colors.textPrimary),
                ),
              ),
              if (onChange != null)
                TextButton(
                  key: const Key('change-preview-center'),
                  onPressed: onChange,
                  style: accentColor == null
                      ? null
                      : TextButton.styleFrom(foregroundColor: accentColor),
                  child: const Text('Changer'),
                ),
              TextButton(
                key: const Key('exit-cross-role-preview'),
                onPressed: onExit,
                style: accentColor == null
                    ? null
                    : TextButton.styleFrom(foregroundColor: accentColor),
                child: Text(exitLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<ResponsePlace?> showResponsibleCenterPicker(
  BuildContext context, {
  required ResponsibleAccess access,
  required List<ResponsePlace> locations,
  String? selectedLocationId,
  Color? accentColor,
}) {
  final allowedLocations =
      locations
          .where((location) => access.canManage(location.id))
          .toList(growable: false)
        ..sort((first, second) => first.name.compareTo(second.name));
  return showNativeBottomSheet<ResponsePlace>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: context.v5Colors.surfaceElevated,
    builder: (sheetContext) => ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 620),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Text(
              'Choisir un centre',
              style: Theme.of(sheetContext).textTheme.headlineSmall,
            ),
          ),
          if (allowedLocations.isEmpty)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(V5Spacing.xl),
                  child: Text('Aucun centre autorisé.'),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                key: const Key('responsible-center-picker'),
                padding: const EdgeInsets.only(bottom: V5Spacing.lg),
                itemCount: allowedLocations.length,
                itemBuilder: (context, index) {
                  final location = allowedLocations[index];
                  final selected = location.id == selectedLocationId;
                  return ListTile(
                    key: Key('preview-center-${location.id}'),
                    minTileHeight: 52,
                    title: Text(location.name),
                    trailing: selected
                        ? Icon(
                            Icons.check_rounded,
                            color: accentColor ?? context.v5Colors.info,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(location),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}
