import 'package:flutter/material.dart';

import '../models/health_profession.dart';
import '../models/need.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class CreateNeedScreen extends StatefulWidget {
  const CreateNeedScreen({super.key, this.onViewMission});

  final VoidCallback? onViewMission;

  @override
  State<CreateNeedScreen> createState() => _CreateNeedScreenState();
}

class _CreateNeedScreenState extends State<CreateNeedScreen> {
  final Map<String, int> _requiredByProfession = {
    for (final profession in HealthProfessionRegistry.values) profession.id: 0,
  };
  ResponsePlace? _selectedLocation;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final Set<String> _equipment = {'Tables', 'Serviettes'};
  final _detailsController = TextEditingController();
  bool _publishing = false;
  String? _errorMessage;
  _PublishedMission? _publishedMission;
  CoordinationRepository? _repository;
  Stream<ResponsibleAccess?>? _responsibleAccess;
  Stream<List<ResponsePlace>>? _locations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = RepositoryScope.of(context);
    if (!identical(repository, _repository)) {
      _repository = repository;
      _responsibleAccess = repository.watchResponsibleAccess();
      _locations = repository.watchLocations();
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = _repository!;
    return StreamBuilder<ResponsibleAccess?>(
      stream: _responsibleAccess,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final access = snapshot.data;
        if (access == null) {
          return _ResponsibleLogin(repository: repository);
        }
        if (!access.active) {
          return _ResponsibleLogin(
            repository: repository,
            initialMessage: 'Votre compte responsable est inactif.',
          );
        }
        return _buildForm(context, access);
      },
    );
  }

  Widget _buildForm(BuildContext context, ResponsibleAccess access) {
    if (_publishedMission != null) {
      return _MissionPublishedView(
        mission: _publishedMission!,
        onViewMission: widget.onViewMission,
        onCreateAnother: _resetForm,
      );
    }
    return PageContainer(
      child: ListView(
        key: const PageStorageKey('create'),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
        children: [
          const PageHeader(
            eyebrow: 'Nouvelle mission',
            title: 'Créer un besoin',
            subtitle: 'Publiez les renforts nécessaires.',
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _publishing
                  ? null
                  : RepositoryScope.of(context).signOutResponsible,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Se déconnecter'),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LocationInput(
                    access: access,
                    locations: _locations!,
                    selectedLocation: _selectedLocation,
                    enabled: !_publishing,
                    onSelected: (location) {
                      if (!mounted) return;
                      setState(() {
                        _selectedLocation = location;
                        _errorMessage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  _PickerField(
                    key: const Key('mission-date'),
                    label: 'Date',
                    value: _selectedDate == null
                        ? 'Choisir une date'
                        : _formatDate(_selectedDate!),
                    icon: Icons.calendar_today_rounded,
                    onTap: _publishing ? null : _pickDate,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerField(
                          key: const Key('mission-start-time'),
                          label: 'Début',
                          value: _startTime == null
                              ? 'Choisir'
                              : _formatTime(_startTime!),
                          icon: Icons.schedule_rounded,
                          onTap: _publishing
                              ? null
                              : () => _pickTime(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PickerField(
                          key: const Key('mission-end-time'),
                          label: 'Fin',
                          value: _endTime == null
                              ? 'Choisir'
                              : _formatTime(_endTime!),
                          icon: Icons.schedule_rounded,
                          onTap: _publishing
                              ? null
                              : () => _pickTime(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('Professionnels recherchés'),
                  const SizedBox(height: 8),
                  for (final profession in HealthProfessionRegistry.values) ...[
                    _QuotaStepper(
                      label: profession.missionLabel,
                      value: _requiredByProfession[profession.id]!,
                      removeKey: Key('${profession.id}-remove'),
                      addKey: Key('${profession.id}-add'),
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
                  const SizedBox(height: 18),
                  const _FieldLabel('Matériel'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        [
                              'Tables',
                              'Serviettes',
                              'Huiles',
                              'Gels froids',
                              'Tapis',
                            ]
                            .map(
                              (item) => FilterChip(
                                label: Text(item),
                                selected: _equipment.contains(item),
                                onSelected: _publishing
                                    ? null
                                    : (selected) => setState(
                                        () => selected
                                            ? _equipment.add(item)
                                            : _equipment.remove(item),
                                      ),
                                selectedColor: AppColors.orangeSoft,
                                checkmarkColor: AppColors.orange,
                                side: const BorderSide(color: AppColors.border),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('Commentaire'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _detailsController,
                    enabled: !_publishing,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Accès, contact sur place, consignes…',
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorMessage!,
                      key: const Key('mission-form-error'),
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('publish-mission'),
                    onPressed: _publishing ? null : _publish,
                    icon: _publishing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(_publishing ? 'Publication…' : 'Publier'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today,
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

  Future<void> _publish() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => _errorMessage = validation);
      return;
    }
    final draft = _buildDraft();
    setState(() {
      _publishing = true;
      _errorMessage = null;
    });
    debugPrint('Publication mission : début de validation confirmée');
    try {
      final id = await RepositoryScope.of(context).createMission(draft);
      if (!mounted) return;
      debugPrint('Publication mission confirmée : $id');
      setState(() {
        _publishing = false;
        _publishedMission = _PublishedMission(id: id, draft: draft);
      });
    } catch (error, stackTrace) {
      debugPrint('Publication mission échouée : $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _errorMessage = 'La mission n’a pas pu être publiée. Réessayez.';
      });
    }
  }

  String? _validate() {
    if (_selectedLocation == null) return 'Choisissez un lieu';
    if (_selectedDate == null) return 'Choisissez une date';
    if (_startTime == null) return 'Choisissez une heure de début';
    if (_endTime == null) return 'Choisissez une heure de fin';
    if (_minutes(_startTime!) == _minutes(_endTime!)) {
      return 'L’heure de fin doit être postérieure à l’heure de début';
    }
    if (_requiredByProfession.values.every((quota) => quota == 0)) {
      return 'Indiquez au moins un professionnel nécessaire';
    }
    return null;
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
      _equipment
        ..clear()
        ..addAll(['Tables', 'Serviettes']);
      _detailsController.clear();
      _errorMessage = null;
      _publishedMission = null;
    });
  }

  void _changeQuota(String professionId, int delta) {
    setState(() {
      final current = _requiredByProfession[professionId]!;
      _requiredByProfession[professionId] = current + delta;
      _errorMessage = null;
    });
  }

  static int _minutes(TimeOfDay value) => value.hour * 60 + value.minute;
  static String _formatDate(DateTime value) =>
      '${_two(value.day)}/${_two(value.month)}/${value.year}';
  static String _formatTime(TimeOfDay value) =>
      '${_two(value.hour)}:${_two(value.minute)}';
  static String _two(int value) => value.toString().padLeft(2, '0');
}

class _ResponsibleLogin extends StatefulWidget {
  const _ResponsibleLogin({required this.repository, this.initialMessage});

  final CoordinationRepository repository;
  final String? initialMessage;

  @override
  State<_ResponsibleLogin> createState() => _ResponsibleLoginState();
}

class _ResponsibleLoginState extends State<_ResponsibleLogin> {
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 42, 20, 36),
        children: [
          const PageHeader(
            eyebrow: 'Espace responsable',
            title: 'Se connecter',
            subtitle: 'Vous devez vous connecter pour déclarer un besoin.',
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    key: const Key('manager-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Adresse email',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('manager-password'),
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _loading ? null : _signIn(),
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _message!,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('manager-sign-in'),
                    onPressed: _loading ? null : _signIn,
                    child: Text(_loading ? 'Connexion…' : 'Se connecter'),
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

class _PublishedMission {
  const _PublishedMission({required this.id, required this.draft});
  final String id;
  final MissionDraft draft;
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
                    value: '${_time(draft.startAt)} → ${_time(draft.endAt)}',
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

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
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
    required this.access,
    required this.locations,
    required this.selectedLocation,
    required this.enabled,
    required this.onSelected,
  });

  final ResponsibleAccess access;
  final Stream<List<ResponsePlace>> locations;
  final ResponsePlace? selectedLocation;
  final bool enabled;
  final ValueChanged<ResponsePlace?> onSelected;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ResponsePlace>>(
      stream: locations,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final available = snapshot.data!
            .where((location) => location.isOperational)
            .toList(growable: false);
        if (access.isSiteManager) {
          return _buildLockedLocation(context, available);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FieldLabel('Lieu d’intervention'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const Key('mission-location'),
              isExpanded: true,
              initialValue:
                  available.any(
                    (location) => location.id == selectedLocation?.id,
                  )
                  ? selectedLocation?.id
                  : null,
              hint: const Text('Choisir un lieu'),
              items: available
                  .map(
                    (location) => DropdownMenuItem(
                      value: location.id,
                      child: Text(
                        location.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: enabled
                  ? (id) => onSelected(
                      available
                          .where((location) => location.id == id)
                          .firstOrNull,
                    )
                  : null,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ],
        );
      },
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
    return Container(
      key: const Key('mission-location-locked'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              location.name,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotaStepper extends StatelessWidget {
  const _QuotaStepper({
    required this.label,
    required this.value,
    required this.onRemove,
    required this.onAdd,
    required this.removeKey,
    required this.addKey,
  });

  final String label;
  final int value;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;
  final Key removeKey;
  final Key addKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            key: removeKey,
            onPressed: onRemove,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            key: addKey,
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: Theme.of(context).textTheme.titleMedium);
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 54,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(icon, size: 17, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
