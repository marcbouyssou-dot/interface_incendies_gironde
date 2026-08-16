import 'package:flutter/material.dart';

import '../models/operation.dart';
import '../models/operational_scope.dart';
import '../models/territory.dart';
import '../services/platform_administration_service.dart';
import '../theme/v5_foundation.dart';
import '../utils/operation_presentation.dart';
import '../widgets/v5_form_system.dart';

class PlatformOperationFormDialog extends StatefulWidget {
  const PlatformOperationFormDialog({
    super.key,
    required this.territories,
    this.operation,
    this.now,
  });

  final List<Territory> territories;
  final Operation? operation;
  final DateTime? now;

  @override
  State<PlatformOperationFormDialog> createState() =>
      _PlatformOperationFormDialogState();
}

class _PlatformOperationFormDialogState
    extends State<PlatformOperationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _context;
  late OperationType? _type;
  late DateTime _startAt;
  late DateTime? _endAt;
  late Set<String> _territoryIds;

  @override
  void initState() {
    super.initState();
    final operation = widget.operation;
    _name = TextEditingController(text: operation?.name);
    _context = TextEditingController(text: operation?.context);
    _type = operation?.type;
    _startAt = operation?.startAt ?? widget.now ?? DateTime.now();
    _endAt = operation?.endAt;
    _territoryIds =
        operation?.scopeRefs
            .where((ref) => ref.kind == OperationalScopeKind.territory)
            .map((ref) => ref.id)
            .toSet() ??
        <String>{};
  }

  @override
  void dispose() {
    _name.dispose();
    _context.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_territoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un territoire.')),
      );
      return;
    }
    if (_endAt != null && !_endAt!.isAfter(_startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fin doit suivre le début.')),
      );
      return;
    }
    final name = _name.text.trim();
    final preservedLocationScopes =
        widget.operation?.scopeRefs.where(
          (ref) => ref.kind == OperationalScopeKind.location,
        ) ??
        const Iterable<OperationalScopeRef>.empty();
    Navigator.of(context).pop(
      OperationAdministrationDraft(
        operationId:
            widget.operation?.id ?? createOperationId(name, now: widget.now),
        name: name,
        type: _type!,
        context: _context.text.trim().isEmpty ? null : _context.text.trim(),
        startAt: _startAt,
        endAt: _endAt,
        scopeRefs: [
          ...preservedLocationScopes,
          ..._territoryIds.map(
            (id) => OperationalScopeRef(
              kind: OperationalScopeKind.territory,
              id: id,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.operation != null;
    final territories = widget.territories
        .where((territory) => territory.active)
        .toList(growable: false);
    return V5Dialog(
      title: editing ? 'Modifier l’opération' : 'Nouvelle opération',
      icon: editing ? Icons.edit_outlined : Icons.add_circle_outline_rounded,
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            V5TextField(
              key: const Key('platform-operation-name'),
              label: 'Nom',
              controller: _name,
              maxLength: 160,
              textCapitalization: TextCapitalization.sentences,
              isRequired: true,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ce champ est obligatoire.'
                  : null,
            ),
            const SizedBox(height: V5Spacing.md),
            V5SelectField<OperationType>(
              key: const Key('platform-operation-type'),
              label: 'Type',
              value: _type,
              options: OperationType.values
                  .map(
                    (type) => V5SelectOption(
                      value: type,
                      label: operationTypeLabel(type),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _type = value),
              validator: (value) =>
                  value == null ? 'Sélectionnez un type.' : null,
            ),
            const SizedBox(height: V5Spacing.md),
            V5TextField(
              key: const Key('platform-operation-context'),
              label: 'Contexte (facultatif)',
              controller: _context,
              maxLength: 500,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: V5Spacing.md),
            V5DateField(
              key: const Key('platform-operation-start'),
              label: 'Début',
              value: _startAt,
              onChanged: (value) {
                if (value != null) setState(() => _startAt = value);
              },
              validator: (value) => value == null ? 'Date requise.' : null,
            ),
            const SizedBox(height: V5Spacing.md),
            SwitchListTile.adaptive(
              key: const Key('platform-operation-has-end'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Date de fin'),
              value: _endAt != null,
              onChanged: (enabled) => setState(() {
                _endAt = enabled ? _startAt.add(const Duration(days: 1)) : null;
              }),
            ),
            if (_endAt != null) ...[
              const SizedBox(height: V5Spacing.xs),
              V5DateField(
                key: const Key('platform-operation-end'),
                label: 'Fin',
                value: _endAt,
                firstDate: _startAt,
                onChanged: (value) => setState(() => _endAt = value),
              ),
            ],
            const SizedBox(height: V5Spacing.lg),
            Text('Périmètres', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: V5Spacing.xs),
            Wrap(
              spacing: V5Spacing.xs,
              runSpacing: V5Spacing.xs,
              children: [
                for (final territory in territories)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: FilterChip(
                      key: Key('operation-scope-${territory.id}'),
                      label: Text(territory.name),
                      selected: _territoryIds.contains(territory.id),
                      onSelected: (selected) => setState(() {
                        selected
                            ? _territoryIds.add(territory.id)
                            : _territoryIds.remove(territory.id);
                      }),
                    ),
                  ),
              ],
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
          key: const Key('submit-platform-operation'),
          label: editing ? 'Enregistrer' : 'Créer l’opération',
          style: V5DialogActionStyle.primary,
          onPressed: _submit,
        ),
      ],
    );
  }
}
