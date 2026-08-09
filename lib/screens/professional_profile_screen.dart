import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../models/need.dart';
import '../models/professional_equipment.dart';
import '../models/responsible_access.dart';
import '../models/volunteer_profile.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../services/professional_verification_service.dart';
import '../theme/v5_foundation.dart';
import '../widgets/perspective_switcher.dart';
import '../widgets/professional_page_header.dart';
import '../widgets/professional_rpps_verification.dart';
import '../widgets/native_interactions.dart';
import '../widgets/v5_controls.dart';
import '../widgets/v5_form_system.dart';

class ProfessionalProfileScreen extends StatefulWidget {
  const ProfessionalProfileScreen({
    super.key,
    required this.onOpenResponsibleAccess,
    required this.onOpenSettings,
    required this.onSignOut,
    this.onExitCrossRolePreview,
    this.verificationService = const FakeProfessionalVerificationService(),
  });

  final VoidCallback onOpenResponsibleAccess;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onSignOut;
  final VoidCallback? onExitCrossRolePreview;
  final ProfessionalVerificationService verificationService;

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

  Future<void> _confirmProfessionalIdentity(
    ProfessionalVerificationResult verification,
  ) async {
    final profile = await RepositoryScope.of(
      context,
    ).confirmProfessionalRpps(verification);
    if (!mounted) return;
    setState(() => _profile = Future.value(profile));
  }

  Future<void> _editProfile(VolunteerProfile? profile) async {
    final saved = await showNativeBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _ProfessionalProfileEditor(profile: profile),
    );
    if (saved == true && mounted) {
      _reloadProfile();
      V5Toast.show(
        context,
        message: 'Profil enregistré.',
        tone: V5ToastTone.success,
      );
    }
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
            return const V5LoadingState(label: 'Chargement du profil…');
          }
          final profile = snapshot.hasError ? null : snapshot.data;
          final profileComplete = _isProfileComplete(profile);
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
                      if (profile != null &&
                          ProfessionalRppsVerification.supportsProfession(
                            profile.profession,
                          )) ...[
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
                              profile
                                      ?.effectiveProfessionalIdValue
                                      .isNotEmpty ==
                                  true
                              ? profile!.effectiveProfessionalIdValue
                              : 'Non renseigné',
                        ),
                      ],
                      _ProfileValue(
                        label: 'État',
                        value: profileComplete
                            ? 'Profil complet'
                            : 'Profil à compléter',
                        valueColor: profileComplete
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
                            profileComplete
                                ? 'Modifier'
                                : 'Compléter mon profil',
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
                                    child: V5Button(
                                      onPressed: widget.onExitCrossRolePreview,
                                      icon: Icons.arrow_back_rounded,
                                      tone: V5ButtonTone.tonal,
                                      label: 'Revenir à mon espace réel',
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
      labels.add(profile.otherEquipmentDetails!.trim());
    }
    return labels.join(' • ');
  }

  bool _isProfileComplete(VolunteerProfile? profile) {
    if (profile == null || !profile.hasValidProfessionalIdentifier) {
      return false;
    }
    final email = profile.email?.trim() ?? '';
    final hasIdentity =
        profile.firstName.trim().isNotEmpty &&
        profile.lastName.trim().isNotEmpty &&
        profile.phone.trim().isNotEmpty &&
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    final hasCompleteCpts =
        (profile.cptsId?.trim().isNotEmpty ?? false) ==
        (profile.cptsLabel?.trim().isNotEmpty ?? false);
    final hasEquipmentDetails =
        !ProfessionalEquipmentRegistry.requiresDetails(profile.equipment) ||
        (profile.otherEquipmentDetails?.trim().isNotEmpty ?? false);
    return hasIdentity && hasCompleteCpts && hasEquipmentDetails;
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

  final VolunteerProfile? profile;

  @override
  State<_ProfessionalProfileEditor> createState() =>
      _ProfessionalProfileEditorState();
}

