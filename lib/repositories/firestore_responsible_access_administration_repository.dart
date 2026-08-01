import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/responsible_account.dart';
import 'responsible_access_administration_repository.dart';

abstract interface class ResponsibleAccessAdministrationDataSource {
  String? get currentUserId;

  Future<Map<String, Object?>> listAccounts();

  Future<Map<String, Object?>> updateAccess(Map<String, Object?> data);
}

class FirebaseResponsibleAccessAdministrationDataSource
    implements ResponsibleAccessAdministrationDataSource {
  FirebaseResponsibleAccessAdministrationDataSource({
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
  Future<Map<String, Object?>> listAccounts() async {
    final response = await functions
        .httpsCallable('listResponsibleAccess')
        .call<Object?>();
    return _map(response.data);
  }

  @override
  Future<Map<String, Object?>> updateAccess(Map<String, Object?> data) async {
    final response = await functions
        .httpsCallable('updateResponsibleAccess')
        .call<Object?>(data);
    return _map(response.data);
  }
}

class FirestoreResponsibleAccessAdministrationRepository
    implements ResponsibleAccessAdministrationRepository {
  FirestoreResponsibleAccessAdministrationRepository({
    required ResponsibleAccessAdministrationDataSource dataSource,
  }) : _dataSource = dataSource;

  factory FirestoreResponsibleAccessAdministrationRepository.withFirebase({
    required FirebaseAuth auth,
    FirebaseFunctions? functions,
  }) => FirestoreResponsibleAccessAdministrationRepository(
    dataSource: FirebaseResponsibleAccessAdministrationDataSource(
      auth: auth,
      functions: functions,
    ),
  );

  final ResponsibleAccessAdministrationDataSource _dataSource;

  @override
  Future<List<ResponsibleAccount>> listAccounts() async {
    _requireSession();
    try {
      final data = await _dataSource.listAccounts();
      final accounts = data['accounts'];
      if (accounts is! List) throw const FormatException();
      final result = accounts
          .map((value) => ResponsibleAccount.fromMap(_map(value)))
          .toList(growable: false);
      result.sort(
        (left, right) => left.identityLabel.compareTo(right.identityLabel),
      );
      return result;
    } on FirebaseFunctionsException catch (error) {
      throw ResponsibleAccessAdministrationException(_messageFor(error.code));
    } on ResponsibleAccessAdministrationException {
      rethrow;
    } catch (_) {
      throw const ResponsibleAccessAdministrationException(
        'Les accès responsables ne sont pas disponibles. Réessayez.',
      );
    }
  }

  @override
  Future<ResponsibleAccount> updateAccess(
    ResponsibleAccessUpdate update,
  ) async {
    _requireSession();
    try {
      final account = (await _dataSource.updateAccess(
        update.toMap(),
      ))['account'];
      final updated = ResponsibleAccount.fromMap(_map(account));
      return updated;
    } on FirebaseFunctionsException catch (error) {
      throw ResponsibleAccessAdministrationException(_messageFor(error.code));
    } on ResponsibleAccessAdministrationException {
      rethrow;
    } catch (_) {
      throw const ResponsibleAccessAdministrationException(
        'L’accès responsable n’a pas pu être modifié. Réessayez.',
      );
    }
  }

  void _requireSession() {
    if (_dataSource.currentUserId == null) {
      throw const ResponsibleAccessAdministrationException(
        'Session coordinateur requise.',
      );
    }
  }

  String _messageFor(String code) => switch (code) {
    'permission-denied' => 'Accès coordinateur actif requis.',
    'not-found' => 'Compte responsable introuvable.',
    'failed-precondition' =>
      'Cette modification d’accès ne peut pas être enregistrée.',
    'invalid-argument' => 'Les accès sélectionnés sont invalides.',
    _ => 'L’accès responsable n’a pas pu être modifié. Réessayez.',
  };
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) throw const FormatException();
  return value.map((key, item) => MapEntry(key.toString(), item));
}
