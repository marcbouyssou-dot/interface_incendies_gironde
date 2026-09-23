import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../models/health_profession.dart';
import '../models/need.dart';
import '../models/professional_equipment.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/diffusion_read_repository.dart';
import '../repositories/diffusion_read_repository_scope.dart';
import '../repositories/platform_runtime.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../utils/french_date_time.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';
import '../widgets/responsible_diffusion_summary.dart';
import '../widgets/v5_controls.dart';
import '../widgets/v5_form_system.dart';

Future<void> openMissionEditor(BuildContext context, CoordinationNeed mission) {
  final liveData = LiveCoordinationDataScope.of(context);
  return Navigator.of(context).push<void>(
    AppPageRoute<void>(
      builder: (_) => LiveCoordinationDataScope(
        data: liveData,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: SafeArea(child: CreateNeedScreen(mission: mission)),
        ),
      ),
    ),
  );
}

class CreateNeedScreen extends StatefulWidget {
  const CreateNeedScreen({
    super.key,
    this.onViewMission,
    this.onMissionPublished,
    this.mission,
    this.mobilizationId,
    this.createMission,
  });

  final VoidCallback? onViewMission;
  final ValueChanged<CoordinationNeed>? onMissionPublished;
  final CoordinationNeed? mission;
  final String? mobilizationId;
  final Future<String> Function(MissionDraft draft)? createMission;

  @override
  State<CreateNeedScreen> createState() => _CreateNeedScreenState();
}

class _ResponsibleAccessReadFailure extends StatelessWidget {
  const _ResponsibleAccessReadFailure();

