import 'package:flutter/widgets.dart';

enum CrossRolePerspective { actual, professional, responsible, coordinator }

@immutable
class CrossRoleOperationContext {
  CrossRoleOperationContext({
    required this.operationId,
    required this.operationName,
    required Set<String> mobilizationIds,
    required Set<String> locationIds,
  }) : mobilizationIds = Set.unmodifiable(mobilizationIds),
       locationIds = Set.unmodifiable(locationIds);

  final String operationId;
  final String operationName;
  final Set<String> mobilizationIds;
  final Set<String> locationIds;
}

class CrossRolePerspectiveController extends ChangeNotifier {
  CrossRolePerspective _perspective = CrossRolePerspective.actual;
  String? _responsibleLocationId;
  CrossRoleOperationContext? _operationContext;

  CrossRolePerspective get perspective => _perspective;
  String? get responsibleLocationId => _responsibleLocationId;
  CrossRoleOperationContext? get operationContext => _operationContext;

  void showActualRole() {
    if (_perspective == CrossRolePerspective.actual &&
        _responsibleLocationId == null) {
      return;
    }
    _perspective = CrossRolePerspective.actual;
    _responsibleLocationId = null;
    _operationContext = null;
    notifyListeners();
  }

  void showProfessional() => _showProfessional();

  void showProfessionalForOperation(CrossRoleOperationContext context) =>
      _showProfessional(operationContext: context);

  void _showProfessional({CrossRoleOperationContext? operationContext}) {
    if (_perspective == CrossRolePerspective.professional &&
        identical(_operationContext, operationContext)) {
      return;
    }
    _perspective = CrossRolePerspective.professional;
    _responsibleLocationId = null;
    _operationContext = operationContext;
    notifyListeners();
  }

  void showResponsible([String? locationId]) =>
      _showResponsible(locationId: locationId);

  void showResponsibleForOperation(
    String locationId,
    CrossRoleOperationContext context,
  ) => _showResponsible(locationId: locationId, operationContext: context);

  void _showResponsible({
    String? locationId,
    CrossRoleOperationContext? operationContext,
  }) {
    if (_perspective == CrossRolePerspective.responsible &&
        _responsibleLocationId == locationId &&
        identical(_operationContext, operationContext)) {
      return;
    }
    _perspective = CrossRolePerspective.responsible;
    _responsibleLocationId = locationId;
    _operationContext = operationContext;
    notifyListeners();
  }

  void showCoordinator() => _showCoordinator();

  void showCoordinatorForOperation(CrossRoleOperationContext context) =>
      _showCoordinator(operationContext: context);

  void _showCoordinator({CrossRoleOperationContext? operationContext}) {
    if (_perspective == CrossRolePerspective.coordinator &&
        identical(_operationContext, operationContext)) {
      return;
    }
    _perspective = CrossRolePerspective.coordinator;
    _responsibleLocationId = null;
    _operationContext = operationContext;
    notifyListeners();
  }
}

class CrossRolePerspectiveScope extends StatefulWidget {
  const CrossRolePerspectiveScope({super.key, required this.child});

  final Widget child;

  static CrossRolePerspectiveController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'CrossRolePerspectiveScope absent de l’arbre');
    return controller!;
  }

  static CrossRolePerspectiveController? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_CrossRolePerspectiveInherited>();
    return scope?.notifier;
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
