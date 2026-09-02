import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../models/need.dart';
import '../models/professional_equipment.dart';
import '../models/professional_profile_validation.dart';
import '../models/volunteer_profile.dart';
import '../repositories/repository_scope.dart';
import '../services/professional_verification_service.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/professional_page_header.dart';
import '../widgets/professional_rpps_verification.dart';
import '../widgets/native_interactions.dart';
import '../widgets/v5_controls.dart';
import '../widgets/v5_form_system.dart';
import 'diagnostic_push_registration_screen.dart';

class ProfessionalProfileScreen extends StatefulWidget {
  const ProfessionalProfileScreen({
    super.key,
    required this.onOpenResponsibleAccess,
    required this.onOpenSettings,
    required this.onOpenNotifications,
    required this.onSignOut,
    this.verificationService = const FakeProfessionalVerificationService(),
  });

  final VoidCallback onOpenResponsibleAccess;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenNotifications;
  final Future<void> Function() onSignOut;
  final ProfessionalVerificationService verificationService;

  @override
  State<ProfessionalProfileScreen> createState() =>
      _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends State<ProfessionalProfileScreen> {
  Object? _repositoryIdentity;
  Future<VolunteerProfile?>? _profile;
  bool _signingOut = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = RepositoryScope.of(context);
    if (!identical(repository, _repositoryIdentity)) {
      _repositoryIdentity = repository;
      _profile = repository.getVolunteerProfile();
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
          final profileComplete = ProfessionalProfileValidation.isComplete(
            profile,
          );
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
                  const ProfessionalPageHeader(title: 'Mon profil'),
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
                    title: 'Adresse professionnelle',
                    icon: Icons.location_on_outlined,
                    children: [
                      _ProfileValue(
                        label: 'Adresse',
                        value:
                            profile
                                    ?.professionalAddress
                                    .addressLineLabel
                                    .isNotEmpty ==
                                true
                            ? profile!.professionalAddress.addressLineLabel
                            : 'Adresse professionnelle à compléter',
                        valueColor: profile?.hasProfessionalAddress == true
                            ? null
                            : context.v5Colors.warning,
                      ),
                      _ProfileValue(
                        label: 'Code postal · Ville',
                        value:
                            profile
                                    ?.professionalAddress
                                    .localityLabel
                                    .isNotEmpty ==
                                true
                            ? profile!.professionalAddress.localityLabel
                            : 'À compléter',
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('edit-professional-address'),
                          onPressed: () => _editProfile(profile),
                          child: const Text('Modifier'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  _ProfileSection(
                    title: 'CPTS',
                    icon: Icons.hub_outlined,
                    children: [
                      _ProfileValue(
                        label: 'CPTS',
                        value: profile?.cptsLabel?.trim().isNotEmpty == true
                            ? profile!.cptsLabel!.trim()
                            : 'Aucune CPTS renseignée',
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('edit-professional-cpts'),
                          onPressed: () => _editProfile(profile),
                          child: const Text('Modifier'),
                        ),
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
                  const SizedBox(height: V5Spacing.lg),
                  OutlinedButton.icon(
                    key: const Key('open-notification-center'),
                    onPressed: widget.onOpenNotifications,
                    icon: const Icon(Icons.notifications_outlined),
                    label: const Text('Notifications'),
                  ),
                  const SizedBox(height: V5Spacing.xs),
                  // TEMPORAIRE — recette diagnostic Push (JOB-0024). Bouton temporaire,
                  // à retirer après la recette iPhone du diagnostic Push. Volontairement
                  // hors du bloc `if (kDebugMode)` : doit rester visible en build
                  // release / Deploy Preview pour permettre le diagnostic sur un iPhone
                  // réel.
                  OutlinedButton.icon(
                    key: const Key('open-diagnostic-push'),
                    onPressed: () => Navigator.of(context).push(
                      AppPageRoute<void>(
                        builder: (_) =>
                            const DiagnosticPushRegistrationScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('Diagnostic Push'),
                  ),
                  const SizedBox(height: V5Spacing.xs),
                  if (kDebugMode) ...[
                    OutlinedButton.icon(
                      key: const Key('open-development-settings'),
                      onPressed: widget.onOpenSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Réglages'),
                    ),
                    const SizedBox(height: V5Spacing.xs),
                  ],
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
  late final TextEditingController _cptsLabel;
  late final TextEditingController _professionalAddressLine1;
  late final TextEditingController _professionalAddressLine2;
  late final TextEditingController _professionalPostalCode;
  late final TextEditingController _professionalCity;
  late final TextEditingController _professionalCountryCode;
  late final TextEditingController _equipmentDetails;
  late final Set<String> _equipment;
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
                    Row(
                      children: [
                        Expanded(
                          child: V5TextField(
                            key: const Key('professional-profile-postal-code'),
                            label: 'Code postal',
                            controller: _professionalPostalCode,
                            focusNode: _professionalPostalCodeFocus,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                            validator: _professionalPostalCodeValidator,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: V5Spacing.xs),
                        Expanded(
                          child: V5TextField(
                            key: const Key('professional-profile-city'),
                            label: 'Ville',
                            controller: _professionalCity,
                            focusNode: _professionalCityFocus,
                            textCapitalization: TextCapitalization.words,
                            maxLength: 120,
                            validator: _professionalCityValidator,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
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
              const SizedBox(height: V5Spacing.sm),
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
    if (!_hasProfessionalAddressInput) return null;
    return _required(value) == null
        ? null
        : 'Renseignez l’adresse professionnelle.';
  }

  String? _professionalPostalCodeValidator(String? value) {
    if (!_hasProfessionalAddressInput) return null;
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return 'Renseignez le code postal professionnel.';
    if (_normalizedProfessionalCountryCode == 'FR' &&
        !RegExp(r'^\d{5}$').hasMatch(normalized)) {
      return 'Le code postal doit contenir exactement 5 chiffres.';
    }
    return null;
  }

  String? _professionalCityValidator(String? value) {
    if (!_hasProfessionalAddressInput) return null;
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
        cptsLabel: _cptsLabel.text.trim(),
        professionalAddressLine1: _professionalAddressLine1.text.trim(),
        professionalAddressLine2: _professionalAddressLine2.text.trim(),
        professionalPostalCode: _professionalPostalCode.text.trim(),
        professionalCity: _professionalCity.text.trim(),
        professionalCountryCode: _normalizedProfessionalCountryCode,
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
        error: _professionalCountryCodeValidator(_professionalCountryCode.text),
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