  @override
  Widget build(BuildContext context) {
    return const PageContainer(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Votre accès responsable ne peut pas être vérifié.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _CreateNeedScreenState extends State<CreateNeedScreen> {
  final Map<String, int> _requiredByProfession = {
    for (final profession in HealthProfessionRegistry.values) profession.id: 0,
  };
  final _locationKey = GlobalKey(debugLabel: 'mission-location-anchor');
  final _dateKey = GlobalKey(debugLabel: 'mission-date-anchor');
  final _startTimeKey = GlobalKey(debugLabel: 'mission-start-time-anchor');
  final _endTimeKey = GlobalKey(debugLabel: 'mission-end-time-anchor');
  final Map<String, GlobalKey> _quotaKeys = {
    for (final profession in HealthProfessionRegistry.values)
      profession.id: GlobalKey(
        debugLabel: 'mission-${profession.id}-quota-anchor',
      ),
  };
  final _locationFocusNode = FocusNode(debugLabel: 'mission-location');
  final _dateFocusNode = FocusNode(debugLabel: 'mission-date');
  final _startTimeFocusNode = FocusNode(debugLabel: 'mission-start-time');
  final _endTimeFocusNode = FocusNode(debugLabel: 'mission-end-time');
  final Map<String, FocusNode> _quotaFocusNodes = {
    for (final profession in HealthProfessionRegistry.values)
      profession.id: FocusNode(debugLabel: 'mission-${profession.id}-quota'),
  };
  ResponsePlace? _selectedLocation;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  NeedPriority _priority = NeedPriority.standard;
  final Set<String> _equipment = {};
  final List<String> _equipmentProfessionHistory = [];
  final _detailsController = TextEditingController();
  bool _publishing = false;
  String? _errorMessage;
  MissionDraft? _reviewDraft;
  _PublishedMission? _publishedMission;
  CoordinationRepository? _repository;
  LiveCoordinationData? _liveData;
  Stream<ResponsibleAccess?>? _responsibleAccess;
  Stream<List<ResponsePlace>>? _locations;

  bool get _isEditing => widget.mission != null;

  @override
  void initState() {
    super.initState();
    final mission = widget.mission;
    if (mission == null) return;
    _selectedDate = mission.startAt == null
        ? null
        : DateUtils.dateOnly(mission.startAt!);
    _startTime = mission.startAt == null
        ? null
        : TimeOfDay.fromDateTime(mission.startAt!);
    _endTime = mission.endAt == null
        ? null
        : TimeOfDay.fromDateTime(mission.endAt!);
    _priority = mission.priority;
    for (final quota in mission.professionQuotas.values) {
      _requiredByProfession[quota.professionId] = quota.required;
    }
    for (final profession in HealthProfessionRegistry.values) {
      if (_requiredByProfession[profession.id]! > 0) {
        _equipmentProfessionHistory.add(profession.id);
      }
    }
    _equipment
      ..clear()
      ..addAll(mission.equipment);
    _retainCompatibleEquipment();
    _detailsController.text = mission.details ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = RepositoryScope.of(context);
    final liveData = LiveCoordinationDataScope.of(context);
    if (!identical(repository, _repository) ||
        !identical(liveData, _liveData)) {
      _repository = repository;
      _liveData = liveData;
      _responsibleAccess = liveData.watchResponsibleAccess();
      _locations = liveData.watchLocations();
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _locationFocusNode.dispose();
    _dateFocusNode.dispose();
    _startTimeFocusNode.dispose();
    _endTimeFocusNode.dispose();
    for (final focusNode in _quotaFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = _repository!;
    return StreamBuilder<ResponsibleAccess?>(
      stream: _responsibleAccess,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (isInvalidResponsibleAccessError(snapshot.error)) {
            return const InvalidResponsibleAccessState();
          }
          return const _ResponsibleAccessReadFailure();
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const V5LoadingState(label: 'Chargement de vos accès…');
        }
        final access = snapshot.data;
        if (access == null) {
          return ResponsibleLogin(repository: repository);
        }
        if (!access.active) {
          return ResponsibleLogin(
            repository: repository,
            initialMessage: 'Votre compte responsable est inactif.',
          );
        }
        return StreamBuilder<List<ResponsePlace>>(
          stream: _locations,
          builder: (context, locationsSnapshot) {
            if (locationsSnapshot.hasError) {
              return const CriticalDataUnavailableState(
                stateKey: Key('create-need-locations-unavailable-state'),
                eyebrow: 'Nouvelle mission',
                title: 'Informations des centres indisponibles',
                message:
                    'Nous ne pouvons pas charger les lieux d’intervention '
                    'pour le moment.',
                safetyMessage:
                    'La création d’un besoin est suspendue afin d’éviter '
                    'd’utiliser des informations périmées.',
              );
            }
            if (!locationsSnapshot.hasData) {
              return const V5LoadingState(label: 'Chargement des centres…');
            }
            return _buildForm(context, access, locationsSnapshot.data!);
          },
        );
      },
    );
  }

  Widget _buildForm(
    BuildContext context,
    ResponsibleAccess access,
    List<ResponsePlace> locations,
  ) {
    if (!_isEditing && _publishedMission != null) {
      final diffusionRepository = DiffusionReadRepositoryScope.maybeOf(context);
      return _MissionPublishedView(
        mission: _publishedMission!,
        diffusionRepository: diffusionRepository,
        onViewMission: widget.onViewMission,
        onCreateAnother: _resetForm,
      );
    }
    if (!_isEditing && _reviewDraft != null) {
      return _MissionReviewView(
        draft: _reviewDraft!,
        publishing: _publishing,
        errorMessage: _errorMessage,
        onBack: _publishing
            ? null
            : () => setState(() {
                _reviewDraft = null;
                _errorMessage = null;
              }),
        onPublish: _publishing
            ? null
            : () => _publish(access, confirmedDraft: _reviewDraft!),
      );
    }
    if (_isEditing && _selectedLocation == null) {
      _selectedLocation = responsePlaceForNeed(widget.mission!, locations);
    }
    final responsibleLocationId = _isEditing
        ? null
        : access.singleManagedLocationId;
    if (responsibleLocationId != null) {
      final responsibleLocation = locations
          .where(
            (location) =>
                location.id == responsibleLocationId &&
                location.isOperational &&
                location.isEnabled,
          )
          .firstOrNull;
      if (responsibleLocation == null) {
        return const CriticalDataUnavailableState(
          stateKey: Key('responsible-create-location-unavailable'),
          eyebrow: 'Nouveau besoin',
          title: 'Centre indisponible',
          message: 'Le centre associé à votre compte ne peut pas être chargé.',
          safetyMessage:
              'La création est suspendue afin de ne jamais publier pour un '
              'autre centre.',
        );
      }
      _selectedLocation = responsibleLocation;
    }
    final requestedProfessionals = _requiredByProfession.values.fold<int>(
      0,
      (total, quota) => total + quota,
    );
    final equipmentProfession = _equipmentProfession;
    final displayedEquipment = _displayedEquipment;
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDate =
        _isEditing && _selectedDate != null && _selectedDate!.isBefore(today)
        ? _selectedDate!
        : today;
    return PageContainer(
      child: Material(
        color: context.v5Colors.canvas,
        child: ListView(
          key: const PageStorageKey('create'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (Navigator.of(context).canPop()) ...[
                      TextButton.icon(
                        key: const Key('create-need-back'),
                        style: TextButton.styleFrom(
                          foregroundColor: context.v5Colors.textPrimary,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(44, 44),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: _publishing
                            ? null
                            : () => Navigator.maybePop(context),
                        icon: const Icon(Icons.chevron_left_rounded, size: 18),
                        label: const Text('Retour'),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _isEditing
                                ? 'Modifier la mission'
                                : 'Exprimer un besoin',
                            style: TextStyle(
                              color: context.v5Colors.textPrimary,
                              fontSize: 24,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.55,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const BrandMark(size: 46),
                      ],
                    ),
                    const SizedBox(height: 14),
                    V5Section(
                      title: _isEditing
                          ? 'Professionnels recherchés'
                          : '1. De quoi avez-vous besoin ?',
                      leading: const Icon(Icons.groups_2_outlined),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isEditing) ...[
                            Text(
                              'Choisissez la profession recherchée.',
                              style: TextStyle(
                                color: context.v5Colors.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: V5Spacing.md),
                            Text(
                              '2. Combien ?',
                              style: TextStyle(
                                color: context.v5Colors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: V5Spacing.xs),
                          ],
                          Text(
                            'Un besoin concerne une seule profession. Ajouter '
                            'une autre profession remplace la sélection actuelle.',
                            style: TextStyle(
                              color: context.v5Colors.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: V5Spacing.sm),
                          for (final profession
                              in HealthProfessionRegistry.values) ...[
                            _QuotaStepper(
                              key: _quotaKeys[profession.id],
                              profession: profession,
                              value: _requiredByProfession[profession.id]!,
                              removeKey: Key('${profession.id}-remove'),
                              addKey: Key('${profession.id}-add'),
                              addFocusNode: _quotaFocusNodes[profession.id]!,
                              onRemove:
                                  !_publishing &&
                                      _requiredByProfession[profession.id]! > 0
                                  ? () => _changeQuota(profession.id, -1)
                                  : null,
                              onAdd: _publishing
                                  ? null
                                  : () => _changeQuota(profession.id, 1),
                            ),
                            if (profession !=
                                HealthProfessionRegistry.values.last)
                              const SizedBox(height: V5Spacing.xs),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    V5Section(
                      title: _isEditing ? 'Lieu' : '3. Où ?',
                      leading: const Icon(Icons.place_outlined),
                      child: _LocationInput(
                        key: _locationKey,
                        access: access,
                        locations: locations,
                        selectedLocation: _selectedLocation,
                        preserveUnavailableSelection: _isEditing,
                        enabled: !_publishing,
                        focusNode: _locationFocusNode,
                        onSelected: (location) {
                          if (!mounted) return;
                          setState(() {
                            _selectedLocation = location;
                            _errorMessage = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    V5Section(
                      title: _isEditing ? 'Créneau' : '4. Quand ?',
                      leading: const Icon(Icons.event_available_outlined),
                      child: Column(
                        children: [
                          KeyedSubtree(
                            key: _dateKey,
                            child: V5DateField(
                              key: const Key('mission-date'),
                              label: 'Date',
                              value: _selectedDate,
                              firstDate: firstDate,
                              lastDate: DateTime(
                                today.year + 2,
                                today.month,
                                today.day,
                              ),
                              formatter: (_, value) => _formatDate(value),
                              focusNode: _dateFocusNode,
                              onChanged: _publishing
                                  ? null
                                  : (value) {
                                      if (value == null || !mounted) return;
                                      setState(() {
                                        _selectedDate = value;
                                        _errorMessage = null;
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(height: V5Spacing.md),
                          KeyedSubtree(
                            key: _startTimeKey,
                            child: V5TimeField(
                              key: const Key('mission-start-time'),
                              label: 'Début',
                              value: _startTime,
                              pickerInitialValue: const TimeOfDay(
                                hour: 8,
                                minute: 0,
                              ),
                              use24HourFormat: true,
                              focusNode: _startTimeFocusNode,
                              onChanged: _publishing
                                  ? null
                                  : (value) {
                                      if (value == null || !mounted) return;
                                      setState(() {
                                        _startTime = value;
                                        _errorMessage = null;
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(height: V5Spacing.md),
                          KeyedSubtree(
                            key: _endTimeKey,
                            child: V5TimeField(
                              key: const Key('mission-end-time'),
                              label: 'Fin',
                              value: _endTime,
                              pickerInitialValue: const TimeOfDay(
                                hour: 12,
                                minute: 0,
                              ),
                              use24HourFormat: true,
                              focusNode: _endTimeFocusNode,
                              onChanged: _publishing
                                  ? null
                                  : (value) {
                                      if (value == null || !mounted) return;
                                      setState(() {
                                        _endTime = value;
                                        _errorMessage = null;
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    V5Section(
                      title: _isEditing ? 'Priorité' : '5. Priorité',
                      leading: const Icon(Icons.priority_high_rounded),
                      child: V5SelectField<NeedPriority>(
                        key: const Key('mission-priority'),
                        label: 'Priorité',
                        value: _priority,
                        sheetTitle: 'Choisir la priorité',
                        supportingText:
                            'La priorité qualifie le besoin sans modifier les droits.',
                        options: [
                          for (final priority in NeedPriority.values)
                            V5SelectOption(
                              value: priority,
                              label: priority.label,
                            ),
                        ],
                        onChanged: _publishing
                            ? null
                            : (value) {
                                if (value == null || !mounted) return;
                                setState(() {
                                  _priority = value;
                                  _errorMessage = null;
                                });
                              },
                      ),
                    ),
                    const SizedBox(height: 20),
                    V5Section(
                      title: _isEditing
                          ? 'Informations complémentaires'
                          : '6. Informations complémentaires',
                      leading: const Icon(Icons.medical_services_outlined),
                      child: equipmentProfession == null
                          ? Padding(
                              key: Key('mission-equipment-empty'),
                              padding: EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(top: 1),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      size: 14,
                                      color: context.v5Colors.textSecondary,
                                    ),
                                  ),
                                  SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      'Ajoutez au moins un professionnel recherché '
                                      'pour afficher le matériel correspondant.',
                                      style: TextStyle(
                                        color: context.v5Colors.textSecondary,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _EquipmentProfessionContext(
                                  professionLabel:
                                      equipmentProfession.missionLabel,
                                ),
                                const SizedBox(height: V5Spacing.sm),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: [
                                    for (final equipment in displayedEquipment)
                                      V5ChoiceChip(
                                        key: Key(
                                          'mission-equipment-${equipment.id}',
                                        ),
                                        label: equipment.label,
                                        selected: _equipment.contains(
                                          equipment.label,
                                        ),
                                        onSelected: _publishing
                                            ? null
                                            : (selected) => setState(() {
                                                if (selected) {
                                                  _equipment.add(
                                                    equipment.label,
                                                  );
                                                } else {
                                                  _equipment.remove(
                                                    equipment.label,
                                                  );
                                                }
                                              }),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),
                    V5TextField(
                      label: 'Commentaire facultatif',
                      controller: _detailsController,
                      enabled: !_publishing,
                      maxLines: 4,
                      minLines: 3,
                      hint: 'Ajouter un commentaire (optionnel)',
                      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                      onTapOutside: _isEditing
                          ? (_) => FocusManager.instance.primaryFocus?.unfocus()
                          : null,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        container: true,
                        liveRegion: true,
                        label: 'Erreur : $_errorMessage',
                        child: ExcludeSemantics(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: context.v5Colors.dangerContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _errorMessage!,
                              key: const Key('mission-form-error'),
                              style: TextStyle(
                                color: context.v5Colors.danger,
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    V5Button(
                      key: Key(
                        _isEditing ? 'update-mission' : 'review-mission',
                      ),
                      expanded: true,
                      backgroundColor: context.v5Colors.accent,
                      foregroundColor: context.v5Colors.onAccent,
                      loading: _publishing,
                      onPressed: _publishing
                          ? null
                          : _isEditing
                          ? () => _publish(access)
                          : _review,
                      label: _publishing
                          ? _isEditing
                                ? 'Enregistrement…'
                                : 'Publication…'
                          : _isEditing
                          ? 'Enregistrer les modifications'
                          : 'Voir le résumé',
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        requestedProfessionals == 0
                            ? 'Aucun professionnel demandé pour le moment'
                            : '$requestedProfessionals professionnel${requestedProfessionals > 1 ? 's' : ''} demandé${requestedProfessionals > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: context.v5Colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: context.v5Colors.textSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: const Size(44, 44),
                          tapTargetSize: MaterialTapTargetSize.padded,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _publishing
                            ? null
                            : RepositoryScope.of(context).signOutResponsible,
                        icon: const Icon(Icons.logout_rounded, size: 15),
                        label: const Text('Se déconnecter'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _review() {
    final validation = _validate();
    if (validation != null) {
      setState(() => _errorMessage = validation.message);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showValidationError(validation),
      );
      return;
    }
    setState(() {
      _reviewDraft = _buildDraft();
      _errorMessage = null;
    });
  }

  Future<void> _publish(
    ResponsibleAccess access, {
    MissionDraft? confirmedDraft,
  }) async {
    if (_publishing) return;

    if (confirmedDraft == null) {
      final validation = _validate();
      if (validation != null) {
        setState(() => _errorMessage = validation.message);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showValidationError(validation),
        );
        return;
      }
    }
    final draft = confirmedDraft ?? _buildDraft();
    setState(() {
      _publishing = true;
      _errorMessage = null;
    });
    debugPrint('Publication mission : début de validation confirmée');
    try {
      if (_isEditing) {
        await RepositoryScope.of(
          context,
        ).updateMission(widget.mission!.id, draft);
        if (!mounted) return;
        setState(() => _publishing = false);
        V5Toast.show(
          context,
          message: 'Mission mise à jour.',
          tone: V5ToastTone.success,
        );
        if (Navigator.of(context).canPop()) Navigator.pop(context);
        return;
      }
      final id =
          await (widget.createMission?.call(draft) ??
              RepositoryScope.of(context).createMission(draft));
      if (!mounted) return;
      debugPrint('Publication mission confirmée : $id');
      widget.onMissionPublished?.call(
        CoordinationNeed(
          id: id,
          mobilizationId: widget.mobilizationId,
          locationId: draft.location.id,
          place: draft.location.name,
          group: draft.location.group,
          date: FrenchDateTime.date(draft.startAt),
          time: FrenchDateTime.timeRange(draft.startAt, draft.endAt),
          startAt: draft.startAt,
          endAt: draft.endAt,
          requiredPhysiotherapists: draft.requiredPhysiotherapists,
          registeredPhysiotherapists: 0,
          requiredPodiatrists: draft.requiredPodiatrists,
          registeredPodiatrists: 0,
          professionQuotas: draft.professionQuotas,
          equipment: List.of(draft.equipment),
          priority: draft.priority,
          details: draft.details.trim(),
          createdBy: access.uid,
        ),
      );
      setState(() {
        _publishing = false;
        _reviewDraft = null;
        _publishedMission = _PublishedMission(id: id, draft: draft);
      });
    } on RepositoryException catch (error, stackTrace) {
      debugPrint('Enregistrement mission refusé : $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _errorMessage = _isEditing
            ? error.message
            : 'La mission n’a pas pu être publiée. Réessayez.';
      });
    } catch (error, stackTrace) {
      debugPrint('Publication mission échouée : $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _errorMessage = _isEditing
            ? 'La mission n’a pas pu être mise à jour. Réessayez.'
            : 'La mission n’a pas pu être publiée. Réessayez.';
      });
    }
  }

  _MissionFormValidationError? _validate() {
    if (_selectedLocation == null) {
      return _MissionFormValidationError(
        message: 'Choisissez un lieu d’intervention.',
        targetKey: _locationKey,
        focusNode: _locationFocusNode,
      );
    }
    if (_selectedDate == null) {
      return _MissionFormValidationError(
        message: 'Choisissez une date.',
        targetKey: _dateKey,
        focusNode: _dateFocusNode,
      );
    }
    if (_startTime == null) {
      return _MissionFormValidationError(
        message: 'Choisissez une heure de début.',
        targetKey: _startTimeKey,
        focusNode: _startTimeFocusNode,
      );
    }
    if (_endTime == null) {
      return _MissionFormValidationError(
        message: 'Choisissez une heure de fin.',
        targetKey: _endTimeKey,
        focusNode: _endTimeFocusNode,
      );
    }
    if (_minutes(_endTime!) <= _minutes(_startTime!)) {
      return _MissionFormValidationError(
        message: 'L’heure de fin doit être postérieure à l’heure de début.',
        targetKey: _endTimeKey,
        focusNode: _endTimeFocusNode,
      );
    }
    if (_requiredByProfession.values.every((quota) => quota == 0)) {
      final firstProfession = HealthProfessionRegistry.values.first;
      return _MissionFormValidationError(
        message: 'Indiquez au moins un professionnel nécessaire.',
        targetKey: _quotaKeys[firstProfession.id]!,
        focusNode: _quotaFocusNodes[firstProfession.id]!,
      );
    }
    final mission = widget.mission;
    if (mission != null) {
      for (final quota in mission.professionQuotas.values) {
        if (_requiredByProfession[quota.professionId]! < quota.registered) {
          return _MissionFormValidationError(
            message:
                'Le besoin ne peut pas être inférieur aux engagements '
                'confirmés.',
            targetKey: _quotaKeys[quota.professionId]!,
            focusNode: _quotaFocusNodes[quota.professionId]!,
          );
        }
      }
    }
    return null;
  }

  Future<void> _showValidationError(
    _MissionFormValidationError validation,
  ) async {
    if (!mounted) return;
    validation.focusNode.requestFocus();
    final targetContext = validation.targetKey.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: 0.15,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  MissionDraft _buildDraft() {
    final schedule = MissionSchedule.fromLocal(
      date: _selectedDate!,
      startMinutes: _minutes(_startTime!),
      endMinutes: _minutes(_endTime!),
    );
    return MissionDraft(
      location: _selectedLocation!,
      startAt: schedule.startAt,
      endAt: schedule.endAt,
      requiredByProfession: Map.of(_requiredByProfession),
      priority: _priority,
      equipment: _equipment.toList(growable: false),
      details: _detailsController.text,
    );
  }

  void _resetForm() {
    setState(() {
      _selectedLocation = null;
      _selectedDate = null;
      _startTime = null;
      _endTime = null;
      _priority = NeedPriority.standard;
      for (final profession in _requiredByProfession.keys) {
        _requiredByProfession[profession] = 0;
      }
      _equipmentProfessionHistory.clear();
      _equipment.clear();
      _detailsController.clear();
      _errorMessage = null;
      _reviewDraft = null;
      _publishedMission = null;
    });
  }

  void _changeQuota(String professionId, int delta) {
    final current = _requiredByProfession[professionId]!;
    final updated = current + delta;
    setState(() {
      if (!_isEditing && delta > 0 && current == 0) {
        for (final otherProfessionId in _requiredByProfession.keys) {
          if (otherProfessionId != professionId) {
            _requiredByProfession[otherProfessionId] = 0;
          }
        }
        _equipmentProfessionHistory.removeWhere(
          (otherProfessionId) => otherProfessionId != professionId,
        );
      }
      _requiredByProfession[professionId] = updated;
      _equipmentProfessionHistory.remove(professionId);
      if (updated > 0) _equipmentProfessionHistory.add(professionId);
      _retainCompatibleEquipment();
      _errorMessage = null;
    });
    final profession = HealthProfessionRegistry.byId(professionId);
    if (profession != null && MediaQuery.supportsAnnounceOf(context)) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        _quotaValueLabel(profession, updated),
        Directionality.of(context),
      );
    }
  }

  HealthProfessionDefinition? get _equipmentProfession {
    for (final professionId in _equipmentProfessionHistory.reversed) {
      if (_requiredByProfession[professionId]! > 0) {
        return HealthProfessionRegistry.byId(professionId);
      }
    }
    for (final profession in HealthProfessionRegistry.values.reversed) {
      if (_requiredByProfession[profession.id]! > 0) return profession;
    }
    return null;
  }

  List<ProfessionalEquipmentDefinition> get _displayedEquipment {
    final profession = _equipmentProfession;
    if (profession == null) return const [];
    final seenIds = <String>{};
    final seenLabels = <String>{};
    return ProfessionalEquipmentRegistry.forProfession(profession.id)
        .where(
          (equipment) =>
              seenIds.add(equipment.id) &&
              seenLabels.add(equipment.label.trim().toLowerCase()),
        )
        .toList(growable: false);
  }

  List<ProfessionalEquipmentDefinition> get _availableEquipment {
    final activeProfessionIds = _requiredByProfession.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toSet();
    final seenIds = <String>{};
    final seenLabels = <String>{};
    return ProfessionalEquipmentRegistry.values
        .where(
          (equipment) =>
              equipment.professionIds.any(activeProfessionIds.contains) &&
              seenIds.add(equipment.id) &&
              seenLabels.add(equipment.label.trim().toLowerCase()),
        )
        .toList(growable: false);
  }

  void _retainCompatibleEquipment() {
    final availableById = {
      for (final equipment in _availableEquipment) equipment.id: equipment,
    };
    final retainedLabels = <String>{};
    for (final value in _equipment) {
      final definition = _equipmentDefinition(value);
      if (definition != null && availableById.containsKey(definition.id)) {
        retainedLabels.add(definition.label);
      }
    }
    _equipment
      ..clear()
      ..addAll(retainedLabels);
  }

  static ProfessionalEquipmentDefinition? _equipmentDefinition(String value) {
    final normalized = ProfessionalEquipmentRegistry.normalizeStoredValue(
      value,
    );
    final byId = ProfessionalEquipmentRegistry.byId(normalized);
    if (byId != null) return byId;
    final normalizedLabel = value.trim().toLowerCase();
    for (final equipment in ProfessionalEquipmentRegistry.values) {
      if (equipment.label.toLowerCase() == normalizedLabel) return equipment;
    }
    return null;
  }

  static int _minutes(TimeOfDay value) => value.hour * 60 + value.minute;
  static String _formatDate(DateTime value) => FrenchDateTime.date(value);
}

class _EquipmentProfessionContext extends StatelessWidget {
  const _EquipmentProfessionContext({required this.professionLabel});

  final String professionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Row(
      children: [
        Text(
          'pour :',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.warningContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.warning.withValues(alpha: 0.42)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.medical_services_outlined,
                  size: 13,
                  color: colors.warning,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    professionLabel,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateNeedFieldLabel extends StatelessWidget {
  const _CreateNeedFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: context.v5Colors.textSecondary,
        fontSize: 12,
        letterSpacing: 0.45,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class ResponsibleLogin extends StatefulWidget {
  const ResponsibleLogin({
    super.key,
    required this.repository,
    this.initialMessage,
    this.onSignedIn,
  });

  final CoordinationRepository repository;
  final String? initialMessage;
  final VoidCallback? onSignedIn;

  @override
  State<ResponsibleLogin> createState() => _ResponsibleLoginState();
}

class _ResponsibleLoginState extends State<ResponsibleLogin> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _message = 'Identifiants incorrects.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final repository = widget.repository;
      final signIn = repository is PlatformAccountAuthenticator
          ? (repository as PlatformAccountAuthenticator)
                .signInPlatformOrResponsible(
                  email: _email.text,
                  password: _password.text,
                )
          : repository.signInResponsible(
              email: _email.text,
              password: _password.text,
            );
      await signIn.timeout(const Duration(seconds: 15));
      widget.onSignedIn?.call();
    } on RepositoryException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error, stackTrace) {
      debugPrint('Connexion responsable impossible : $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _message = 'Identifiants incorrects.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return PageContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth <= 556
              ? 18.0
              : (constraints.maxWidth - 520) / 2;
          return Material(
            color: colors.canvas,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                36,
              ),
              children: [
                const _ResponsibleLoginHeader(),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.outline),
                    boxShadow: V5Elevation.level1(colors),
                  ),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        V5TextField(
                          key: const Key('manager-email'),
                          label: 'Adresse email',
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          prefixIcon: const Icon(Icons.alternate_email_rounded),
                        ),
                        const SizedBox(height: 14),
                        V5TextField(
                          key: const Key('manager-password'),
                          label: 'Mot de passe',
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _loading ? null : _signIn(),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: colors.dangerContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.danger.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _message!,
                              style: TextStyle(
                                color: colors.danger,
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        V5Button(
                          key: const Key('manager-sign-in'),
                          expanded: true,
                          backgroundColor: colors.accent,
                          foregroundColor: colors.onAccent,
                          loading: _loading,
                          onPressed: _loading ? null : _signIn,
                          label: _loading ? 'Connexion…' : 'Se connecter',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ResponsibleLoginHeader extends StatelessWidget {
  const _ResponsibleLoginHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BrandMark(size: 52),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MobSanté',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 22,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ESPACE RESPONSABLE',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'Se connecter',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 27,
            height: 1.12,
            letterSpacing: -0.7,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Vous devez vous connecter pour déclarer un besoin.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PublishedMission {
  const _PublishedMission({required this.id, required this.draft});
  final String id;
  final MissionDraft draft;
}

class _MissionFormValidationError {
  const _MissionFormValidationError({
    required this.message,
    required this.targetKey,
    required this.focusNode,
  });

  final String message;
  final GlobalKey targetKey;
  final FocusNode focusNode;
}

class _MissionReviewView extends StatelessWidget {
  const _MissionReviewView({
    required this.draft,
    required this.publishing,
    required this.errorMessage,
    required this.onBack,
    required this.onPublish,
  });

  final MissionDraft draft;
  final bool publishing;
  final String? errorMessage;
  final VoidCallback? onBack;
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: ListView(
        key: const Key('need-review'),
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 36),
        children: [
          TextButton.icon(
            key: const Key('edit-need-from-review'),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
            ),
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Modifier le besoin'),
          ),
          const SizedBox(height: 12),
          Text(
            'Résumé du besoin',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Vérifiez les informations avant de publier.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _MissionDraftSummary(draft: draft),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              key: const Key('mission-review-error'),
              style: TextStyle(
                color: context.v5Colors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 24),
          V5Button(
            key: const Key('publish-mission'),
            expanded: true,
            loading: publishing,
            onPressed: onPublish,
            label: publishing ? 'Publication…' : 'Publier le besoin',
          ),
        ],
      ),
    );
  }
}

class _MissionPublishedView extends StatelessWidget {
  const _MissionPublishedView({
    required this.mission,
    required this.diffusionRepository,
    required this.onViewMission,
    required this.onCreateAnother,
  });

  final _PublishedMission mission;
  final DiffusionReadRepository? diffusionRepository;
  final VoidCallback? onViewMission;
  final VoidCallback onCreateAnother;

  @override
  Widget build(BuildContext context) {
    final draft = mission.draft;
    return PageContainer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 36),
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.green,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            'Votre besoin est publié.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 24),
          _MissionDraftSummary(
            draft: draft,
            status: diffusionRepository == null
                ? 'En attente de diffusion'
                : null,
          ),
          if (diffusionRepository case final repository?) ...[
            const SizedBox(height: 20),
            ResponsibleDiffusionSummary(
              needId: mission.id,
              repository: repository,
            ),
          ],
          const SizedBox(height: 20),
          V5Button(
            expanded: true,
            onPressed: onViewMission,
            label: 'Voir le besoin',
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onCreateAnother,
            child: const Text('Exprimer un autre besoin'),
          ),
        ],
      ),
    );
  }
}

class _MissionDraftSummary extends StatelessWidget {
  const _MissionDraftSummary({required this.draft, this.status});

  final MissionDraft draft;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final professions = HealthProfessionRegistry.values
        .where((item) => draft.requiredByProfession[item.id]! > 0)
        .toList(growable: false);
    final quantity = professions.fold<int>(
      0,
      (total, item) => total + draft.requiredByProfession[item.id]!,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryLine(
              label: 'Profession',
              value: professions.map((item) => item.missionLabel).join(', '),
            ),
            const SizedBox(height: 14),
            _SummaryLine(label: 'Quantité', value: '$quantity'),
            const SizedBox(height: 14),
            _SummaryLine(label: 'Lieu', value: draft.location.name),
            const SizedBox(height: 14),
            _SummaryLine(
              label: 'Créneau',
              value:
                  '${_CreateNeedScreenState._formatDate(draft.startAt)} · '
                  '${FrenchDateTime.timeRange(draft.startAt, draft.endAt)}',
            ),
            const SizedBox(height: 14),
            _SummaryLine(label: 'Priorité', value: draft.priority.label),
            if (status != null) ...[
              const SizedBox(height: 14),
              _SummaryLine(label: 'Statut', value: status!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 3),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _LocationInput extends StatelessWidget {
  const _LocationInput({
    super.key,
    required this.access,
    required this.locations,
    required this.selectedLocation,
    required this.preserveUnavailableSelection,
    required this.enabled,
    required this.focusNode,
    required this.onSelected,
  });

  final ResponsibleAccess access;
  final List<ResponsePlace> locations;
  final ResponsePlace? selectedLocation;
  final bool preserveUnavailableSelection;
  final bool enabled;
  final FocusNode focusNode;
  final ValueChanged<ResponsePlace?> onSelected;

  @override
  Widget build(BuildContext context) {
    final available = locations
        .where((location) => location.isOperational && location.isEnabled)
        .toList(growable: false);
    final selected = selectedLocation;
    final displayed =
        preserveUnavailableSelection &&
            selected != null &&
            !available.any((location) => location.id == selected.id)
        ? [selected, ...available]
        : available;
    if (access.singleManagedLocationId != null) {
      return _buildLockedLocation(context, displayed);
    }
    final selectable = access.isLocationRestricted
        ? displayed
              .where((location) => access.locationIds.contains(location.id))
              .toList(growable: false)
        : displayed;
    return V5SelectField<String>(
      key: const Key('mission-location'),
      label: 'Lieu',
      value: selectable.any((location) => location.id == selectedLocation?.id)
          ? selectedLocation?.id
          : null,
      placeholder: 'Choisir un lieu',
      sheetTitle: 'Choisir le lieu d’intervention',
      focusNode: focusNode,
      options: [
        for (final location in selectable)
          V5SelectOption(
            value: location.id,
            label: location.name,
            enabled: location.isOperational && location.isEnabled,
          ),
      ],
      onChanged: enabled
          ? (id) => onSelected(
              selectable
                  .where(
                    (location) =>
                        location.id == id &&
                        location.isOperational &&
                        location.isEnabled,
                  )
                  .firstOrNull,
            )
          : null,
    );
  }

  Widget _buildLockedLocation(
    BuildContext context,
    List<ResponsePlace> available,
  ) {
    final locationId = access.singleManagedLocationId;
    final location = available
        .where((candidate) => candidate.id == locationId)
        .firstOrNull;
    if (location == null) {
      if (selectedLocation != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onSelected(null));
      }
      return Text(
        'Aucun lieu unique n’est configuré pour ce compte.',
        key: const Key('mission-location-error'),
        style: TextStyle(
          color: context.v5Colors.danger,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    if (selectedLocation?.id != location.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onSelected(location));
    }
    return ConstrainedBox(
      key: const Key('mission-location-locked'),
      constraints: const BoxConstraints(minHeight: 62),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _CreateNeedFieldLabel('Lieu'),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  location.name,
                  style: TextStyle(
                    color: context.v5Colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: context.v5Colors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuotaStepper extends StatelessWidget {
  const _QuotaStepper({
    super.key,
    required this.profession,
    required this.value,
    required this.onRemove,
    required this.onAdd,
    required this.removeKey,
    required this.addKey,
    required this.addFocusNode,
  });

  final HealthProfessionDefinition profession;
  final int value;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;
  final Key removeKey;
  final Key addKey;
  final FocusNode addFocusNode;

  @override
  Widget build(BuildContext context) {
    final valueLabel = _quotaValueLabel(profession, value);
    final professionLabel = _quotaProfessionSingular(profession);
    final colors = context.v5Colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              profession.missionLabel,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _QuotaIconButton(
            key: removeKey,
            onPressed: onRemove,
            icon: Icons.remove_rounded,
            semanticLabel: 'Retirer un $professionLabel',
            semanticValue: valueLabel,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40),
            child: Semantics(
              label: valueLabel,
              child: ExcludeSemantics(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          _QuotaIconButton(
            key: addKey,
            focusNode: addFocusNode,
            onPressed: onAdd,
            icon: Icons.add_rounded,
            semanticLabel: 'Ajouter un $professionLabel',
            semanticValue: valueLabel,
          ),
        ],
      ),
    );
  }
}

class _QuotaIconButton extends StatelessWidget {
  const _QuotaIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    required this.semanticValue,
    this.focusNode,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final String semanticValue;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colors = context.v5Colors;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      value: semanticValue,
      onTap: onPressed,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 44,
        child: IconButton(
          focusNode: focusNode,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(44),
            foregroundColor: colors.textPrimary,
            backgroundColor: colors.surfaceElevated,
            disabledForegroundColor: colors.disabledForeground,
            disabledBackgroundColor: colors.disabledBackground,
            side: BorderSide(
              color: enabled ? colors.textPrimary : colors.outline,
              width: 1.2,
            ),
            shape: const CircleBorder(),
          ),
          icon: Icon(icon, size: 19),
        ),
      ),
    );
  }
}

String _quotaProfessionSingular(HealthProfessionDefinition profession) =>
    switch (profession.id) {
      HealthProfessionId.physiotherapist => 'masseur-kinésithérapeute',
      HealthProfessionId.podiatrist => 'pédicure-podologue',
      HealthProfessionId.physician => 'médecin',
      HealthProfessionId.nurse => 'infirmier',
      HealthProfessionId.veterinarian => 'vétérinaire',
      HealthProfessionId.otherHealthProfessional =>
        'autre professionnel de santé',
      _ => profession.missionLabel.toLowerCase(),
    };

String _quotaValueLabel(HealthProfessionDefinition profession, int value) {
  final singular = _quotaProfessionSingular(profession);
  if (value == 1) return '1 $singular demandé';
  final plural = profession.id == HealthProfessionId.otherHealthProfessional
      ? 'autres professionnels de santé'
      : '${singular}s';
  return '$value $plural demandés';
}
