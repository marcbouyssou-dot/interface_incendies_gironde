import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../platform_admin/platform_actor_view_data.dart';
import 'platform_actor_read_repository.dart';

class FirebasePlatformActorReadRepository
    implements PlatformActorReadRepository {
  FirebasePlatformActorReadRepository({
    required FirebaseAuth auth,
    FirebaseFunctions? functions,
  }) : _auth = auth,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(app: auth.app, region: 'europe-west1');

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  @override
  Future<PlatformActorDirectoryViewData> loadDirectory() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const PlatformActorReadException('Session Administrateur requise.');
    }
    try {
      final response = await _functions
          .httpsCallable('listPlatformActorDirectory')
          .call<Object?>();
      return PlatformActorDirectoryViewData.fromMap(_map(response.data));
    } on FirebaseFunctionsException catch (error) {
      throw PlatformActorReadException(switch (error.code) {
        'unauthenticated' => 'Reconnectez-vous pour consulter les acteurs.',
        'permission-denied' => 'Accès Administrateur requis.',
        _ => 'Les acteurs ne sont pas disponibles. Réessayez.',
      });
    } on PlatformActorReadException {
      rethrow;
    } catch (_) {
      throw const PlatformActorReadException(
        'Les acteurs ne sont pas disponibles. Réessayez.',
      );
    }
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) throw const FormatException('Annuaire invalide.');
  return value.map((key, item) => MapEntry(key.toString(), item));
}
