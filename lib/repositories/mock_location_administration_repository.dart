import '../models/admin_location.dart';
import '../models/need.dart';
import 'location_administration_repository.dart';

class MockLocationAdministrationRepository
    implements LocationAdministrationRepository {
  MockLocationAdministrationRepository({
    List<AdminLocation>? initialLocations,
    void Function(List<AdminLocation>)? onChanged,
  }) : _onChanged = onChanged,
       _locations = {
         for (final location in initialLocations ?? const <AdminLocation>[])
           location.id: location,
       };

  factory MockLocationAdministrationRepository.fromResponsePlaces(
    Iterable<ResponsePlace> places, {
    void Function(List<AdminLocation>)? onChanged,
  }) => MockLocationAdministrationRepository(
    onChanged: onChanged,
    initialLocations: places
        .map(
          (place) => AdminLocation(
            id: place.id,
            name: place.name,
            group: place.group,
            type: place.type,
            addressLine1:
                place.structuredAddress?.addressLine1 ?? place.address,
            addressLine2: place.structuredAddress?.addressLine2,
            postalCode: place.structuredAddress?.postalCode,
            city: place.structuredAddress?.city,
            country: place.structuredAddress?.country ?? 'France',
            contactName: place.contactName,
            contactPhone: place.contactPhone,
            latitude: place.structuredAddress?.latitude,
            longitude: place.structuredAddress?.longitude,
            active: place.isEnabled,
            isOperational: place.isOperational,
            canDelete: true,
          ),
        )
        .toList(growable: false),
  );

  final Map<String, AdminLocation> _locations;
  final void Function(List<AdminLocation>)? _onChanged;

  @override
  Future<List<AdminLocation>> listLocations() async {
    final result = _locations.values.toList(growable: false);
    result.sort((left, right) => left.name.compareTo(right.name));
    return result;
  }

  @override
  Future<AdminLocation> createLocation(AdminLocationDraft draft) async {
    if (_locations.containsKey(draft.id)) {
      throw const LocationAdministrationException(
        'Cet identifiant de lieu existe déjà.',
      );
    }
    final location = _fromDraft(draft, active: true);
    _locations[location.id] = location;
    _notify();
    return location;
  }

  @override
  Future<AdminLocation> updateLocation(AdminLocationDraft draft) async {
    final current = _locations[draft.id];
    if (current == null) {
      throw const LocationAdministrationException('Lieu introuvable.');
    }
    final location = _fromDraft(
      draft,
      active: current.active,
      isOperational: current.isOperational,
      canDelete: current.canDelete,
    );
    _locations[location.id] = location;
    _notify();
    return location;
  }

  @override
  Future<AdminLocation> setLocationActive({
    required String locationId,
    required bool active,
  }) async {
    final current = _locations[locationId];
    if (current == null) {
      throw const LocationAdministrationException('Lieu introuvable.');
    }
    final updated = current.copyWith(active: active);
    _locations[locationId] = updated;
    _notify();
    return updated;
  }

  @override
  Future<void> deleteLocation(String locationId) async {
    final current = _locations[locationId];
    if (current == null) {
      throw const LocationAdministrationException('Lieu introuvable.');
    }
    if (!current.canDelete) {
      throw const LocationAdministrationException(
        'Ce lieu est encore utilisé et ne peut pas être supprimé. '
        'Vous pouvez le désactiver.',
      );
    }
    _locations.remove(locationId);
    _notify();
  }

  AdminLocation _fromDraft(
    AdminLocationDraft draft, {
    required bool active,
    bool isOperational = true,
    bool canDelete = true,
  }) => AdminLocation(
    id: draft.id,
    name: draft.name.trim(),
    group: draft.group,
    type: draft.type,
    addressLine1: draft.addressLine1,
    addressLine2: draft.addressLine2,
    postalCode: draft.postalCode,
    city: draft.city,
    country: draft.country,
    contactName: draft.contactName,
    contactPhone: draft.contactPhone,
    latitude: draft.latitude,
    longitude: draft.longitude,
    active: active,
    isOperational: isOperational,
    canDelete: canDelete,
  );

  void _notify() {
    final values = _locations.values.toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
    _onChanged?.call(List.unmodifiable(values));
  }
}
