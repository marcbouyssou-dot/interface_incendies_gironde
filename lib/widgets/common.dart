import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/volunteer_profile.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/repository_scope.dart';
import '../screens/engagement_confirmation_screen.dart';
import '../theme/app_theme.dart';

class PageContainer extends StatelessWidget {
  const PageContainer({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: child,
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.orange,
                  fontSize: 11,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 7),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.action});
  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null)
          Text(
            action!,
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class TerritorialGroupFilter extends StatelessWidget {
  const TerritorialGroupFilter({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TerritorialGroup? value;
  final ValueChanged<TerritorialGroup?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value?.name ?? 'all',
      isExpanded: true,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.map_outlined, size: 20),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: [
        const DropdownMenuItem(value: 'all', child: Text('Tous les secteurs')),
        ...TerritorialGroup.values.map(
          (group) => DropdownMenuItem(
            value: group.name,
            child: Text(group.label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (selected) {
        onChanged(
          selected == null || selected == 'all'
              ? null
              : TerritorialGroup.values.byName(selected),
        );
      },
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final NeedStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      NeedStatus.critical => ('Critique', AppColors.red, AppColors.redSoft),
      NeedStatus.toComplete => (
        'À compléter',
        AppColors.orange,
        AppColors.orangeSoft,
      ),
      NeedStatus.complete => ('Complet', AppColors.green, AppColors.greenSoft),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
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

class CoverageBar extends StatelessWidget {
  const CoverageBar({super.key, required this.need});
  final CoordinationNeed need;

  @override
  Widget build(BuildContext context) {
    final color = switch (need.status) {
      NeedStatus.critical => AppColors.red,
      NeedStatus.toComplete => AppColors.orange,
      NeedStatus.complete => AppColors.green,
    };
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuotaLabel(
                profession: 'MK',
                registered: need.registeredPhysiotherapists,
                required: need.requiredPhysiotherapists,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuotaLabel(
                profession: 'PP',
                registered: need.registeredPodiatrists,
                required: need.requiredPodiatrists,
              ),
            ),
            Text(
              '${(need.coverage * 100).round()}%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedCoverageIndicator(
          value: need.coverage,
          color: color,
          minHeight: 8,
        ),
      ],
    );
  }
}

class AnimatedCoverageIndicator extends StatelessWidget {
  const AnimatedCoverageIndicator({
    super.key,
    required this.value,
    this.color = AppColors.orange,
    this.minHeight = 16,
  });

  final double value;
  final Color color;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) => ClipRRect(
        borderRadius: BorderRadius.circular(minHeight),
        child: LinearProgressIndicator(
          minHeight: minHeight,
          value: animatedValue,
          color: color,
          backgroundColor: AppColors.border,
        ),
      ),
    );
  }
}

class _QuotaLabel extends StatelessWidget {
  const _QuotaLabel({
    required this.profession,
    required this.registered,
    required this.required,
  });

  final String profession;
  final int registered;
  final int required;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$profession $registered / $required',
      style: const TextStyle(
        color: AppColors.navy,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class NeedCard extends StatelessWidget {
  const NeedCard({super.key, required this.need, this.compact = false});
  final CoordinationNeed need;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final missingMk =
        (need.requiredPhysiotherapists - need.registeredPhysiotherapists).clamp(
          0,
          need.requiredPhysiotherapists,
        );
    final missingPp = (need.requiredPodiatrists - need.registeredPodiatrists)
        .clamp(0, need.requiredPodiatrists);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.fire_truck_rounded,
                    color: AppColors.orange,
                    size: 28,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      need.place.toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Aujourd’hui',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _operationalTime(need.time),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Récupération pompiers',
                style: TextStyle(
                  color: AppColors.orange,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 22),
              const Divider(height: 1),
              const SizedBox(height: 20),
              const Text(
                'IL MANQUE',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (need.requiredPhysiotherapists > 0)
                    _MissingQuota(value: missingMk, profession: 'MK'),
                  if (need.requiredPhysiotherapists > 0 &&
                      need.requiredPodiatrists > 0)
                    const SizedBox(width: 30),
                  if (need.requiredPodiatrists > 0)
                    _MissingQuota(value: missingPp, profession: 'PP'),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                children: need.equipment
                    .map(
                      (item) => Tooltip(
                        message: item,
                        child: Icon(
                          _equipmentIcon(item),
                          color: AppColors.navySoft,
                          size: 25,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 18),
              _NeedActions(need: need),
            ],
          ),
        ),
      ),
    );
  }

  static String _operationalTime(String time) {
    return time
        .replaceAll(':00', 'h')
        .replaceAll(' — ', ' → ')
        .replaceAll(':', 'h');
  }

  static IconData _equipmentIcon(String item) {
    final normalized = item.toLowerCase();
    if (normalized.contains('table') || normalized.contains('fauteuil')) {
      return Icons.bed_rounded;
    }
    if (normalized.contains('froid') || normalized.contains('glace')) {
      return Icons.ac_unit_rounded;
    }
    if (normalized.contains('huile') ||
        normalized.contains('gel') ||
        normalized.contains('serviette')) {
      return Icons.water_drop_rounded;
    }
    return Icons.medical_services_rounded;
  }
}

class _NeedActions extends StatelessWidget {
  const _NeedActions({required this.need});

  final CoordinationNeed need;

  @override
  Widget build(BuildContext context) {
    final repository = RepositoryScope.of(context);
    return StreamBuilder<EngagementInfo?>(
      stream: repository.watchMyEngagement(need.id),
      builder: (context, engagementSnapshot) {
        if (engagementSnapshot.hasError) {
          return const FilledButton(
            onPressed: null,
            child: Text('Statut indisponible'),
          );
        }
        if (engagementSnapshot.connectionState == ConnectionState.waiting &&
            !engagementSnapshot.hasData) {
          return const FilledButton(
            onPressed: null,
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final engagement = engagementSnapshot.data;
        if (engagement != null) {
          final actionLabel = switch (engagement.status) {
            EngagementStatus.pending => 'CONFIRMER MA PARTICIPATION',
            EngagementStatus.confirmed => 'PARTICIPATION CONFIRMÉE',
            EngagementStatus.standby => 'RENFORT',
            EngagementStatus.cancelled => 'JE M’ENGAGE À NOUVEAU',
          };
          final actionIcon = switch (engagement.status) {
            EngagementStatus.pending => Icons.schedule_rounded,
            EngagementStatus.confirmed => Icons.check_circle_rounded,
            EngagementStatus.standby => Icons.groups_rounded,
            EngagementStatus.cancelled => Icons.cancel_rounded,
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _EngagementStatusBadge(status: engagement.status),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed:
                    engagement.status == EngagementStatus.cancelled ||
                        engagement.status == EngagementStatus.pending
                    ? () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => _RegistrationSheet(need: need),
                      )
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.greenSoft,
                  disabledForegroundColor: AppColors.green,
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: Icon(actionIcon),
                label: Text(actionLabel),
              ),
              if (engagement.status == EngagementStatus.standby) ...[
                const SizedBox(height: 8),
                const Text(
                  'Vous serez contacté si nécessaire.',
                  textAlign: TextAlign.center,
                ),
              ],
              if (engagement.status != EngagementStatus.cancelled) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: Key('cancel-engagement-${need.id}'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _CancelEngagementDialog(
                      need: need,
                      engagement: engagement,
                    ),
                  ),
                  child: const Text('Annuler mon engagement'),
                ),
              ],
            ],
          );
        }
        return FilledButton.icon(
          onPressed: need.status == NeedStatus.complete
              ? null
              : () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => _RegistrationSheet(need: need),
                ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.greenSoft,
            disabledForegroundColor: AppColors.green,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          icon: Icon(
            need.status == NeedStatus.complete
                ? Icons.check_circle_rounded
                : Icons.bolt_rounded,
          ),
          label: Text(
            need.status == NeedStatus.complete
                ? 'MISSION COMPLÈTE'
                : '❤️ JE M’ENGAGE',
          ),
        );
      },
    );
  }
}

