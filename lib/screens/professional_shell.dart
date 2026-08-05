import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../repositories/repository_scope.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/v5_bottom_navigation.dart';
import 'create_need_screen.dart';
import 'development_settings_screen.dart';
import 'slots_screen.dart';

class ProfessionalShell extends StatefulWidget {
  const ProfessionalShell({super.key, this.initialIndex = 0})
    : assert(initialIndex >= 0 && initialIndex < 3);

  final int initialIndex;

  @override
  State<ProfessionalShell> createState() => _ProfessionalShellState();
}

class _ProfessionalShellState extends State<ProfessionalShell> {
  late int _currentIndex;
  final List<Widget?> _screens = List<Widget?>.filled(3, null);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens[_currentIndex] = _createScreen(_currentIndex);
  }

  Widget _createScreen(int index) => switch (index) {
    0 => const SlotsScreen(professionalJourney: true),
    1 => const ProfessionalEngagementsScreen(),
    2 => ProfessionalProfileScreen(
      onOpenResponsibleAccess: _openResponsibleAccess,
      onOpenSettings: _openSettings,
    ),
    _ => throw RangeError.index(index, _screens),
  };

  void _selectTab(int index) {
    setState(() {
      _screens[index] ??= _createScreen(index);
      _currentIndex = index;
    });
  }

  void _openResponsibleAccess() {
    final repository = RepositoryScope.of(context);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: ResponsibleLogin(
              repository: repository,
              onSignedIn: () {
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      AppPageRoute<void>(builder: (_) => const DevelopmentSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.v5Colors.canvas,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: List.generate(
            _screens.length,
            (index) => _screens[index] ?? const SizedBox.shrink(),
          ),
        ),
      ),
      bottomNavigationBar: V5BottomNavigation(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
      ),
    );
  }
}

class ProfessionalEngagementsScreen extends StatelessWidget {
  const ProfessionalEngagementsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ProfessionalPlaceholderScreen(
    icon: Icons.volunteer_activism_outlined,
    title: 'Engagements',
    message: 'Vos engagements seront bientôt disponibles ici.',
  );
}

class ProfessionalProfileScreen extends StatelessWidget {
  const ProfessionalProfileScreen({
    super.key,
    required this.onOpenResponsibleAccess,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenResponsibleAccess;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => _ProfessionalPlaceholderScreen(
    icon: Icons.person_outline_rounded,
    title: 'Profil',
    message: 'Votre profil professionnel sera bientôt disponible ici.',
    footer: Column(
      children: [
        if (kDebugMode)
          OutlinedButton.icon(
            key: const Key('open-development-settings'),
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Réglages'),
          ),
        TextButton(
          key: const Key('open-responsible-access'),
          onPressed: onOpenResponsibleAccess,
          child: const Text('Accès responsable'),
        ),
      ],
    ),
  );
}

class _ProfessionalPlaceholderScreen extends StatelessWidget {
  const _ProfessionalPlaceholderScreen({
    required this.icon,
    required this.title,
    required this.message,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return ColoredBox(
      color: colors.canvas,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(V5Spacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: colors.textSecondary),
                const SizedBox(height: V5Spacing.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: V5Spacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
                if (footer != null) ...[
                  const SizedBox(height: V5Spacing.xl),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
