import 'package:flutter/material.dart';

import '../models/admin_invitation.dart';
import '../models/need.dart';
import '../models/responsible_account.dart';
import '../repositories/admin_invitation_repository.dart';
import '../repositories/admin_invitation_repository_scope.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/responsible_access_administration_repository.dart';
import '../repositories/responsible_access_administration_repository_scope.dart';
import '../theme/app_theme.dart';
import '../utils/app_page_route.dart';
import '../utils/french_date_time.dart';
import '../widgets/common.dart';
import '../widgets/location_multi_selector.dart';
import 'responsible_access_form_screen.dart';

class AdminInvitationsScreen extends StatefulWidget {
  const AdminInvitationsScreen({super.key});

  @override
  State<AdminInvitationsScreen> createState() => _AdminInvitationsScreenState();
}

class _AdminInvitationsScreenState extends State<AdminInvitationsScreen> {
  LiveCoordinationData? _liveData;
  Stream<ResponsibleAccess?>? _access;
  Stream<List<ResponsePlace>>? _locations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liveData = LiveCoordinationDataScope.of(context);
    if (!identical(liveData, _liveData)) {
      _liveData = liveData;
      _access = liveData.watchResponsibleAccess();
      _locations = liveData.watchLocations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Responsables')),
      body: SafeArea(
        top: false,
        child: StreamBuilder<ResponsibleAccess?>(
          stream: _access,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              if (isInvalidResponsibleAccessError(snapshot.error)) {
                return const InvalidResponsibleAccessState();
              }
              return const _AccessDenied();
            }
            if (!snapshot.hasData) {
              return snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : const _AccessDenied();
            }
            if (snapshot.data?.isCoordinator != true) {
              return const _AccessDenied();
            }
            return _CoordinatorInvitationsContent(
              repository: AdminInvitationRepositoryScope.of(context),
              accessRepository:
                  ResponsibleAccessAdministrationRepositoryScope.of(context),
              currentUid: snapshot.data!.uid,
              locations: _locations!,
            );
          },
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Accès réservé au coordinateur départemental.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _CoordinatorInvitationsContent extends StatefulWidget {
  const _CoordinatorInvitationsContent({
    required this.repository,
    required this.accessRepository,
    required this.currentUid,
    required this.locations,
  });

  final AdminInvitationRepository repository;
  final ResponsibleAccessAdministrationRepository accessRepository;
  final String currentUid;
  final Stream<List<ResponsePlace>> locations;

  @override
  State<_CoordinatorInvitationsContent> createState() =>
      _CoordinatorInvitationsContentState();
}

class _CoordinatorInvitationsContentState
    extends State<_CoordinatorInvitationsContent> {
  late Stream<List<AdminInvitation>> _invitations;
  late Future<List<ResponsibleAccount>> _accounts;

  @override
  void initState() {
    super.initState();
    _invitations = widget.repository.watchInvitations();
    _accounts = widget.accessRepository.listAccounts();
  }

  @override
  void didUpdateWidget(_CoordinatorInvitationsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _invitations = widget.repository.watchInvitations();
    }
    if (!identical(oldWidget.accessRepository, widget.accessRepository)) {
      _accounts = widget.accessRepository.listAccounts();
    }
  }

  Future<void> _openForm(List<ResponsePlace> locations) async {
    final invitation = await Navigator.of(context).push<AdminInvitation>(
      AppPageRoute(
        builder: (_) => AdminInvitationFormScreen(
          repository: widget.repository,
          locations: locations,
        ),
      ),
    );
    if (!mounted || invitation == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Invitation créée. Préparez maintenant le compte pour envoyer '
          'l’e-mail d’activation.',
        ),
      ),
    );
  }

  Future<void> _manageAccess(
    ResponsibleAccount account,
    List<ResponsePlace> locations,
  ) async {
    if (account.uid == widget.currentUid) return;
    final updated = await Navigator.of(context).push<ResponsibleAccount>(
      AppPageRoute(
        builder: (_) => ResponsibleAccessFormScreen(
          account: account,
          currentUid: widget.currentUid,
          locations: locations,
          repository: widget.accessRepository,
        ),
      ),
    );
    if (!mounted || updated == null) return;
    _reloadAccounts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.access.active
              ? 'Accès responsable mis à jour.'
              : 'Accès responsable désactivé.',
        ),
      ),
    );
  }

  void _reloadAccounts() {
    setState(() {
      _accounts = widget.accessRepository.listAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ResponsePlace>>(
      stream: widget.locations,
      builder: (context, locationSnapshot) {
        if (locationSnapshot.hasError) {
          return const _ErrorState(
            message: 'Les lieux ne sont pas disponibles.',
          );
        }
        if (!locationSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final locations = locationSnapshot.data!;
        final locationsById = {for (final value in locations) value.id: value};
        return StreamBuilder<List<AdminInvitation>>(
          stream: _invitations,
          builder: (context, snapshot) {
            final invitations = snapshot.data
                ?.where((invitation) => invitation.isUnused)
                .toList(growable: false);
            return PageContainer(
              child: ListView(
                key: const Key('admin-invitations-list'),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                children: [
                  PageHeader(
                    eyebrow: 'Administration',
                    title: 'Responsables',
                    subtitle: 'Invitations et accès aux centres',
                    trailing: IconButton.filled(
                      key: const Key('invite-admin-button'),
                      tooltip: 'Inviter un responsable',
                      onPressed: () => _openForm(locations),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      key: const Key('responsible-accounts-section'),
                      title: const Text('Accès existants'),
                      subtitle: const Text('Comptes, rôles et centres'),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                      children: [
                        FutureBuilder<List<ResponsibleAccount>>(
                          future: _accounts,
                          builder: (context, accountSnapshot) {
                            if (accountSnapshot.hasError) {
                              return _AccessListError(onRetry: _reloadAccounts);
                            }
                            if (!accountSnapshot.hasData) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return Column(
                              children: accountSnapshot.data!
                                  .map(
                                    (account) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _ResponsibleAccountCard(
                                        account: account,
                                        currentUid: widget.currentUid,
                                        locationsById: locationsById,
                                        onManage: () =>
                                            _manageAccess(account, locations),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SectionTitle(title: 'Invitations'),
                  const SizedBox(height: 10),
                  if (snapshot.hasError)
                    const _ErrorState(
                      message: 'Les invitations ne sont pas disponibles.',
                    )
                  else if (!snapshot.hasData)
                    const Center(child: CircularProgressIndicator())
                  else if (invitations!.isEmpty)
                    const _EmptyInvitations()
                  else
                    ...invitations.map(
                      (invitation) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InvitationCard(
                          invitation: invitation,
                          locationsById: locationsById,
                          onEdit: () => _edit(invitation, locations),
                          onCancel: () => _cancel(invitation),
                          onReactivate: () => _reactivate(invitation),
                          onResend: () => _resend(invitation),
                          onDelete: () => _delete(invitation),
                          provisioning: _provisioningIds.contains(
                            invitation.id,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _edit(
    AdminInvitation invitation,
    List<ResponsePlace> locations,
  ) async {
    final updated = await Navigator.of(context).push<AdminInvitation>(
      AppPageRoute(
        builder: (_) => AdminInvitationFormScreen(
          repository: widget.repository,
          locations: locations,
          invitation: invitation,
        ),
      ),
    );
    if (!mounted || updated == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invitation mise à jour.')));
  }

  Future<void> _cancel(AdminInvitation invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler cette invitation ?'),
        content: const Text(
          'Le futur responsable ne pourra plus utiliser cette invitation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Conserver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler l’invitation'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.cancelInvitation(invitation.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation annulée.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L’invitation n’a pas pu être annulée. Réessayez.'),
        ),
      );
    }
  }

  Future<void> _reactivate(AdminInvitation invitation) async {
    var expirationDays = 7;
    final selectedDays = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Réactiver cette invitation ?'),
          content: DropdownButtonFormField<int>(
            key: const Key('reactivate-expiration'),
            initialValue: expirationDays,
            decoration: const InputDecoration(labelText: 'Nouvelle validité'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('24 heures')),
              DropdownMenuItem(value: 7, child: Text('7 jours')),
              DropdownMenuItem(value: 14, child: Text('14 jours')),
            ],
            onChanged: (value) =>
                setDialogState(() => expirationDays = value ?? 7),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour'),
            ),
            FilledButton(
              key: const Key('confirm-reactivate-invitation'),
              onPressed: () => Navigator.pop(context, expirationDays),
              child: const Text('Réactiver'),
            ),
          ],
        ),
      ),
    );
    if (selectedDays == null) return;
    try {
      await widget.repository.reactivateInvitation(
        invitation.id,
        DateTime.now().add(Duration(days: selectedDays)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation réactivée.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L’invitation n’a pas pu être réactivée. Réessayez.'),
        ),
      );
    }
  }

  Future<void> _delete(AdminInvitation invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer définitivement cette invitation ?'),
        content: const Text('Cette opération est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Conserver'),
          ),
          FilledButton(
            key: const Key('confirm-delete-invitation'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteInvitation(invitation.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation supprimée.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L’invitation n’a pas pu être supprimée. Réessayez.'),
        ),
      );
    }
  }

  final Set<String> _provisioningIds = {};

  Future<void> _resend(AdminInvitation invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renvoyer l’e-mail d’activation ?'),
        content: const Text(
          'Cette action prépare ou réutilise le compte responsable, puis '
          'envoie un nouveau lien d’activation.\n\n'
          'Un compte déjà préparé conserve le même identifiant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            key: const Key('confirm-resend-invitation'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Renvoyer'),
          ),
        ],
      ),
    );
    if (confirmed != true || _provisioningIds.contains(invitation.id)) return;
    setState(() => _provisioningIds.add(invitation.id));
    try {
      await widget.repository.provisionInvitation(invitation.id, resend: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail d’activation envoyé.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L’e-mail d’activation n’a pas pu être envoyé.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _provisioningIds.remove(invitation.id));
    }
  }
}

class _ResponsibleAccountCard extends StatelessWidget {
  const _ResponsibleAccountCard({
    required this.account,
    required this.currentUid,
    required this.locationsById,
    required this.onManage,
  });

  final ResponsibleAccount account;
  final String currentUid;
  final Map<String, ResponsePlace> locationsById;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final access = account.access;
    final isSelf = account.uid == currentUid;
    final roleLabel = access.isCumulative
        ? 'Coordinateur et responsable'
        : access.roles.contains(ResponsibleRole.coordinator)
        ? 'Coordinateur départemental'
        : 'Responsable de centre';
    final locations =
        access.locationIds
            .map((id) => locationsById[id]?.name ?? 'Lieu indisponible')
            .toList()
          ..sort();
    return Card(
      key: Key('responsible-account-${account.uid}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    account.identityLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _AccountStatusBadge(active: access.active),
              ],
            ),
            if (account.email case final email?) ...[
              const SizedBox(height: 4),
              Text(email),
            ],
            const SizedBox(height: 8),
            Text(
              roleLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              access.locationIds.isEmpty
                  ? 'Tous les centres'
                  : '${locations.length} centre${locations.length > 1 ? 's' : ''} · '
                        '${locations.join(' · ')}',
            ),
            if (isSelf) ...[
              const SizedBox(height: 10),
              const Text(
                'Votre propre accès doit être géré par un autre coordinateur.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key('manage-responsible-${account.uid}'),
                onPressed: isSelf ? null : onManage,
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Gérer l’accès'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountStatusBadge extends StatelessWidget {
  const _AccountStatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.green : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Actif' : 'Inactif',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AccessListError extends StatelessWidget {
  const _AccessListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Text(
              'Les accès responsables ne sont pas disponibles.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.locationsById,
    required this.onEdit,
    required this.onCancel,
    required this.onReactivate,
    required this.onResend,
    required this.onDelete,
    required this.provisioning,
  });

  final AdminInvitation invitation;
  final Map<String, ResponsePlace> locationsById;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onReactivate;
  final VoidCallback onResend;
  final VoidCallback onDelete;
  final bool provisioning;

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = invitation.isExpired
        ? AdminInvitationStatus.expired
        : invitation.status;
    final locationLabels =
        (invitation.locationIds.isEmpty
                ? const ['Tous les centres']
                : invitation.locationIds
                      .map(
                        (id) => locationsById[id]?.name ?? 'Lieu indisponible',
                      )
                      .toList())
            .toList()
          ..sort();
    return Card(
      key: Key('invitation-card-${invitation.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    invitation.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _InvitationStatusBadge(status: effectiveStatus),
              ],
            ),
            const SizedBox(height: 5),
            Text(invitation.email),
            const SizedBox(height: 10),
            Text(
              invitation.role == AdminInvitationDraft.coordinatorRole
                  ? 'Coordinateur départemental'
                  : 'Responsable de centre',
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(locationLabels.join(' · ')),
            const SizedBox(height: 8),
            Text(
              'Créée le ${FrenchDateTime.date(invitation.createdAt)} · '
              'Expire le ${FrenchDateTime.date(invitation.expiresAt)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (effectiveStatus == AdminInvitationStatus.pending) ...[
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    key: Key('resend-invitation-${invitation.id}'),
                    onPressed: provisioning ? null : onResend,
                    child: Text(provisioning ? 'Envoi…' : 'Renvoyer'),
                  ),
                  TextButton(
                    key: Key('edit-invitation-${invitation.id}'),
                    onPressed: provisioning ? null : onEdit,
                    child: const Text('Modifier'),
                  ),
                  TextButton(
                    key: Key('cancel-invitation-${invitation.id}'),
                    onPressed: provisioning ? null : onCancel,
                    child: const Text('Annuler'),
                  ),
                  TextButton(
                    key: Key('delete-invitation-${invitation.id}'),
                    onPressed: provisioning ? null : onDelete,
                    child: const Text('Supprimer'),
                  ),
                ],
              ),
            ] else if (effectiveStatus == AdminInvitationStatus.cancelled) ...[
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    key: Key('reactivate-invitation-${invitation.id}'),
                    onPressed: onReactivate,
                    child: const Text('Réactiver'),
                  ),
                  TextButton(
                    key: Key('edit-invitation-${invitation.id}'),
                    onPressed: onEdit,
                    child: const Text('Modifier'),
                  ),
                  TextButton(
                    key: Key('delete-invitation-${invitation.id}'),
                    onPressed: onDelete,
                    child: const Text('Supprimer'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InvitationStatusBadge extends StatelessWidget {
  const _InvitationStatusBadge({required this.status});

  final AdminInvitationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AdminInvitationStatus.pending => ('En attente', AppColors.orange),
      AdminInvitationStatus.accepted => ('Compte préparé', AppColors.green),
      AdminInvitationStatus.expired => ('Expirée', AppColors.textMuted),
      AdminInvitationStatus.cancelled => ('Annulée', AppColors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyInvitations extends StatelessWidget {
  const _EmptyInvitations();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.mark_email_unread_outlined, size: 36),
            SizedBox(height: 10),
            Text('Aucune invitation pour le moment.'),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class AdminInvitationFormScreen extends StatefulWidget {
  const AdminInvitationFormScreen({
    super.key,
    required this.repository,
    required this.locations,
    this.invitation,
  });

  final AdminInvitationRepository repository;
  final List<ResponsePlace> locations;
  final AdminInvitation? invitation;

  @override
  State<AdminInvitationFormScreen> createState() =>
      _AdminInvitationFormScreenState();
}

class _AdminInvitationFormScreenState extends State<AdminInvitationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final Set<String> _selectedLocations = {};
  late String _role;
  int _expirationDays = 7;
  bool _submitting = false;

  bool get _hasValidIdentity =>
      _nameController.text.trim().isNotEmpty &&
      _isValidInvitationEmail(_emailController.text);

  bool get _canSubmit => !_submitting && _hasValidIdentity;

  bool get _isEditing => widget.invitation != null;

  @override
  void initState() {
    super.initState();
    final invitation = widget.invitation;
    _nameController.text = invitation?.displayName ?? '';
    _emailController.text = invitation?.email ?? '';
    _role = invitation?.role ?? AdminInvitationDraft.siteManagerRole;
    _selectedLocations.addAll(invitation?.locationIds ?? const {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Modifier l’invitation' : 'Inviter un responsable',
        ),
      ),
      bottomNavigationBar: _InvitationSubmitBar(
        submitting: _submitting,
        enabled: _canSubmit,
        onSubmit: _submit,
        editing: _isEditing,
      ),
      body: PageContainer(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            key: const Key('admin-invitation-form'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: AppFormLayout.pagePadding,
            children: [
              TextFormField(
                key: const Key('invitation-display-name'),
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nom complet'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Saisissez le nom du responsable.'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppFormLayout.fieldSpacing),
              TextFormField(
                key: const Key('invitation-email'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                readOnly: _isEditing,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (value) {
                  return _isValidInvitationEmail(value ?? '')
                      ? null
                      : 'Saisissez une adresse e-mail valide.';
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppFormLayout.fieldSpacing),
              DropdownButtonFormField<String>(
                key: const Key('invitation-role'),
                initialValue: _role,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Rôle'),
                items: const [
                  DropdownMenuItem(
                    value: AdminInvitationDraft.siteManagerRole,
                    child: Text('Responsable de centre'),
                  ),
                  DropdownMenuItem(
                    value: AdminInvitationDraft.coordinatorRole,
                    child: Text('Coordinateur départemental'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _role = value!;
                  if (_role == AdminInvitationDraft.coordinatorRole) {
                    _selectedLocations.clear();
                  }
                }),
              ),
              if (!_isEditing) ...[
                const SizedBox(height: AppFormLayout.fieldSpacing),
                DropdownButtonFormField<int>(
                  key: const Key('invitation-expiration'),
                  initialValue: _expirationDays,
                  decoration: const InputDecoration(labelText: 'Validité'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('24 heures')),
                    DropdownMenuItem(value: 7, child: Text('7 jours')),
                    DropdownMenuItem(value: 14, child: Text('14 jours')),
                  ],
                  onChanged: (value) =>
                      setState(() => _expirationDays = value ?? 7),
                ),
              ],
              if (_role == AdminInvitationDraft.siteManagerRole) ...[
                const SizedBox(height: AppFormLayout.sectionSpacing),
                const FormSectionTitle(title: 'Centres autorisés'),
                const SizedBox(height: AppFormLayout.titleSpacing),
                LocationMultiSelector(
                  locations: widget.locations,
                  selectedIds: _selectedLocations,
                  enabled: !_submitting,
                  onChanged: (selectedIds) => setState(() {
                    _selectedLocations
                      ..clear()
                      ..addAll(selectedIds);
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_formKey.currentState?.validate() != true) return;
    if (_isEditing) {
      await _submitUpdate();
      return;
    }
    final now = DateTime.now();
    late final AdminInvitationDraft draft;
    try {
      draft = AdminInvitationDraft(
        email: _emailController.text,
        displayName: _nameController.text,
        role: _role,
        locationIds: _selectedLocations,
        expiresAt: now.add(Duration(days: _expirationDays)),
      );
      draft.validate(now: now);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
      return;
    }
    setState(() => _submitting = true);
    try {
      final invitation = await widget.repository.createInvitation(draft);
      if (mounted) Navigator.pop(context, invitation);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
    }
  }

  Future<void> _submitUpdate() async {
    late final AdminInvitationUpdate update;
    try {
      update = AdminInvitationUpdate(
        displayName: _nameController.text,
        role: _role,
        locationIds: _selectedLocations,
      );
      update.validate();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
      return;
    }
    setState(() => _submitting = true);
    try {
      final updated = await widget.repository.updateInvitation(
        widget.invitation!.id,
        update,
      );
      if (mounted) Navigator.pop(context, updated);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is FormatException
                ? error.message
                : 'L’invitation n’a pas pu être modifiée. Réessayez.',
          ),
        ),
      );
    }
  }

  String _messageFor(Object error) {
    if (error is FormatException) return error.message;
    return 'L’invitation n’a pas pu être créée. Réessayez.';
  }
}

bool _isValidInvitationEmail(String value) {
  final email = value.trim();
  return email.length <= AdminInvitationDraft.maxEmailLength &&
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
}

class _InvitationSubmitBar extends StatelessWidget {
  const _InvitationSubmitBar({
    required this.submitting,
    required this.enabled,
    required this.onSubmit,
    required this.editing,
  });

  final bool submitting;
  final bool enabled;
  final VoidCallback onSubmit;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 10,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          minimum: AppFormLayout.actionBarPadding,
          child: SizedBox(
            height: AppFormLayout.actionHeight,
            child: FilledButton.icon(
              key: Key(
                editing ? 'save-admin-invitation' : 'create-admin-invitation',
              ),
              onPressed: enabled ? onSubmit : null,
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                submitting
                    ? (editing ? 'Enregistrement…' : 'Création…')
                    : (editing ? 'Enregistrer' : 'Créer l’invitation'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