class _EngagementStatusBadge extends StatelessWidget {
  const _EngagementStatusBadge({required this.status});

  final EngagementStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (status) {
      EngagementStatus.pending => (AppColors.orange, AppColors.orangeSoft),
      EngagementStatus.confirmed => (AppColors.green, AppColors.greenSoft),
      EngagementStatus.standby => (AppColors.navy, AppColors.background),
      EngagementStatus.cancelled => (AppColors.red, AppColors.redSoft),
    };
    return Container(
      key: Key('engagement-status-${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CancelEngagementDialog extends StatefulWidget {
  const _CancelEngagementDialog({required this.need, required this.engagement});

  final CoordinationNeed need;
  final EngagementInfo engagement;

  @override
  State<_CancelEngagementDialog> createState() =>
      _CancelEngagementDialogState();
}

class _CancelEngagementDialogState extends State<_CancelEngagementDialog> {
  bool _submitting = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await RepositoryScope.of(
        context,
      ).cancelEngagement(widget.need.id).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre désengagement a bien été enregistré.'),
        ),
      );
    } on RepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Le désengagement n’a pas pu être enregistré. Réessayez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Se désengager de cette mission ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.need.place),
          Text(widget.need.date),
          Text(widget.need.time),
          Text(
            widget.engagement.profession == VolunteerProfession.mk
                ? 'Masseur-kinésithérapeute'
                : 'Pédicure-podologue',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('confirm-cancel-engagement'),
          onPressed: _submitting ? null : _confirm,
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirmer mon désengagement'),
        ),
      ],
    );
  }
}

