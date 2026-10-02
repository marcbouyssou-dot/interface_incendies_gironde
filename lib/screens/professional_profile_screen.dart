import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../models/need.dart';
import '../models/mobilization_preferences.dart';
import '../models/professional_equipment.dart';
import '../models/professional_profile_validation.dart';
import '../models/volunteer_profile.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../services/professional_verification_service.dart';
import '../theme/v5_foundation.dart';
import '../widgets/professional_page_header.dart';
import '../widgets/professional_rpps_verification.dart';
import '../widgets/native_interactions.dart';
import '../widgets/v5_controls.dart';
import '../widgets/v5_form_system.dart';

/// Capitalizes word starts without changing the remaining letters of a name.
String normalizeProfessionalName(String value) {
  final trimmed = value.trim();
  return trimmed.replaceAllMapped(RegExp(r"(^|[\s\-’'])([a-zà-ÿ])"), (match) {
    final prefix = match.group(1)!;
    final letter = match.group(2)!;
    if (letter == 'd' &&
        match.end < trimmed.length &&
        (trimmed[match.end] == "'" || trimmed[match.end] == '’')) {
      return '$prefix$letter';
    }
    return '$prefix${letter.toUpperCase()}';
  });
}

String professionalIdentifierLabel(
  VolunteerProfession? profession,
  ProfessionalIdType? currentType,
) =>
    (profession == null ? null : requiredProfessionalIdType(profession))
        ?.label ??
    currentType?.label ??
    'RPPS ou numéro ordinal';

String _locationSearchText(String value) {
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'á': 'a',
    'ã': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ÿ': 'y',
    'ý': 'y',
    'œ': 'oe',
    'æ': 'ae',
  };
  return value.toLowerCase().split('').map((c) => accents[c] ?? c).join();
}

String _weekdayLabel(ProfessionalWeekday weekday) => switch (weekday) {
  ProfessionalWeekday.monday => 'Lundi',
  ProfessionalWeekday.tuesday => 'Mardi',
  ProfessionalWeekday.wednesday => 'Mercredi',
  ProfessionalWeekday.thursday => 'Jeudi',
  ProfessionalWeekday.friday => 'Vendredi',
  ProfessionalWeekday.saturday => 'Samedi',
  ProfessionalWeekday.sunday => 'Dimanche',
};

String _timeBandLabel(String value) => switch (value) {
  'morning' => 'Matin',
  'afternoon' => 'Après-midi',
  'evening' => 'Soir',
  'night' => 'Nuit',
  _ => value,
};

class _PreferenceOption<T> {
  const _PreferenceOption(this.value, this.label, {this.id});

  final T value;
  final String label;
  final String? id;
}

enum _ProfileEditorMode { completion, full, preferences, equipment, cpts }

enum _ProfileEditorResult { saved, completeProfile }

class ProfessionalProfileScreen extends StatefulWidget {
  const ProfessionalProfileScreen({
    super.key,
    required this.onOpenNotifications,
    this.initiallyOpenEditor = false,
    this.returnToMissionLabel,
    this.onReturnToMission,
    this.verificationService = const FakeProfessionalVerificationService(),
  });

  final VoidCallback onOpenNotifications;
  final bool initiallyOpenEditor;
  final String? returnToMissionLabel;
  final VoidCallback? onReturnToMission;
  final ProfessionalVerificationService verificationService;

  @override
  State<ProfessionalProfileScreen> createState() =>
      _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends State<ProfessionalProfileScreen> {
  Object? _repositoryIdentity;
  LiveCoordinationData? _liveData;
  StreamSubscription<List<ResponsePlace>>? _locationsSubscription;
  List<ResponsePlace> _availableLocations = const [];
  Future<VolunteerProfile?>? _profile;
  bool _initialEditorScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = RepositoryScope.of(context);
    if (!identical(repository, _repositoryIdentity)) {
      _repositoryIdentity = repository;
      _profile = repository.getVolunteerProfile();
    }
    final liveData = LiveCoordinationDataScope.of(context);
    if (!identical(liveData, _liveData)) {
      _liveData = liveData;
      unawaited(_locationsSubscription?.cancel());
      _locationsSubscription = liveData.watchLocations().listen((locations) {
        if (mounted) _availableLocations = locations;
      });
    }
  }

  @override
  void dispose() {
    unawaited(_locationsSubscription?.cancel());
    super.dispose();
  }

  void _reloadProfile() {
    setState(() {
      _profile = RepositoryScope.of(context).getVolunteerProfile();
    });
  }

  Future<void> _confirmProfessionalIdentity(
    ProfessionalVerificationResult verification,
  ) async {
    final profile = await RepositoryScope.of(
      context,
    ).confirmProfessionalRpps(verification);
    if (!mounted) return;
    setState(() => _profile = Future.value(profile));
  }

