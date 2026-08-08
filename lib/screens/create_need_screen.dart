import 'package:flutter/material.dart';

import '../models/health_profession.dart';
import '../models/need.dart';
import '../models/professional_equipment.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import '../utils/app_page_route.dart';
import '../utils/french_date_time.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';

abstract final class _CreateNeedVisuals {
  static const navy = Color(0xFF173052);
  static const orange = Color(0xFFF45A0A);
  static const orangeSoft = Color(0xFFFFE8DB);
  static const background = Color(0xFFF6F7F8);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const borderStrong = Color(0xFFD5D8D5);
  static const textMuted = Color(0xFF7C817F);
  static const textDisabled = Color(0xFFAEB2B0);
}

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
  });

  final VoidCallback? onViewMission;
  final ValueChanged<CoordinationNeed>? onMissionPublished;
  final CoordinationNeed? mission;

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
  final Set<String> _equipment = {};
  final List<String> _equipmentProfessionHistory = [];
  final _detailsController = TextEditingController();
  bool _publishing = false;
  String? _errorMessage;
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
          return const Center(child: CircularProgressIndicator());
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
              return const Center(child: CircularProgressIndicator());
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
      return _MissionPublishedView(
        mission: _publishedMission!,
        onViewMission: widget.onViewMission,
        onCreateAnother: _resetForm,
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
    return PageContainer(
      child: Material(
        color: _CreateNeedVisuals.background,
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
                        style: TextButton.styleFrom(
                          foregroundColor: _CreateNeedVisuals.navy,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
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
                                : 'Créer un besoin',
                            style: const TextStyle(
                              color: _CreateNeedVisuals.navy,
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
                    _NeedSummaryCard(
                      location: _selectedLocation,
                      date: _selectedDate,
                      startTime: _startTime,
                      endTime: _endTime,
                      requestedProfessionals: requestedProfessionals,
                    ),
                    const SizedBox(height: 10),
                    _FormDetailsCard(
                      children: [
                        if (responsibleLocationId == null) ...[
                          _LocationInput(
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
                          const _CreateNeedDivider(),
                        ],
                        KeyedSubtree(
                          key: _dateKey,
                          child: _PickerField(
                            key: const Key('mission-date'),
                            label: 'Date',
                            value: _selectedDate == null
                                ? 'Choisir une date'
                                : _formatDate(_selectedDate!),
                            focusNode: _dateFocusNode,
                            onTap: _publishing ? null : _pickDate,
                          ),
                        ),
                        const _CreateNeedDivider(),
                        KeyedSubtree(
                          key: _startTimeKey,
                          child: _PickerField(
                            key: const Key('mission-start-time'),
                            label: 'Début',
                            value: _startTime == null
                                ? 'Choisir une heure'
                                : _formatTime(_startTime!),
                            focusNode: _startTimeFocusNode,
                            onTap: _publishing
                                ? null
                                : () => _pickTime(isStart: true),
                          ),
                        ),
                        const _CreateNeedDivider(),
                        KeyedSubtree(
                          key: _endTimeKey,
                          child: _PickerField(
                            key: const Key('mission-end-time'),
                            label: 'Fin',
                            value: _endTime == null
                                ? 'Choisir une heure'
                                : _formatTime(_endTime!),
                            focusNode: _endTimeFocusNode,
                            onTap: _publishing
                                ? null
                                : () => _pickTime(isStart: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _CreateNeedSectionTitle('Professionnels recherchés'),
                    const SizedBox(height: 9),
                    for (final profession
                        in HealthProfessionRegistry.values) ...[
                      _QuotaStepper(
                        key: _quotaKeys[profession.id],
                        label: profession.missionLabel,
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
                      if (profession != HealthProfessionRegistry.values.last)
                        const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 20),
                    const _CreateNeedSectionTitle('Matériel conseillé'),
                    const SizedBox(height: 9),
                    if (equipmentProfession == null)
                      const Padding(
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
                                color: _CreateNeedVisuals.textMuted,
                              ),
                            ),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Ajoutez au moins un professionnel recherché '
                                'pour afficher le matériel correspondant.',
                                style: TextStyle(
                                  color: _CreateNeedVisuals.textMuted,
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      _EquipmentProfessionContext(
                        professionLabel: equipmentProfession.missionLabel,
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final equipment in displayedEquipment)
                            FilterChip(
                              key: Key('mission-equipment-${equipment.id}'),
                              label: Text(equipment.label),
                              selected: _equipment.contains(equipment.label),
                              onSelected: _publishing
                                  ? null
                                  : (selected) => setState(() {
                                      if (selected) {
                                        _equipment.add(equipment.label);
                                      } else {
                                        _equipment.remove(equipment.label);
                                      }
                                    }),
                              selectedColor: _CreateNeedVisuals.orangeSoft,
                              backgroundColor: Colors.white,
                              checkmarkColor: _CreateNeedVisuals.orange,
                              showCheckmark: true,
                              side: BorderSide(
                                color: _equipment.contains(equipment.label)
                                    ? _CreateNeedVisuals.orange
                                    : _CreateNeedVisuals.borderStrong,
                                width: _equipment.contains(equipment.label)
                                    ? 1.4
                                    : 1,
                              ),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              labelStyle: const TextStyle(
                                color: _CreateNeedVisuals.navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _CreateNeedFieldLabel('Commentaire facultatif'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _detailsController,
                      enabled: !_publishing,
                      maxLines: 4,
                      minLines: 3,
                      style: const TextStyle(
                        color: _CreateNeedVisuals.navy,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                      onTapOutside: _isEditing
                          ? (_) => FocusManager.instance.primaryFocus?.unfocus()
                          : null,
                      decoration: InputDecoration(
                        hintText: 'Ajouter un commentaire (optionnel)',
                        hintStyle: const TextStyle(
                          color: Color(0xFF747A78),
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _CreateNeedVisuals.borderStrong,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _CreateNeedVisuals.borderStrong,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _CreateNeedVisuals.orange,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.redSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _errorMessage!,
                          key: const Key('mission-form-error'),
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        key: Key(
                          _isEditing ? 'update-mission' : 'publish-mission',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _CreateNeedVisuals.orange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _CreateNeedVisuals.orange
                              .withValues(alpha: 0.55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                          shadowColor: _CreateNeedVisuals.orange.withValues(
                            alpha: 0.24,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: _publishing ? null : () => _publish(access),
                        child: _publishing
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isEditing
                                        ? 'Enregistrement…'
                                        : 'Publication…',
                                  ),
                                ],
                              )
                            : Text(
                                _isEditing
                                    ? 'Enregistrer les modifications'
                                    : 'Publier le besoin',
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        requestedProfessionals == 0
                            ? 'Aucun professionnel demandé pour le moment'
                            : '$requestedProfessionals professionnel${requestedProfessionals > 1 ? 's' : ''} demandé${requestedProfessionals > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: _CreateNeedVisuals.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: _CreateNeedVisuals.textMuted,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.padded,
                          textStyle: const TextStyle(
                            fontSize: 11,
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

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDate =
        _isEditing && _selectedDate != null && _selectedDate!.isBefore(today)
        ? _selectedDate!
        : today;
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: firstDate,
      lastDate: DateTime(today.year + 2, today.month, today.day),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedDate = selected;
        _errorMessage = null;
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? _startTime ?? const TimeOfDay(hour: 8, minute: 0)
        : _endTime ?? const TimeOfDay(hour: 12, minute: 0);
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = selected;
        } else {
          _endTime = selected;
        }
        _errorMessage = null;
      });
    }
  }

  Future<void> _publish(ResponsibleAccess access) async {
    if (_publishing) return;

    final validation = _validate();
    if (validation != null) {
      setState(() => _errorMessage = validation.message);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showValidationError(validation),
      );
      return;
    }
    final draft = _buildDraft();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mission mise à jour.')));
        if (Navigator.of(context).canPop()) Navigator.pop(context);
        return;
      }
      final id = await RepositoryScope.of(context).createMission(draft);
      if (!mounted) return;
      debugPrint('Publication mission confirmée : $id');
      widget.onMissionPublished?.call(
        CoordinationNeed(
          id: id,
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
          details: draft.details.trim(),
          createdBy: access.uid,
        ),
      );
      setState(() {
        _publishing = false;
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
    if (_minutes(_startTime!) == _minutes(_endTime!)) {
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
      duration: const Duration(milliseconds: 300),
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
      for (final profession in _requiredByProfession.keys) {
        _requiredByProfession[profession] = 0;
      }
      _equipmentProfessionHistory.clear();
      _equipment.clear();
      _detailsController.clear();
      _errorMessage = null;
      _publishedMission = null;
    });
  }

  void _changeQuota(String professionId, int delta) {
    setState(() {
      final current = _requiredByProfession[professionId]!;
      final updated = current + delta;
      _requiredByProfession[professionId] = updated;
      _equipmentProfessionHistory.remove(professionId);
      if (updated > 0) _equipmentProfessionHistory.add(professionId);
      _retainCompatibleEquipment();
      _errorMessage = null;
    });
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
  static String _formatTime(TimeOfDay value) =>
      FrenchDateTime.timeFromParts(value.hour, value.minute);
}

class _NeedSummaryCard extends StatelessWidget {
  const _NeedSummaryCard({
    required this.location,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.requestedProfessionals,
  });

  final ResponsePlace? location;
  final DateTime? date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final int requestedProfessionals;

  @override
  Widget build(BuildContext context) {
    final dateLabel = date == null
        ? 'Date à définir'
        : 'Date · ${FrenchDateTime.date(date!)}';
    final timeLabel = switch ((startTime, endTime)) {
      (final start?, final end?) => '${_formatTime(start)}–${_formatTime(end)}',
      (final start?, null) => 'Début ${_formatTime(start)} · fin à définir',
      (null, final end?) => 'Début à définir · fin ${_formatTime(end)}',
      _ => 'Horaires à définir',
    };
    final professionLabel = requestedProfessionals == 1
        ? 'professionnel'
        : 'professionnels';
    final requestedLabel =
        '$requestedProfessionals $professionLabel '
        '${requestedProfessionals == 1 ? 'demandé' : 'demandés'}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
      decoration: BoxDecoration(
        color: _CreateNeedVisuals.fieldBackground,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _CreateNeedVisuals.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location == null
                      ? 'Lieu à définir'
                      : 'Lieu · ${location!.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _CreateNeedVisuals.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$dateLabel · $timeLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _CreateNeedVisuals.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Semantics(
            label: requestedLabel,
            child: ExcludeSemantics(
              child: Text.rich(
                TextSpan(
                  text: '$requestedProfessionals\n',
                  style: const TextStyle(
                    color: _CreateNeedVisuals.navy,
                    fontSize: 22,
                    height: 0.9,
                    fontWeight: FontWeight.w800,
                  ),
                  children: [
                    TextSpan(
                      text: professionLabel,
                      style: const TextStyle(
                        color: _CreateNeedVisuals.textMuted,
                        fontSize: 9,
                        height: 1.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(TimeOfDay value) =>
      FrenchDateTime.timeFromParts(value.hour, value.minute);
}

class _FormDetailsCard extends StatelessWidget {
  const _FormDetailsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _CreateNeedVisuals.border),
      ),
      child: Column(children: children),
    );
  }
}

class _CreateNeedDivider extends StatelessWidget {
  const _CreateNeedDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: _CreateNeedVisuals.border,
    );
  }
}

class _CreateNeedSectionTitle extends StatelessWidget {
  const _CreateNeedSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: _CreateNeedVisuals.navy,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _EquipmentProfessionContext extends StatelessWidget {
  const _EquipmentProfessionContext({required this.professionLabel});

  final String professionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'pour :',
          style: TextStyle(
            color: _CreateNeedVisuals.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _CreateNeedVisuals.orangeSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _CreateNeedVisuals.orange.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.medical_services_outlined,
                  size: 13,
                  color: _CreateNeedVisuals.orange,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    professionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _CreateNeedVisuals.navy,
                      fontSize: 11,
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
      style: const TextStyle(
        color: _CreateNeedVisuals.textMuted,
        fontSize: 9,
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
      await widget.repository
          .signInResponsible(email: _email.text, password: _password.text)
          .timeout(const Duration(seconds: 15));
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
    return PageContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth <= 556
              ? 18.0
              : (constraints.maxWidth - 520) / 2;
          return Material(
            color: _CreateNeedVisuals.background,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _CreateNeedVisuals.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A173052),
                        blurRadius: 18,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: const Key('manager-email'),
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          style: const TextStyle(
                            color: _CreateNeedVisuals.navy,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _responsibleLoginInputDecoration(
                            labelText: 'Adresse email',
                            icon: Icons.alternate_email_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          key: const Key('manager-password'),
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _loading ? null : _signIn(),
                          style: const TextStyle(
                            color: _CreateNeedVisuals.navy,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _responsibleLoginInputDecoration(
                            labelText: 'Mot de passe',
                            icon: Icons.lock_outline_rounded,
                          ),
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
                              color: const Color(0xFFFFF1F0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFD6D2),
                              ),
                            ),
                            child: Text(
                              _message!,
                              style: const TextStyle(
                                color: AppColors.red,
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 56,
                          child: FilledButton(
                            key: const Key('manager-sign-in'),
                            onPressed: _loading ? null : _signIn,
                            style: FilledButton.styleFrom(
                              backgroundColor: _CreateNeedVisuals.orange,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  _CreateNeedVisuals.orangeSoft,
                              disabledForegroundColor:
                                  _CreateNeedVisuals.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: Text(
                              _loading ? 'Connexion…' : 'Se connecter',
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
        },
      ),
    );
  }
}

class _ResponsibleLoginHeader extends StatelessWidget {
  const _ResponsibleLoginHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BrandMark(size: 52),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MobSanté',
                    style: TextStyle(
                      color: _CreateNeedVisuals.navy,
                      fontSize: 22,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ESPACE RESPONSABLE',
                    style: TextStyle(
                      color: _CreateNeedVisuals.textMuted,
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 22),
        Text(
          'Se connecter',
          style: TextStyle(
            color: _CreateNeedVisuals.navy,
            fontSize: 27,
            height: 1.12,
            letterSpacing: -0.7,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Vous devez vous connecter pour déclarer un besoin.',
          style: TextStyle(
            color: _CreateNeedVisuals.textMuted,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

InputDecoration _responsibleLoginInputDecoration({
  required String labelText,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: labelText,
    labelStyle: const TextStyle(
      color: _CreateNeedVisuals.textMuted,
      fontWeight: FontWeight.w600,
    ),
    prefixIcon: Icon(icon, color: _CreateNeedVisuals.navy, size: 21),
    filled: true,
    fillColor: _CreateNeedVisuals.fieldBackground,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _CreateNeedVisuals.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _CreateNeedVisuals.navy, width: 1.5),
    ),
  );
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

class _MissionPublishedView extends StatelessWidget {
  const _MissionPublishedView({
    required this.mission,
    required this.onViewMission,
    required this.onCreateAnother,
  });

  final _PublishedMission mission;
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
            'Mission publiée',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryLine(label: 'Lieu', value: draft.location.name),
                  const SizedBox(height: 14),
                  _SummaryLine(
                    label: 'Date',
                    value: _CreateNeedScreenState._formatDate(draft.startAt),
                  ),
                  const SizedBox(height: 14),
                  _SummaryLine(
                    label: 'Horaires',
                    value: FrenchDateTime.timeRange(draft.startAt, draft.endAt),
                  ),
                  const SizedBox(height: 14),
                  _SummaryLine(
                    label: 'Quotas',
                    value: HealthProfessionRegistry.values
                        .where(
                          (profession) =>
                              draft.requiredByProfession[profession.id]! > 0,
                        )
                        .map(
                          (profession) =>
                              '${profession.shortLabel} '
                              '${draft.requiredByProfession[profession.id]}',
                        )
                        .join(' • '),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onViewMission,
            child: const Text('Voir la mission'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onCreateAnother,
            child: const Text('Déclarer un autre besoin'),
          ),
        ],
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
    return SizedBox(
      height: 62,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _CreateNeedFieldLabel('Lieu'),
          const SizedBox(height: 4),
          Expanded(
            child: DropdownButtonFormField<String>(
              key: const Key('mission-location'),
              focusNode: focusNode,
              isExpanded: true,
              isDense: true,
              initialValue:
                  selectable.any(
                    (location) => location.id == selectedLocation?.id,
                  )
                  ? selectedLocation?.id
                  : null,
              hint: const Text(
                'Choisir un lieu',
                style: TextStyle(
                  color: _CreateNeedVisuals.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              items: selectable
                  .map(
                    (location) => DropdownMenuItem(
                      value: location.id,
                      enabled: location.isOperational && location.isEnabled,
                      child: Text(
                        location.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
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
              icon: const Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: _CreateNeedVisuals.navy,
              ),
              style: const TextStyle(
                color: _CreateNeedVisuals.navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                isDense: true,
                isCollapsed: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
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
      return const Text(
        'Aucun lieu unique n’est configuré pour ce compte.',
        key: Key('mission-location-error'),
        style: TextStyle(
          color: AppColors.red,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    if (selectedLocation?.id != location.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onSelected(location));
    }
    return SizedBox(
      key: const Key('mission-location-locked'),
      height: 62,
      child: Column(
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
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _CreateNeedVisuals.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: _CreateNeedVisuals.textMuted,
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
    required this.label,
    required this.value,
    required this.onRemove,
    required this.onAdd,
    required this.removeKey,
    required this.addKey,
    required this.addFocusNode,
  });

  final String label;
  final int value;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;
  final Key removeKey;
  final Key addKey;
  final FocusNode addFocusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _CreateNeedVisuals.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _CreateNeedVisuals.navy,
                fontSize: 12.5,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _QuotaIconButton(
            key: removeKey,
            onPressed: onRemove,
            icon: Icons.remove_rounded,
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _CreateNeedVisuals.navy,
                fontSize: 20,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _QuotaIconButton(
            key: addKey,
            focusNode: addFocusNode,
            onPressed: onAdd,
            icon: Icons.add_rounded,
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
    this.focusNode,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        focusNode: focusNode,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: _CreateNeedVisuals.navy,
          backgroundColor: Colors.white,
          disabledForegroundColor: _CreateNeedVisuals.textDisabled,
          disabledBackgroundColor: _CreateNeedVisuals.fieldBackground,
          side: BorderSide(
            color: enabled
                ? _CreateNeedVisuals.navy
                : _CreateNeedVisuals.borderStrong,
            width: 1.2,
          ),
          shape: const CircleBorder(),
        ),
        icon: Icon(icon, size: 19),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.focusNode,
    required this.onTap,
  });

  final String label;
  final String value;
  final FocusNode focusNode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        focusNode: focusNode,
        onTap: onTap,
        child: SizedBox(
          height: 62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CreateNeedFieldLabel(label),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onTap == null
                            ? _CreateNeedVisuals.textMuted
                            : _CreateNeedVisuals.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: _CreateNeedVisuals.navy,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
