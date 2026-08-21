import 'package:flutter/widgets.dart';

import '../perspective/cross_role_perspective.dart';
import 'coordination_repository.dart';
import 'read_only_preview_coordination_repository.dart';

class RepositoryScope extends InheritedWidget {
  const RepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final CoordinationRepository repository;

  static CoordinationRepository of(BuildContext context) {
    final repository = rawOf(context);
    final preview = CrossRolePerspectiveScope.maybeOf(
      context,
    )?.operationContext;
    return preview == null
        ? repository
        : ReadOnlyPreviewCoordinationRepository(
            repository,
            operationContext: preview,
          );
  }

  static CoordinationRepository rawOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'RepositoryScope absent de l’arbre de widgets');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(RepositoryScope oldWidget) {
    return repository != oldWidget.repository;
  }
}
