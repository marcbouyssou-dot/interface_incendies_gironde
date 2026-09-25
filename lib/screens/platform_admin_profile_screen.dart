import 'package:flutter/material.dart';

import '../services/platform_administration_service.dart';
import '../theme/platform_admin_identity.dart';
import '../theme/v5_foundation.dart';
import '../widgets/professional_page_header.dart';
import '../widgets/v5_controls.dart';

/// Minimal identity screen for the Platform Administrator role. Shows only
/// data already available from the authenticated session — no new backend
/// model, no fabricated fields. Sign-out stays a separate action in
/// [PlatformAdminMoreScreen]; this screen is identity-only.
class PlatformAdminProfileScreen extends StatelessWidget {
  const PlatformAdminProfileScreen({
    super.key,
    required this.administrationService,
  });

  final PlatformAdministrationService administrationService;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final accent = PlatformAdminIdentity.accent(context);
    final email = administrationService.currentUserEmail;
    return ColoredBox(
      color: colors.canvas,
      child: ListView(
        key: const PageStorageKey('platform-admin-profile'),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MobSantePageHeader(title: 'Mon profil'),
                  const SizedBox(height: V5Spacing.xxl),
                  Text(
                    'Identité',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  _ProfileGroup(
                    children: [
                      _ProfileLine(
                        label: 'Rôle',
                        value: 'Administrateur plateforme',
                        accent: accent,
                      ),
                      _ProfileLine(
                        label: 'Email',
                        value: email ?? 'Non renseigné',
                        accent: accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return SizedBox(
      width: double.infinity,
      child: V5Card(
        padding: EdgeInsets.zero,
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
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: V5Spacing.lg,
        vertical: V5Spacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: V5Spacing.lg),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
