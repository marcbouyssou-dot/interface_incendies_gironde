import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/professional_page_header.dart';
import '../widgets/v5_controls.dart';
import 'development_settings_screen.dart';

class ResponsibleProfileScreen extends StatefulWidget {
  const ResponsibleProfileScreen({super.key, this.previewLocationId});

  final String? previewLocationId;

  @override
  State<ResponsibleProfileScreen> createState() =>
      _ResponsibleProfileScreenState();
}

class _ResponsibleProfileScreenState extends State<ResponsibleProfileScreen> {
  LiveCoordinationData? _liveData;
  Stream<ResponsibleAccess?>? _access;
  Stream<List<ResponsePlace>>? _locations;
  bool _signingOut = false;

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
    return StreamBuilder<ResponsibleAccess?>(
      stream: _access,
      builder: (context, accessSnapshot) => StreamBuilder<List<ResponsePlace>>(
        stream: _locations,
        builder: (context, locationsSnapshot) {
          if (accessSnapshot.hasError || locationsSnapshot.hasError) {
            return const _ProfileMessage(
              message: 'Le profil est temporairement indisponible.',
            );
          }
          if (!locationsSnapshot.hasData) {
            return const Center(
              child: SizedBox.square(
                dimension: 22,
                child: V5ActivityIndicator(),
              ),
            );
          }
          return _ResponsibleProfileContent(
            access: accessSnapshot.data,
            locations: locationsSnapshot.data!,
            signingOut: _signingOut,
            onOpenSettings: _openSettings,
            onSignOut: _signOut,
            previewLocationId: widget.previewLocationId,
          );
        },
      ),
    );
  }

  void _openSettings() {
    final liveData = LiveCoordinationDataScope.of(context);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: const DevelopmentSettingsScreen(),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await RepositoryScope.of(context).signOutResponsible();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }
}

class _ResponsibleProfileContent extends StatelessWidget {
  const _ResponsibleProfileContent({
    required this.access,
    required this.locations,
    required this.signingOut,
    required this.onOpenSettings,
    required this.onSignOut,
    required this.previewLocationId,
  });

  final ResponsibleAccess? access;
  final List<ResponsePlace> locations;
  final bool signingOut;
  final VoidCallback onOpenSettings;
  final VoidCallback onSignOut;
  final String? previewLocationId;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final locationById = {
      for (final location in locations) location.id: location,
    };
    final perimeter = previewLocationId != null
        ? [locationById[previewLocationId]?.name ?? 'Centre sélectionné']
        : access == null
        ? const <String>[]
        : access!.isCoordinator
        ? const ['Tous les centres — accès Coordinateur']
        : [
            for (final id in access!.locationIds)
              locationById[id]?.name ?? 'Centre attribué',
          ];
    return ColoredBox(
      color: colors.canvas,
      child: ListView(
        key: const PageStorageKey('responsible-profile'),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MobSantePageHeader(title: 'Mon profil responsable'),
                  const SizedBox(height: V5Spacing.xxl),
                  Text(
                    'Centre géré',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  _ProfileGroup(
                    children: perimeter.isEmpty
                        ? const [
                            _ProfileLine(
                              label: 'Centre',
                              value: 'Aucun périmètre attribué',
                            ),
                          ]
                        : [
                            for (final location in perimeter)
                              _ProfileLine(label: 'Centre', value: location),
                          ],
                  ),
                  const SizedBox(height: V5Spacing.xxl),
                  if (kDebugMode) ...[
                    OutlinedButton(
                      key: const Key('responsible-development-settings'),
                      onPressed: onOpenSettings,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: colors.accent,
                        side: BorderSide(color: colors.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(V5Radius.control),
                        ),
                      ),
                      child: const Text('Réglages'),
                    ),
                    const SizedBox(height: V5Spacing.md),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      key: const Key('responsible-sign-out'),
                      onPressed: signingOut ? null : onSignOut,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: colors.textSecondary,
                      ),
                      child: Text(
                        signingOut ? 'Déconnexion…' : 'Se déconnecter',
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

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      width: double.infinity,
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
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.label, required this.value});

  final String label;
  final String value;

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
                color: context.v5Colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(V5Spacing.xl),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    ),
  );
}
