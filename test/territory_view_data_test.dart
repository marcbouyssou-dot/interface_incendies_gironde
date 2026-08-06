import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/coordinator/territory_view_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';

void main() {
  const locations = [
    ResponsePlace(
      id: 'critical-center',
      name: 'Centre critique',
      type: ResponsePlaceType.civilianReceptionSite,
      group: TerritorialGroup.medoc,
      activeNeeds: 1,
    ),
    ResponsePlace(
      id: 'watch-center',
      name: 'Centre surveillé',
      type: ResponsePlaceType.civilianReceptionSite,
      group: TerritorialGroup.libournais,
      activeNeeds: 1,
    ),
    ResponsePlace(
      id: 'stable-center',
      name: 'Centre stable',
      type: ResponsePlaceType.civilianReceptionSite,
      group: TerritorialGroup.southGironde,
      activeNeeds: 1,
    ),
  ];

  CoordinationNeed mission({
    required String id,
    required String locationId,
    required TerritorialGroup group,
    required int registered,
    DateTime? startAt,
    DateTime? endAt,
  }) => CoordinationNeed(
    id: id,
    locationId: locationId,
    place: locationId,
    group: group,
    date: 'Demain',
    time: '08:00 — 12:00',
    requiredPhysiotherapists: 2,
    registeredPhysiotherapists: registered,
    requiredPodiatrists: 0,
    registeredPodiatrists: 0,
    equipment: const [],
    startAt: startAt,
    endAt: endAt,
  );

  test('territorial view derives only current operational facts', () {
    final now = DateTime(2026, 8, 6, 10);
    final view = CoordinatorTerritoryViewData.from(
      now: now,
      locations: locations,
      missions: [
        mission(
          id: 'critical',
          locationId: 'critical-center',
          group: TerritorialGroup.medoc,
          registered: 0,
          startAt: DateTime(2026, 8, 7, 8),
          endAt: DateTime(2026, 8, 7, 12),
        ),
        mission(
          id: 'watch',
          locationId: 'watch-center',
          group: TerritorialGroup.libournais,
          registered: 1,
          startAt: DateTime(2026, 8, 8, 8),
          endAt: DateTime(2026, 8, 8, 12),
        ),
        mission(
          id: 'stable',
          locationId: 'stable-center',
          group: TerritorialGroup.southGironde,
          registered: 2,
          endAt: DateTime(2026, 8, 7, 12),
        ),
        mission(
          id: 'past',
          locationId: 'critical-center',
          group: TerritorialGroup.medoc,
          registered: 0,
          endAt: DateTime(2026, 8, 5, 12),
        ),
      ],
    );

    expect(view.activeNeeds, 3);
    expect(view.mobilizedProfessionals, 3);
    expect(view.coveredCenters, 1);
    expect(view.sectorsRequiringAttention, hasLength(2));
    expect(
      view.sectors
          .singleWhere((sector) => sector.group == TerritorialGroup.medoc)
          .status,
      TerritoryOperationalStatus.critical,
    );
    expect(
      view.sectors
          .singleWhere((sector) => sector.group == TerritorialGroup.libournais)
          .status,
      TerritoryOperationalStatus.watch,
    );
    expect(
      view.sectors
          .singleWhere(
            (sector) => sector.group == TerritorialGroup.southGironde,
          )
          .status,
      TerritoryOperationalStatus.stable,
    );
  });
}
