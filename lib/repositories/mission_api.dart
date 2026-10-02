import 'package:cloud_functions/cloud_functions.dart';

/// Transport for server-validated mission creation.
abstract interface class MissionApi {
  Future<String> createMission(Map<String, Object?> request);
}

class FirebaseMissionApi implements MissionApi {
  FirebaseMissionApi(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<String> createMission(Map<String, Object?> request) async {
    final response = await _functions
        .httpsCallable('createMission')
        .call<Map<dynamic, dynamic>>(request);
    final missionId = response.data['missionId'];
    if (missionId is! String || missionId.isEmpty) {
      throw const FormatException('Invalid createMission response');
    }
    return missionId;
  }
}
