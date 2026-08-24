import 'package:flutter/widgets.dart';

import 'diffusion_read_repository.dart';

class DiffusionReadRepositoryScope extends InheritedWidget {
  const DiffusionReadRepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final DiffusionReadRepository? repository;

  static DiffusionReadRepository? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DiffusionReadRepositoryScope>()
      ?.repository;

  @override
  bool updateShouldNotify(DiffusionReadRepositoryScope oldWidget) =>
      !identical(repository, oldWidget.repository);
}
