import 'package:flutter/material.dart';

import '../models/need.dart';
import '../theme/app_theme.dart';
import 'v5_form_system.dart';

class LocationMultiSelector extends StatefulWidget {
  const LocationMultiSelector({
    super.key,
    required this.locations,
    required this.selectedIds,
    required this.onChanged,
    this.enabled = true,
    this.listHeight = 340,
  });

  final List<ResponsePlace> locations;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;
  final double listHeight;

  @override
  State<LocationMultiSelector> createState() => _LocationMultiSelectorState();
}

class _LocationMultiSelectorState extends State<LocationMultiSelector> {
  final _searchController = TextEditingController();
  late final Set<TerritorialGroup> _expandedGroups;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _expandedGroups = widget.locations
        .map((location) => location.group)
        .toSet();
  }

  @override
  void didUpdateWidget(LocationMultiSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldGroups = oldWidget.locations
        .map((location) => location.group)
        .toSet();
    _expandedGroups.addAll(
      widget.locations
          .map((location) => location.group)
          .where((group) => !oldGroups.contains(group)),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ResponsePlace> get _availableLocations => widget.locations
      .where((location) => location.isOperational && location.isEnabled)
      .toList(growable: false);

  List<ResponsePlace> get _filteredLocations {
    final query = _normalizeForSearch(_query);
    if (query.isEmpty) return _availableLocations;
    return _availableLocations
        .where((location) => _searchText(location).contains(query))
        .toList(growable: false);
  }

  String _searchText(ResponsePlace location) {
    final address = location.structuredAddress;
    final value = [
      location.name,
      location.group.label,
      location.type.label,
      location.address,
      address?.addressLine1,
      address?.addressLine2,
      address?.postalCode,
      address?.city,
      address?.fullAddress,
    ].whereType<String>().join(' ');
    return _normalizeForSearch(value);
  }

  String _normalizeForSearch(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[àáâãäå]'), 'a')
        .replaceAll(RegExp('[ç]'), 'c')
        .replaceAll(RegExp('[èéêë]'), 'e')
        .replaceAll(RegExp('[ìíîï]'), 'i')
        .replaceAll(RegExp('[ñ]'), 'n')
        .replaceAll(RegExp('[òóôõö]'), 'o')
        .replaceAll(RegExp('[ùúûü]'), 'u')
        .replaceAll(RegExp('[ýÿ]'), 'y');
  }

  void _updateSearch(String value) {
    setState(() {
      _query = value;
      if (value.trim().isNotEmpty) {
        _expandedGroups.addAll(
          _availableLocations
              .where(
                (location) =>
                    _searchText(location).contains(_normalizeForSearch(value)),
              )
              .map((location) => location.group),
        );
      }
    });
  }

  void _toggleLocation(String locationId, bool selected) {
    final updated = Set<String>.of(widget.selectedIds);
    selected ? updated.add(locationId) : updated.remove(locationId);
    widget.onChanged(Set.unmodifiable(updated));
  }

  void _toggleGroup(TerritorialGroup group) {
    setState(() {
      _expandedGroups.contains(group)
          ? _expandedGroups.remove(group)
          : _expandedGroups.add(group);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final visibleHeight = mediaQuery.size.height - mediaQuery.viewInsets.bottom;
    final preferredListHeight = visibleHeight * 0.35;
    final effectiveListHeight = widget.listHeight <= 180
        ? widget.listHeight
        : preferredListHeight.clamp(180.0, widget.listHeight).toDouble();
    final available = _availableLocations;
    final filtered = _filteredLocations;
    final selectedLocations = available
        .where((location) => widget.selectedIds.contains(location.id))
        .toList(growable: false);
    final count = widget.selectedIds.length;
    final countLabel =
        '$count centre${count > 1 ? 's' : ''} '
        'sélectionné${count > 1 ? 's' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        V5TextField(
          key: const Key('location-search'),
          label: 'Rechercher un centre',
          controller: _searchController,
          enabled: widget.enabled,
          textInputAction: TextInputAction.search,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  key: const Key('clear-location-search'),
                  tooltip: 'Effacer la recherche',
                  onPressed: () {
                    _searchController.clear();
                    _updateSearch('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          onChanged: _updateSearch,
        ),
        const SizedBox(height: 12),
        Semantics(
          key: const Key('location-selection-count'),
          liveRegion: true,
          label: countLabel,
          child: Text(
            countLabel,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (selectedLocations.isNotEmpty) ...[
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: selectedLocations
                .map(
                  (location) => InputChip(
                    key: Key('selected-location-${location.id}'),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        location.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    deleteButtonTooltipMessage:
                        'Retirer ${location.name} de la sélection',
                    onDeleted: widget.enabled
                        ? () => _toggleLocation(location.id, false)
                        : null,
                  ),
                )
                .toList(growable: false),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          '${filtered.length} centre${filtered.length > 1 ? 's' : ''} '
          'disponible${filtered.length > 1 ? 's' : ''}',
          key: const Key('location-result-count'),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          height: effectiveListHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: filtered.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Aucun centre ne correspond à votre recherche.',
                      key: Key('location-search-empty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : ListView(
                  key: const Key('location-selector-list'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    for (final group in TerritorialGroup.values)
                      if (filtered.any((location) => location.group == group))
                        _LocationGroup(
                          group: group,
                          locations: filtered
                              .where((location) => location.group == group)
                              .toList(growable: false),
                          selectedIds: widget.selectedIds,
                          expanded: _expandedGroups.contains(group),
                          enabled: widget.enabled,
                          onToggle: () => _toggleGroup(group),
                          onLocationChanged: _toggleLocation,
                        ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _LocationGroup extends StatelessWidget {
  const _LocationGroup({
    required this.group,
    required this.locations,
    required this.selectedIds,
    required this.expanded,
    required this.enabled,
    required this.onToggle,
    required this.onLocationChanged,
  });

  final TerritorialGroup group;
  final List<ResponsePlace> locations;
  final Set<String> selectedIds;
  final bool expanded;
  final bool enabled;
  final VoidCallback onToggle;
  final void Function(String locationId, bool selected) onLocationChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          label:
              '${group.label}, ${locations.length} '
              'centre${locations.length > 1 ? 's' : ''}',
          child: InkWell(
            key: Key('location-group-${group.name}'),
            canRequestFocus: enabled,
            onTap: enabled ? onToggle : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.label,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${locations.length}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expanded)
          for (final location in locations)
            CheckboxListTile(
              key: Key('invitation-location-${location.id}'),
              value: selectedIds.contains(location.id),
              dense: true,
              contentPadding: const EdgeInsets.only(left: 8, right: 12),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                location.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                location.type.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onChanged: enabled
                  ? (selected) =>
                        onLocationChanged(location.id, selected == true)
                  : null,
            ),
        if (expanded) const Divider(height: 1),
      ],
    );
  }
}
