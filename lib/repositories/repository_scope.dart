import 'package:flutter/widgets.dart';

import 'coordination_repository.dart';

class RepositoryScope extends InheritedWidget {
  const RepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final CoordinationRepository repository;

  static CoordinationRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'RepositoryScope absent de l’arbre de widgets');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(RepositoryScope oldWidget) {
    return repository != oldWidget.repository;
  }
}
