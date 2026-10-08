import 'package:flutter/material.dart';

import '../config/patient_data_guidance.dart';
import '../repositories/professional_targeting_repository.dart';
import '../services/reference_geocoding_service.dart';
import '../theme/v5_foundation.dart';
import 'v5_form_system.dart';

/// Un seul accord visible. Le dépôt persiste séparément la zone privée et la
/// préférence de notification dans une même transaction.
class ProfessionalTargetingSection extends StatefulWidget {
  const ProfessionalTargetingSection({
    super.key,
    required this.repository,
    required this.geocodingService,
    required this.hasProfile,
    this.professionalAddress,
  });

  final ProfessionalTargetingRepository? repository;
  final ReferenceGeocodingService? geocodingService;
  final bool hasProfile;
  final String? professionalAddress;

  @override
  State<ProfessionalTargetingSection> createState() =>
      _ProfessionalTargetingSectionState();
}

class _ProfessionalTargetingSectionState
    extends State<ProfessionalTargetingSection> {
  String _precisionLabel(String value) => switch (value) {
    'housenumber' => 'adresse précise',
    'street' => 'rue',
    'locality' => 'lieu',
    'municipality' => 'commune',
    _ => 'à vérifier',
  };

  Stream<ProfessionalTargetingPreference>? _preferences;
  bool _saving = false;
  bool _searching = false;
  bool _editingPoint = false;
  final TextEditingController _query = TextEditingController();
  List<ReferenceAddressCandidate> _candidates = const [];
  ReferenceAddressCandidate? _selected;
  String? _searchError;
  int? _pendingRadius;
  bool _legacyOptedOut = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final service = widget.geocodingService;
    final query = _query.text.trim();
    if (service == null || _searching || query.length < 4) {
      setState(() => _searchError = 'Saisissez au moins 4 caractères.');
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
      _candidates = const [];
      _selected = null;
    });
    try {
      final candidates = await service.searchAddress(query);
      if (!mounted || _query.text.trim() != query) return;
      setState(() {
        _candidates = candidates;
        _searchError = candidates.isEmpty
            ? 'Aucun résultat. Précisez le lieu ou l’adresse.'
            : null;
      });
    } on ReferenceGeocodingException catch (error) {
      if (!mounted) return;
      setState(
        () => _searchError = switch (error.failure) {
          ReferenceGeocodingFailure.timeout =>
            'La recherche a expiré. Réessayez.',
          ReferenceGeocodingFailure.invalidQuery =>
            'Saisissez une adresse ou un lieu valide.',
          _ => 'Le géocodage est temporairement indisponible.',
        },
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _searchError = 'Le géocodage est temporairement indisponible.',
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _select(ReferenceAddressCandidate candidate) async {
    final service = widget.geocodingService;
    if (service == null) return;
    try {
      final resolved = await service.resolveAddress(candidate);
      if (mounted) {
        setState(() {
          _selected = resolved;
          _searchError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _searchError = 'Sélection invalide. Relancez la recherche.',
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _preferences = widget.repository?.watchProfessionalTargeting();
  }

  @override
  void didUpdateWidget(covariant ProfessionalTargetingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _preferences = widget.repository?.watchProfessionalTargeting();
      _legacyOptedOut = false;
    }
  }

  Future<void> _disableLegacy() async {
    final repository = widget.repository;
    if (_saving || repository == null) return;
    setState(() => _saving = true);
    try {
      await repository.disableLegacyProfessionalSolicitations();
      if (mounted) setState(() => _legacyOptedOut = true);
    } catch (_) {
      if (mounted) {
        V5Toast.show(
          context,
          message: 'Impossible de désactiver les anciennes alertes.',
          tone: V5ToastTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _save(ProfessionalTargetingPreference preference) async {
    final repository = widget.repository;
    if (_saving || repository == null) return false;
    setState(() => _saving = true);
    try {
      await repository.saveProfessionalTargeting(preference);
      if (mounted) {
        V5Toast.show(
          context,
          message: 'Zone d’intervention enregistrée.',
          tone: V5ToastTone.success,
        );
      }
      return true;
    } catch (_) {
      if (mounted) {
        V5Toast.show(
          context,
          message: 'La zone d’intervention est temporairement indisponible.',
          tone: V5ToastTone.danger,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmPoint(ProfessionalTargetingPreference preference) async {
    final selected = _selected;
    if (selected == null) return;
    final saved = await _save(
      preference
          .withRadius(_pendingRadius ?? preference.radiusKm)
          .withConfirmedPoint(
            latitude: selected.latitude,
            longitude: selected.longitude,
            provider: selected.provider,
            precision: selected.precision,
          ),
    );
    if (saved && mounted) {
      setState(() {
        _editingPoint = false;
        _selected = null;
        _candidates = const [];
        _query.clear();
        _pendingRadius = null;
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<ProfessionalTargetingPreference>(
    stream: _preferences,
    initialData: const ProfessionalTargetingPreference(),
    builder: (context, snapshot) {
      final preference =
          snapshot.data ?? const ProfessionalTargetingPreference();
      final canEdit =
          widget.repository != null && widget.hasProfile && !_saving;
      final legacyActive =
          !preference.hasReferencePoint &&
          preference.legacyOptIn &&
          !_legacyOptedOut;
      final address = widget.professionalAddress?.trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Je souhaite être informé lorsqu’une mission correspondant à ma '
            'profession est disponible dans ma zone d’intervention.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: V5Spacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recevoir les sollicitations MobSanté',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Switch.adaptive(
                key: const Key('professional-targeting-enabled'),
                value: preference.hasReferencePoint
                    ? preference.enabled
                    : legacyActive,
                onChanged: !canEdit
                    ? null
                    : preference.hasReferencePoint
                    ? (value) => _save(preference.withEnabled(value))
                    : legacyActive
                    ? (value) {
                        if (!value) _disableLegacy();
                      }
                    : null,
              ),
            ],
          ),
          Text(
            preference.hasReferencePoint
                ? preference.enabled
                      ? 'Activée'
                      : 'Désactivée'
                : legacyActive
                ? 'Anciennes alertes actives pendant la transition'
                : 'Non configurée',
            key: const Key('professional-targeting-status'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: V5Spacing.sm),
          Text(
            'Point de référence',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            preference.hasReferencePoint
                ? 'Point enregistré pour vos sollicitations.'
                : 'Aucun point de référence défini.',
            key: const Key('professional-targeting-point'),
          ),
          if (!preference.hasReferencePoint) ...[
            const SizedBox(height: V5Spacing.xs),
            if (legacyActive)
              Text(
                'Vos alertes déjà activées continuent provisoirement sans '
                'point de référence. Vous pouvez les arrêter ici.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Text(
              !widget.hasProfile
                  ? 'Complétez d’abord votre profil professionnel.'
                  : 'L’activation nécessite un point confirmé.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (address != null && address.isNotEmpty)
              Text(
                'Votre adresse professionnelle ($address) peut être utilisée '
                'comme recherche initiale.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ] else
            TextButton.icon(
              key: const Key('professional-targeting-clear-point'),
              onPressed: canEdit
                  ? () => _save(preference.withoutPoint())
                  : null,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Retirer mon point de référence'),
            ),
          if (widget.hasProfile) ...[
            TextButton.icon(
              key: const Key('professional-targeting-edit-point'),
              onPressed: canEdit && widget.geocodingService != null
                  ? () => setState(() {
                      _editingPoint = !_editingPoint;
                      _candidates = const [];
                      _selected = null;
                      _searchError = null;
                    })
                  : null,
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: Text(
                preference.hasReferencePoint
                    ? 'Modifier mon point de référence'
                    : 'Définir mon point de référence',
              ),
            ),
            if (_editingPoint) ...[
              const SizedBox(height: V5Spacing.xs),
              Text(
                'La recherche transmet uniquement le lieu saisi au service '
                'public de géocodage de l’IGN via MobSanté. Le libellé '
                'n’est pas conservé après confirmation. '
                '${PatientDataGuidance.warning}',
                key: const Key('professional-targeting-provider-disclosure'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: V5Spacing.xs),
              TextField(
                key: const Key('professional-targeting-address-query'),
                controller: _query,
                maxLength: 120,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {
                  _candidates = const [];
                  _selected = null;
                  _searchError = null;
                }),
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(
                  labelText: 'Adresse ou lieu de référence',
                  hintText: 'Ex. 10 rue de la Paix 75002 Paris',
                ),
              ),
              if (address != null && address.isNotEmpty)
                TextButton(
                  key: const Key('professional-targeting-use-profile-address'),
                  onPressed: () => setState(() {
                    _query.text = address;
                    _candidates = const [];
                    _selected = null;
                    _searchError = null;
                  }),
                  child: const Text('Reprendre mon adresse professionnelle'),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const Key('professional-targeting-search'),
                  onPressed: canEdit && !_searching ? _search : null,
                  child: Text(_searching ? 'Recherche…' : 'Rechercher'),
                ),
              ),
              if (_searchError != null)
                Text(
                  _searchError!,
                  key: const Key('professional-targeting-search-error'),
                ),
              for (final candidate in _candidates)
                ListTile(
                  key: Key(
                    'professional-targeting-candidate-${_candidates.indexOf(candidate)}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(candidate.displayLabel),
                  subtitle: Text(
                    'Précision : ${_precisionLabel(candidate.precision)}',
                  ),
                  onTap: canEdit ? () => _select(candidate) : null,
                ),
              if (_selected != null) ...[
                const SizedBox(height: V5Spacing.xs),
                Text(
                  'Confirmer ce point : ${_selected!.displayLabel}',
                  key: const Key('professional-targeting-confirmation'),
                ),
                Text('Précision : ${_precisionLabel(_selected!.precision)}'),
                FilledButton(
                  key: const Key('professional-targeting-confirm-point'),
                  onPressed: canEdit ? () => _confirmPoint(preference) : null,
                  child: const Text('Confirmer ce point'),
                ),
                const Text(
                  'La confirmation enregistre le point sans activer les sollicitations.',
                ),
                if (legacyActive)
                  const Text(
                    'Vos anciennes alertes s’arrêteront à la confirmation ; '
                    'vous pourrez ensuite activer le ciblage par rayon.',
                  ),
              ],
            ],
          ],
          const SizedBox(height: V5Spacing.sm),
          Text(
            'Rayon d’intervention',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: V5Spacing.xs),
          Wrap(
            key: const Key('professional-targeting-radius-choices'),
            spacing: V5Spacing.xs,
            runSpacing: V5Spacing.xs,
            children: [
              for (final radius
                  in ProfessionalTargetingPreference.radiusChoices)
                ChoiceChip(
                  key: Key('professional-targeting-radius-$radius'),
                  label: Text('$radius km'),
                  selected: (_pendingRadius ?? preference.radiusKm) == radius,
                  onSelected: canEdit
                      ? (_) {
                          if (preference.hasReferencePoint) {
                            _save(preference.withRadius(radius));
                          } else {
                            setState(() => _pendingRadius = radius);
                          }
                        }
                      : null,
                ),
            ],
          ),
          if (!preference.hasReferencePoint && _pendingRadius != null)
            Text(
              'Ce rayon sera enregistré après confirmation du point.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: V5Spacing.sm),
          Text(
            'Ce point sert uniquement à sélectionner les missions dans votre '
            'zone d’intervention. Il n’est pas affiché aux autres utilisateurs.',
            key: const Key('professional-targeting-privacy'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (snapshot.hasError)
            Text(
              'La zone d’intervention est temporairement indisponible.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      );
    },
  );
}
