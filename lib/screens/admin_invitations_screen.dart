import 'package:flutter/material.dart';

import '../models/admin_invitation.dart';
import '../models/need.dart';
import '../repositories/admin_invitation_repository.dart';
import '../repositories/admin_invitation_repository_scope.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

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
      body: StreamBuilder<ResponsibleAccess?>(
        stream: _access,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
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
            locations: _locations!,
          );
        },
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
    required this.locations,
  });

  final AdminInvitationRepository repository;
  final Stream<List<ResponsePlace>> locations;

  @override
  State<_CoordinatorInvitationsContent> createState() =>
      _CoordinatorInvitationsContentState();
}

class _CoordinatorInvitationsContentState
    extends State<_CoordinatorInvitationsContent> {
  late Stream<List<AdminInvitation>> _invitations;

  @override
  void initState() {
    super.initState();
    _invitations = widget.repository.watchInvitations();
  }

  @override
  void didUpdateWidget(_CoordinatorInvitationsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _invitations = widget.repository.watchInvitations();
    }
  }

  Future<void> _openForm(List<ResponsePlace> locations) async {
    final invitation = await Navigator.of(context).push<AdminInvitation>(
      MaterialPageRoute(
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
          'Invitation créée. L’envoi de l’email sera activé dans une prochaine étape.',
        ),
      ),
    );
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
                  if (snapshot.hasError)
                    const _ErrorState(
                      message: 'Les invitations ne sont pas disponibles.',
                    )
                  else if (!snapshot.hasData)
                    const Center(child: CircularProgressIndicator())
                  else if (snapshot.data!.isEmpty)
                    const _EmptyInvitations()
                  else
                    ...snapshot.data!.map(
                      (invitation) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InvitationCard(
                          invitation: invitation,
                          locationsById: locationsById,
                          onCancel: () => _cancel(invitation),
                          onProvision: () => _provision(invitation),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L’invitation n’a pas pu être annulée. Réessayez.'),
        ),
      );
    }
  }

  final Set<String> _provisioningIds = {};

  Future<void> _provision(AdminInvitation invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Préparer ce compte ?'),
        content: const Text(
          'Le compte Firebase Auth et son rôle seront préparés. '
          'Aucun e-mail ne sera envoyé à cette étape.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            key: const Key('confirm-provision-invitation'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Préparer le compte'),
          ),
        ],
      ),
    );
    if (confirmed != true || _provisioningIds.contains(invitation.id)) return;
    setState(() => _provisioningIds.add(invitation.id));
    try {
      await widget.repository.provisionInvitation(invitation.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Compte préparé. L’envoi automatique de l’invitation sera activé prochainement.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le compte n’a pas pu être préparé. Réessayez.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _provisioningIds.remove(invitation.id));
    }
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.locationsById,
    required this.onCancel,
    required this.onProvision,
    required this.provisioning,
  });

  final AdminInvitation invitation;
  final Map<String, ResponsePlace> locationsById;
  final VoidCallback onCancel;
  final VoidCallback onProvision;
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
              'Créée le ${_dateLabel(invitation.createdAt)} · '
              'Expire le ${_dateLabel(invitation.expiresAt)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (effectiveStatus == AdminInvitationStatus.pending) ...[
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    key: Key('provision-invitation-${invitation.id}'),
                    onPressed: provisioning ? null : onProvision,
                    child: Text(
                      provisioning ? 'Préparation…' : 'Préparer le compte',
                    ),
                  ),
                  TextButton(
                    key: Key('cancel-invitation-${invitation.id}'),
                    onPressed: provisioning ? null : onCancel,
                    child: const Text('Annuler'),
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
      AdminInvitationStatus.accepted => ('Acceptée', AppColors.green),
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
  });

  final AdminInvitationRepository repository;
  final List<ResponsePlace> locations;

  @override
  State<AdminInvitationFormScreen> createState() =>
      _AdminInvitationFormScreenState();
}

class _AdminInvitationFormScreenState extends State<AdminInvitationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<String> _selectedLocations = {};
  String _role = AdminInvitationDraft.siteManagerRole;
  int _expirationDays = 7;
  bool _submitting = false;
  String _search = '';

  List<ResponsePlace> get _availableLocations {
    final query = _search.trim().toLowerCase();
    final values = widget.locations
        .where((location) => location.isOperational)
        .where((location) {
          if (query.isEmpty) return true;
          final city = location.structuredAddress?.city ?? '';
          return '${location.name} ${location.type.label} $city'
              .toLowerCase()
              .contains(query);
        })
        .toList();
    values.sort((left, right) => left.name.compareTo(right.name));
    return values;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inviter un responsable')),
      body: PageContainer(
        child: Form(
          key: _formKey,
          child: ListView(
            key: const Key('admin-invitation-form'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              TextFormField(
                key: const Key('invitation-display-name'),
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nom complet'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Saisissez le nom du responsable.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('invitation-email'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                      ? null
                      : 'Saisissez une adresse e-mail valide.';
                },
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
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
              if (_role == AdminInvitationDraft.siteManagerRole) ...[
                const SizedBox(height: 22),
                const SectionTitle(title: 'Centres autorisés'),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('location-search'),
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Rechercher un centre',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
                const SizedBox(height: 8),
                if (_selectedLocations.isEmpty)
                  const Text(
                    'Sélectionnez au moins un centre.',
                    key: Key('location-selection-hint'),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ..._availableLocations.map((location) {
                  final city = location.structuredAddress?.city?.trim();
                  final details = [
                    location.type.label,
                    if (city != null && city.isNotEmpty) city,
                  ].join(' · ');
                  return CheckboxListTile(
                    key: Key('invitation-location-${location.id}'),
                    value: _selectedLocations.contains(location.id),
                    contentPadding: EdgeInsets.zero,
                    title: Text(location.name),
                    subtitle: Text(details),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (selected) => setState(() {
                      if (selected == true) {
                        _selectedLocations.add(location.id);
                      } else {
                        _selectedLocations.remove(location.id);
                      }
                    }),
                  );
                }),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  key: const Key('create-admin-invitation'),
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(_submitting ? 'Création…' : 'Créer l’invitation'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_role == AdminInvitationDraft.siteManagerRole &&
        _selectedLocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un centre.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final invitation = await widget.repository.createInvitation(
        AdminInvitationDraft(
          email: _emailController.text,
          displayName: _nameController.text,
          role: _role,
          locationIds: _selectedLocations,
          expiresAt: DateTime.now().add(Duration(days: _expirationDays)),
        ),
      );
      if (mounted) Navigator.pop(context, invitation);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
    }
  }

  String _messageFor(Object error) {
    if (error is FormatException) return error.message;
    return 'L’invitation n’a pas pu être créée. Réessayez.';
  }
}

String _dateLabel(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
