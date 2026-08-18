import 'package:flutter/material.dart';

import '../theme/platform_admin_identity.dart';
import '../theme/v5_foundation.dart';
import '../widgets/perspective_switcher.dart';
import '../widgets/v5_controls.dart';
import '../widgets/v5_form_system.dart';

class PlatformAdminMoreScreen extends StatefulWidget {
  const PlatformAdminMoreScreen({super.key, required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  State<PlatformAdminMoreScreen> createState() =>
      _PlatformAdminMoreScreenState();
}

class _PlatformAdminMoreScreenState extends State<PlatformAdminMoreScreen> {
  bool _confirmationOpen = false;
  bool _signingOut = false;

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
                  V5Section(
                    title: 'Session',
                    leading: Icon(Icons.lock_outline_rounded, color: accent),
                    child: V5Button(
                      key: const Key('platform-admin-sign-out'),
                      expanded: true,
                      onPressed: _confirmationOpen || _signingOut
                          ? null
                          : _requestSignOut,
                      label: _signingOut ? 'Déconnexion…' : 'Se déconnecter',
                      icon: Icons.logout_rounded,
                      tone: V5ButtonTone.secondary,
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