  Future<void> _editProfile(
    VolunteerProfile? profile, {
    required _ProfileEditorMode mode,
  }) async {
    final result = await showNativeBottomSheet<_ProfileEditorResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _ProfessionalProfileEditor(
        profile: profile,
        availableLocations: _availableLocations,
        mode: mode,
      ),
    );
    if (result == _ProfileEditorResult.completeProfile && mounted) {
      await _editProfile(profile, mode: _ProfileEditorMode.completion);
      return;
    }
    if (result == _ProfileEditorResult.saved && mounted) {
      _reloadProfile();
      V5Toast.show(
        context,
        message: 'Profil enregistré.',
        tone: V5ToastTone.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.v5Colors.canvas,
      child: FutureBuilder<VolunteerProfile?>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const V5LoadingState(label: 'Chargement du profil…');
          }
          final profile = snapshot.hasError ? null : snapshot.data;
          final profileComplete = ProfessionalProfileValidation.isComplete(
            profile,
          );
          final profileGaps =
              (profile == null
              ? ProfessionalProfileValidation.engagementGaps(
                  firstName: null,
                  lastName: null,
                  phone: null,
                  email: null,
                  profession: VolunteerProfession.mk,
                  professionalIdType: ProfessionalIdType.rpps,
                  professionalIdValue: null,
                  professionalAddressLine1: null,
                  professionalPostalCode: null,
                  professionalCity: null,
                )
              : ProfessionalProfileValidation.engagementGapsForProfile(
                  profile,
                        ))
                  .toSet();
          bool requiresAction(EngagementProfileGap gap) =>
              profileGaps.contains(gap);
          if (widget.initiallyOpenEditor && !_initialEditorScheduled) {
            _initialEditorScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _editProfile(profile, mode: _ProfileEditorMode.completion);
              }
            });
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth <= 556
                  ? 18.0
                  : (constraints.maxWidth - 520) / 2;
              return ListView(
                key: const PageStorageKey('professional-profile'),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  10,
                  horizontalPadding,
                  36,
                ),
                children: [
                  const ProfessionalIdentityHeader(),
                  const SizedBox(height: V5Spacing.md),
                  _ProfileCompletionActions(
                    complete: profileComplete,
                    missingInformation: _missingInformation(profile),
                    onEdit: () => _editProfile(
                      profile,
                      mode: profileComplete
                          ? _ProfileEditorMode.full
                          : _ProfileEditorMode.completion,
                    ),
                  ),
                  if (widget.onReturnToMission != null) ...[
                    const SizedBox(height: V5Spacing.xs),
                    TextButton.icon(
                      key: const Key('return-to-engagement-mission'),
                      onPressed: widget.onReturnToMission,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(
                        widget.returnToMissionLabel == null
                            ? 'Retour à la mission'
                            : 'Retour à ${widget.returnToMissionLabel}',
                      ),
                    ),
                  ],
                  const SizedBox(height: V5Spacing.sm),
                  _ProfileSection(
                    title: 'Identité et coordonnées',
                    icon: Icons.person_outline_rounded,
                    children: [
                      _ProfileValue(
                        key: const Key('professional-profile-value-name'),
                        label: 'Nom',
                        value: profile?.displayName.isNotEmpty == true
                            ? profile!.displayName
                            : 'Non renseigné',
                        requiresAction:
                            requiresAction(EngagementProfileGap.firstName) ||
                            requiresAction(EngagementProfileGap.lastName),
                      ),
                      _ProfileValue(
                        key: const Key('professional-profile-value-phone'),
                        label: 'Téléphone',
                        value: profile?.phone.trim().isNotEmpty == true
                            ? profile!.phone.trim()
                            : 'Non renseigné',
                        requiresAction: requiresAction(
                          EngagementProfileGap.phone,
                        ),
                      ),
                      _ProfileValue(
                        key: const Key('professional-profile-value-email'),
                        label: 'Email',
                        value: profile?.email?.trim().isNotEmpty == true
                            ? profile!.email!.trim()
                            : 'Non renseigné',
                        requiresAction: requiresAction(
                          EngagementProfileGap.email,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  _ProfileSection(
                    title: 'Informations professionnelles',
                    icon: Icons.medical_information_outlined,
                    children: [
                      _ProfileValue(
                        key: const Key('professional-profile-value-profession'),
                        label: 'Profession',
                        value: profile?.profession.label ?? 'Non renseignée',
                        requiresAction: profile == null,
                      ),
                      _ProfileValue(
                        key: const Key('professional-profile-value-address'),
                        label: 'Adresse',
                        value:
                            profile
                                    ?.professionalAddress
                                    .addressLineLabel
                                    .isNotEmpty ==
                                true
                            ? profile!.professionalAddress.addressLineLabel
                            : 'Adresse professionnelle à compléter',
                        requiresAction: requiresAction(
                          EngagementProfileGap.professionalAddress,
                        ),
                      ),
                      _ProfileValue(
                        key: const Key('professional-profile-value-locality'),
                        label: 'Code postal · Ville',
                        value:
                            profile
                                    ?.professionalAddress
                                    .localityLabel
                                    .isNotEmpty ==
                                true
                            ? profile!.professionalAddress.localityLabel
                            : 'À compléter',
                        requiresAction:
                            requiresAction(
                              EngagementProfileGap.professionalPostalCode,
                            ) ||
                            requiresAction(
                              EngagementProfileGap.professionalCity,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  _ProfileSection(
                    title: 'RPPS et vérification',
                    icon: Icons.verified_user_outlined,
                    children: [
                      if (profile != null &&
                          ProfessionalRppsVerification.supportsProfession(
                            profile.profession,
                          )) ...[
                        if (requiresAction(
                          EngagementProfileGap.professionalIdentifier,
                        )) ...[
                          const _ProfileValue(
                            key: Key('professional-profile-value-identifier'),
                            label: 'Identifiant professionnel',
                            value: 'À compléter',
                            requiresAction: true,
                          ),
                          const SizedBox(height: V5Spacing.xs),
                        ],
                        if (profile.effectiveProfessionalIdType ==
                            ProfessionalIdType.ordinal) ...[
                          _ProfileValue(
                            label: 'Identifiant historique',
                            value:
                                '${profile.effectiveProfessionalIdType.label} '
                                '${profile.effectiveProfessionalIdValue}',
                          ),
                          const SizedBox(height: V5Spacing.xs),
                        ],
                        ProfessionalRppsVerification(
                          key: ValueKey(
                            'professional-rpps-${profile.profession.name}',
                          ),
                          profession: profile.profession,
                          service: widget.verificationService,
                          initialRpps:
                              profile.effectiveProfessionalIdType ==
                                  ProfessionalIdType.rpps
                              ? profile.effectiveProfessionalIdValue
                              : '',
                          persistedVerification:
                              profile.hasVerifiedProfessionalIdentity
                              ? ProfessionalVerificationResult(
                                  status:
                                      ProfessionalVerificationStatus.verified,
                                  rpps: profile.effectiveProfessionalIdValue,
                                  firstName: profile.verifiedFirstName!,
                                  lastName: profile.verifiedLastName!,
                                  professionCode:
                                      profile.verifiedProfessionCode!,
                                  professionLabel:
                                      profile.verifiedProfessionLabel!,
                                  source: profile.verificationSource!,
                                )
                              : null,
                          verifiedAt: profile.verifiedAt,
                          onIdentityConfirmed: _confirmProfessionalIdentity,
                        ),
                      ] else ...[
                        _ProfileValue(
                          key: const Key(
                            'professional-profile-value-identifier-type',
                          ),
                          label: 'Type d’identifiant',
                          value: profile == null
                              ? 'Non renseigné'
                              : professionalIdentifierLabel(
                                  profile.profession,
                                  profile.effectiveProfessionalIdType,
                                ),
                          requiresAction: requiresAction(
                            EngagementProfileGap.professionalIdentifier,
                          ),
                        ),
                        _ProfileValue(
                          key: const Key(
                            'professional-profile-value-identifier',
                          ),
                          label: professionalIdentifierLabel(
                            profile?.profession ?? VolunteerProfession.mk,
                            profile?.effectiveProfessionalIdType,
                          ),
                          value:
                              profile
                                      ?.effectiveProfessionalIdValue
                                      .isNotEmpty ==
                                  true
                              ? profile!.effectiveProfessionalIdValue
                              : 'Non renseigné',
                          requiresAction: requiresAction(
                            EngagementProfileGap.professionalIdentifier,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  _ProfileSection(
                    title: 'CPTS',
                    icon: Icons.hub_outlined,
                    children: [
                      _ProfileValue(
                        key: const Key('professional-profile-value-cpts'),
                        label: 'CPTS',
                        value: profile?.cptsLabel?.trim().isNotEmpty == true
                            ? profile!.cptsLabel!.trim()
                            : 'Aucune CPTS renseignée',
                        requiresAction: requiresAction(
                          EngagementProfileGap.cptsLabel,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('edit-professional-cpts'),
                          onPressed: () => _editProfile(
                            profile,
                            mode: _ProfileEditorMode.cpts,
                          ),
                          child: const Text('Modifier ma CPTS'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  _ProfileSection(
                    title: 'Mon matériel disponible',
                    icon: Icons.medical_services_outlined,
                    children: [
                      _ProfileValue(
                        key: const Key('professional-profile-value-equipment'),
                        label: 'Équipements',
                        value: _equipmentSummary(profile),
                        requiresAction: requiresAction(
                          EngagementProfileGap.equipmentDetails,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('edit-professional-equipment'),
                          onPressed: () => _editProfile(
                            profile,
                            mode: _ProfileEditorMode.equipment,
                          ),
                          child: const Text('Modifier le matériel disponible'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  _ProfileSection(
                    title: 'Préférences générales',
                    icon: Icons.tune_rounded,
                    children: [
                      _ProfileValue(
                        label: 'Territoires et lieux',
                        value: _geographySummary(profile),
                      ),
                      _ProfileValue(
                        label: 'Jours préférés',
                        value: _weekdaySummary(profile),
                      ),
                      _ProfileValue(
                        label: 'Bandes horaires',
                        value: _timeBandSummary(profile),
                      ),
                      Text(
                        'Préférences récurrentes uniquement — elles ne '
                        'constituent pas des disponibilités datées.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.v5Colors.textSecondary,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const Key('edit-professional-preferences'),
                          onPressed: () => _editProfile(
                            profile,
                            mode: _ProfileEditorMode.preferences,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Modifier mes préférences'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: V5Spacing.lg),
                  const _ProfileGroupLabel('COMPTE'),
                  const SizedBox(height: V5Spacing.xs),
                  OutlinedButton.icon(
                    key: const Key('open-notification-center'),
                    onPressed: widget.onOpenNotifications,
                    icon: const Icon(Icons.notifications_outlined),
                    label: const Text('Notifications'),
                  ),
                  // TODO: Auth Professionnel récupérable (email/OTP, lien
                  // magique ou passkey) avant de réintroduire Déconnexion.
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _equipmentSummary(VolunteerProfile? profile) {
    if (profile == null || profile.equipment.isEmpty) return 'Aucun renseigné';
    final labels = ProfessionalEquipmentRegistry.normalizeStoredValues(
      profile.equipment,
    ).map(ProfessionalEquipmentRegistry.displayLabel).toList();
    if (profile.otherEquipmentDetails?.trim().isNotEmpty == true) {
      labels.add(profile.otherEquipmentDetails!.trim());
    }
    return labels.join(' • ');
  }

  List<String> _missingInformation(VolunteerProfile? profile) {
    if (profile == null) {
      return const [
        'Identité',
        'Coordonnées',
        'Profession',
        'Numéro RPPS',
        'Adresse professionnelle',
        'Code postal professionnel',
        'Ville professionnelle',
      ];
    }
    return ProfessionalProfileValidation.engagementGapsForProfile(
      profile,
    ).map((gap) => gap.label(profile.profession)).toList(growable: false);
  }

  String _geographySummary(VolunteerProfile? profile) {
    final preferences = profile?.mobilizationPreferences;
    if (preferences == null ||
        (preferences.territoryIds.isEmpty && preferences.locationIds.isEmpty)) {
      return 'Aucune préférence renseignée';
    }
    return [
      if (preferences.territoryIds.isNotEmpty)
        'Secteurs : ${preferences.territoryIds.join(', ')}',
      if (preferences.locationIds.isNotEmpty)
        'Établissements : ${preferences.locationIds.join(', ')}',
    ].join(' · ');
  }

  String _weekdaySummary(VolunteerProfile? profile) {
    final weekdays = profile?.mobilizationPreferences?.preferredWeekdays;
    if (weekdays == null || weekdays.isEmpty) {
      return 'Aucune préférence renseignée';
    }
    return ProfessionalWeekday.values
        .where(weekdays.contains)
        .map(_weekdayLabel)
        .join(', ');
  }

  String _timeBandSummary(VolunteerProfile? profile) {
    final bands = profile?.mobilizationPreferences?.preferredTimeBands;
    if (bands == null || bands.isEmpty) {
      return 'Aucune préférence renseignée';
    }
    return bands.map(_timeBandLabel).join(', ');
  }
}

class _MultiSelectPreferenceField<T> extends StatelessWidget {
  const _MultiSelectPreferenceField({
    super.key,
    required this.label,
    required this.keyPrefix,
    required this.values,
    required this.options,
    required this.onChanged,
    this.searchable = false,
  });

  final String label;
  final String keyPrefix;
  final Set<T> values;
  final List<_PreferenceOption<T>> options;
  final ValueChanged<Set<T>> onChanged;
  final bool searchable;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final selectedLabels = options
        .where((option) => values.contains(option.value))
        .map((option) => option.label)
        .join(', ');
    return Semantics(
      button: true,
      label: label,
      value: selectedLabels.isEmpty ? 'Aucune sélection' : selectedLabels,
      child: InkWell(
        borderRadius: BorderRadius.circular(V5Radius.control),
        onTap: options.isEmpty ? null : () => _openPicker(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          child: Text(
            selectedLabels.isEmpty
                ? options.isEmpty
                      ? 'Aucun choix disponible'
                      : 'Sélectionner'
                : selectedLabels,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: selectedLabels.isEmpty
                  ? colors.textSecondary
                  : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) => showNativeBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
    builder: (sheetContext) => _PreferencePickerContent<T>(
      label: label,
      keyPrefix: keyPrefix,
      values: values,
      options: options,
      searchable: searchable,
      onChanged: onChanged,
    ),
  );
}

class _PreferencePickerContent<T> extends StatefulWidget {
  const _PreferencePickerContent({
    required this.label,
    required this.keyPrefix,
    required this.values,
    required this.options,
    required this.searchable,
    required this.onChanged,
  });

  final String label;
  final String keyPrefix;
  final Set<T> values;
  final List<_PreferenceOption<T>> options;
  final bool searchable;
  final ValueChanged<Set<T>> onChanged;

  @override
  State<_PreferencePickerContent<T>> createState() =>
      _PreferencePickerContentState<T>();
}

class _PreferencePickerContentState<T>
    extends State<_PreferencePickerContent<T>> {
  late final Set<T> _draft = Set<T>.of(widget.values);
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleOptions = widget.options
        .where(
          (option) => _locationSearchText(
            option.label,
          ).contains(_locationSearchText(_query.trim())),
        )
        .toList(growable: false);
    return Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
            widget.label,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: V5Spacing.sm),
          if (widget.searchable) ...[
            TextField(
              key: Key('${widget.keyPrefix}-search'),
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Rechercher un établissement',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        key: Key('${widget.keyPrefix}-search-clear'),
                        tooltip: 'Effacer la recherche',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _query = '';
                        }),
                      ),
                ),
              ),
              const SizedBox(height: V5Spacing.sm),
          ],
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                for (final option in visibleOptions)
                      CheckboxListTile(
                        key: Key(
                      '${widget.keyPrefix}-${option.id ?? option.value.toString().split('.').last}',
                        ),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(option.label),
                    value: _draft.contains(option.value),
                    onChanged: (selected) => setState(() {
                          if (selected == true) {
                        _draft.add(option.value);
                          } else {
                        _draft.remove(option.value);
                          }
                        }),
                      ),
                if (widget.searchable && visibleOptions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Aucun établissement trouvé')),
                  ),
                  ],
                ),
              ),
              const SizedBox(height: V5Spacing.sm),
              V5Button(
            key: Key('${widget.keyPrefix}-apply'),
                expanded: true,
                onPressed: () {
              widget.onChanged(Set<T>.of(_draft));
              Navigator.of(context).pop();
                },
                label: 'Valider',
              ),
            ],
          ),
    );
  }
}

class _ProfileGroupLabel extends StatelessWidget {
  const _ProfileGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: context.v5Colors.textSecondary,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    ),
  );
}

class _ProfileCompletionActions extends StatelessWidget {
  const _ProfileCompletionActions({
    required this.complete,
    required this.missingInformation,
    required this.onEdit,
  });

  final bool complete;
  final List<String> missingInformation;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Column(
      key: const Key('professional-profile-completion-actions'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              complete
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              color: complete ? colors.success : colors.danger,
            ),
            const SizedBox(width: V5Spacing.xs),
            Expanded(
              child: Text(
                complete ? 'Profil complet' : 'Profil à compléter',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        if (!complete && missingInformation.isNotEmpty) ...[
          const SizedBox(height: V5Spacing.xs),
          Text(
            'Informations manquantes : ${missingInformation.join(', ')}.',
            key: const Key('professional-profile-missing-information'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: V5Spacing.sm),
        V5Button(
          key: const Key('edit-professional-profile'),
          expanded: true,
          icon: Icons.edit_outlined,
          onPressed: onEdit,
          label: complete
              ? 'Modifier mes informations professionnelles'
              : 'Compléter mon profil',
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return V5Section(
      title: title,
      leading: Icon(icon),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const SizedBox(height: V5Spacing.xs),
          ],
        ],
      ),
    );
  }
}

class _ProfileValue extends StatelessWidget {
  const _ProfileValue({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.requiresAction = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool requiresAction;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 4,
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
      const SizedBox(width: V5Spacing.sm),
      Expanded(
        flex: 6,
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color:
                valueColor ??
                (requiresAction
                    ? context.v5Colors.danger
                    : context.v5Colors.textPrimary),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _ProfessionalProfileEditor extends StatefulWidget {
  const _ProfessionalProfileEditor({
    required this.profile,
    required this.availableLocations,
    required this.mode,
  });

  final VolunteerProfile? profile;
  final List<ResponsePlace> availableLocations;
  final _ProfileEditorMode mode;

  @override
  State<_ProfessionalProfileEditor> createState() =>
      _ProfessionalProfileEditorState();
}

class _ProfessionalProfileEditorState
    extends State<_ProfessionalProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  late VolunteerProfession _profession;
  late ProfessionalIdType _idType;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _idValue;
  late final TextEditingController _cptsLabel;
  late final TextEditingController _professionalAddressLine1;
  late final TextEditingController _professionalAddressLine2;
  late final TextEditingController _professionalPostalCode;
  late final TextEditingController _professionalCity;
  late final TextEditingController _professionalCountryCode;
  late final TextEditingController _equipmentDetails;
  late final Set<String> _equipment;
  late final Set<String> _territoryIds;
  late final Set<String> _locationIds;
  late final Set<String> _timeBands;
  late final Set<ProfessionalWeekday> _preferredWeekdays;
  final _firstNameFocus = FocusNode(debugLabel: 'profile-first-name');
  final _lastNameFocus = FocusNode(debugLabel: 'profile-last-name');
  final _phoneFocus = FocusNode(debugLabel: 'profile-phone');
  final _emailFocus = FocusNode(debugLabel: 'profile-email');
  final _idTypeFocus = FocusNode(debugLabel: 'profile-id-type');
  final _idValueFocus = FocusNode(debugLabel: 'profile-id-value');
  final _cptsLabelFocus = FocusNode(debugLabel: 'profile-cpts-label');
  final _professionalAddressLine1Focus = FocusNode(
    debugLabel: 'profile-professional-address-line-1',
  );
  final _professionalAddressLine2Focus = FocusNode(
    debugLabel: 'profile-professional-address-line-2',
  );
  final _professionalPostalCodeFocus = FocusNode(
    debugLabel: 'profile-professional-postal-code',
  );
  final _professionalCityFocus = FocusNode(
    debugLabel: 'profile-professional-city',
  );
  final _professionalCountryCodeFocus = FocusNode(
    debugLabel: 'profile-professional-country-code',
  );
  final _equipmentDetailsFocus = FocusNode(
    debugLabel: 'profile-equipment-details',
  );
  bool _saving = false;
  List<EngagementProfileGap> _hiddenCompletionGaps = const [];

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _profession = profile?.profession ?? VolunteerProfession.mk;
    final existingIdType = profile?.effectiveProfessionalIdType;
    final requiredIdType = requiredProfessionalIdType(_profession);
    _idType = requiredIdType ?? existingIdType ?? ProfessionalIdType.none;
    _firstName = TextEditingController(text: profile?.firstName);
    _lastName = TextEditingController(text: profile?.lastName);
    _phone = TextEditingController(text: profile?.phone);
    _email = TextEditingController(text: profile?.email);
    _idValue = TextEditingController(
      text: requiredIdType != null && existingIdType != requiredIdType
          ? ''
          : profile?.effectiveProfessionalIdValue,
    );
    _cptsLabel = TextEditingController(text: profile?.cptsLabel);
    _professionalAddressLine1 = TextEditingController(
      text: profile?.professionalAddressLine1,
    );
    _professionalAddressLine2 = TextEditingController(
      text: profile?.professionalAddressLine2,
    );
    _professionalPostalCode = TextEditingController(
      text: profile?.professionalPostalCode,
    );
    _professionalCity = TextEditingController(text: profile?.professionalCity);
    _professionalCountryCode = TextEditingController(
      text: profile?.professionalCountryCode ?? 'FR',
    );
    _equipmentDetails = TextEditingController(
      text: profile?.otherEquipmentDetails,
    );
    _equipment = ProfessionalEquipmentRegistry.normalizeStoredValues(
      profile?.equipment ?? const [],
    ).toSet();
    final preferences = profile?.mobilizationPreferences;
    _territoryIds = Set.of(preferences?.territoryIds ?? const {});
    _locationIds = Set.of(preferences?.locationIds ?? const {});
    _timeBands = Set.of(preferences?.preferredTimeBands ?? const {});
    _preferredWeekdays = Set.of(preferences?.preferredWeekdays ?? const {});
    if (widget.mode == _ProfileEditorMode.completion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusFirstInvalidField(announce: false);
      });
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _idValue.dispose();
    _cptsLabel.dispose();
    _professionalAddressLine1.dispose();
    _professionalAddressLine2.dispose();
    _professionalPostalCode.dispose();
    _professionalCity.dispose();
    _professionalCountryCode.dispose();
    _equipmentDetails.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _idTypeFocus.dispose();
    _idValueFocus.dispose();
    _cptsLabelFocus.dispose();
    _professionalAddressLine1Focus.dispose();
    _professionalAddressLine2Focus.dispose();
    _professionalPostalCodeFocus.dispose();
    _professionalCityFocus.dispose();
    _professionalCountryCodeFocus.dispose();
    _equipmentDetailsFocus.dispose();
    super.dispose();
  }

  List<ProfessionalIdType> get _idTypes {
    final requiredType = requiredProfessionalIdType(_profession);
    return requiredType == null ? ProfessionalIdType.values : [requiredType];
  }

  bool get _usesFixedIdentifierType =>
      requiredProfessionalIdType(_profession) != null;

  bool get _showsProfessionalInformation =>
      widget.mode == _ProfileEditorMode.completion ||
      widget.mode == _ProfileEditorMode.full;

  bool get _showsCpts =>
      _showsProfessionalInformation || widget.mode == _ProfileEditorMode.cpts;

  bool get _showsEquipment =>
      _showsProfessionalInformation ||
      widget.mode == _ProfileEditorMode.equipment;

  bool get _showsPreferences =>
      _showsProfessionalInformation ||
      widget.mode == _ProfileEditorMode.preferences;

  String get _editorTitle => switch (widget.mode) {
    _ProfileEditorMode.completion => 'Compléter mon profil',
    _ProfileEditorMode.full => 'Mes informations professionnelles',
    _ProfileEditorMode.preferences => 'Mes préférences',
    _ProfileEditorMode.equipment => 'Mon matériel disponible',
    _ProfileEditorMode.cpts => 'Ma CPTS',
  };

  String get _editorSubtitle => switch (widget.mode) {
    _ProfileEditorMode.completion =>
      'Complétez en priorité les informations nécessaires à vos engagements.',
    _ProfileEditorMode.full => 'Modifiez les informations de votre profil.',
    _ProfileEditorMode.preferences =>
      'Indiquez où et quand vous souhaitez généralement intervenir.',
    _ProfileEditorMode.equipment =>
      'Sélectionnez uniquement le matériel que vous pouvez mobiliser.',
    _ProfileEditorMode.cpts => 'Renseignez ou modifiez votre CPTS.',
  };

  List<ProfessionalEquipmentDefinition> get _equipmentOptions =>
      ProfessionalEquipmentRegistry.forProfession(_profession.canonicalId!);

  List<_PreferenceOption<String>> get _territoryOptions {
    final groups = <String, String>{
      for (final location in widget.availableLocations)
        location.group.name: location.group.label,
      for (final value in _territoryIds) value: value,
    };
    return groups.entries
        .map((entry) => _PreferenceOption(entry.key, entry.value))
        .toList(growable: false);
  }

  List<_PreferenceOption<String>> get _locationOptions {
    final locations = <String, String>{
      for (final location in widget.availableLocations)
        if (location.isOperational && location.isEnabled)
          location.id: location.name,
      for (final value in _locationIds) value: value,
    };
    return locations.entries
        .map((entry) => _PreferenceOption(entry.key, entry.value))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.v5Colors.canvas,
      child: SingleChildScrollView(
        key: const Key('professional-profile-editor-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          18,
          4,
          18,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            key: Key('professional-profile-editor-mode-${widget.mode.name}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfessionalProfileEditorHeader(
                title: _editorTitle,
                subtitle: _editorSubtitle,
              ),
              const SizedBox(height: V5Spacing.lg),
              if (_showsProfessionalInformation) ...[
              V5Section(
                title: 'Identité professionnelle',
                leading: const Icon(Icons.person_outline_rounded),
                child: Column(
                  children: [
                    V5SelectField<VolunteerProfession>(
                      key: const Key('professional-profile-profession'),
                      label: 'Profession',
                      value: _profession,
                      options: [
                        for (final profession in VolunteerProfession.values)
                          V5SelectOption(
                            value: profession,
                            label: profession.label,
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _profession = value;
                          _equipment.removeWhere(
                            (item) =>
                                !ProfessionalEquipmentRegistry.isCompatible(
                                  item,
                                  value.canonicalId!,
                                ),
                          );
                            final requiredIdType = requiredProfessionalIdType(
                              value,
                            );
                          if (requiredIdType != null) {
                            if (_idType != requiredIdType) {
                              _idValue.clear();
                            }
                            _idType = requiredIdType;
                          } else if (professionAllowsNoIdentifier(value)) {
                            _idType = ProfessionalIdType.none;
                            _idValue.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: V5Spacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: V5TextField(
                            key: const Key('professional-profile-first-name'),
                            label: 'Prénom',
                            controller: _firstName,
                              textCapitalization: TextCapitalization.words,
                            focusNode: _firstNameFocus,
                            isRequired: true,
                            validator: _required,
                          ),
                        ),
                        const SizedBox(width: V5Spacing.xs),
                        Expanded(
                          child: V5TextField(
                            key: const Key('professional-profile-last-name'),
                            label: 'Nom',
                            controller: _lastName,
                              textCapitalization: TextCapitalization.words,
                            focusNode: _lastNameFocus,
                            isRequired: true,
                            validator: _required,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: V5Spacing.sm),
                    V5TextField(
                      key: const Key('professional-profile-phone'),
                      label: 'Téléphone',
                      controller: _phone,
                      focusNode: _phoneFocus,
                      keyboardType: TextInputType.phone,
                      isRequired: true,
                      validator: _required,
                    ),
                    const SizedBox(height: V5Spacing.sm),
                    V5TextField(
                      key: const Key('professional-profile-email'),
                      label: 'Email',
                      semanticLabel: 'Email professionnel',
                      controller: _email,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      isRequired: true,
                      validator: _emailValidator,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: V5Spacing.sm),
              V5Section(
                title: 'Identifiant professionnel',
                leading: const Icon(Icons.verified_user_outlined),
                child: Column(
                  children: [
                    if (_usesFixedIdentifierType)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Identifiant : ${_idType.label}',
                            key: const Key(
                              'professional-profile-fixed-id-type',
                            ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    else
                      V5SelectField<ProfessionalIdType>(
                        key: ValueKey(
                          'professional-profile-id-type-${_profession.name}',
                        ),
                        label: 'Type d’identifiant',
                        focusNode: _idTypeFocus,
                        value: _idType,
                        options: [
                          for (final type in _idTypes)
                            V5SelectOption(value: type, label: type.label),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _idType = value;
                              if (value == ProfessionalIdType.none) {
                                _idValue.clear();
                              }
                            });
                          }
                        },
                        validator: (value) {
                          if (value == ProfessionalIdType.rpps ||
                              value == ProfessionalIdType.ordinal) {
                            return null;
                          }
                          if (value == ProfessionalIdType.none &&
                              professionAllowsNoIdentifier(_profession)) {
                            return null;
                          }
                          return 'Choisissez un identifiant professionnel.';
                        },
                      ),
                    if (_idType != ProfessionalIdType.none) ...[
                      const SizedBox(height: V5Spacing.sm),
                      V5TextField(
                        key: const Key('professional-profile-id-value'),
                        label: _idType.label,
                        controller: _idValue,
                        focusNode: _idValueFocus,
                        keyboardType: _idType == ProfessionalIdType.rpps
                            ? TextInputType.number
                            : TextInputType.text,
                        isRequired: true,
                        inputFormatters: [
                          if (_idType == ProfessionalIdType.rpps)
                            FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(
                            _idType == ProfessionalIdType.rpps ? 11 : 32,
                          ),
                        ],
                        validator: _idValidator,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: V5Spacing.sm),
              V5Section(
                title: 'Adresse professionnelle principale',
                leading: const Icon(Icons.location_on_outlined),
                child: Column(
                  children: [
                    V5TextField(
                      key: const Key('professional-profile-address-line-1'),
                      label: 'Adresse',
                      controller: _professionalAddressLine1,
                      focusNode: _professionalAddressLine1Focus,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 240,
                      isRequired: true,
                      validator: _professionalAddressLine1Validator,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: V5Spacing.sm),
                    V5TextField(
                      key: const Key('professional-profile-address-line-2'),
                      label: 'Complément d’adresse (facultatif)',
                      controller: _professionalAddressLine2,
                      focusNode: _professionalAddressLine2Focus,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 240,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: V5Spacing.sm),
                    Theme(
                      data: Theme.of(context).copyWith(
                        textTheme: Theme.of(context).textTheme.copyWith(
                          labelLarge: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(fontSize: 10.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                          child: V5TextField(
                                key: const Key(
                                  'professional-profile-postal-code',
                                ),
                            label: 'Code postal',
                            controller: _professionalPostalCode,
                            focusNode: _professionalPostalCodeFocus,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                            maxLength: 5,
                            isRequired: true,
                            validator: _professionalPostalCodeValidator,
                            onChanged: (_) => setState(() {}),
                          ),
                          ),
                          const SizedBox(width: V5Spacing.xs),
                          Expanded(
                            flex: 3,
                          child: V5TextField(
                            key: const Key('professional-profile-city'),
                            label: 'Ville',
                            controller: _professionalCity,
                            focusNode: _professionalCityFocus,
                            textCapitalization: TextCapitalization.words,
                            maxLength: 120,
                            isRequired: true,
                            validator: _professionalCityValidator,
                            onChanged: (_) => setState(() {}),
                          ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: V5Spacing.sm),
                    V5TextField(
                      key: const Key('professional-profile-country-code'),
                      label: 'Code pays',
                      supportingText: 'FR par défaut',
                      controller: _professionalCountryCode,
                      focusNode: _professionalCountryCodeFocus,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: _professionalCountryCodeValidator,
                    ),
                  ],
                ),
              ),
              ],
              if (_showsProfessionalInformation && _showsCpts)
              const SizedBox(height: V5Spacing.sm),
              if (_showsCpts)
              V5Section(
                title: 'CPTS',
                leading: const Icon(Icons.hub_outlined),
                child: V5TextField(
                  key: const Key('professional-profile-cpts-label'),
                  label: 'Nom de la CPTS (facultatif)',
                  supportingText: 'Laissez vide si vous n’avez aucune CPTS.',
                  controller: _cptsLabel,
                  focusNode: _cptsLabelFocus,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 160,
                ),
              ),
              if (_showsCpts && _showsEquipment)
              const SizedBox(height: V5Spacing.sm),
              if (_showsEquipment)
              V5Section(
                title: 'Mon matériel disponible',
                leading: const Icon(Icons.medical_services_outlined),
                child: Column(
                  children: [
                    for (final equipment in _equipmentOptions)
                      V5CheckboxTile(
                        key: Key(
                          'professional-profile-equipment-${equipment.id}',
                        ),
                        label: equipment.label,
                        value: _equipment.contains(equipment.id),
                        onChanged: (selected) => setState(() {
                          if (selected) {
                            _equipment.add(equipment.id);
                          } else {
                            _equipment.remove(equipment.id);
                          }
                        }),
                      ),
                    if (ProfessionalEquipmentRegistry.requiresDetails(
                      _equipment,
                    ))
                      V5TextField(
                        key: const Key(
                          'professional-profile-equipment-details',
                        ),
                        label: 'Précisez le matériel',
                        controller: _equipmentDetails,
                        focusNode: _equipmentDetailsFocus,
                        isRequired: true,
                        validator: _required,
                      ),
                  ],
                ),
              ),
              if (_showsEquipment && _showsPreferences)
              const SizedBox(height: V5Spacing.sm),
              if (_showsPreferences)
              V5Section(
                title: 'Préférences générales',
                leading: const Icon(Icons.tune_rounded),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ces préférences sont récurrentes. Elles ne créent ni '
                      'agenda ni disponibilité datée.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.v5Colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: V5Spacing.sm),
                    Text(
                      'Où souhaitez-vous intervenir ?',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.v5Colors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: V5Spacing.xs),
                    _MultiSelectPreferenceField<String>(
                      key: const Key('professional-profile-territories'),
                      label: 'Secteurs d’intervention',
                      keyPrefix: 'professional-profile-territory',
                      values: _territoryIds,
                      options: _territoryOptions,
                      onChanged: (values) => setState(() {
                        _territoryIds
                          ..clear()
                          ..addAll(values);
                      }),
                    ),
                    const SizedBox(height: V5Spacing.sm),
                    _MultiSelectPreferenceField<String>(
                      key: const Key('professional-profile-locations'),
                      label: 'Établissements précis (facultatif)',
                      keyPrefix: 'professional-profile-location',
                        searchable: true,
                      values: _locationIds,
                      options: _locationOptions,
                      onChanged: (values) => setState(() {
                        _locationIds
                          ..clear()
                          ..addAll(values);
                      }),
                    ),
                    const SizedBox(height: V5Spacing.sm),
                    _MultiSelectPreferenceField<ProfessionalWeekday>(
                      key: const Key('professional-profile-weekdays'),
                      label: 'Jours',
                      keyPrefix: 'professional-profile-weekday',
                      values: _preferredWeekdays,
                      options: [
                        for (final weekday in ProfessionalWeekday.values)
                          _PreferenceOption(weekday, _weekdayLabel(weekday)),
                      ],
                      onChanged: (values) => setState(() {
                        _preferredWeekdays
                          ..clear()
                          ..addAll(values);
                      }),
                    ),
                    const SizedBox(height: V5Spacing.sm),
                    _MultiSelectPreferenceField<String>(
                      key: const Key('professional-profile-time-bands'),
                      label: 'Horaires',
                      keyPrefix: 'professional-profile-time-band',
                      values: _timeBands,
                      options: const [
                        _PreferenceOption('morning', 'Matin'),
                        _PreferenceOption('afternoon', 'Après-midi'),
                        _PreferenceOption('evening', 'Soirée'),
                        _PreferenceOption('night', 'Nuit'),
                      ],
                      onChanged: (values) => setState(() {
                        _timeBands
                          ..clear()
                          ..addAll(values);
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: V5Spacing.lg),
              if (_hiddenCompletionGaps.isNotEmpty) ...[
                Text(
                  'Votre profil doit être complété avant cette modification. '
                  'Priorité : ${_hiddenCompletionGaps.first.label(_profession)}.',
                  key: const Key('targeted-save-completion-message'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.v5Colors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: V5Spacing.xs),
                TextButton.icon(
                  key: const Key('complete-profile-after-targeted-save'),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(_ProfileEditorResult.completeProfile),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Compléter mon profil'),
                ),
                const SizedBox(height: V5Spacing.sm),
              ],
              V5Button(
                key: const Key('save-professional-profile'),
                expanded: true,
                loading: _saving,
                onPressed: _saving ? null : _save,
                label: _saving ? 'Enregistrement…' : 'Enregistrer',
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _required(String? value) =>
      value?.trim().isNotEmpty == true ? null : 'Champ requis';

  static String? _emailValidator(String? value) {
    if (!ProfessionalProfileValidation.isValidEmail(value)) {
      return 'Email invalide';
    }
    return null;
  }

  String? _idValidator(String? value) =>
      professionalIdentifierValidationMessage(_idType, value);

  bool get _hasProfessionalAddressInput => [
    _professionalAddressLine1.text,
    _professionalAddressLine2.text,
    _professionalPostalCode.text,
    _professionalCity.text,
  ].any((value) => value.trim().isNotEmpty);

  String get _normalizedProfessionalCountryCode {
    final value = _professionalCountryCode.text.trim().toUpperCase();
    return value.isEmpty ? 'FR' : value;
  }

  String? _professionalAddressLine1Validator(String? value) {
    return _required(value) == null
        ? null
        : 'Renseignez l’adresse professionnelle.';
  }

  String? _professionalPostalCodeValidator(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return 'Renseignez le code postal professionnel.';
    if (_normalizedProfessionalCountryCode == 'FR' &&
        !RegExp(r'^\d{5}$').hasMatch(normalized)) {
      return 'Le code postal doit contenir exactement 5 chiffres.';
    }
    return null;
  }

  String? _professionalCityValidator(String? value) {
    return _required(value) == null
        ? null
        : 'Renseignez la ville professionnelle.';
  }

  String? _professionalCountryCodeValidator(String? value) {
    if (!_hasProfessionalAddressInput) return null;
    final normalized = value?.trim().toUpperCase() ?? '';
    if (normalized.isEmpty) return null;
    return RegExp(r'^[A-Z]{2}$').hasMatch(normalized)
        ? null
        : 'Le code pays doit contenir deux lettres.';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      await _focusFirstInvalidField();
      return;
    }
    setState(() {
      _saving = true;
      _hiddenCompletionGaps = const [];
    });
    late final VolunteerProfile updatedProfile;
    try {
      final currentProfile =
          widget.profile ??
          VolunteerProfile(
            uid: '',
            firstName: '',
            lastName: '',
            phone: '',
            profession: _profession,
          );
      final updatedPreferences = MobilizationPreferences(
        preferredMobilizationTypes:
            currentProfile
                .mobilizationPreferences
                ?.preferredMobilizationTypes ??
            const {},
        territoryIds: _territoryIds,
        locationIds: _locationIds,
        preferredWeekdays: _preferredWeekdays,
        preferredTimeBands: _timeBands,
        schemaVersion:
            currentProfile.mobilizationPreferences?.schemaVersion ?? 1,
      );
      final updatedEquipmentDetails =
          ProfessionalEquipmentRegistry.requiresDetails(_equipment)
          ? _equipmentDetails.text.trim()
          : '';
      switch (widget.mode) {
        case _ProfileEditorMode.preferences:
          updatedProfile = currentProfile.copyWith(
            mobilizationPreferences: updatedPreferences,
          );
        case _ProfileEditorMode.equipment:
          updatedProfile = currentProfile.copyWith(
            equipment: _equipment.toList(growable: false),
            otherEquipmentDetails: updatedEquipmentDetails,
          );
        case _ProfileEditorMode.cpts:
          updatedProfile = currentProfile.copyWith(
            cptsLabel: _cptsLabel.text.trim(),
          );
        case _ProfileEditorMode.completion:
        case _ProfileEditorMode.full:
          updatedProfile = currentProfile.copyWith(
            firstName: normalizeProfessionalName(_firstName.text),
            lastName: normalizeProfessionalName(_lastName.text),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            profession: _profession,
            professionalIdType: _idType,
            professionalIdValue: _idValue.text.trim(),
            cptsLabel: _cptsLabel.text.trim(),
            professionalAddressLine1: _professionalAddressLine1.text.trim(),
            professionalAddressLine2: _professionalAddressLine2.text.trim(),
            professionalPostalCode: _professionalPostalCode.text.trim(),
            professionalCity: _professionalCity.text.trim(),
            professionalCountryCode: _normalizedProfessionalCountryCode,
            equipment: _equipment.toList(growable: false),
            otherEquipmentDetails: updatedEquipmentDetails,
            mobilizationPreferences: updatedPreferences,
          );
      }
      await RepositoryScope.of(context).saveVolunteerProfile(updatedProfile);
      if (mounted) Navigator.of(context).pop(_ProfileEditorResult.saved);
    } catch (error) {
      if (!mounted) return;
      final persistenceError = ProfessionalProfileValidation.persistenceError(
        email: updatedProfile.email,
        professionalIdType: updatedProfile.effectiveProfessionalIdType,
        professionalIdValue: updatedProfile.effectiveProfessionalIdValue,
        cptsId: updatedProfile.cptsId,
        cptsLabel: updatedProfile.cptsLabel,
        professionalAddressLine1: updatedProfile.professionalAddressLine1,
        professionalAddressLine2: updatedProfile.professionalAddressLine2,
        professionalPostalCode: updatedProfile.professionalPostalCode,
        professionalCity: updatedProfile.professionalCity,
        professionalCountryCode: updatedProfile.professionalCountryCode,
        equipment: updatedProfile.equipment,
        otherEquipmentDetails: updatedProfile.otherEquipmentDetails,
      );
      final hiddenGaps = ProfessionalProfileValidation.engagementGapsForProfile(
        updatedProfile,
      ).where((gap) => !_showsGap(gap)).toList(growable: false);
      final isHiddenCompletenessFailure =
          !_showsProfessionalInformation &&
          hiddenGaps.isNotEmpty &&
          error is RepositoryException &&
          persistenceError != null &&
          error.message == persistenceError;
      if (isHiddenCompletenessFailure) {
        setState(() {
          _saving = false;
          _hiddenCompletionGaps = hiddenGaps;
        });
        return;
      }
      setState(() => _saving = false);
      V5Toast.show(
        context,
        message: 'Le profil n’a pas pu être enregistré. Réessayez.',
        tone: V5ToastTone.danger,
      );
    }
  }

  bool _showsGap(EngagementProfileGap gap) => switch (gap) {
    EngagementProfileGap.cptsLabel => _showsCpts,
    EngagementProfileGap.equipmentDetails => _showsEquipment,
    _ => _showsProfessionalInformation,
  };

  Future<void> _focusFirstInvalidField({bool announce = true}) async {
    final failure = _firstInvalidField();
    if (failure == null) return;
    await _focusAndAnnounce(
      focusNode: failure.focusNode,
      label: failure.label,
      error: failure.error,
      announce: announce,
    );
  }

  ({FocusNode focusNode, String label, String error})? _firstInvalidField() {
    final candidates = <({FocusNode focusNode, String label, String? error})>[
      if (_showsProfessionalInformation) ...[
        (
          focusNode: _firstNameFocus,
          label: 'Prénom',
          error: _required(_firstName.text),
        ),
        (
          focusNode: _lastNameFocus,
          label: 'Nom',
          error: _required(_lastName.text),
        ),
        (
          focusNode: _phoneFocus,
          label: 'Téléphone',
          error: _required(_phone.text),
        ),
        (
          focusNode: _emailFocus,
          label: 'Email professionnel',
          error: _emailValidator(_email.text),
        ),
        (
          focusNode: _idTypeFocus,
          label: 'Type d’identifiant',
          error:
              _idType == ProfessionalIdType.rpps ||
                  _idType == ProfessionalIdType.ordinal ||
                  (_idType == ProfessionalIdType.none &&
                      professionAllowsNoIdentifier(_profession))
              ? null
              : 'Choisissez un identifiant professionnel.',
        ),
        if (_idType != ProfessionalIdType.none)
          (
            focusNode: _idValueFocus,
            label: _idType.label,
            error: _idValidator(_idValue.text),
          ),
        (
          focusNode: _professionalAddressLine1Focus,
          label: 'Adresse professionnelle',
          error: _professionalAddressLine1Validator(
            _professionalAddressLine1.text,
          ),
        ),
        (
          focusNode: _professionalPostalCodeFocus,
          label: 'Code postal professionnel',
          error: _professionalPostalCodeValidator(_professionalPostalCode.text),
        ),
        (
          focusNode: _professionalCityFocus,
          label: 'Ville professionnelle',
          error: _professionalCityValidator(_professionalCity.text),
        ),
        (
          focusNode: _professionalCountryCodeFocus,
          label: 'Code pays',
          error: _professionalCountryCodeValidator(
            _professionalCountryCode.text,
          ),
        ),
      ],
      if (_showsEquipment &&
          ProfessionalEquipmentRegistry.requiresDetails(_equipment))
        (
          focusNode: _equipmentDetailsFocus,
          label: 'Précisez le matériel',
          error: _required(_equipmentDetails.text),
        ),
    ];
    for (final candidate in candidates) {
      if (candidate.error != null) {
        return (
          focusNode: candidate.focusNode,
          label: candidate.label,
          error: candidate.error!,
        );
      }
    }
    return null;
  }

  Future<void> _focusAndAnnounce({
    required FocusNode focusNode,
    required String label,
    required String error,
    bool announce = true,
  }) async {
    focusNode.requestFocus();
    final fieldContext = focusNode.context;
    if (fieldContext != null) {
      await Scrollable.ensureVisible(
        fieldContext,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
    }
    if (!mounted) return;
    if (announce && MediaQuery.supportsAnnounceOf(context)) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        '$label. Erreur : $error',
        Directionality.of(context),
      );
    }
  }
}
