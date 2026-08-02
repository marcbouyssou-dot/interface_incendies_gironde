import 'package:flutter/material.dart';

import '../models/admin_location.dart';
import '../models/need.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/location_administration_repository.dart';
import '../repositories/location_administration_repository_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import '../utils/app_page_route.dart';
import 'admin_location_form_screen.dart';

enum _LocationStatusFilter { all, active, inactive }

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
      appBar: AppBar(title: const Text('Lieux')),
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
              return const Center(child: CircularProgressIndicator());
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
                  return const Center(child: CircularProgressIndicator());
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
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        key: const Key('admin-location-list'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          FilledButton.icon(
            key: const Key('admin-location-create'),
            onPressed: _openCreate,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Créer un lieu'),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('admin-location-search'),
            decoration: const InputDecoration(
              labelText: 'Rechercher un lieu',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          Column(children: [_groupFilter(), _typeFilter(), _statusFilter()]),
          const SizedBox(height: 14),
          Text(
            '${filtered.length} lieu${filtered.length > 1 ? 'x' : ''}',
            key: const Key('admin-location-result-count'),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Aucun lieu ne correspond aux filtres.'),
              ),
            ),
          for (final location in filtered) ...[
            _LocationCard(
              location: location,
              onEdit: () => _openEdit(location),
              onToggle: () => _toggle(location),
              onDelete: location.canDelete ? () => _delete(location) : null,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _groupFilter() => SizedBox(
    width: double.infinity,
    child: DropdownButton<TerritorialGroup?>(
      key: const Key('admin-location-group-filter'),
      value: _group,
      isExpanded: true,
      hint: const Text('Tous les territoires'),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('Tous les territoires'),
        ),
        for (final value in TerritorialGroup.values)
          DropdownMenuItem(value: value, child: Text(value.label)),
      ],
      onChanged: (value) => setState(() => _group = value),
    ),
  );

  Widget _typeFilter() => SizedBox(
    width: double.infinity,
    child: DropdownButton<ResponsePlaceType?>(
      key: const Key('admin-location-type-filter'),
      value: _type,
      isExpanded: true,
      hint: const Text('Tous les types'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Tous les types')),
        for (final value in ResponsePlaceType.values)
          DropdownMenuItem(value: value, child: Text(value.label)),
      ],
      onChanged: (value) => setState(() => _type = value),
    ),
  );

  Widget _statusFilter() => SizedBox(
    width: double.infinity,
    child: DropdownButton<_LocationStatusFilter>(
      key: const Key('admin-location-status-filter'),
      value: _status,
      isExpanded: true,
      items: const [
        DropdownMenuItem(
          value: _LocationStatusFilter.all,
          child: Text('Tous les statuts'),
        ),
        DropdownMenuItem(
          value: _LocationStatusFilter.active,
          child: Text('Actifs'),
        ),
        DropdownMenuItem(
          value: _LocationStatusFilter.inactive,
          child: Text('Désactivés'),
        ),
      ],
      onChanged: (value) => setState(() => _status = value!),
    ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
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
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Retour'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
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
    return Card(
      key: Key('admin-location-${location.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    location.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusBadge(active: location.active),
              ],
            ),
            const SizedBox(height: 6),
            Text(location.addressLabel),
            const SizedBox(height: 4),
            Text(
              '${location.group.label} · ${location.type.label}',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            if (!location.isOperational) ...[
              const SizedBox(height: 4),
              const Text(
                'Lieu non opérationnel dans le référentiel',
                style: TextStyle(color: AppColors.orange),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
                TextButton.icon(
                  key: Key('admin-location-toggle-${location.id}'),
                  onPressed: onToggle,
                  icon: Icon(
                    location.active
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                  ),
                  label: Text(location.active ? 'Désactiver' : 'Réactiver'),
                ),
                if (onDelete != null)
                  TextButton.icon(
                    key: Key('admin-location-delete-${location.id}'),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer'),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Lieu utilisé : désactivation uniquement',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: active ? AppColors.greenSoft : Colors.black12,
      borderRadius: BorderRadius.circular(999),
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
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Les lieux ne sont pas disponibles.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}

class _AccessRefused extends StatelessWidget {
  const _AccessRefused({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Accès coordinateur actif requis.'),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ],
      ),
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
