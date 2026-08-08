import 'package:flutter/material.dart';

import '../models/admin_location.dart';
import '../models/need.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/location_administration_repository.dart';
import '../repositories/location_administration_repository_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import '../utils/app_page_route.dart';
import '../widgets/v5_controls.dart';
import '../widgets/v5_form_system.dart';
import '../widgets/v5_secondary_navigation.dart';
import 'admin_location_form_screen.dart';

abstract final class _LocationAdminVisuals {
  static const background = Color(0xFFF6F7F8);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF7C817F);
  static const orange = Color(0xFFF25C05);
}

enum _LocationStatusFilter { all, active, inactive }

const _allFilters = 'all';

class LocationAdministrationScreen extends StatefulWidget {
  const LocationAdministrationScreen({super.key});

  @override
  State<LocationAdministrationScreen> createState() =>
      _LocationAdministrationScreenState();
}

class _LocationAdministrationScreenState
    extends State<LocationAdministrationScreen> {
  CoordinationRepository? _coordinationRepository;
  LocationAdministrationRepository? _repository;
  Stream<ResponsibleAccess?>? _access;
  Future<List<AdminLocation>>? _locations;
  String _query = '';
  TerritorialGroup? _group;
  ResponsePlaceType? _type;
  _LocationStatusFilter _status = _LocationStatusFilter.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coordinationRepository = RepositoryScope.of(context);
    final repository = LocationAdministrationRepositoryScope.of(context);
    if (!identical(coordinationRepository, _coordinationRepository) ||
        !identical(repository, _repository)) {
      _coordinationRepository = coordinationRepository;
      _repository = repository;
      _access = coordinationRepository.watchResponsibleAccess();
      _locations = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LocationAdminVisuals.background,
      appBar: const V5SecondaryNavigationBar(title: 'Lieux'),
      body: SafeArea(
        top: false,
        child: StreamBuilder<ResponsibleAccess?>(
          stream: _access,
          builder: (context, accessSnapshot) {
            if (accessSnapshot.hasError) {
              return _AccessRefused(onRetry: _retryAccess);
            }
            if (!accessSnapshot.hasData &&
                accessSnapshot.connectionState == ConnectionState.waiting) {
              return const _LocationAdminLoading();
            }
            final access = accessSnapshot.data;
            if (access == null || !access.active || !access.isCoordinator) {
              return const _AccessRefused();
            }
            _locations ??= _repository!.listLocations();
            return FutureBuilder<List<AdminLocation>>(
              future: _locations,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _LoadError(onRetry: _reload);
                }
                if (!snapshot.hasData) {
                  return const _LocationAdminLoading();
                }
                return _content(snapshot.data!);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _content(List<AdminLocation> locations) {
    final filtered = locations
        .where((location) {
          final search = _normalize(
            '${location.name} ${location.id} ${location.addressLabel}',
          );
          if (_query.isNotEmpty && !search.contains(_normalize(_query))) {
            return false;
          }
          if (_group != null && location.group != _group) return false;
          if (_type != null && location.type != _type) return false;
          return switch (_status) {
            _LocationStatusFilter.all => true,
            _LocationStatusFilter.active => location.active,
            _LocationStatusFilter.inactive => !location.active,
          };
        })
        .toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth <= 596
            ? 18.0
            : (constraints.maxWidth - 560) / 2;
        return RefreshIndicator(
          color: _LocationAdminVisuals.orange,
          onRefresh: _reload,
          child: ListView(
            key: const Key('admin-location-list'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              36,
            ),
            children: [
              _LocationAdminHeader(onCreate: _openCreate),
              const SizedBox(height: 20),
              V5Section(
                title: 'Filtres',
                leading: const Icon(Icons.tune_rounded),
                child: Column(
                  children: [
                    V5TextField(
                      key: const Key('admin-location-search'),
                      label: 'Rechercher un lieu',
                      prefixIcon: const Icon(Icons.search_rounded),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 12),
                    _groupFilter(),
                    const SizedBox(height: 9),
                    _typeFilter(),
                    const SizedBox(height: 9),
                    _statusFilter(),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                '${filtered.length} lieu${filtered.length > 1 ? 'x' : ''}',
                key: const Key('admin-location-result-count'),
                style: const TextStyle(
                  color: _LocationAdminVisuals.navy,
                  fontSize: 19,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 11),
              if (filtered.isEmpty) const _EmptyLocationAdminState(),
              for (final location in filtered) ...[
                _LocationCard(
                  location: location,
                  onEdit: () => _openEdit(location),
                  onToggle: () => _toggle(location),
                  onDelete: location.canDelete ? () => _delete(location) : null,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _groupFilter() => V5SelectField<String>(
    key: const Key('admin-location-group-filter'),
    label: 'Territoire',
    value: _group?.name ?? _allFilters,
    leading: const Icon(Icons.map_outlined),
    options: [
      const V5SelectOption(value: _allFilters, label: 'Tous les territoires'),
      for (final value in TerritorialGroup.values)
        V5SelectOption(value: value.name, label: value.label),
    ],
    onChanged: (value) => setState(
      () => _group = value == _allFilters
          ? null
          : TerritorialGroup.values
                .where((candidate) => candidate.name == value)
                .firstOrNull,
    ),
  );

  Widget _typeFilter() => V5SelectField<String>(
    key: const Key('admin-location-type-filter'),
    label: 'Type de lieu',
    value: _type?.name ?? _allFilters,
    leading: const Icon(Icons.category_outlined),
    options: [
      const V5SelectOption(value: _allFilters, label: 'Tous les types'),
      for (final value in ResponsePlaceType.values)
        V5SelectOption(value: value.name, label: value.label),
    ],
    onChanged: (value) => setState(
      () => _type = value == _allFilters
          ? null
          : ResponsePlaceType.values
                .where((candidate) => candidate.name == value)
                .firstOrNull,
    ),
  );

  Widget _statusFilter() => V5SelectField<_LocationStatusFilter>(
    key: const Key('admin-location-status-filter'),
    label: 'Statut',
    value: _status,
    leading: const Icon(Icons.toggle_on_outlined),
    options: const [
      V5SelectOption(
        value: _LocationStatusFilter.all,
        label: 'Tous les statuts',
      ),
      V5SelectOption(value: _LocationStatusFilter.active, label: 'Actifs'),
      V5SelectOption(
        value: _LocationStatusFilter.inactive,
        label: 'Désactivés',
      ),
    ],
    onChanged: (value) {
      if (value != null) setState(() => _status = value);
    },
  );

  Future<void> _openCreate() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(AppPageRoute(builder: (_) => const AdminLocationFormScreen()));
    if (changed == true) await _reload();
  }

  Future<void> _openEdit(AdminLocation location) async {
    final changed = await Navigator.of(context).push<bool>(
      AppPageRoute(builder: (_) => AdminLocationFormScreen(location: location)),
    );
    if (changed == true) await _reload();
  }

  Future<void> _toggle(AdminLocation location) async {
    final active = !location.active;
    if (!await _confirm(
      title: active ? 'Réactiver ce lieu ?' : 'Désactiver ce lieu ?',
      message: active
          ? 'Le lieu sera de nouveau proposé pour les nouveaux besoins.'
          : 'Le lieu restera visible dans les missions existantes.',
      action: active ? 'Réactiver' : 'Désactiver',
    )) {
      return;
    }
    await _runMutation(
      () => _repository!.setLocationActive(
        locationId: location.id,
        active: active,
      ),
      active ? 'Lieu réactivé.' : 'Lieu désactivé.',
    );
  }

  Future<void> _delete(AdminLocation location) async {
    if (!await _confirm(
      title: 'Supprimer définitivement ce lieu ?',
      message:
          'Cette opération est irréversible. Aucun historique ne sera supprimé.',
      action: 'Supprimer',
      destructive: true,
    )) {
      return;
    }
    await _runMutation(
      () => _repository!.deleteLocation(location.id),
      'Lieu supprimé.',
    );
  }

  Future<void> _runMutation(
    Future<Object?> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (!mounted) return;
      V5Toast.show(context, message: success, tone: V5ToastTone.success);
      await _reload();
    } on LocationAdministrationException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) _showError('L’opération a échoué. Réessayez.');
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async =>
      await showV5Confirmation(
        context: context,
        title: title,
        message: message,
        confirmLabel: action,
        cancelLabel: 'Retour',
        destructive: destructive,
      ) ??
      false;

  Future<void> _reload() async {
    final locations = _repository!.listLocations();
    setState(() {
      _locations = locations;
    });
    try {
      await locations;
    } catch (_) {
      // The FutureBuilder presents the explicit retry state.
    }
  }

  void _retryAccess() {
    setState(() => _access = _coordinationRepository!.watchResponsibleAccess());
  }

  void _showError(String message) {
    V5Toast.show(context, message: message, tone: V5ToastTone.danger);
  }
}

class _LocationAdminHeader extends StatelessWidget {
  const _LocationAdminHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ADMINISTRATION',
          style: TextStyle(
            color: _LocationAdminVisuals.textMuted,
            fontSize: 12,
            letterSpacing: 1.25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Gestion des lieux',
          style: TextStyle(
            color: _LocationAdminVisuals.navy,
            fontSize: 27,
            height: 1.12,
            letterSpacing: -0.7,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Centres actifs et lieux historiques',
          style: TextStyle(
            color: _LocationAdminVisuals.textMuted,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 17),
        V5Button(
          key: const Key('admin-location-create'),
          expanded: true,
          backgroundColor: _LocationAdminVisuals.orange,
          foregroundColor: Colors.white,
          icon: Icons.add_location_alt_outlined,
          onPressed: onCreate,
          label: 'Créer un lieu',
        ),
      ],
    );
  }
}

class _EmptyLocationAdminState extends StatelessWidget {
  const _EmptyLocationAdminState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _locationAdminCardDecoration(),
      child: const Column(
        children: [
          Icon(
            Icons.location_off_outlined,
            color: _LocationAdminVisuals.textMuted,
            size: 34,
          ),
          SizedBox(height: 11),
          Text(
            'Aucun lieu ne correspond aux filtres.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _LocationAdminVisuals.navy,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationAdminLoading extends StatelessWidget {
  const _LocationAdminLoading();

  @override
  Widget build(BuildContext context) {
    return const V5LoadingState(label: 'Chargement des lieux…');
  }
}

BoxDecoration _locationAdminCardDecoration({Color? color}) {
  return BoxDecoration(
    color: color ?? _LocationAdminVisuals.surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _LocationAdminVisuals.border),
    boxShadow: const [
      BoxShadow(color: Color(0x08173052), blurRadius: 12, offset: Offset(0, 3)),
    ],
  );
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final AdminLocation location;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('admin-location-${location.id}'),
      decoration: _locationAdminCardDecoration(
        color: location.active
            ? _LocationAdminVisuals.surface
            : _LocationAdminVisuals.fieldBackground,
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    location.name,
                    style: const TextStyle(
                      color: _LocationAdminVisuals.navy,
                      fontSize: 17,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(active: location.active),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: _LocationAdminVisuals.border),
            ),
            _LocationAdminDetail(
              icon: Icons.location_on_outlined,
              value: location.addressLabel,
            ),
            const SizedBox(height: 8),
            _LocationAdminDetail(
              icon: Icons.map_outlined,
              value: location.group.label,
            ),
            const SizedBox(height: 8),
            _LocationAdminDetail(
              icon: Icons.category_outlined,
              value: location.type.label,
            ),
            if (!location.isOperational) ...[
              const SizedBox(height: 10),
              const Text(
                'Lieu non opérationnel dans le référentiel',
                style: TextStyle(
                  color: _LocationAdminVisuals.orange,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _LocationAdminVisuals.navy,
                  side: const BorderSide(color: _LocationAdminVisuals.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                icon: const Icon(Icons.edit_outlined, size: 19),
                label: const Text('Modifier'),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  key: Key('admin-location-toggle-${location.id}'),
                  onPressed: onToggle,
                  icon: Icon(
                    location.active
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: 18,
                  ),
                  label: Text(location.active ? 'Désactiver' : 'Réactiver'),
                ),
                if (onDelete != null)
                  TextButton.icon(
                    key: Key('admin-location-delete-${location.id}'),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer'),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Lieu utilisé : désactivation uniquement',
                      style: TextStyle(
                        color: _LocationAdminVisuals.textMuted,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationAdminDetail extends StatelessWidget {
  const _LocationAdminDetail({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _LocationAdminVisuals.textMuted, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _LocationAdminVisuals.navy,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: active ? AppColors.greenSoft : _LocationAdminVisuals.surface,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: active
            ? AppColors.green.withValues(alpha: .22)
            : _LocationAdminVisuals.border,
      ),
    ),
    child: Text(
      active ? 'Actif' : 'Désactivé',
      style: TextStyle(
        color: active ? AppColors.green : AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _LocationAdminMessageState(
    icon: Icons.cloud_off_outlined,
    message: 'Les lieux ne sont pas disponibles.',
    action: V5Button(
      expanded: true,
      onPressed: onRetry,
      backgroundColor: _LocationAdminVisuals.orange,
      foregroundColor: Colors.white,
      label: 'Réessayer',
    ),
  );
}

class _LocationAdminMessageState extends StatelessWidget {
  const _LocationAdminMessageState({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _LocationAdminVisuals.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: _locationAdminCardDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: _LocationAdminVisuals.textMuted, size: 36),
                  const SizedBox(height: 13),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _LocationAdminVisuals.navy,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: action),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessRefused extends StatelessWidget {
  const _AccessRefused({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _LocationAdminMessageState(
    icon: Icons.lock_outline_rounded,
    message: 'Accès coordinateur actif requis.',
    action: onRetry == null
        ? null
        : V5Button(
            expanded: true,
            onPressed: onRetry,
            backgroundColor: _LocationAdminVisuals.orange,
            foregroundColor: Colors.white,
            label: 'Réessayer',
          ),
  );
}

String _normalize(String value) {
  const replacements = <String, String>{
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'œ': 'oe',
    'æ': 'ae',
  };
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final character = String.fromCharCode(rune);
    buffer.write(replacements[character] ?? character);
  }
  return buffer.toString();
}
