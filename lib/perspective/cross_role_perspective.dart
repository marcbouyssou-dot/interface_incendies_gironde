import 'package:flutter/widgets.dart';

enum CrossRolePerspective { actual, professional, responsible, coordinator }

class CrossRolePerspectiveController extends ChangeNotifier {
  CrossRolePerspective _perspective = CrossRolePerspective.actual;
  String? _responsibleLocationId;

  CrossRolePerspective get perspective => _perspective;
  String? get responsibleLocationId => _responsibleLocationId;

  void showActualRole() {
    if (_perspective == CrossRolePerspective.actual &&
        _responsibleLocationId == null) {
      return;
    }
    _perspective = CrossRolePerspective.actual;
    _responsibleLocationId = null;
    notifyListeners();
  }

  void showProfessional() {
    if (_perspective == CrossRolePerspective.professional) return;
    _perspective = CrossRolePerspective.professional;
    _responsibleLocationId = null;
    notifyListeners();
  }

  void showResponsible([String? locationId]) {
    if (_perspective == CrossRolePerspective.responsible &&
        _responsibleLocationId == locationId) {
      return;
    }
    _perspective = CrossRolePerspective.responsible;
    _responsibleLocationId = locationId;
    notifyListeners();
  }

  void showCoordinator() {
    if (_perspective == CrossRolePerspective.coordinator) return;
    _perspective = CrossRolePerspective.coordinator;
    _responsibleLocationId = null;
    notifyListeners();
  }
}

class CrossRolePerspectiveScope extends StatefulWidget {
  const CrossRolePerspectiveScope({super.key, required this.child});

  final Widget child;

  static CrossRolePerspectiveController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_CrossRolePerspectiveInherited>();
    assert(scope != null, 'CrossRolePerspectiveScope absent de l’arbre');
    return scope!.notifier!;
  }

  @override
  State<CrossRolePerspectiveScope> createState() =>
      _CrossRolePerspectiveScopeState();
}

class _CrossRolePerspectiveScopeState extends State<CrossRolePerspectiveScope> {
  final _controller = CrossRolePerspectiveController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CrossRolePerspectiveInherited(
    notifier: _controller,
    child: widget.child,
  );
}

class _CrossRolePerspectiveInherited
    extends InheritedNotifier<CrossRolePerspectiveController> {
  const _CrossRolePerspectiveInherited({
    required super.notifier,
    required super.child,
  });
}
