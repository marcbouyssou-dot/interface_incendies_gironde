import 'package:flutter/material.dart';

import '../services/operational_context_provider.dart';
import '../theme/v5_foundation.dart';
import '../utils/operation_presentation.dart';

class MissionOperationContextBadge extends StatelessWidget {
  const MissionOperationContextBadge({
    super.key,
    required this.mobilizationId,
    this.showLegacy = false,
  });

  final String? mobilizationId;
  final bool showLegacy;

  @override
  Widget build(BuildContext context) {
    final provider = OperationalContextScope.maybeOf(context);
    final id = mobilizationId;
    if (provider == null || id == null || id.isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<OperationalMissionContext?>(
      stream: provider.watchForMobilization(id),
      builder: (context, snapshot) {
        final operationalContext = snapshot.data;
        if (snapshot.hasError || operationalContext == null) {
          return const SizedBox.shrink();
        }
        if (operationalContext.isLegacy && !showLegacy) {
          return const SizedBox.shrink();
        }
        final label =
            operationalContext.operationName ??
            (showLegacy ? 'Mobilisation historique' : null);
        if (label == null) return const SizedBox.shrink();
        final type = operationalContext.operationType;
        final semanticLabel = type == null
            ? 'Contexte : $label'
            : 'Contexte : $label, ${operationTypeLabel(type)}';
        return Semantics(
          label: semanticLabel,
          child: ExcludeSemantics(
            child: Container(
              key: Key('mission-operation-context-$id'),
              padding: const EdgeInsets.symmetric(
                horizontal: V5Spacing.sm,
                vertical: V5Spacing.xxs,
              ),
              decoration: BoxDecoration(
                color: context.v5Colors.infoContainer,
                borderRadius: BorderRadius.circular(V5Radius.pill),
              ),
              child: Text(
                type == null ? label : '$label · ${operationTypeLabel(type)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.v5Colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
