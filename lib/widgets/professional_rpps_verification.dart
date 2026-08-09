import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/need.dart';
import '../services/professional_verification_service.dart';
import '../theme/v5_foundation.dart';
import 'v5_controls.dart';
import 'v5_form_system.dart';

class ProfessionalRppsVerification extends StatefulWidget {
  const ProfessionalRppsVerification({
    super.key,
    required this.profession,
    required this.service,
    this.initialRpps = '',
    this.onIdentityConfirmed,
  });

  final VolunteerProfession profession;
  final ProfessionalVerificationService service;
  final String initialRpps;
  final ValueChanged<ProfessionalVerificationResult>? onIdentityConfirmed;

  static bool supportsProfession(VolunteerProfession profession) =>
      switch (profession) {
        VolunteerProfession.mk ||
        VolunteerProfession.nurse ||
        VolunteerProfession.doctor ||
        VolunteerProfession.pp => true,
        VolunteerProfession.veterinarian ||
        VolunteerProfession.otherHealthProfessional => false,
      };

  @override
  State<ProfessionalRppsVerification> createState() =>
      _ProfessionalRppsVerificationState();
}

class _ProfessionalRppsVerificationState
    extends State<ProfessionalRppsVerification> {
  late final TextEditingController _controller;
  ProfessionalVerificationResult? _result;
  bool _loading = false;
  bool _identityConfirmed = false;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialRpps.trim());
    _controller.addListener(_handleRppsChanged);
  }

  @override
  void didUpdateWidget(covariant ProfessionalRppsVerification oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profession != widget.profession ||
        oldWidget.initialRpps.trim() != widget.initialRpps.trim()) {
      _requestGeneration += 1;
      _controller.removeListener(_handleRppsChanged);
      _controller.text = widget.initialRpps.trim();
      _controller.addListener(_handleRppsChanged);
      _result = null;
      _loading = false;
      _identityConfirmed = false;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleRppsChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleRppsChanged() {
    _requestGeneration += 1;
    if (_result == null && !_identityConfirmed && !_loading) return;
    setState(() {
      _result = null;
      _identityConfirmed = false;
      _loading = false;
    });
  }

  Future<void> _verify() async {
    final rpps = _controller.text.trim();
    final generation = ++_requestGeneration;
    if (!RegExp(r'^\d{11}$').hasMatch(rpps)) {
      setState(() {
        _loading = false;
        _identityConfirmed = false;
        _result = ProfessionalVerificationResult.empty(
          status: ProfessionalVerificationStatus.invalid,
          rpps: rpps,
        );
      });
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
      _identityConfirmed = false;
    });
    ProfessionalVerificationResult result;
    try {
      result = await widget.service.verifyRpps(rpps);
    } catch (_) {
      result = ProfessionalVerificationResult.empty(
        status: ProfessionalVerificationStatus.unavailable,
        rpps: rpps,
      );
    }
    if (!mounted || generation != _requestGeneration) return;
    setState(() {
      _loading = false;
      _result = result;
    });
  }

  void _confirmIdentity(ProfessionalVerificationResult result) {
    setState(() => _identityConfirmed = true);
    widget.onIdentityConfirmed?.call(result);
  }

  bool _isCompatible(ProfessionalVerificationResult result) {
    final expectedCode = switch (widget.profession) {
      VolunteerProfession.doctor => '10',
      VolunteerProfession.nurse => '60',
      VolunteerProfession.mk => '70',
      VolunteerProfession.pp => '80',
      VolunteerProfession.veterinarian ||
      VolunteerProfession.otherHealthProfessional => null,
    };
    return expectedCode != null && result.professionCode == expectedCode;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        V5TextField(
          key: const Key('professional-rpps-field'),
          label: 'Numéro RPPS',
          controller: _controller,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          onFieldSubmitted: (_) {
            if (!_loading) _verify();
          },
        ),
        const SizedBox(height: V5Spacing.sm),
        V5Button(
          key: const Key('verify-professional-rpps'),
          expanded: true,
          loading: _loading,
          onPressed: _loading ? null : _verify,
          label: _loading ? 'Vérification en cours…' : 'Vérifier',
        ),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          child: _buildResult(context),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final result = _result;
    if (result == null) return const SizedBox.shrink();
    return Padding(
      key: ValueKey('${result.status.wireValue}-${result.rpps}'),
      padding: const EdgeInsets.only(top: V5Spacing.sm),
      child: switch (result.status) {
        ProfessionalVerificationStatus.invalid => const _RppsStatusMessage(
          key: Key('professional-rpps-invalid'),
          message: 'Le numéro RPPS doit contenir 11 chiffres',
          tone: _RppsStatusTone.danger,
        ),
        ProfessionalVerificationStatus.notFound => const _RppsStatusMessage(
          key: Key('professional-rpps-not-found'),
          message: 'RPPS non reconnu',
          tone: _RppsStatusTone.warning,
        ),
        ProfessionalVerificationStatus.unavailable => const _RppsStatusMessage(
          key: Key('professional-rpps-unavailable'),
          message: 'Le service de vérification est momentanément indisponible',
          tone: _RppsStatusTone.warning,
        ),
        ProfessionalVerificationStatus.verified =>
          _isCompatible(result)
              ? _VerifiedRppsResult(
                  result: result,
                  confirmed: _identityConfirmed,
                  onConfirm: () => _confirmIdentity(result),
                )
              : const _RppsStatusMessage(
                  key: Key('professional-rpps-incompatible'),
                  message: 'Ce RPPS correspond à une autre profession',
                  tone: _RppsStatusTone.danger,
                ),
      },
    );
  }
}

class _VerifiedRppsResult extends StatelessWidget {
  const _VerifiedRppsResult({
    required this.result,
    required this.confirmed,
    required this.onConfirm,
  });

  final ProfessionalVerificationResult result;
  final bool confirmed;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      key: const Key('professional-rpps-verified'),
      padding: const EdgeInsets.all(V5Spacing.md),
      decoration: BoxDecoration(
        color: colors.successContainer,
        borderRadius: BorderRadius.circular(V5Radius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(V5Radius.pill),
            ),
            child: Text(
              'Profil vérifié',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: V5Spacing.sm),
          Text(
            'Identité retrouvée',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            '${result.firstName} ${result.lastName}'.trim(),
            key: const Key('professional-rpps-identity'),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: V5Spacing.xs),
          Text(
            'Profession officielle',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            result.professionLabel,
            key: const Key('professional-rpps-profession'),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: V5Spacing.sm),
          V5Button(
            key: const Key('confirm-professional-identity'),
            expanded: true,
            tone: V5ButtonTone.secondary,
            onPressed: confirmed ? null : onConfirm,
            label: confirmed ? 'Identité confirmée' : 'Confirmer mon identité',
          ),
          if (confirmed) ...[
            const SizedBox(height: V5Spacing.xs),
            Text(
              'Votre identité est confirmée pour cette session.',
              key: const Key('professional-rpps-confirmed'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.success),
            ),
          ],
        ],
      ),
    );
  }
}

enum _RppsStatusTone { warning, danger }

class _RppsStatusMessage extends StatelessWidget {
  const _RppsStatusMessage({
    super.key,
    required this.message,
    required this.tone,
  });

  final String message;
  final _RppsStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final (foreground, background) = switch (tone) {
      _RppsStatusTone.warning => (colors.warning, colors.warningContainer),
      _RppsStatusTone.danger => (colors.danger, colors.dangerContainer),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(V5Spacing.sm),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(V5Radius.control),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
