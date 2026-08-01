import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/admin_location.dart';
import 'location_administration_repository.dart';

abstract interface class LocationAdministrationDataSource {
  String? get currentUserId;

  Future<Map<String, Object?>> listLocations();

  Future<Map<String, Object?>> manageLocation(Map<String, Object?> data);
}

class FirebaseLocationAdministrationDataSource
    implements LocationAdministrationDataSource {
  FirebaseLocationAdministrationDataSource({
    required this.auth,
    FirebaseFunctions? functions,
  }) : functions =
           functions ??
           FirebaseFunctions.instanceFor(app: auth.app, region: 'europe-west1');

  final FirebaseAuth auth;
  final FirebaseFunctions functions;

  @override
  String? get currentUserId => auth.currentUser?.uid;

  @override
  Future<Map<String, Object?>> listLocations() async {
    final response = await functions.httpsCallable('listAdminLocations').call();
    return _map(response.data);
  }

  @override
  Future<Map<String, Object?>> manageLocation(Map<String, Object?> data) async {
    final response = await functions
        .httpsCallable('manageLocation')
        .call<Object?>(data);
    return _map(response.data);
  }
}

class FirestoreLocationAdministrationRepository
    implements LocationAdministrationRepository {
  FirestoreLocationAdministrationRepository({
    required LocationAdministrationDataSource dataSource,
  }) : _dataSource = dataSource;

  factory FirestoreLocationAdministrationRepository.withFirebase({
    required FirebaseAuth auth,
    FirebaseFunctions? functions,
  }) => FirestoreLocationAdministrationRepository(
    dataSource: FirebaseLocationAdministrationDataSource(
      auth: auth,
      functions: functions,
    ),
  );

  final LocationAdministrationDataSource _dataSource;

  @override
  Future<List<AdminLocation>> listLocations() async {
    _requireSession();
    try {
      final values = (await _dataSource.listLocations())['locations'];
      if (values is! List) throw const FormatException();
      return values
          .map((value) => AdminLocation.fromMap(_map(value)))
          .toList(growable: false);
    } on FirebaseFunctionsException catch (error) {
      throw LocationAdministrationException(_messageFor(error.code));
    } on LocationAdministrationException {
      rethrow;
    } catch (_) {
      throw const LocationAdministrationException(
        'Les lieux ne sont pas disponibles. Réessayez.',
      );
    }
  }

  @override
  Future<AdminLocation> createLocation(AdminLocationDraft draft) =>
      _write('create', draft.id, draft.toCallableData());

  @override
  Future<AdminLocation> updateLocation(AdminLocationDraft draft) =>
      _write('update', draft.id, draft.toCallableData());

  @override
  Future<AdminLocation> setLocationActive({
    required String locationId,
    required bool active,
  }) => _write('setActive', locationId, {'active': active});

  @override
  Future<void> deleteLocation(String locationId) async {
    await _manage('delete', locationId, null);
  }

  Future<AdminLocation> _write(
    String action,
    String locationId,
    Map<String, Object?> data,
  ) async {
    final response = await _manage(action, locationId, data);
    return AdminLocation.fromMap(_map(response['location']));
  }

  Future<Map<String, Object?>> _manage(
    String action,
    String locationId,
    Map<String, Object?>? data,
  ) async {
    _requireSession();
    try {
      final request = <String, Object?>{
        'action': action,
        'locationId': locationId,
      };
      if (data != null) request['data'] = data;
      return await _dataSource.manageLocation(request);
    } on FirebaseFunctionsException catch (error) {
      throw LocationAdministrationException(_messageFor(error.code));
    } on LocationAdministrationException {
      rethrow;
    } catch (_) {
      throw const LocationAdministrationException(
        'Le lieu n’a pas pu être enregistré. Réessayez.',
      );
    }
  }

  void _requireSession() {
    if (_dataSource.currentUserId == null) {
      throw const LocationAdministrationException(
        'Session coordinateur requise.',
      );
    }
  }

  String _messageFor(String code) => switch (code) {
    'permission-denied' => 'Accès coordinateur actif requis.',
    'already-exists' => 'Cet identifiant de lieu existe déjà.',
    'not-found' => 'Lieu introuvable.',
    'failed-precondition' =>
      'Ce lieu est encore utilisé et ne peut pas être supprimé. '
          'Vous pouvez le désactiver.',
    'invalid-argument' => 'Les informations du lieu sont invalides.',
    _ => 'Le lieu n’a pas pu être enregistré. Réessayez.',
  };
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) throw const FormatException();
  return value.map((key, item) => MapEntry(key.toString(), item));
}
