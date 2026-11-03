import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mynotes/features/capture/services/capture_exception.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String placeName;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.placeName,
  });
}

class LocationService {
  /// Throws [CaptureUnavailableException] when location services are off or
  /// permission is refused.
  Future<LocationResult> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const CaptureUnavailableException(
        'Location services are turned off.',
        needsSettings: true,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const CaptureUnavailableException(
        'Location access is blocked for Notely.',
        needsSettings: true,
      );
    }
    if (permission == LocationPermission.denied) {
      throw const CaptureUnavailableException('Location permission was not granted.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final placemark = placemarks.firstOrNull;
      final parts = <String>[
        if (placemark?.name != null && placemark!.name!.isNotEmpty) placemark.name!,
        if (placemark?.street != null && placemark!.street!.isNotEmpty) placemark.street!,
        if (placemark?.locality != null && placemark!.locality!.isNotEmpty) placemark.locality!,
        if (placemark?.administrativeArea != null && placemark!.administrativeArea!.isNotEmpty) placemark.administrativeArea!,
        if (placemark?.country != null && placemark!.country!.isNotEmpty) placemark.country!,
      ];
      final placeName = parts.isNotEmpty ? parts.join(', ') : 'Unknown location';

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        placeName: placeName,
      );
    } catch (_) {
      // Reverse geocoding needs a network; fall back to coordinates.
      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        placeName:
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
      );
    }
  }
}