class _ProfessionalProfileEditorState
    extends State<_ProfessionalProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  late VolunteerProfession _profession;
  late ProfessionalIdType _idType;
  late final VolunteerProfession? _initialProfession;
  late final bool _legacyOrdinalProfile;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _idValue;
  late final TextEditingController _cptsId;
  late final TextEditingController _cptsLabel;
  late final TextEditingController _equipmentDetails;
  late final Set<String> _equipment;
  final _firstNameFocus = FocusNode(debugLabel: 'profile-first-name');
  final _lastNameFocus = FocusNode(debugLabel: 'profile-last-name');
  final _phoneFocus = FocusNode(debugLabel: 'profile-phone');
  final _emailFocus = FocusNode(debugLabel: 'profile-email');
  final _idTypeFocus = FocusNode(debugLabel: 'profile-id-type');
  final _idValueFocus = FocusNode(debugLabel: 'profile-id-value');
  final _cptsIdFocus = FocusNode(debugLabel: 'profile-cpts-id');
  final _cptsLabelFocus = FocusNode(debugLabel: 'profile-cpts-label');
  final _equipmentDetailsFocus = FocusNode(
    debugLabel: 'profile-equipment-details',
  );
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _profession = profile?.profession ?? VolunteerProfession.mk;
    _initialProfession = profile?.profession;
    _legacyOrdinalProfile =
        profile != null &&
        ProfessionalRppsVerification.supportsProfession(profile.profession) &&
        profile.effectiveProfessionalIdType == ProfessionalIdType.ordinal;
    _idType =
        profile?.effectiveProfessionalIdType ??
        (ProfessionalRppsVerification.supportsProfession(_profession)
            ? ProfessionalIdType.rpps
            : ProfessionalIdType.none);
    _firstName = TextEditingController(text: profile?.firstName);
    _lastName = TextEditingController(text: profile?.lastName);
    _phone = TextEditingController(text: profile?.phone);
    _email = TextEditingController(text: profile?.email);
    _idValue = TextEditingController(
      text: profile?.effectiveProfessionalIdValue,
    );
    _cptsId = TextEditingController(text: profile?.cptsId);
    _cptsLabel = TextEditingController(text: profile?.cptsLabel);
    _equipmentDetails = TextEditingController(
      text: profile?.otherEquipmentDetails,
    );
    _equipment = ProfessionalEquipmentRegistry.normalizeStoredValues(
      profile?.equipment ?? const [],
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
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _idTypeFocus.dispose();
    _idValueFocus.dispose();
    _cptsIdFocus.dispose();
    _cptsLabelFocus.dispose();
    _equipmentDetailsFocus.dispose();
    super.dispose();
  }

  List<ProfessionalIdType> get _idTypes =>
      _profession == VolunteerProfession.veterinarian
      ? const [ProfessionalIdType.ordinal]
      : ProfessionalRppsVerification.supportsProfession(_profession)
      ? const [ProfessionalIdType.rpps]
      : ProfessionalIdType.values;

  bool get _keepsLegacyOrdinal =>
      _legacyOrdinalProfile && _profession == _initialProfession;

  bool get _usesFixedIdentifierType =>
      _keepsLegacyOrdinal ||
      ProfessionalRppsVerification.supportsProfession(_profession) ||
      _profession == VolunteerProfession.veterinarian;

  List<ProfessionalEquipmentDefinition> get _equipmentOptions =>
      ProfessionalEquipmentRegistry.forProfession(_profession.canonicalId!);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.profile == null
                    ? 'Compléter mon profil'
                    : 'Modifier mon profil',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: V5Spacing.lg),
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
                          if (value == VolunteerProfession.veterinarian) {
                            _idType = ProfessionalIdType.ordinal;
                          } else if (ProfessionalRppsVerification.supportsProfession(
                            value,
                          )) {
                            _idType = _keepsLegacyOrdinal
                                ? ProfessionalIdType.ordinal
                                : ProfessionalIdType.rpps;
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
                          _keepsLegacyOrdinal
                              ? 'Identifiant historique : Numéro ordinal'
                              : 'Identifiant : ${_idType.label}',
                          key: const Key('professional-profile-fixed-id-type'),
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
                          if (value != null) setState(() => _idType = value);
                        },
                        validator: (value) =>
                            value == ProfessionalIdType.rpps ||
                                value == ProfessionalIdType.ordinal
                            ? null
                            : 'Choisissez un identifiant professionnel.',
                      ),
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
                ),
              ),
              const SizedBox(height: V5Spacing.sm),
              V5Section(
                title: 'Territoire',
                leading: const Icon(Icons.location_on_outlined),
                child: Column(
                  children: [
                    V5TextField(
                      key: const Key('professional-profile-cpts-id'),
                      label: 'Identifiant CPTS (facultatif)',
                      controller: _cptsId,
                      focusNode: _cptsIdFocus,
                    ),
                    const SizedBox(height: V5Spacing.sm),
                    V5TextField(
                      key: const Key('professional-profile-cpts-label'),
                      label: 'CPTS (facultatif)',
                      controller: _cptsLabel,
                      focusNode: _cptsLabelFocus,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: V5Spacing.sm),
              V5Section(
                title: 'Matériel disponible',
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
              const SizedBox(height: V5Spacing.lg),
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
    if (!_formKey.currentState!.validate()) {
      await _focusFirstInvalidField();
      return;
    }
    if ((_cptsId.text.trim().isEmpty) != (_cptsLabel.text.trim().isEmpty)) {
      final missingCptsId = _cptsId.text.trim().isEmpty;
      await _focusAndAnnounce(
        focusNode: missingCptsId ? _cptsIdFocus : _cptsLabelFocus,
        label: missingCptsId ? 'Identifiant CPTS' : 'CPTS',
        error: 'Renseignez ensemble l’identifiant et le nom CPTS.',
      );
      if (!mounted) return;
      V5Toast.show(
        context,
        message: 'Renseignez ensemble l’identifiant et le nom CPTS.',
        tone: V5ToastTone.warning,
      );
      return;
    }
    setState(() => _saving = true);
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
      final updatedProfile = currentProfile.copyWith(
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
      );
      await RepositoryScope.of(context).saveVolunteerProfile(updatedProfile);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      V5Toast.show(
        context,
        message: 'Le profil n’a pas pu être enregistré. Réessayez.',
        tone: V5ToastTone.danger,
      );
    }
  }

  Future<void> _focusFirstInvalidField() async {
    final failure = _firstInvalidField();
    if (failure == null) return;
    await _focusAndAnnounce(
      focusNode: failure.focusNode,
      label: failure.label,
      error: failure.error,
    );
  }

  ({FocusNode focusNode, String label, String error})? _firstInvalidField() {
    final candidates = <({FocusNode focusNode, String label, String? error})>[
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
                _idType == ProfessionalIdType.ordinal
            ? null
            : 'Choisissez un identifiant professionnel.',
      ),
      (
        focusNode: _idValueFocus,
        label: _idType.label,
        error: _idValidator(_idValue.text),
      ),
      if (ProfessionalEquipmentRegistry.requiresDetails(_equipment))
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
    if (MediaQuery.supportsAnnounceOf(context)) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        '$label. Erreur : $error',
        Directionality.of(context),
      );
    }
  }
}
