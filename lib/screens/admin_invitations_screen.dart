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
import '../widgets/v5_form_system.dart';
import 'responsible_access_form_screen.dart';

abstract final class _ResponsibleVisuals {
  static const background = Color(0xFFF6F7F8);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF7C817F);
  static const orange = Color(0xFFF25C05);
  static const orangeSoft = Color(0xFFFFE8D9);
}

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
      backgroundColor: _ResponsibleVisuals.background,
      appBar: AppBar(
        title: const Text('Responsables'),
        backgroundColor: _ResponsibleVisuals.background,
        foregroundColor: _ResponsibleVisuals.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          color: _ResponsibleVisuals.navy,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
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
                  ? const _ManagementLoading()
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
    return const ColoredBox(
      color: _ResponsibleVisuals.background,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Accès réservé au coordinateur départemental.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ResponsibleVisuals.textMuted,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagementLoading extends StatelessWidget {
  const _ManagementLoading();

  @override
  Widget build(BuildContext context) {
    return const V5LoadingState(label: 'Chargement des responsables…');
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
    V5Toast.show(
      context,
      message:
          'Invitation créée. Préparez maintenant le compte pour envoyer '
          'l’e-mail d’activation.',
      tone: V5ToastTone.success,
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
    V5Toast.show(
      context,
      message: updated.access.active
          ? 'Accès responsable mis à jour.'
          : 'Accès responsable désactivé.',
      tone: V5ToastTone.success,
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
          return const _ManagementLoading();
        }
        final locations = locationSnapshot.data!;
        final locationsById = {for (final value in locations) value.id: value};
        return StreamBuilder<List<AdminInvitation>>(
          stream: _invitations,
          builder: (context, snapshot) {
            final invitations = snapshot.data
                ?.where((invitation) => invitation.isUnused)
                .toList(growable: false);
            return LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth <= 596
                    ? 18.0
                    : (constraints.maxWidth - 560) / 2;
                return Material(
                  color: _ResponsibleVisuals.background,
                  child: ListView(
                    key: const Key('admin-invitations-list'),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      12,
                      horizontalPadding,
                      36,
                    ),
                    children: [
                      _ResponsibleHeader(onInvite: () => _openForm(locations)),
                      const SizedBox(height: 22),
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: _responsibleCardDecoration(),
                        child: ExpansionTile(
                          key: const Key('responsible-accounts-section'),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 17,
                            vertical: 5,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            13,
                            0,
                            13,
                            4,
                          ),
                          iconColor: _ResponsibleVisuals.navy,
                          collapsedIconColor: _ResponsibleVisuals.textMuted,
                          title: const Text(
                            'Accès existants',
                            style: TextStyle(
                              color: _ResponsibleVisuals.navy,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: const Text(
                            'Comptes, rôles et centres',
                            style: TextStyle(
                              color: _ResponsibleVisuals.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          children: [
                            FutureBuilder<List<ResponsibleAccount>>(
                              future: _accounts,
                              builder: (context, accountSnapshot) {
                                if (accountSnapshot.hasError) {
                                  return _AccessListError(
                                    onRetry: _reloadAccounts,
                                  );
                                }
                                if (!accountSnapshot.hasData) {
                                  return const _InlineLoading();
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
                                            onManage: () => _manageAccess(
                                              account,
                                              locations,
                                            ),
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
                      const SizedBox(height: 24),
                      const _ManagementSectionTitle(title: 'Invitations'),
                      const SizedBox(height: 11),
                      if (snapshot.hasError)
                        const _ErrorState(
                          message: 'Les invitations ne sont pas disponibles.',
                        )
                      else if (!snapshot.hasData)
                        const _InlineLoading()
                      else if (invitations!.isEmpty)
                        const _EmptyInvitations()
                      else
                        ...invitations.map(
                          (invitation) => Padding(
                            padding: const EdgeInsets.only(bottom: 13),
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
    V5Toast.show(
      context,
      message: 'Invitation mise à jour.',
      tone: V5ToastTone.success,
    );
  }

  Future<void> _cancel(AdminInvitation invitation) async {
    final confirmed = await showV5Confirmation(
      context: context,
      title: 'Annuler cette invitation ?',
      message: 'Le futur responsable ne pourra plus utiliser cette invitation.',
      cancelLabel: 'Conserver',
      confirmLabel: 'Annuler l’invitation',
      destructive: true,
    );
    if (confirmed != true) return;
    try {
      await widget.repository.cancelInvitation(invitation.id);
      if (!mounted) return;
      V5Toast.show(
        context,
        message: 'Invitation annulée.',
        tone: V5ToastTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      V5Toast.show(
        context,
        message: 'L’invitation n’a pas pu être annulée. Réessayez.',
        tone: V5ToastTone.danger,
      );
    }
  }

  Future<void> _reactivate(AdminInvitation invitation) async {
    var expirationDays = 7;
    final selectedDays = await showV5Dialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => V5Dialog(
          title: 'Réactiver cette invitation ?',
          content: V5SelectField<int>(
            key: const Key('reactivate-expiration'),
            label: 'Nouvelle validité',
            value: expirationDays,
            options: const [
              V5SelectOption(value: 1, label: '24 heures'),
              V5SelectOption(value: 7, label: '7 jours'),
              V5SelectOption(value: 14, label: '14 jours'),
            ],
            onChanged: (value) =>
                setDialogState(() => expirationDays = value ?? 7),
          ),
          actions: [
            V5DialogAction(
              label: 'Retour',
              onPressed: () => Navigator.pop(context),
            ),
            V5DialogAction(
              key: const Key('confirm-reactivate-invitation'),
              label: 'Réactiver',
              onPressed: () => Navigator.pop(context, expirationDays),
              style: V5DialogActionStyle.primary,
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
      V5Toast.show(
        context,
        message: 'Invitation réactivée.',
        tone: V5ToastTone.success,
      );
    } catch (_) {
      if (!mounted) return;
      V5Toast.show(
        context,
        message: 'L’invitation n’a pas pu être réactivée. Réessayez.',
        tone: V5ToastTone.danger,
      );
    }
  }

  Future<void> _delete(AdminInvitation invitation) async {
    final confirmed = await showV5Confirmation(
      context: context,
      title: 'Supprimer définitivement cette invitation ?',
      message: 'Cette opération est irréversible.',
      cancelLabel: 'Conserver',
      confirmLabel: 'Supprimer définitivement',
      destructive: true,
      confirmKey: const Key('confirm-delete-invitation'),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteInvitation(invitation.id);
      if (!mounted) return;
      V5Toast.show(
        context,
        message: 'Invitation supprimée.',
        tone: V5ToastTone.success,
      );
    } catch (_) {
      if (!mounted) return;
      V5Toast.show(
        context,
        message: 'L’invitation n’a pas pu être supprimée. Réessayez.',
        tone: V5ToastTone.danger,
      );
    }
  }

  final Set<String> _provisioningIds = {};

  Future<void> _resend(AdminInvitation invitation) async {
    final confirmed = await showV5Confirmation(
      context: context,
      title: 'Renvoyer l’e-mail d’activation ?',
      message:
          'Cette action prépare ou réutilise le compte responsable, puis '
          'envoie un nouveau lien d’activation.\n\n'
          'Un compte déjà préparé conserve le même identifiant.',
      cancelLabel: 'Retour',
      confirmLabel: 'Renvoyer',
      confirmKey: const Key('confirm-resend-invitation'),
    );
    if (confirmed != true || _provisioningIds.contains(invitation.id)) return;
    setState(() => _provisioningIds.add(invitation.id));
    try {
      await widget.repository.provisionInvitation(invitation.id, resend: true);
      if (!mounted) return;
      V5Toast.show(
        context,
        message: 'E-mail d’activation envoyé.',
        tone: V5ToastTone.success,
      );
    } catch (_) {
      if (!mounted) return;
      V5Toast.show(
        context,
        message: 'L’e-mail d’activation n’a pas pu être envoyé.',
        tone: V5ToastTone.danger,
      );
    } finally {
      if (mounted) setState(() => _provisioningIds.remove(invitation.id));
    }
  }
}

class _ResponsibleHeader extends StatelessWidget {
  const _ResponsibleHeader({required this.onInvite});

  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADMINISTRATION',
                style: TextStyle(
                  color: _ResponsibleVisuals.textMuted,
                  fontSize: 10,
                  letterSpacing: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Responsables',
                style: TextStyle(
                  color: _ResponsibleVisuals.navy,
                  fontSize: 27,
                  height: 1.12,
                  letterSpacing: -0.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Invitations et accès aux centres',
                style: TextStyle(
                  color: _ResponsibleVisuals.textMuted,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 52,
          height: 52,
          child: IconButton.filled(
            key: const Key('invite-admin-button'),
            tooltip: 'Inviter un responsable',
            onPressed: onInvite,
            style: IconButton.styleFrom(
              backgroundColor: _ResponsibleVisuals.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ),
      ],
    );
  }
}

class _ManagementSectionTitle extends StatelessWidget {
  const _ManagementSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: _ResponsibleVisuals.navy,
        fontSize: 19,
        height: 1.15,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return const V5LoadingState(label: 'Chargement…', compact: true);
  }
}

BoxDecoration _responsibleCardDecoration({Color? color}) {
  return BoxDecoration(
    color: color ?? _ResponsibleVisuals.surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _ResponsibleVisuals.border),
    boxShadow: const [
      BoxShadow(color: Color(0x08173052), blurRadius: 12, offset: Offset(0, 3)),
    ],
  );
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
    return Container(
      key: Key('responsible-account-${account.uid}'),
      decoration: _responsibleCardDecoration(
        color: _ResponsibleVisuals.fieldBackground,
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    account.identityLabel,
                    style: const TextStyle(
                      color: _ResponsibleVisuals.navy,
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _AccountStatusBadge(active: access.active),
              ],
            ),
            if (account.email case final email?) ...[
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(
                  color: _ResponsibleVisuals.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: _ResponsibleVisuals.border),
            ),
            _ManagementDetailLine(
              icon: Icons.admin_panel_settings_outlined,
              text: roleLabel,
            ),
            const SizedBox(height: 8),
            _ManagementDetailLine(
              icon: Icons.location_on_outlined,
              text: access.locationIds.isEmpty
                  ? 'Tous les centres'
                  : '${locations.length} centre${locations.length > 1 ? 's' : ''} · '
                        '${locations.join(' · ')}',
            ),
            if (isSelf) ...[
              const SizedBox(height: 10),
              const Text(
                'Votre propre accès doit être géré par un autre coordinateur.',
                style: TextStyle(
                  color: _ResponsibleVisuals.textMuted,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 13),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key('manage-responsible-${account.uid}'),
                onPressed: isSelf ? null : onManage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ResponsibleVisuals.navy,
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: _ResponsibleVisuals.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
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

class _ManagementDetailLine extends StatelessWidget {
  const _ManagementDetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _ResponsibleVisuals.textMuted, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _ResponsibleVisuals.navy,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
        border: Border.all(color: color.withValues(alpha: .22)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFDCD8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Les accès responsables ne sont pas disponibles.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ResponsibleVisuals.navy,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
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
    return Container(
      key: Key('invitation-card-${invitation.id}'),
      decoration: _responsibleCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    invitation.displayName,
                    style: const TextStyle(
                      color: _ResponsibleVisuals.navy,
                      fontSize: 17,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _InvitationStatusBadge(status: effectiveStatus),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              invitation.email,
              style: const TextStyle(
                color: _ResponsibleVisuals.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: _ResponsibleVisuals.border),
            ),
            _ManagementDetailLine(
              icon: Icons.admin_panel_settings_outlined,
              text: invitation.role == AdminInvitationDraft.coordinatorRole
                  ? 'Coordinateur départemental'
                  : 'Responsable de centre',
            ),
            const SizedBox(height: 8),
            _ManagementDetailLine(
              icon: Icons.location_on_outlined,
              text: locationLabels.join(' · '),
            ),
            const SizedBox(height: 10),
            Text(
              'Créée le ${FrenchDateTime.date(invitation.createdAt)} · '
              'Expire le ${FrenchDateTime.date(invitation.expiresAt)}',
              style: const TextStyle(
                color: _ResponsibleVisuals.textMuted,
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (effectiveStatus == AdminInvitationStatus.pending) ...[
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: Key('resend-invitation-${invitation.id}'),
                    onPressed: provisioning ? null : onResend,
                    style: _primaryInvitationButtonStyle(),
                    icon: provisioning
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_outlined, size: 19),
                    label: Text(provisioning ? 'Envoi…' : 'Renvoyer'),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    children: [
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
                ],
              ),
            ] else if (effectiveStatus == AdminInvitationStatus.cancelled) ...[
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: Key('reactivate-invitation-${invitation.id}'),
                    onPressed: onReactivate,
                    style: _primaryInvitationButtonStyle(),
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                    label: const Text('Réactiver'),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    children: [
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
        border: Border.all(color: color.withValues(alpha: .22)),
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

ButtonStyle _primaryInvitationButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: _ResponsibleVisuals.orange,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
  );
}

class _EmptyInvitations extends StatelessWidget {
  const _EmptyInvitations();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _responsibleCardDecoration(),
      child: const Padding(
        padding: EdgeInsets.all(26),
        child: Column(
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              color: _ResponsibleVisuals.textMuted,
              size: 34,
            ),
            SizedBox(height: 12),
            Text(
              'Aucune invitation pour le moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ResponsibleVisuals.navy,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFDCD8)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _ResponsibleVisuals.navy,
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.w700,
        ),
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
      backgroundColor: _ResponsibleVisuals.background,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Modifier l’invitation' : 'Inviter un responsable',
        ),
        backgroundColor: _ResponsibleVisuals.background,
        foregroundColor: _ResponsibleVisuals.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          color: _ResponsibleVisuals.navy,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      bottomNavigationBar: _InvitationSubmitBar(
        submitting: _submitting,
        enabled: _canSubmit,
        onSubmit: _submit,
        editing: _isEditing,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth <= 556
              ? 18.0
              : (constraints.maxWidth - 520) / 2;
          return Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              key: const Key('admin-invitation-form'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                36,
              ),
              children: [
                V5Section(
                  title: 'Invitation',
                  leading: const Icon(Icons.person_add_alt_1_outlined),
                  child: Column(
                    children: [
                      V5TextField(
                        key: const Key('invitation-display-name'),
                        label: 'Nom complet',
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Saisissez le nom du responsable.'
                            : null,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppFormLayout.fieldSpacing),
                      V5TextField(
                        key: const Key('invitation-email'),
                        label: 'E-mail',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        readOnly: _isEditing,
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                        validator: (value) {
                          return _isValidInvitationEmail(value ?? '')
                              ? null
                              : 'Saisissez une adresse e-mail valide.';
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppFormLayout.fieldSpacing),
                      V5SelectField<String>(
                        key: const Key('invitation-role'),
                        label: 'Rôle',
                        value: _role,
                        leading: const Icon(
                          Icons.admin_panel_settings_outlined,
                        ),
                        options: const [
                          V5SelectOption(
                            value: AdminInvitationDraft.siteManagerRole,
                            label: 'Responsable de centre',
                          ),
                          V5SelectOption(
                            value: AdminInvitationDraft.coordinatorRole,
                            label: 'Coordinateur départemental',
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
                        V5SelectField<int>(
                          key: const Key('invitation-expiration'),
                          label: 'Validité',
                          value: _expirationDays,
                          leading: const Icon(Icons.schedule_outlined),
                          options: const [
                            V5SelectOption(value: 1, label: '24 heures'),
                            V5SelectOption(value: 7, label: '7 jours'),
                            V5SelectOption(value: 14, label: '14 jours'),
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
              ],
            ),
          );
        },
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
      V5Toast.show(
        context,
        message: _messageFor(error),
        tone: V5ToastTone.danger,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final invitation = await widget.repository.createInvitation(draft);
      if (mounted) Navigator.pop(context, invitation);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      V5Toast.show(
        context,
        message: _messageFor(error),
        tone: V5ToastTone.danger,
      );
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
      V5Toast.show(
        context,
        message: _messageFor(error),
        tone: V5ToastTone.danger,
      );
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
      V5Toast.show(
        context,
        message: error is FormatException
            ? error.message
            : 'L’invitation n’a pas pu être modifiée. Réessayez.',
        tone: V5ToastTone.danger,
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
      color: _ResponsibleVisuals.surface,
      elevation: 6,
      shadowColor: const Color(0x24173052),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          minimum: AppFormLayout.actionBarPadding,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  key: Key(
                    editing
                        ? 'save-admin-invitation'
                        : 'create-admin-invitation',
                  ),
                  onPressed: enabled ? onSubmit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _ResponsibleVisuals.orange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _ResponsibleVisuals.orangeSoft,
                    disabledForegroundColor: _ResponsibleVisuals.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
        ),
      ),
    );
  }
}
