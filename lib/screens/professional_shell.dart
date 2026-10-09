import 'package:flutter/material.dart';

import '../dev/role_preview.dart';
import '../config/beta_terms.dart';
import '../models/volunteer_profile.dart';
import '../models/public_mission_discovery.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/public_mission_discovery_repository.dart';
import '../repositories/professional_admission_repository.dart';
import '../repositories/repository_scope.dart';
import '../services/professional_verification_service.dart';
import '../theme/v5_foundation.dart';
import '../utils/account_password_recovery.dart';
import '../utils/app_page_route.dart';
import '../widgets/native_interactions.dart';
import '../widgets/professional_page_header.dart';
import '../widgets/v5_bottom_navigation.dart';
import '../widgets/v5_controls.dart';
import '../widgets/v5_form_system.dart';
import 'create_need_screen.dart';
import 'development_settings_screen.dart';
import 'professional_engagements_screen.dart';
import 'professional_profile_screen.dart';
import 'notification_center_screen.dart';
import 'information_consent_screen.dart';
import 'slots_screen.dart';

class ProfessionalShell extends StatefulWidget {
  const ProfessionalShell({
    super.key,
    this.initialIndex = 0,
    this.verificationService = const FakeProfessionalVerificationService(),
    this.showResponsibleLogin = true,
    this.showProfessionalEmailLogin = false,
    this.publicMissionDiscoveryRepository =
        const EmptyPublicMissionDiscoveryRepository(),
  }) : assert(initialIndex >= 0 && initialIndex < 3);

  final int initialIndex;
  final ProfessionalVerificationService verificationService;
  final bool showResponsibleLogin;
  final bool showProfessionalEmailLogin;
  final PublicMissionDiscoveryRepository publicMissionDiscoveryRepository;

  @override
  State<ProfessionalShell> createState() => _ProfessionalShellState();
}

