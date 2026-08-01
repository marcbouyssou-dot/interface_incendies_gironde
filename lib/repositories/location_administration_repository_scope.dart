import 'package:flutter/widgets.dart';

import 'location_administration_repository.dart';

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
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(LocationAdministrationRepositoryScope oldWidget) =>
      !identical(repository, oldWidget.repository);
}
