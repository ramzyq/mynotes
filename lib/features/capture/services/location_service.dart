import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

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
  Future<LocationResult?> getCurrentLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
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
      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        placeName:
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
      );
    }
  }
}
