import 'coordination_repository.dart';
import '../utils/switch_latest.dart';

/// Borne les lectures d'engagements à la chaîne organisationnelle canonique.
///
/// La mission reste l'unique source de vérité : aucun champ organisationnel
/// éventuellement présent sur un engagement n'est lu ni considéré ici.
class OrganizationScopedEngagementReadRepository
    implements MissionEngagementReadRepository {
  const OrganizationScopedEngagementReadRepository({
    required MissionEngagementReadRepository delegate,
    required MissionAccessReadRepository missionRepository,
  }) : _delegate = delegate,
       _missionRepository = missionRepository;

  final MissionEngagementReadRepository _delegate;
  final MissionAccessReadRepository _missionRepository;

  @override
  Stream<List<EngagementInfo>> watchMissionEngagements(String missionId) {
    if (missionId.isEmpty ||
        missionId.trim() != missionId ||
        missionId.contains('/')) {
      return Stream<List<EngagementInfo>>.value(const []);
    }
    return switchLatest(_missionRepository.watchAccessibleMission(missionId), (
      mission,
    ) {
      if (mission == null || mission.id != missionId) {
        return Stream<List<EngagementInfo>>.value(const []);
      }
      return _delegate
          .watchMissionEngagements(missionId)
          .map(
            (engagements) => List<EngagementInfo>.unmodifiable(
              engagements.where(
                (engagement) => engagement.missionId == missionId,
              ),
            ),
          );
    });
  }
}