class MissionCancellationButton extends StatelessWidget {
  const MissionCancellationButton({super.key, required this.need});

  final CoordinationNeed need;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: Key('cancel-mission-${need.id}'),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => _CancelMissionDialog(need: need),
      ),
      icon: const Icon(Icons.cancel_outlined),
      label: const Text('Annuler ce besoin'),
    );
  }
}

class _CancelMissionDialog extends StatefulWidget {
  const _CancelMissionDialog({required this.need});
  final CoordinationNeed need;

  @override
  State<_CancelMissionDialog> createState() => _CancelMissionDialogState();
}

class _CancelMissionDialogState extends State<_CancelMissionDialog> {
  final _reason = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await RepositoryScope.of(context)
          .cancelMission(widget.need.id, _reason.text)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Le besoin a été annulé.')));
    } on RepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'L’annulation n’a pas pu être enregistrée. Réessayez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Annuler ce besoin ?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cette mission ne sera plus proposée aux professionnels. '
              'Les engagements existants resteront conservés dans '
              'l’historique.',
            ),
            const SizedBox(height: 14),
            Text(widget.need.place),
            Text('${widget.need.date} • ${widget.need.time}'),
            Text('MK engagés : ${widget.need.registeredPhysiotherapists}'),
            Text('PP engagés : ${widget.need.registeredPodiatrists}'),
            const SizedBox(height: 14),
            TextField(
              key: const Key('cancellation-reason'),
              controller: _reason,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motif de l’annulation',
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        FilledButton(
          key: const Key('confirm-cancel-mission'),
          onPressed: _submitting ? null : _confirm,
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirmer l’annulation'),
        ),
      ],
    );
  }
}

class _MissingQuota extends StatelessWidget {
  const _MissingQuota({required this.value, required this.profession});
  final int value;
  final String profession;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 34,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 7),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            profession,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _RegistrationSheet extends StatefulWidget {
  const _RegistrationSheet({required this.need});
  final CoordinationNeed need;

  @override
  State<_RegistrationSheet> createState() => _RegistrationSheetState();
}

class _RegistrationSheetState extends State<_RegistrationSheet> {
  VolunteerProfession _profession = VolunteerProfession.mk;
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _rppsController = TextEditingController();
  final _cptsIdController = TextEditingController();
  final _cptsController = TextEditingController();
  final _equipmentController = TextEditingController();
  bool _submitting = false;
  bool _loadingProfile = true;
  bool _editingProfile = true;
  String? _profileError;
  VolunteerProfile? _profile;
  bool _profileLoadStarted = false;

  bool get _mkAvailable =>
      widget.need.registeredPhysiotherapists <
      widget.need.requiredPhysiotherapists;

  bool get _ppAvailable =>
      widget.need.registeredPodiatrists < widget.need.requiredPodiatrists;

