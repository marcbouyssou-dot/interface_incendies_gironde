import 'package:flutter/widgets.dart';

import '../perspective/cross_role_perspective.dart';
import 'read_only_preview_coordination_repository.dart';
import 'responsible_access_administration_repository.dart';

class ResponsibleAccessAdministrationRepositoryScope extends InheritedWidget {
  const ResponsibleAccessAdministrationRepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final ResponsibleAccessAdministrationRepository repository;

  static ResponsibleAccessAdministrationRepository of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<
          ResponsibleAccessAdministrationRepositoryScope
        >();
    assert(
      scope != null,
      'ResponsibleAccessAdministrationRepositoryScope absent',
    );
    final repository = scope!.repository;
    return CrossRolePerspectiveScope.maybeOf(context)?.operationContext == null
        ? repository
        : ReadOnlyPreviewResponsibleAccessAdministrationRepository(repository);
  }

  @override
  bool updateShouldNotify(
    ResponsibleAccessAdministrationRepositoryScope oldWidget,
  ) => !identical(repository, oldWidget.repository);
}