class _ProfessionalShellState extends State<ProfessionalShell> {
  late int _currentIndex;
  final List<Widget?> _screens = List<Widget?>.filled(3, null);
  Object? _repositoryIdentity;
  Future<VolunteerProfile?>? _profile;
  Stream<ProfessionalAdmissionState>? _admission;
  late Stream<List<PublicMissionDiscovery>> _publicMissions;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens[_currentIndex] = _createScreen(_currentIndex);
    _publicMissions = widget.publicMissionDiscoveryRepository
        .watchMissions()
        .asBroadcastStream();
  }

  @override
  void didUpdateWidget(covariant ProfessionalShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showResponsibleLogin != widget.showResponsibleLogin) {
      _screens[2] = _createScreen(2);
    }
    if (!identical(
      oldWidget.publicMissionDiscoveryRepository,
      widget.publicMissionDiscoveryRepository,
    )) {
      _publicMissions = widget.publicMissionDiscoveryRepository
          .watchMissions()
          .asBroadcastStream();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = RepositoryScope.of(context);
    if (!identical(repository, _repositoryIdentity)) {
      _repositoryIdentity = repository;
      _profile = repository.getVolunteerProfile();
      _admission = _admissionStream(repository);
    }
  }

  Widget _createScreen(int index) => switch (index) {
    0 => const SlotsScreen(professionalJourney: true),
    1 => const ProfessionalEngagementsScreen(),
    2 => ProfessionalProfileScreen(
      onOpenResponsibleAccess: _openResponsibleAccess,
      onOpenProfessionalAccount: widget.showProfessionalEmailLogin
          ? _openProfessionalAccount
          : null,
      showResponsibleLogin: widget.showResponsibleLogin,
      onOpenSettings: _openSettings,
      onOpenNotifications: _openNotifications,
      onSignOut: _signOut,
      verificationService: widget.verificationService,
    ),
    _ => throw RangeError.index(index, _screens),
  };

  Stream<ProfessionalAdmissionState> _admissionStream(Object repository) =>
      repository is ProfessionalAdmissionRepository
      ? repository.watchProfessionalAdmission()
      : Stream<ProfessionalAdmissionState>.multi(
          (controller) => controller.add(
            const ProfessionalAdmissionState(
              mode: ProfessionalAdmissionMode.open,
            ),
          ),
        );

  void _selectTab(int index) {
    setState(() {
      if (index != 2) {
        final repository = RepositoryScope.of(context);
        _profile = repository.getVolunteerProfile();
        _admission = _admissionStream(repository);
      }
      _screens[index] ??= _createScreen(index);
      _currentIndex = index;
    });
  }

  Widget _operationalTabs() => StreamBuilder<ProfessionalAdmissionState>(
    stream: _admission,
    builder: (context, admissionSnapshot) {
      if (admissionSnapshot.hasError) {
        return const V5LoadingState(
          label: 'Admission temporairement indisponible',
        );
      }
      final admission = admissionSnapshot.data;
      if (admission == null) {
        return const V5LoadingState(label: 'Vérification de l’accès…');
      }
      return _operationalTabsForAdmission(admission);
    },
  );

  Widget _operationalTabsForAdmission(ProfessionalAdmissionState admission) =>
      FutureBuilder<VolunteerProfile?>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const V5LoadingState(label: 'Chargement du profil…');
          }
          final verified =
              snapshot.data?.hasVerifiedProfessionalIdentity == true;
          if (!verified || !admission.canReadOperationalData) {
            return _ProfessionalDiscoveryState(
              missions: _currentIndex == 0,
              invitationOnly:
                  admission.mode == ProfessionalAdmissionMode.invitationOnly,
              verified: verified,
              hasProfile: snapshot.data != null,
              onUseInvitation: _useInvitation,
              onAcceptTerms:
                  admission.operationIds.isNotEmpty && !admission.termsAccepted
                  ? _acceptUpdatedTerms
                  : null,
              onCompleteProfile: () => _selectTab(2),
              publicMissions: _publicMissions,
            );
          }
          return NativeTabView(
            index: _currentIndex,
            children: List.generate(
              _screens.length,
              (index) => _screens[index] ?? const SizedBox.shrink(),
            ),
          );
        },
      );

  Future<void> _useInvitation() async {
    final repository = RepositoryScope.of(context);
    if (repository is! ProfessionalAdmissionRepository) return;
    final hasProfile = await repository.getVolunteerProfile() != null;
    if (!mounted) return;
    final redeemed = await showDialog<bool>(
      context: context,
      builder: (_) => _ProfessionalInvitationDialog(
        repository: repository as ProfessionalAdmissionRepository,
        hasProfile: hasProfile,
      ),
    );
    if (!mounted) return;
    setState(() {
      _profile = RepositoryScope.of(context).getVolunteerProfile();
      _admission = _admissionStream(repository);
      _screens[2] = _createScreen(2);
    });
    if (redeemed == true) {
      if (!hasProfile) _selectTab(2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasProfile
                ? 'Invitation enregistrée pour cette Action.'
                : 'Invitation vérifiée. Complétez votre profil, puis confirmez votre RPPS et revenez valider l’invitation.',
          ),
        ),
      );
    }
  }

  Future<void> _acceptUpdatedTerms() async {
    final repository = RepositoryScope.of(context);
    if (repository is! BetaTermsAcceptanceRepository) return;
    final termsRepository = repository as BetaTermsAcceptanceRepository;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => _BetaTermsDialog(repository: termsRepository),
    );
    if (accepted == true && mounted) {
      setState(() => _admission = _admissionStream(repository));
    }
  }

  Future<void> _openProfessionalAccount() async {
    final repository = RepositoryScope.of(context);
    if (repository is! ProfessionalAdmissionRepository) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _ProfessionalInvitationDialog(
        repository: repository as ProfessionalAdmissionRepository,
        invitationRequired: false,
      ),
    );
    if (!mounted) return;
    setState(() {
      _profile = repository.getVolunteerProfile();
      _admission = _admissionStream(repository);
      _screens[2] = _createScreen(2);
    });
  }

  void _openResponsibleAccess() {
    final repository = RepositoryScope.of(context);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: ResponsibleLogin(
              repository: repository,
              onSignedIn: () {
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    final liveData = LiveCoordinationDataScope.of(context);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: const DevelopmentSettingsScreen(),
        ),
      ),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => const NotificationCenterScreen(
          showProfessionalTargetingGuidance: true,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final repository = RepositoryScope.of(context);
    if (repository is ProfessionalAdmissionRepository) {
      await (repository as ProfessionalAdmissionRepository)
          .signOutProfessionalEmail();
      if (mounted) {
        setState(() {
          _profile = repository.getVolunteerProfile();
          _admission = _admissionStream(repository);
          _screens[2] = _createScreen(2);
        });
      }
    } else {
      await repository.signOutResponsible();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RolePreviewDebugOverlay(
      journeyLabel: 'Professionnel de santé',
      child: Scaffold(
        backgroundColor: context.v5Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: _currentIndex == 2 ? _screens[2]! : _operationalTabs(),
        ),
        bottomNavigationBar: V5BottomNavigation(
          selectedIndex: _currentIndex,
          onDestinationSelected: _selectTab,
        ),
      ),
    );
  }
}

