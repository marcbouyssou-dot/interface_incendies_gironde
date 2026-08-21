import 'package:flutter/widgets.dart';

import '../perspective/cross_role_perspective.dart';
import 'location_administration_repository.dart';
import 'read_only_preview_coordination_repository.dart';

class LocationAdministrationRepositoryScope extends InheritedWidget {
  const LocationAdministrationRepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final LocationAdministrationRepository repository;

  static LocationAdministrationRepository of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<
          LocationAdministrationRepositoryScope
        >();
    assert(scope != null, 'LocationAdministrationRepositoryScope absent');
    final repository = scope!.repository;
    return CrossRolePerspectiveScope.maybeOf(context)?.operationContext == null
        ? repository
        : ReadOnlyPreviewLocationAdministrationRepository(repository);
  }

  @override
  bool updateShouldNotify(LocationAdministrationRepositoryScope oldWidget) =>
      !identical(repository, oldWidget.repository);
}
