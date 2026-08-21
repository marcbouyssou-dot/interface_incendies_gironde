import 'package:flutter/widgets.dart';

import 'organization_read_repository.dart';

/// Point d'injection central des lectures Organisation RC4.
///
/// Ce scope reste indépendant de [RepositoryScope] afin que les wrappers de
/// prévisualisation RC3 ne puissent ni remplacer ni altérer le contexte
/// organisationnel.
class OrganizationRepositoryScope extends InheritedWidget {
  const OrganizationRepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final OrganizationReadRepository repository;

  static OrganizationReadRepository of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<OrganizationRepositoryScope>();
    assert(scope != null, 'OrganizationRepositoryScope absent de l’arbre');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(OrganizationRepositoryScope oldWidget) =>
      !identical(repository, oldWidget.repository);
}