  @override
  void initState() {
    super.initState();
    if (!_mkAvailable && _ppAvailable) {
      _profession = VolunteerProfession.pp;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileLoadStarted) return;
    _profileLoadStarted = true;
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _rppsController.dispose();
    _cptsIdController.dispose();
    _cptsController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await RepositoryScope.of(context).getVolunteerProfile();
      if (!mounted) return;
      if (profile != null) {
        _firstNameController.text = profile.firstName;
        _lastNameController.text = profile.lastName;
        _phoneController.text = profile.phone;
        _emailController.text = profile.email ?? '';
        _rppsController.text = profile.rpps ?? '';
        _cptsIdController.text = profile.cptsId ?? '';
        _cptsController.text = profile.cptsLabel ?? '';
        _equipmentController.text = profile.equipment.join(', ');
        final profileProfessionAvailable =
            (profile.profession == VolunteerProfession.mk && _mkAvailable) ||
            (profile.profession == VolunteerProfession.pp && _ppAvailable);
        if (profileProfessionAvailable) {
          _profession = profile.profession;
        }
      }
      setState(() {
        _profile = profile;
        _editingProfile =
            profile == null ||
            !profile.profession.isSupportedByCurrentMission ||
            !((profile.profession == VolunteerProfession.mk && _mkAvailable) ||
                (profile.profession == VolunteerProfession.pp && _ppAvailable));
        _loadingProfile = false;
        _profileError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _profileError = 'Votre profil n’a pas pu être chargé.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_profileError != null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_profileError!),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _loadingProfile = true;
                    _profileError = null;
                  });
                  _loadProfile();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'S’inscrire à la mission',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 5),
              Text(
                widget.need.place,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              if (_profile != null && !_editingProfile) ...[
                _ProfileSummary(profile: _profile!),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => setState(() => _editingProfile = true),
                  child: const Text('Modifier mes informations'),
                ),
                const SizedBox(height: 12),
              ],
              if (_editingProfile) ...[
                Text(
                  'Profession',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                RadioGroup<VolunteerProfession>(
                  groupValue: _profession,
                  onChanged: (value) => setState(() => _profession = value!),
                  child: Column(
                    children: [
                      RadioListTile<VolunteerProfession>(
                        contentPadding: EdgeInsets.zero,
                        value: VolunteerProfession.mk,
                        enabled: _mkAvailable,
                        title: const Text('Masseur-kinésithérapeute'),
                        subtitle: _mkAvailable
                            ? null
                            : const Text('Besoin couvert'),
                      ),
                      RadioListTile<VolunteerProfession>(
                        contentPadding: EdgeInsets.zero,
                        value: VolunteerProfession.pp,
                        enabled: _ppAvailable,
                        title: const Text('Pédicure-podologue'),
                        subtitle: _ppAvailable
                            ? null
                            : const Text('Besoin couvert'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Prénom'),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nom'),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                  validator: _phone,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: _email,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _rppsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Numéro RPPS'),
                  validator: _rpps,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cptsIdController,
                  decoration: const InputDecoration(
                    labelText: 'Identifiant CPTS',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cptsController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'CPTS'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _equipmentController,
                  decoration: const InputDecoration(
                    labelText: 'Matériel disponible (facultatif)',
                    hintText: 'Table, huiles, serviettes…',
                  ),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: _submitting || (!_mkAvailable && !_ppAvailable)
                    ? null
                    : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('CONFIRMER MA PARTICIPATION'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Champ requis' : null;
  }

  static String? _phone(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return 'Champ requis';
    if (normalized.replaceAll(RegExp(r'\D'), '').length < 6) {
      return 'Téléphone trop court';
    }
    return null;
  }

  static String? _email(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return 'Champ requis';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      return 'Email invalide';
    }
    return null;
  }

  static String? _rpps(String? value) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), '') ?? '';
    if (!RegExp(r'^\d{11}$').hasMatch(normalized)) {
      return 'Saisissez un numéro RPPS valide à 11 chiffres.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    late final EngagementCreationResult result;
    try {
      result = await RepositoryScope.of(context).createEngagement(
        missionId: widget.need.id,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        rpps: _rppsController.text.replaceAll(RegExp(r'\s+'), ''),
        cptsId: _cptsIdController.text,
        cptsLabel: _cptsController.text,
        profession: _profession,
        equipment: _equipmentController.text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
      );
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    } catch (error, stackTrace) {
      debugPrint('Erreur UI createEngagement : $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L’inscription n’a pas pu être enregistrée. Réessayez.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            EngagementConfirmationScreen(need: widget.need, result: result),
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});

  final VolunteerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.displayName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(profile.profession.label),
          Text(profile.phone),
          if (profile.rpps != null) Text('RPPS ${profile.rpps}'),
          if (profile.cptsLabel != null) Text(profile.cptsLabel!),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