class _BetaTermsDialog extends StatefulWidget {
  const _BetaTermsDialog({required this.repository});

  final BetaTermsAcceptanceRepository repository;

  @override
  State<_BetaTermsDialog> createState() => _BetaTermsDialogState();
}

class _BetaTermsDialogState extends State<_BetaTermsDialog> {
  bool _checked = false;
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await widget.repository.acceptCurrentBetaTerms();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? 'Mettez l’application à jour pour accepter les CGU.'
              : 'Acceptation indisponible. Réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('CGU Beta V1'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Votre accès à l’Action nécessite l’acceptation des CGU en vigueur.',
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            AppPageRoute<void>(
              builder: (_) => const InformationConsentScreen(),
            ),
          ),
          child: const Text('Lire les CGU Beta'),
        ),
        CheckboxListTile(
          value: _checked,
          onChanged: _busy
              ? null
              : (value) => setState(() => _checked = value == true),
          title: const Text('J’accepte les CGU Beta V1'),
          subtitle: const Text('Version ${BetaTerms.version}'),
        ),
        if (_error != null) Text(_error!),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        child: const Text('Plus tard'),
      ),
      FilledButton(
        onPressed: _busy || !_checked ? null : _accept,
        child: const Text('Accepter'),
      ),
    ],
  );
}

class _ProfessionalInvitationDialog extends StatefulWidget {
  const _ProfessionalInvitationDialog({
    required this.repository,
    this.invitationRequired = true,
    this.hasProfile = true,
  });

  final ProfessionalAdmissionRepository repository;
  final bool invitationRequired;
  final bool hasProfile;

  @override
  State<_ProfessionalInvitationDialog> createState() =>
      _ProfessionalInvitationDialogState();
}

