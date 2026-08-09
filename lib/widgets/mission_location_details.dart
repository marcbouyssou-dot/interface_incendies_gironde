import 'package:flutter/material.dart';

import '../models/need.dart';
import '../theme/app_theme.dart';
import '../utils/external_url_launcher.dart';

abstract final class LocationActionLinks {
  static Uri? directions(ResponsePlace? location) {
    if (location == null) return null;
    final address = location.structuredAddress;
    final latitude = address?.latitude;
    final longitude = address?.longitude;
    final query = latitude != null && longitude != null
        ? '$latitude,$longitude'
        : location.verifiedAddress?.trim();
    if (query == null || query.isEmpty) return null;
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }

  static Uri? phone(ResponsePlace? location) {
    final phone = location?.contactPhone?.trim();
    if (phone == null || phone.isEmpty) return null;
    final dialable = phone.replaceAll(RegExp(r'[^+0-9]'), '');
    return dialable.isEmpty ? null : Uri(scheme: 'tel', path: dialable);
  }
}

class LocationAddressLine extends StatelessWidget {
  const LocationAddressLine({
    super.key,
    required this.location,
    this.maxLines,
    this.selectable = false,
  });

  final ResponsePlace? location;
  final int? maxLines;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final address = location?.verifiedAddress?.trim();
    if (address == null || address.isEmpty) return const SizedBox.shrink();
    const style = TextStyle(
      color: AppColors.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.35,
    );
    final text = Text(
      address,
      key: const Key('location-address-line'),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: style,
    );
    return selectable ? SelectionArea(child: text) : text;
  }
}

class MissionLocationDetails extends StatelessWidget {
  const MissionLocationDetails({
    super.key,
    required this.location,
    this.compact = false,
    this.phoneButtonLabel,
  });

  final ResponsePlace? location;
  final bool compact;
  final String? phoneButtonLabel;

  @override
  Widget build(BuildContext context) {
    final place = location;
    if (place == null) return const SizedBox.shrink();
    final address = place.verifiedAddress;
    final directions = LocationActionLinks.directions(place);
    final phone = LocationActionLinks.phone(place);
    if (address == null &&
        !place.hasContactName &&
        !place.hasContactPhone &&
        directions == null) {
      return const SizedBox.shrink();
    }
    final style = TextStyle(
      color: AppColors.textMuted,
      fontSize: compact ? 12 : 13,
      fontWeight: FontWeight.w600,
      height: 1.35,
    );
    return Padding(
      padding: EdgeInsets.only(top: compact ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (address != null)
            LocationAddressLine(
              key: const Key('mission-location-address'),
              location: place,
              selectable: true,
            ),
          if (place.hasContactName) ...[
            if (address != null) const SizedBox(height: 4),
            Text(
              'Référent : ${place.contactName!.trim()}',
              key: const Key('mission-location-contact'),
              style: style,
            ),
          ],
          if (phone != null)
            TextButton(
              key: const Key('mission-location-phone'),
              onPressed: () => openExternalUrl(phone),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(phoneButtonLabel ?? place.contactPhone!.trim()),
            ),
          if (directions != null)
            TextButton.icon(
              key: const Key('mission-location-directions'),
              onPressed: () => openExternalUrl(directions),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.directions_outlined, size: 18),
              label: const Text('Itinéraire'),
            ),
        ],
      ),
    );
  }
}
