import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/need.dart';
import '../repositories/repository_scope.dart';
import '../widgets/common.dart';

class CreateNeedScreen extends StatefulWidget {
  const CreateNeedScreen({super.key});

  @override
  State<CreateNeedScreen> createState() => _CreateNeedScreenState();
}

class _CreateNeedScreenState extends State<CreateNeedScreen> {
  int _physiotherapists = 4;
  int _podiatrists = 1;
  String? _selectedPlace;
  final Set<String> _equipment = {'Tables', 'Serviettes'};

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: ListView(
        key: const PageStorageKey('create'),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
        children: [
          const PageHeader(
            eyebrow: 'Nouvelle mission',
            title: 'Déclarer un besoin',
            subtitle:
                'Les champs permettront au coordinateur de mobiliser les bons renforts.',
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Lieu d’intervention'),
                  const SizedBox(height: 8),
                  StreamBuilder<List<ResponsePlace>>(
                    stream: RepositoryScope.of(context).watchLocations(),
                    builder: (context, snapshot) {
                      final locations =
                          snapshot.data ?? const <ResponsePlace>[];
                      final selected =
                          locations.any(
                            (location) => location.id == _selectedPlace,
                          )
                          ? _selectedPlace
                          : null;
                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selected,
                        hint: const Text('Choisir un lieu'),
                        items: locations
                            .map(
                              (location) => DropdownMenuItem(
                                value: location.id,
                                child: Text(
                                  location.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedPlace = value),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Expanded(
                        child: _DemoField(
                          label: 'Date',
                          value: '30/07/2026',
                          icon: Icons.calendar_today_rounded,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _DemoField(
                          label: 'Horaires',
                          value: '09:00 — 13:00',
                          icon: Icons.schedule_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('Quotas nécessaires'),
                  const SizedBox(height: 8),
                  _QuotaStepper(
                    label: 'MK nécessaires',
                    value: _physiotherapists,
                    onRemove: _physiotherapists > 0
                        ? () => setState(() => _physiotherapists--)
                        : null,
                    onAdd: () => setState(() => _physiotherapists++),
                  ),
                  const SizedBox(height: 8),
                  _QuotaStepper(
                    label: 'PP nécessaires',
                    value: _podiatrists,
                    onRemove: _podiatrists > 0
                        ? () => setState(() => _podiatrists--)
                        : null,
                    onAdd: () => setState(() => _podiatrists++),
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('Matériel demandé'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        [
                              'Tables',
                              'Serviettes',
                              'Huiles',
                              'Gels froids',
                              'Tapis',
                            ]
                            .map(
                              (item) => FilterChip(
                                label: Text(item),
                                selected: _equipment.contains(item),
                                onSelected: (selected) => setState(
                                  () => selected
                                      ? _equipment.add(item)
                                      : _equipment.remove(item),
                                ),
                                selectedColor: AppColors.orangeSoft,
                                checkmarkColor: AppColors.orange,
                                side: const BorderSide(color: AppColors.border),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('Précisions'),
                  const SizedBox(height: 8),
                  const TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Accès, contact sur place, consignes…',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Besoin enregistré dans le prototype'),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Publier le besoin'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotaStepper extends StatelessWidget {
  const _QuotaStepper({
    required this.label,
    required this.value,
    required this.onRemove,
    required this.onAdd,
  });

  final String label;
  final int value;
  final VoidCallback? onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(onPressed: onAdd, icon: const Icon(Icons.add_rounded)),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: Theme.of(context).textTheme.titleMedium);
}

class _DemoField extends StatelessWidget {
  const _DemoField({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
