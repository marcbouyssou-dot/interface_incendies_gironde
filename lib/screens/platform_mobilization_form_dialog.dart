import 'package:flutter/material.dart';

import '../models/mobilization.dart';
import '../models/territory.dart';
import '../services/platform_administration_service.dart';
import '../widgets/v5_form_system.dart';

class PlatformMobilizationFormDialog extends StatefulWidget {
  const PlatformMobilizationFormDialog({
    super.key,
    required this.territories,
    this.mobilization,
    this.now,
  });

  final List<Territory> territories;
  final Mobilization? mobilization;
  final DateTime? now;

  @override
  State<PlatformMobilizationFormDialog> createState() =>
      _PlatformMobilizationFormDialogState();
}

class _PlatformMobilizationFormDialogState
    extends State<PlatformMobilizationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _subtitle;
  late String? _territoryId;
  late MobilizationContextType? _contextType;

  @override
  void initState() {
    super.initState();
    final mobilization = widget.mobilization;
    _name = TextEditingController(text: mobilization?.name);
    _subtitle = TextEditingController(text: mobilization?.subtitle);
    _territoryId = mobilization?.territoryId;
    _contextType = mobilization?.contextType;
  }

  @override
  void dispose() {
    _name.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _name.text.trim();
    final mobilizationId =
        widget.mobilization?.id ?? createMobilizationId(name, now: widget.now);
    Navigator.of(context).pop(
      MobilizationAdministrationDraft(
        mobilizationId: mobilizationId,
        territoryId: _territoryId!,
        name: name,
        subtitle: _subtitle.text.trim(),
        contextType: _contextType!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.mobilization != null;
    final territories = widget.territories
        .where((territory) => territory.active)
        .map(
          (territory) => V5SelectOption<String>(
            value: territory.id,
            label: '${territory.name} · ${territory.code}',
          ),
        )
        .toList(growable: false);
    return V5Dialog(
      title: editing ? 'Modifier la mobilisation' : 'Nouvelle mobilisation',
      icon: editing ? Icons.edit_outlined : Icons.add_circle_outline_rounded,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            V5TextField(
              key: const Key('platform-mobilization-name'),
              label: 'Nom',
              controller: _name,
              maxLength: 160,
              textCapitalization: TextCapitalization.sentences,
              isRequired: true,
              validator: editing ? _required : _validCreationName,
            ),
            const SizedBox(height: 14),
            V5TextField(
              key: const Key('platform-mobilization-subtitle'),
              label: 'Sous-titre',
              controller: _subtitle,
              maxLength: 240,
              textCapitalization: TextCapitalization.sentences,
              isRequired: true,
              validator: _required,
            ),
            const SizedBox(height: 14),
            V5SelectField<String>(
              key: const Key('platform-mobilization-territory'),
              label: 'Territoire',
              value: _territoryId,
              options: territories,
              onChanged: (value) => setState(() => _territoryId = value),
              validator: (value) =>
                  value == null ? 'Sélectionnez un territoire.' : null,
            ),
            const SizedBox(height: 14),
            V5SelectField<MobilizationContextType>(
              key: const Key('platform-mobilization-context'),
              label: 'Contexte',
              value: _contextType,
              options: MobilizationContextType.values
                  .map(
                    (type) => V5SelectOption<MobilizationContextType>(
                      value: type,
                      label: mobilizationContextLabel(type),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _contextType = value),
              validator: (value) =>
                  value == null ? 'Sélectionnez un contexte.' : null,
            ),
          ],
        ),
      ),
      actions: [
        V5DialogAction(
          label: 'Annuler',
          onPressed: () => Navigator.of(context).pop(),
        ),
        V5DialogAction(
          key: const Key('submit-platform-mobilization'),
          label: editing ? 'Enregistrer' : 'Préparer la mobilisation',
          style: V5DialogActionStyle.primary,
          onPressed: _submit,
        ),
      ],
    );
  }
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Ce champ est obligatoire.' : null;

String? _validCreationName(String? value) {
  final requiredError = _required(value);
  if (requiredError != null) return requiredError;
  try {
    createMobilizationId(value!);
    return null;
  } on PlatformAdministrationException catch (error) {
    return error.message;
  }
}

String mobilizationContextLabel(MobilizationContextType type) => switch (type) {
  MobilizationContextType.fire => 'Incendie',
  MobilizationContextType.flood => 'Inondation',
  MobilizationContextType.heatwave => 'Canicule',
  MobilizationContextType.event => 'Événement',
  MobilizationContextType.whitePlan => 'Plan blanc',
  MobilizationContextType.other => 'Autre',
};
