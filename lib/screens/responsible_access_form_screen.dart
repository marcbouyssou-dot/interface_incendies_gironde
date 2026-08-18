import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/responsible_access.dart';
import '../models/responsible_account.dart';
import '../repositories/responsible_access_administration_repository.dart';
import '../widgets/common.dart';
import '../widgets/location_multi_selector.dart';
import '../widgets/v5_controls.dart';
import '../widgets/v5_form_system.dart';
import '../widgets/v5_secondary_navigation.dart';

abstract final class _AccessFormVisuals {
  static const background = Color(0xFFF6F7F8);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF5F6865);
  static const orange = Color(0xFFB9470A);
}

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
      backgroundColor: _AccessFormVisuals.background,
      appBar: const V5SecondaryNavigationBar(title: 'Gérer l’accès'),
      bottomNavigationBar: Material(
        color: _AccessFormVisuals.surface,
        elevation: 6,
        shadowColor: const Color(0x24173052),
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _AccessFormVisuals.navy,
                          side: const BorderSide(
                            color: _AccessFormVisuals.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
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
                      child: V5Button(
                        key: const Key('save-responsible-access'),
                        expanded: true,
                        backgroundColor: _AccessFormVisuals.orange,
                        foregroundColor: Colors.white,
                        loading: _submitting,
                        onPressed: _submitting ? null : _save,
                        label: _submitting ? 'Enregistrement…' : 'Enregistrer',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth <= 556
              ? 18.0
              : (constraints.maxWidth - 520) / 2;
          return ListView(
            key: const Key('responsible-access-form'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              36,
            ),
            children: [
              V5Section(
                title: 'Accès responsable',
                leading: const Icon(Icons.admin_panel_settings_outlined),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.account.identityLabel,
                      style: const TextStyle(
                        color: _AccessFormVisuals.navy,
                        fontSize: 19,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.account.email case final email?) ...[
                      const SizedBox(height: 5),
                      Text(
                        email,
                        style: const TextStyle(
                          color: _AccessFormVisuals.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 13),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: _accessFormCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: _AccessFormVisuals.fieldBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _AccessFormVisuals.border),
                      ),
                      child: V5SwitchTile(
                        key: const Key('responsible-active-switch'),
                        title: 'Compte actif',
                        subtitle: _active
                            ? 'Accès autorisé'
                            : 'Accès désactivé',
                        value: _active,
                        activeColor: _AccessFormVisuals.orange,
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _active = value),
                      ),
                    ),
                    const SizedBox(height: 14),
                    V5SelectField<String>(
                      key: const Key('responsible-role-choice'),
                      label: 'Rôle',
                      value: _roleChoice,
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      options: const [
                        V5SelectOption(
                          value: ResponsibleRole.siteManager,
                          label: 'Responsable',
                        ),
                        V5SelectOption(
                          value: ResponsibleRole.coordinator,
                          label: 'Coordinateur',
                        ),
                        V5SelectOption(
                          value: _cumulative,
                          label: 'Coordinateur et responsable',
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
                      const Text(
                        'Centres autorisés',
                        style: TextStyle(
                          color: _AccessFormVisuals.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppFormLayout.titleSpacing),
                      LocationMultiSelector(
                        locations: widget.locations,
                        selectedIds: _locationIds,
                        enabled: !_submitting,
                        listHeight: 300,
                        onChanged: (value) =>
                            setState(() => _locationIds = value),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
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
      final confirmed = await showV5Confirmation(
        context: context,
        title: 'Désactiver ce responsable ?',
        message:
            'Le compte et son historique sont conservés, mais ses accès '
            'responsables seront immédiatement suspendus.',
        cancelLabel: 'Conserver l’accès',
        confirmLabel: 'Désactiver',
        destructive: true,
        confirmKey: const Key('confirm-responsible-deactivation'),
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
    V5Toast.show(context, message: message, tone: V5ToastTone.danger);
  }
}

BoxDecoration _accessFormCardDecoration() {
  return BoxDecoration(
    color: _AccessFormVisuals.surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _AccessFormVisuals.border),
    boxShadow: const [
      BoxShadow(color: Color(0x08173052), blurRadius: 12, offset: Offset(0, 3)),
    ],
  );
}

const _cumulative = 'coordinator_site_manager';
