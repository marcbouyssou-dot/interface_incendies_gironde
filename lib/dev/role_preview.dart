import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