class _ProfessionalInvitationDialogState
    extends State<_ProfessionalInvitationDialog> {
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  ProfessionalEmailIdentity? _identity;
  String? _message;
  bool _busy = false;
  bool _recoveringPassword = false;
  bool _recoveryRequested = false;
  bool _termsChecked = false;

  @override
  void initState() {
    super.initState();
    _refreshIdentity();
  }

  @override
  void dispose() {
    _code.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _refreshIdentity() async {
    try {
      final identity = await widget.repository.professionalEmailIdentity();
      if (mounted) {
        setState(() {
          if (_identity?.email != identity.email ||
              _identity?.isAnonymous != identity.isAnonymous) {
            _termsChecked = false;
          }
          _identity = identity;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Session indisponible. Réessayez.');
      }
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) await _refreshIdentity();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeem() async {
    if (_code.text.trim().isEmpty) {
      setState(() => _message = 'Saisissez le code de votre invitation.');
      return;
    }
    await _perform(() async {
      if (!_termsChecked ||
          widget.repository is! BetaTermsAcceptanceRepository) {
        throw StateError('Acceptez les CGU Beta avant de continuer.');
      }
      await (widget.repository as BetaTermsAcceptanceRepository)
          .acceptCurrentBetaTerms();
      if (widget.hasProfile) {
        await widget.repository.redeemProfessionalInvitation(_code.text.trim());
      } else {
        await widget.repository.prepareProfessionalRegistration(
          _code.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> _requestPasswordReset() async {
    if (_busy || _recoveryRequested) return;
    final email = _email.text.trim();
    if (!isValidAccountRecoveryEmail(email)) {
      setState(() => _message = accountPasswordRecoveryInvalidEmailMessage);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.repository.sendAccountPasswordReset(email);
      if (mounted) {
        setState(() {
          _recoveryRequested = true;
          _message = accountPasswordRecoverySuccessMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = accountPasswordRecoveryFailureMessage);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = _identity;
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.invitationRequired
            ? 'Utiliser une invitation'
            : 'Compte MobSanté',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recoveringPassword)
            const Text('Saisissez l’adresse de votre compte professionnel.')
          else if (widget.invitationRequired) ...[
            const Text(
              'Cette invitation est personnelle. Connectez-vous avec '
              'l’adresse vérifiée du destinataire. Préparez ensuite votre profil '
              'et confirmez votre RPPS avant de valider l’accès à l’Action.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('professional-invitation-code'),
              controller: _code,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Code d’invitation'),
            ),
          ] else
            const Text('Connectez-vous à votre compte professionnel existant.'),
          if (identity == null) const LinearProgressIndicator(),
          if (identity?.isAnonymous == true) ...[
            const SizedBox(height: 12),
            TextField(
              key: const Key('professional-invitation-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Adresse e-mail'),
            ),
            if (_recoveringPassword) ...[
              const SizedBox(height: 8),
              if (_recoveryRequested)
                const Text('Pensez à vérifier aussi vos spams.')
              else
                FilledButton(
                  key: const Key('professional-password-reset-submit'),
                  onPressed: _busy ? null : _requestPasswordReset,
                  child: const Text('Envoyer l’e-mail de récupération'),
                ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _recoveringPassword = false;
                        _message = null;
                      }),
                child: const Text('Retour à la connexion'),
              ),
            ] else ...[
              TextField(
                key: const Key('professional-invitation-password'),
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
              ),
              TextButton(
                key: const Key('professional-forgot-password'),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _password.clear();
                        _recoveringPassword = true;
                        _message = null;
                      }),
                child: const Text('Mot de passe oublié ?'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Associer conserve votre profil actuel. Se connecter '
                'ouvre un compte déjà existant.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (widget.invitationRequired)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _perform(
                              () => widget.repository.linkProfessionalEmail(
                                _email.text,
                                _password.text,
                              ),
                            ),
                      child: const Text('Associer mon compte'),
                    ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _perform(
                            () => widget.repository.signInProfessionalEmail(
                              _email.text,
                              _password.text,
                            ),
                          ),
                    child: const Text('Se connecter'),
                  ),
                ],
              ),
            ],
          ],
          if (identity != null && !identity.isAnonymous) ...[
            const SizedBox(height: 12),
            Text(
              identity.emailVerified
                  ? 'Adresse e-mail vérifiée.'
                  : 'Vérifiez votre adresse e-mail avant de valider.',
            ),
            if (!identity.emailVerified)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _perform(
                            widget.repository.sendProfessionalEmailVerification,
                          ),
                    child: const Text('Renvoyer l’e-mail'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _perform(_refreshIdentity),
                    child: const Text('J’ai vérifié mon e-mail'),
                  ),
                ],
              ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _perform(widget.repository.signOutProfessionalEmail),
              child: const Text('Changer de compte'),
            ),
            if (widget.invitationRequired && identity.emailVerified) ...[
              TextButton(
                key: const Key('professional-read-beta-terms'),
                onPressed: () => Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) => const InformationConsentScreen(),
                  ),
                ),
                child: const Text('Lire les CGU Beta'),
              ),
              CheckboxListTile(
                key: const Key('professional-accept-beta-terms'),
                value: _termsChecked,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _termsChecked = value == true),
                title: const Text('J’accepte les CGU Beta V1'),
                subtitle: const Text('Version ${BetaTerms.version}'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(_message!, key: const Key('professional-invitation-message')),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        if (widget.invitationRequired && !_recoveringPassword)
          FilledButton(
            onPressed:
                _busy || identity?.emailVerified != true || !_termsChecked
                ? null
                : _redeem,
            child: Text(widget.hasProfile ? 'Valider' : 'Préparer mon profil'),
          ),
      ],
    );
  }
}

class _ProfessionalDiscoveryState extends StatelessWidget {
  const _ProfessionalDiscoveryState({
    required this.missions,
    required this.invitationOnly,
    required this.verified,
    required this.hasProfile,
    required this.onUseInvitation,
    required this.onAcceptTerms,
    required this.onCompleteProfile,
    required this.publicMissions,
  });

  final bool missions;
  final bool invitationOnly;
  final bool verified;
  final bool hasProfile;
  final VoidCallback onUseInvitation;
  final VoidCallback? onAcceptTerms;
  final VoidCallback onCompleteProfile;
  final Stream<List<PublicMissionDiscovery>> publicMissions;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return ColoredBox(
      color: colors.canvas,
      child: SingleChildScrollView(
        key: Key(
          missions
              ? 'professional-missions-discovery'
              : 'professional-engagements-discovery',
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MobSanteJourneyHeader(
                    journey: MobSanteJourney.professional,
                    pageTitle: missions
                        ? 'Des missions ont besoin de professionnels comme vous'
                        : 'Vos engagements apparaîtront ici',
                    pageTitleKey: const Key('professional-page-title'),
                  ),
                  const SizedBox(height: V5Spacing.md),
                  if (invitationOnly) ...[
                    const Text(
                      'MobSanté est actuellement accessible sur invitation.',
                      key: Key('professional-invitation-only-message'),
                    ),
                    if (!hasProfile) ...[
                      const SizedBox(height: V5Spacing.xs),
                      const Text(
                        'Utilisez votre code d’invitation avant de créer votre profil professionnel.',
                      ),
                    ],
                    const SizedBox(height: V5Spacing.sm),
                    if (onAcceptTerms != null) ...[
                      const Text(
                        'Une acceptation des CGU Beta en vigueur est requise pour accéder à votre Action.',
                      ),
                      FilledButton(
                        key: const Key('professional-reaccept-beta-terms'),
                        onPressed: onAcceptTerms,
                        child: const Text('Accepter les CGU en vigueur'),
                      ),
                    ],
                    OutlinedButton(
                      key: const Key('professional-use-invitation'),
                      onPressed: onUseInvitation,
                      child: const Text('Utiliser mon invitation'),
                    ),
                    const SizedBox(height: V5Spacing.md),
                  ],
                  if (missions) ...[
                    Text(
                      'MobSanté met en relation les professionnels de santé '
                      'avec les besoins sur le terrain.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: V5Spacing.md),
                    StreamBuilder<List<PublicMissionDiscovery>>(
                      stream: publicMissions,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text(
                            snapshot.hasError
                                ? 'Les missions ne sont pas disponibles pour le moment.'
                                : 'Aucune mission à découvrir pour le moment.',
                            key: const Key('public-discovery-empty'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          );
                        }
                        return Column(
                          key: const Key('public-mission-list'),
                          children: [
                            for (final item in snapshot.data!) ...[
                              V5Card(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Besoin ${item.dateLabel.toLowerCase()}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: V5Spacing.xs),
                                    Text('Secteur ${item.sectorLabel}'),
                                    Text(
                                      'Professionnels recherchés : '
                                      '${item.professionLabels.join(', ')}',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: V5Spacing.sm),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: V5Spacing.md),
                  ],
                  Text(
                    verified && invitationOnly
                        ? 'Votre identité professionnelle est vérifiée. Utilisez votre invitation pour accéder aux missions de votre Action.'
                        : missions
                        ? 'Finalisez votre profil professionnel pour découvrir '
                              'les missions correspondant à votre profession, '
                              'consulter leurs informations pratiques et vous engager.'
                        : 'Une fois votre profil professionnel vérifié, vous '
                              'pourrez vous engager sur des missions et retrouver '
                              'ici toutes les informations pratiques.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: V5Spacing.md),
                  FilledButton(
                    key: const Key('professional-verification-cta'),
                    onPressed: onCompleteProfile,
                    child: const Text('Compléter mon profil'),
                  ),
                  if (missions) ...[
                    const SizedBox(height: V5Spacing.lg),
                    V5Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comment ça marche',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: V5Spacing.sm),
                          const Text(
                            'Les missions sont proposées selon votre '
                            'profession et vos disponibilités.',
                          ),
                          const SizedBox(height: V5Spacing.xs),
                          const Text(
                            'Vous pouvez consulter leurs informations '
                            'pratiques avant de vous engager.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
