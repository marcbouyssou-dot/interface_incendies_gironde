import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/need.dart';
import '../models/professional_equipment.dart';
import '../models/responsible_access.dart';
import '../models/volunteer_profile.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/v5_foundation.dart';
import '../widgets/perspective_switcher.dart';
import '../widgets/professional_page_header.dart';

class ProfessionalProfileScreen extends StatefulWidget {
  const ProfessionalProfileScreen({
    super.key,
    required this.onOpenResponsibleAccess,
    required this.onOpenSettings,
    required this.onShowMissions,
    required this.onSignOut,
    this.onExitCrossRolePreview,
  });

  final VoidCallback onOpenResponsibleAccess;
  final VoidCallback onOpenSettings;
  final VoidCallback onShowMissions;
  final Future<void> Function() onSignOut;
  final VoidCallback? onExitCrossRolePreview;

  @override
  State<ProfessionalProfileScreen> createState() =>
      _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends State<ProfessionalProfileScreen> {
  Object? _repositoryIdentity;
  Future<VolunteerProfile?>? _profile;
  LiveCoordinationData? _liveData;
  Stream<ResponsibleAccess?>? _access;
  Stream<List<ResponsePlace>>? _locations;
  bool _signingOut = false;

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
      _access = liveData.watchResponsibleAccess();
      _locations = liveData.watchLocations();
    }
  }

  void _reloadProfile() {
    setState(() {
      _profile = RepositoryScope.of(context).getVolunteerProfile();
    });
  }

  Future<void> _editProfile(VolunteerProfile? profile) async {
    if (profile == null) {
      widget.onShowMissions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choisissez une mission pour créer votre profil professionnel.',
          ),
        ),
      );
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _ProfessionalProfileEditor(profile: profile),
    );
    if (saved == true && mounted) _reloadProfile();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
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
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.hasError ? null : snapshot.data;
          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth <= 556
                  ? 18.0
                  : (constraints.maxWidth - 520) / 2;
              return ListView(
                key: const PageStorageKey('professional-profile'),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  24,
                  horizontalPadding,
                  36,
                ),
                children: [
                  const ProfessionalPageHeader(
                    title: 'Mon profil',
                    subtitle:
                        'Vos informations professionnelles et vos préférences.',
                  ),
                  const SizedBox(height: V5Spacing.lg),
                  _ProfileSection(
                    title: 'Identité professionnelle',
                    icon: Icons.person_outline_rounded,
                    children: [
                      _ProfileValue(
                        label: 'Profession',
                        value: profile?.profession.label ?? 'Non renseignée',
                      ),
                      _ProfileValue(
                        label: 'Nom',
                        value: profile?.displayName.isNotEmpty == true
                            ? profile!.displayName
                            : 'Non renseigné',
                      ),
                      _ProfileValue(
                        label: 'Email',
                        value: profile?.email?.trim().isNotEmpty == true
                            ? profile!.email!.trim()
                            : 'Non renseigné',
                      ),
                    ],
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  _ProfileSection(
                    title: 'Vérification professionnelle',
                    icon: Icons.verified_user_outlined,
                    children: [
                      _ProfileValue(
                        label: 'Type d’identifiant',
                        value:
                            profile?.effectiveProfessionalIdType.label ??
                            'Non renseigné',
                      ),
                      _ProfileValue(
                        label:
                            profile?.effectiveProfessionalIdType.label ??
                            'RPPS ou numéro ordinal',
                        value:
                            profile?.effectiveProfessionalIdValue.isNotEmpty ==
                                true
                            ? profile!.effectiveProfessionalIdValue
                            : 'Non renseigné',
                      ),
                      _ProfileValue(
                        label: 'État',
                        value: profile?.hasValidProfessionalIdentifier == true
                            ? 'Profil complet'
                            : 'Profil à compléter',
                        valueColor:
                            profile?.hasValidProfessionalIdentifier == true
                            ? context.v5Colors.success
                            : context.v5Colors.warning,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const Key('edit-professional-profile'),
                          onPressed: () => _editProfile(profile),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(
                            profile == null
                                ? 'Compléter mon profil'
                                : 'Modifier',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  _ProfileSection(
                    title: 'Territoire',
                    icon: Icons.location_on_outlined,
                    children: [
                      _ProfileValue(
                        label: 'CPTS',
                        value: profile?.cptsLabel?.trim().isNotEmpty == true
                            ? profile!.cptsLabel!.trim()
                            : 'Non renseignée',
                      ),
                    ],
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  _ProfileSection(
                    title: 'Matériel disponible',
                    icon: Icons.medical_services_outlined,
                    children: [
                      _ProfileValue(
                        label: 'Équipements',
                        value: _equipmentSummary(profile),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _editProfile(profile),
                          child: const Text('Modifier'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  _ProfileSection(
                    title: 'Préférences',
                    icon: Icons.tune_rounded,
                    children: [
                      _ProfileValue(
                        label: 'Critères géographiques',
                        value: profile?.cptsLabel?.trim().isNotEmpty == true
                            ? 'Autour de ${profile!.cptsLabel!.trim()}'
                            : 'À choisir dans l’onglet Missions',
                      ),
                      const _ProfileValue(
                        label: 'Critères temporels',
                        value: 'À choisir dans l’onglet Missions',
                      ),
                    ],
                  ),
                  StreamBuilder<ResponsibleAccess?>(
                    stream: _access,
                    builder: (context, accessSnapshot) {
                      final access = accessSnapshot.data;
                      if (access?.hasPrivilegedAccess != true) {
                        return const SizedBox.shrink();
                      }
                      return StreamBuilder<List<ResponsePlace>>(
                        stream: _locations,
                        builder: (context, locationSnapshot) {
                          if (!locationSnapshot.hasData) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: V5Spacing.sm),
                            child: _ProfileSection(
                              title: 'Accès privilégié',
                              icon: Icons.admin_panel_settings_outlined,
                              children: [
                                if (widget.onExitCrossRolePreview != null)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FilledButton.tonalIcon(
                                      onPressed: widget.onExitCrossRolePreview,
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                      ),
                                      label: const Text(
                                        'Revenir à mon espace réel',
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: V5Spacing.sm),
                                if (access!.isCoordinator)
                                  CoordinatorPerspectiveSection(
                                    access: access,
                                    locations: locationSnapshot.data!,
                                  )
                                else
                                  const SiteManagerPerspectiveSection(
                                    title: 'Changer de perspective',
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: V5Spacing.lg),
                  OutlinedButton.icon(
                    key: const Key('open-development-settings'),
                    onPressed: widget.onOpenSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Réglages'),
                  ),
                  const SizedBox(height: V5Spacing.xs),
                  TextButton.icon(
                    key: const Key('open-responsible-access'),
                    onPressed: widget.onOpenResponsibleAccess,
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text('Connexion responsable'),
                  ),
                  TextButton.icon(
                    key: const Key('professional-sign-out'),
                    onPressed: _signingOut ? null : _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(_signingOut ? 'Déconnexion…' : 'Déconnexion'),
                  ),
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
      labels.add(profile!.otherEquipmentDetails!.trim());
    }
    return labels.join(' • ');
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
    final colors = context.v5Colors;
    return Container(
      padding: const EdgeInsets.all(V5Spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
        boxShadow: V5Elevation.level1(colors),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colors.info),
              const SizedBox(width: V5Spacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: V5Spacing.sm),
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
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

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
            color: valueColor ?? context.v5Colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _ProfessionalProfileEditor extends StatefulWidget {
  const _ProfessionalProfileEditor({required this.profile});

  final VolunteerProfile profile;

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
  late final TextEditingController _cptsId;
  late final TextEditingController _cptsLabel;
  late final TextEditingController _equipmentDetails;
  late final Set<String> _equipment;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _profession = profile.profession;
    _idType = profile.effectiveProfessionalIdType;
    _firstName = TextEditingController(text: profile.firstName);
    _lastName = TextEditingController(text: profile.lastName);
    _phone = TextEditingController(text: profile.phone);
    _email = TextEditingController(text: profile.email);
    _idValue = TextEditingController(
      text: profile.effectiveProfessionalIdValue,
    );
    _cptsId = TextEditingController(text: profile.cptsId);
    _cptsLabel = TextEditingController(text: profile.cptsLabel);
    _equipmentDetails = TextEditingController(
      text: profile.otherEquipmentDetails,
    );
    _equipment = ProfessionalEquipmentRegistry.normalizeStoredValues(
      profile.equipment,
    ).toSet();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _idValue.dispose();
    _cptsId.dispose();
    _cptsLabel.dispose();
    _equipmentDetails.dispose();
    super.dispose();
  }

  List<ProfessionalIdType> get _idTypes =>
      _profession == VolunteerProfession.veterinarian
      ? const [ProfessionalIdType.ordinal]
      : ProfessionalIdType.values;

  List<ProfessionalEquipmentDefinition> get _equipmentOptions =>
      ProfessionalEquipmentRegistry.forProfession(_profession.canonicalId!);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.v5Colors.canvas,
      child: SingleChildScrollView(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Modifier mon profil',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: V5Spacing.lg),
              DropdownButtonFormField<VolunteerProfession>(
                initialValue: _profession,
                decoration: const InputDecoration(labelText: 'Profession'),
                items: [
                  for (final profession in VolunteerProfession.values)
                    DropdownMenuItem(
                      value: profession,
                      child: Text(profession.label),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _profession = value;
                    _equipment.removeWhere(
                      (item) => !ProfessionalEquipmentRegistry.isCompatible(
                        item,
                        value.canonicalId!,
                      ),
                    );
                    if (value == VolunteerProfession.veterinarian) {
                      _idType = ProfessionalIdType.ordinal;
                    }
                  });
                },
              ),
              const SizedBox(height: V5Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: V5Spacing.xs),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: V5Spacing.sm),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
                validator: _required,
              ),
              const SizedBox(height: V5Spacing.sm),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: _emailValidator,
              ),
              const SizedBox(height: V5Spacing.sm),
              DropdownButtonFormField<ProfessionalIdType>(
                key: ValueKey('profile-id-type-${_profession.name}'),
                initialValue: _idType,
                decoration: const InputDecoration(
                  labelText: 'Type d’identifiant',
                ),
                items: [
                  for (final type in _idTypes)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _idType = value);
                },
                validator: (value) =>
                    value == ProfessionalIdType.rpps ||
                        value == ProfessionalIdType.ordinal
                    ? null
                    : 'Choisissez un identifiant professionnel.',
              ),
              const SizedBox(height: V5Spacing.sm),
              TextFormField(
                controller: _idValue,
                keyboardType: _idType == ProfessionalIdType.rpps
                    ? TextInputType.number
                    : TextInputType.text,
                inputFormatters: [
                  if (_idType == ProfessionalIdType.rpps)
                    FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(
                    _idType == ProfessionalIdType.rpps ? 11 : 32,
                  ),
                ],
                decoration: InputDecoration(labelText: _idType.label),
                validator: _idValidator,
              ),
              const SizedBox(height: V5Spacing.sm),
              TextFormField(
                controller: _cptsId,
                decoration: const InputDecoration(
                  labelText: 'Identifiant CPTS (facultatif)',
                ),
              ),
              const SizedBox(height: V5Spacing.sm),
              TextFormField(
                controller: _cptsLabel,
                decoration: const InputDecoration(
                  labelText: 'CPTS (facultatif)',
                ),
              ),
              const SizedBox(height: V5Spacing.lg),
              Text(
                'Matériel disponible',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final equipment in _equipmentOptions)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(equipment.label),
                  value: _equipment.contains(equipment.id),
                  onChanged: (selected) => setState(() {
                    if (selected == true) {
                      _equipment.add(equipment.id);
                    } else {
                      _equipment.remove(equipment.id);
                    }
                  }),
                ),
              if (ProfessionalEquipmentRegistry.requiresDetails(_equipment))
                TextFormField(
                  controller: _equipmentDetails,
                  decoration: const InputDecoration(
                    labelText: 'Précisez le matériel',
                  ),
                  validator: _required,
                ),
              const SizedBox(height: V5Spacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
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
    final normalized = value?.trim() ?? '';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      return 'Email invalide';
    }
    return null;
  }

  String? _idValidator(String? value) {
    final normalized = value?.trim() ?? '';
    if (_idType == ProfessionalIdType.rpps &&
        !RegExp(r'^\d{11}$').hasMatch(normalized)) {
      return 'Le numéro RPPS doit contenir exactement 11 chiffres.';
    }
    if (_idType == ProfessionalIdType.ordinal && normalized.isEmpty) {
      return 'Saisissez votre numéro ordinal.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_cptsId.text.trim().isEmpty) != (_cptsLabel.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Renseignez ensemble l’identifiant et le nom CPTS.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await RepositoryScope.of(context).saveVolunteerProfile(
        widget.profile.copyWith(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          profession: _profession,
          professionalIdType: _idType,
          professionalIdValue: _idValue.text.trim(),
          cptsId: _cptsId.text.trim(),
          cptsLabel: _cptsLabel.text.trim(),
          equipment: _equipment.toList(growable: false),
          otherEquipmentDetails:
              ProfessionalEquipmentRegistry.requiresDetails(_equipment)
              ? _equipmentDetails.text.trim()
              : '',
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le profil n’a pas pu être enregistré. Réessayez.'),
        ),
      );
    }
  }
}
