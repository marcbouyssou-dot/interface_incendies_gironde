import '../platform_admin/platform_actor_view_data.dart';

abstract interface class PlatformActorReadRepository {
  Future<PlatformActorDirectoryViewData> loadDirectory();
}

class NoPlatformActorReadRepository implements PlatformActorReadRepository {
  const NoPlatformActorReadRepository();

  @override
  Future<PlatformActorDirectoryViewData> loadDirectory() async =>
      const PlatformActorDirectoryViewData(
        professionals: [],
        coordinators: [],
        managers: [],
      );
}

class PlatformActorReadException implements Exception {
  const PlatformActorReadException(this.message);

  final String message;

  @override
  String toString() => message;
}
