import '../models/responsible_account.dart';

abstract interface class ResponsibleAccessAdministrationRepository {
  Future<List<ResponsibleAccount>> listAccounts();

  Future<ResponsibleAccount> updateAccess(ResponsibleAccessUpdate update);
}

class ResponsibleAccessAdministrationException implements Exception {
  const ResponsibleAccessAdministrationException(this.message);

  final String message;

  @override
  String toString() => message;
}
