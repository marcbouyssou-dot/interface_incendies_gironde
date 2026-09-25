import 'package:flutter/material.dart';

import '../services/platform_administration_service.dart';
import '../theme/platform_admin_identity.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/perspective_switcher.dart';
import '../widgets/v5_form_system.dart';
import 'notification_center_screen.dart';
import 'platform_admin_profile_screen.dart';

class PlatformAdminMoreScreen extends StatefulWidget {
  const PlatformAdminMoreScreen({
    super.key,
    required this.onSignOut,
    required this.administrationService,
  });

  final Future<void> Function() onSignOut;
  final PlatformAdministrationService administrationService;

  @override
  State<PlatformAdminMoreScreen> createState() =>
      _PlatformAdminMoreScreenState();
}

class _PlatformAdminMoreScreenState extends State<PlatformAdminMoreScreen> {
  bool _confirmationOpen = false;
  bool _signingOut = false;

  void _openNotifications() {
    final service = switch (widget.administrationService) {
      final TargetedPushTestService pushTestService => pushTestService,
      _ => null,
    };
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) =>
            NotificationCenterScreen(targetedPushTestService: service),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => PlatformAdminProfileScreen(
          administrationService: widget.administrationService,
        ),
      ),
    );
  }

  Future<void> _requestSignOut() async {
    if (_confirmationOpen || _signingOut) return;
    setState(() => _confirmationOpen = true);
    final confirmed = await showV5Confirmation(
      context: context,
      title: 'Se déconnecter ?',
      message:
          'Vous devrez vous authentifier à nouveau pour accéder à '
          'l’administration de la plateforme.',
      confirmLabel: 'Se déconnecter',
      barrierDismissible: false,
      confirmKey: const Key('confirm-platform-admin-sign-out'),
    );
    if (mounted) setState(() => _confirmationOpen = false);
    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } catch (_) {
      if (mounted) {
        V5Toast.show(
          context,
          message: 'La déconnexion a échoué. Réessayez.',
          tone: V5ToastTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final accent = PlatformAdminIdentity.accent(context);
    return ColoredBox(
      color: colors.canvas,
      child: ListView(
        key: const PageStorageKey('platform-admin-more'),
        padding: const EdgeInsets.fromLTRB(
          V5Spacing.lg,
          V5Spacing.lg,
          V5Spacing.lg,
          V5Spacing.xxl,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Administrateur',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: V5Spacing.sm),
                        Text(
                          'Plus',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: V5Spacing.xs),
                        Text(
                          'Gérez votre session et prévisualisez les parcours.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: V5Spacing.xxl),
                  const PlatformAdminPerspectiveSection(),
                  const SizedBox(height: V5Spacing.xxl),
                  _MoreGroup(
                    accent: accent,
                    children: [
                      _MoreRow(
                        key: const Key('platform-admin-notifications'),
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        accent: accent,
                        onTap: _openNotifications,
                      ),
                      _MoreRow(
                        key: const Key('platform-admin-profile'),
                        icon: Icons.person_outline_rounded,
                        label: 'Profil',
                        accent: accent,
                        onTap: _openProfile,
                      ),
                    ],
                  ),
                  const SizedBox(height: V5Spacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      key: const Key('platform-admin-sign-out'),
                      onPressed: _confirmationOpen || _signingOut
                          ? null
                          : _requestSignOut,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: colors.textSecondary,
                      ),
                      child: Text(
                        _signingOut ? 'Déconnexion…' : 'Se déconnecter',
                      ),
                    ),
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

class _MoreGroup extends StatelessWidget {
  const _MoreGroup({required this.children, required this.accent});

  final List<Widget> children;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
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
                indent: 54,
                color: colors.outline,
              ),
          ],
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: V5Spacing.md),
            child: Row(
              children: [
                Icon(icon, size: 20, color: accent),
                const SizedBox(width: V5Spacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
