import 'package:cloud_functions/cloud_functions.dart';

import '../models/need.dart';
import '../models/user_display_identity.dart';
import 'coordination_repository.dart';

abstract interface class UserDisplayIdentityResolver {
  Future<List<EngagementInfo>> listMissionTeam(String missionId);

  Future<Map<String, UserDisplayIdentity>> listPlatformCoordinators();
}

class FirebaseUserDisplayIdentityResolver
    implements UserDisplayIdentityResolver {
  FirebaseUserDisplayIdentityResolver({required FirebaseFunctions functions})
    : _functions = functions;

  final FirebaseFunctions _functions;

  @override
  Future<List<EngagementInfo>> listMissionTeam(String missionId) async {
    final response = await _functions
        .httpsCallable('listMissionTeam')
        .call<Object?>({'missionId': missionId});
    final members = _map(response.data)['members'];
    if (members is! List) throw const FormatException('Équipe invalide.');
    return members
        .map((value) {
          final data = _map(value);
          final resolvedMissionId = _requiredText(data['missionId']);
          final volunteerId = _requiredText(data['uid']);
          final profession = volunteerProfessionFromId(
            _requiredText(data['profession']),
          );
          final status = EngagementStatus.values.byName(
            _requiredText(data['status']),
          );
          return EngagementInfo(
            missionId: resolvedMissionId,
            volunteerId: volunteerId,
            profession: profession,
            status: status,
            identity: UserDisplayIdentity.fromMap(
              data,
              fallbackLabel: 'Professionnel',
              fallbackProfessionLabel: profession.label,
            ),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<Map<String, UserDisplayIdentity>> listPlatformCoordinators() async {
    final response = await _functions
        .httpsCallable('listPlatformCoordinatorIdentities')
        .call<Object?>();
    final coordinators = _map(response.data)['coordinators'];
    if (coordinators is! List) {
      throw const FormatException('Coordinateurs invalides.');
    }
    return {
      for (final value in coordinators)
        if (_coordinatorIdentity(value) case final identity)
          identity.uid: identity,
    };
  }

  UserDisplayIdentity _coordinatorIdentity(Object? value) =>
      UserDisplayIdentity.fromMap(
        _map(value),
        fallbackLabel: 'Coordinateur',
        fallbackProfessionLabel: 'Coordinateur',
      );
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) throw const FormatException('Réponse invalide.');
  return value.map((key, value) => MapEntry(key.toString(), value));
}

String _requiredText(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Valeur requise absente.');
  }
  return value.trim();
}
