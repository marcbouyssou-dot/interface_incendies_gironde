import '../models/responsible_access.dart';
import '../models/responsible_account.dart';
import 'responsible_access_administration_repository.dart';

class MockResponsibleAccessAdministrationRepository
    implements ResponsibleAccessAdministrationRepository {
  MockResponsibleAccessAdministrationRepository({
    this.currentUid = 'mock-coordinator',
    List<ResponsibleAccount>? initialAccounts,
  }) : _accounts = {
         for (final account in initialAccounts ?? _defaults)
           account.uid: account,
       };

  final String currentUid;
  final Map<String, ResponsibleAccount> _accounts;

  static final _defaults = [
    ResponsibleAccount(
      access: ResponsibleAccess.v2(
        uid: 'mock-coordinator',
        roles: const [ResponsibleRole.coordinator],
        locationIds: const {},
        active: true,
      ),
      displayName: 'Coordinateur MobSanté',
      email: 'coordinateur@example.test',
    ),
    ResponsibleAccount(
      access: ResponsibleAccess.v2(
        uid: 'mock-manager',
        roles: const [ResponsibleRole.siteManager],
        locationIds: const {'bordeauxMetropole-mérignac'},
        active: true,
      ),
      displayName: 'Responsable Mérignac',
      email: 'responsable@example.test',
    ),
  ];

  @override
  Future<List<ResponsibleAccount>> listAccounts() async {
    final result = _accounts.values.toList(growable: false);
    result.sort(
      (left, right) => left.identityLabel.compareTo(right.identityLabel),
    );
    return result;
  }

  @override
  Future<ResponsibleAccount> updateAccess(
    ResponsibleAccessUpdate update,
  ) async {
    if (update.targetUid == currentUid) {
      throw const ResponsibleAccessAdministrationException(
        'Votre propre accès doit être géré par un autre coordinateur.',
      );
    }
    final existing = _accounts[update.targetUid];
    if (existing == null) {
      throw const ResponsibleAccessAdministrationException(
        'Compte responsable introuvable.',
      );
    }
    final updated = existing.copyWith(
      access: ResponsibleAccess.v2(
        uid: update.targetUid,
        roles: update.roles,
        locationIds: update.locationIds,
        active: update.active,
      ),
    );
    _accounts[updated.uid] = updated;
    return updated;
  }
}
