import 'package:flutter/material.dart';

import '../models/diffusion_read_model.dart';
import '../repositories/diffusion_read_repository.dart';
import '../theme/v5_foundation.dart';
import '../utils/diffusion_identifier.dart';
import '../utils/french_date_time.dart';
import 'v5_form_system.dart';

class ResponsibleDiffusionSummary extends StatefulWidget {
  const ResponsibleDiffusionSummary({
    super.key,
    required this.needId,
    required this.repository,
  });

  final String needId;
  final DiffusionReadRepository repository;

  @override
  State<ResponsibleDiffusionSummary> createState() =>
      _ResponsibleDiffusionSummaryState();
}

class _ResponsibleDiffusionSummaryState
    extends State<ResponsibleDiffusionSummary> {
  late Future<DiffusionReadModel?> _diffusion;

  @override
  void initState() {
    super.initState();
    _diffusion = _read();
  }

  @override
  void didUpdateWidget(ResponsibleDiffusionSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.needId != widget.needId ||
        !identical(oldWidget.repository, widget.repository)) {
      _diffusion = _read();
    }
  }

  Future<DiffusionReadModel?> _read() async =>
      widget.repository.readDiffusion(diffusionIdForNeed(widget.needId));

  void _refresh() {
    setState(() => _diffusion = _read());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DiffusionReadModel?>(
      future: _diffusion,
      builder: (context, snapshot) {
        return V5Section(
          title: 'Diffusion',
          subtitle: 'État de diffusion de ce besoin',
          leading: const Icon(Icons.campaign_outlined),
          trailing: IconButton(
            key: const Key('responsible-diffusion-refresh'),
            tooltip: 'Actualiser la diffusion',
            onPressed: snapshot.connectionState == ConnectionState.waiting
                ? null
                : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          child: _content(snapshot),
        );
      },
    );
  }

  Widget _content(AsyncSnapshot<DiffusionReadModel?> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Text(
        'Lecture en cours…',
        key: Key('responsible-diffusion-loading'),
      );
    }
    if (snapshot.hasError) {
      return const Text(
        'État temporairement indisponible.',
        key: Key('responsible-diffusion-unavailable'),
      );
    }
    final diffusion = snapshot.data;
    if (diffusion == null) {
      return const Text(
        'En attente de diffusion.',
        key: Key('responsible-diffusion-absent'),
      );
    }
    if (diffusion.needId != widget.needId) {
      return const Text(
        'État temporairement indisponible.',
        key: Key('responsible-diffusion-unavailable'),
      );
    }
    final createdAt = diffusion.createdAt.toLocal();
    final populationCount = diffusion.populationCount;
    final population = diffusion.snapshotAvailable && populationCount != null
        ? _populationLabel(populationCount)
        : 'Population non encore disponible';
    return Column(
      key: const Key('responsible-diffusion-data'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DiffusionLine(label: 'État', value: diffusion.status),
        const SizedBox(height: V5Spacing.sm),
        _DiffusionLine(
          label: 'Créée le',
          value:
              '${FrenchDateTime.date(createdAt)} · '
              '${FrenchDateTime.time(createdAt)}',
        ),
        const SizedBox(height: V5Spacing.sm),
        _DiffusionLine(label: 'Population ciblée', value: population),
        const SizedBox(height: V5Spacing.sm),
        _DiffusionLine(
          label: 'Snapshot',
          value: diffusion.snapshotAvailable ? 'Disponible' : 'Calcul en cours',
        ),
      ],
    );
  }

  String _populationLabel(int count) =>
      count == 1 ? '1 professionnel' : '$count professionnels';
}

class _DiffusionLine extends StatelessWidget {
  const _DiffusionLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: V5Spacing.xxs),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.v5Colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
