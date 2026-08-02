import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/responsible_access.dart';
import '../models/responsible_account.dart';
import '../repositories/responsible_access_administration_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/location_multi_selector.dart';

class ResponsibleAccessFormScreen extends StatefulWidget {
  const ResponsibleAccessFormScreen({
    super.key,
    required this.account,
    required this.currentUid,
    required this.locations,
    required this.repository,
  });

  final ResponsibleAccount account;
  final String currentUid;
  final List<ResponsePlace> locations;
  final ResponsibleAccessAdministrationRepository repository;

  @override
  State<ResponsibleAccessFormScreen> createState() =>
      _ResponsibleAccessFormScreenState();
}

class _ResponsibleAccessFormScreenState
    extends State<ResponsibleAccessFormScreen> {
  late String _roleChoice;
  late bool _active;
  late Set<String> _locationIds;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final access = widget.account.access;
    _roleChoice = access.isCumulative
        ? _cumulative
        : access.roles.contains(ResponsibleRole.coordinator)
        ? ResponsibleRole.coordinator
        : ResponsibleRole.siteManager;
    _active = access.active;
    _locationIds = Set.of(access.locationIds);
  }

  bool get _includesSiteManager =>
      _roleChoice == ResponsibleRole.siteManager || _roleChoice == _cumulative;

  List<String> get _roles => switch (_roleChoice) {
    ResponsibleRole.coordinator => const [ResponsibleRole.coordinator],
    ResponsibleRole.siteManager => const [ResponsibleRole.siteManager],
    _ => const [ResponsibleRole.coordinator, ResponsibleRole.siteManager],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gérer l’accès')),
      bottomNavigationBar: Material(
        color: Colors.white,
        elevation: 10,
        child: SafeArea(
          top: false,
          minimum: AppFormLayout.actionBarPadding,
          child: SizedBox(
            height: AppFormLayout.actionHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Annuler'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('save-responsible-access'),
                    onPressed: _submitting ? null : _save,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _submitting ? 'Enregistrement…' : 'Enregistrer',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: PageContainer(
        child: ListView(
          key: const Key('responsible-access-form'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: AppFormLayout.pagePadding,
          children: [
            Text(
              widget.account.identityLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.account.email case final email?) ...[
              const SizedBox(height: 4),
              Text(email),
            ],
            const SizedBox(height: AppFormLayout.sectionSpacing),
            SwitchListTile.adaptive(
              key: const Key('responsible-active-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Compte actif'),
              subtitle: Text(_active ? 'Accès autorisé' : 'Accès désactivé'),
              value: _active,
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _active = value),
            ),
            const SizedBox(height: AppFormLayout.fieldSpacing),
            DropdownButtonFormField<String>(
              key: const Key('responsible-role-choice'),
              initialValue: _roleChoice,
              decoration: const InputDecoration(labelText: 'Rôle'),
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: ResponsibleRole.siteManager,
                  child: Text('Responsable de centre'),
                ),
                DropdownMenuItem(
                  value: ResponsibleRole.coordinator,
                  child: Text('Coordinateur départemental'),
                ),
                DropdownMenuItem(
                  value: _cumulative,
                  child: Text('Coordinateur et responsable'),
                ),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() {
                      _roleChoice = value!;
                      if (!_includesSiteManager) _locationIds.clear();
                    }),
            ),
            if (_includesSiteManager) ...[
              const SizedBox(height: AppFormLayout.sectionSpacing),
              const FormSectionTitle(title: 'Centres autorisés'),
              const SizedBox(height: AppFormLayout.titleSpacing),
              LocationMultiSelector(
                locations: widget.locations,
                selectedIds: _locationIds,
                enabled: !_submitting,
                listHeight: 300,
                onChanged: (value) => setState(() => _locationIds = value),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_submitting) return;
    if (widget.account.uid == widget.currentUid) {
      _show('Votre propre accès doit être géré par un autre coordinateur.');
      return;
    }
    if (_includesSiteManager && _locationIds.isEmpty) {
      _show('Sélectionnez au moins un centre.');
      return;
    }
    if (!_active && widget.account.access.active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Désactiver ce responsable ?'),
          content: const Text(
            'Le compte et son historique sont conservés, mais ses accès '
            'responsables seront immédiatement suspendus.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Conserver l’accès'),
            ),
            FilledButton(
              key: const Key('confirm-responsible-deactivation'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Désactiver'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _submitting = true);
    try {
      final account = await widget.repository.updateAccess(
        ResponsibleAccessUpdate(
          targetUid: widget.account.uid,
          roles: _roles,
          locationIds: _includesSiteManager ? _locationIds : const {},
          active: _active,
        ),
      );
      if (mounted) Navigator.pop(context, account);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _show(
        error is ResponsibleAccessAdministrationException
            ? error.message
            : 'L’accès responsable n’a pas pu être modifié. Réessayez.',
      );
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

const _cumulative = 'coordinator_site_manager';
