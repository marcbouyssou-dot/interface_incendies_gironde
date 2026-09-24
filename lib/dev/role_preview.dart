import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum RolePreviewMode { automatic, professional, responsible, coordinator }

extension RolePreviewModeLabel on RolePreviewMode {
  String get label => switch (this) {
    RolePreviewMode.automatic => 'Automatique',
    RolePreviewMode.professional => 'Professionnel',
    RolePreviewMode.responsible => 'Responsable',
    RolePreviewMode.coordinator => 'Coordinateur',
  };
}

class RolePreviewController extends ChangeNotifier {
  RolePreviewMode _mode = RolePreviewMode.automatic;

  RolePreviewMode get mode => _mode;

  void select(RolePreviewMode mode) {
    if (!kDebugMode || mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }
}

class RolePreviewScope extends StatefulWidget {
  const RolePreviewScope({super.key, required this.child});

  final Widget child;

  static RolePreviewController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_RolePreviewInherited>();
    assert(scope != null, 'RolePreviewScope absent de l’arbre');
    return scope!.notifier!;
  }

  @override
  State<RolePreviewScope> createState() => _RolePreviewScopeState();
}

class _RolePreviewScopeState extends State<RolePreviewScope> {
  final _controller = RolePreviewController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _RolePreviewInherited(notifier: _controller, child: widget.child);
}

class _RolePreviewInherited extends InheritedNotifier<RolePreviewController> {
  const _RolePreviewInherited({required super.notifier, required super.child});
}

/// Debug-only overlay: floats a [RolePreviewDebugBanner] on top of [child]
/// so any shell can offer 1-2-tap journey switching without duplicating
/// layout. Renders exactly [child], unchanged, outside kDebugMode.
///
/// This is a pure display affordance around [RolePreviewController] — the
/// single existing source of truth for the previewed journey. It never
/// touches auth, ResponsibleAccess, permissions or repositories.
class RolePreviewDebugOverlay extends StatelessWidget {
  const RolePreviewDebugOverlay({
    super.key,
    required this.journeyLabel,
    required this.child,
  });

  /// The journey this shell instance actually represents (shown while no
  /// preview override is active, i.e. RolePreviewMode.automatic).
  final String journeyLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: RolePreviewDebugBanner(currentJourneyLabel: journeyLabel),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Debug-only pill showing "MODE RECETTE — Parcours : {journey}"; a tap
/// opens a picker over [RolePreviewMode.values] and calls
/// [RolePreviewController.select]. Renders nothing outside kDebugMode.
/// Selecting a mode only ever changes which shell is displayed — see
/// [RolePreviewController.select] and its call site in app_shell.dart,
/// which is the sole place the previewed journey is consumed.
class RolePreviewDebugBanner extends StatelessWidget {
  const RolePreviewDebugBanner({super.key, required this.currentJourneyLabel});

  final String currentJourneyLabel;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final controller = RolePreviewScope.of(context);
    final active = controller.mode != RolePreviewMode.automatic;
    final displayLabel = active ? controller.mode.label : currentJourneyLabel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('role-preview-banner'),
        borderRadius: BorderRadius.circular(999),
        onTap: () => _openPicker(context, controller),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? Colors.deepOrange : Colors.black87,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bug_report_outlined,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'MODE RECETTE · Parcours : $displayLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.expand_more_rounded,
                size: 16,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPicker(BuildContext context, RolePreviewController controller) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MODE RECETTE — affichage uniquement',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
            for (final mode in RolePreviewMode.values)
              ListTile(
                key: Key('role-preview-banner-option-${mode.name}'),
                title: Text(mode.label),
                trailing: mode == controller.mode
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  controller.select(mode);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
