import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:spot_my_car/shared/app_data.dart';

class SpotLocation {
  final String name;
  final double latitude;
  final double longitude;

  const SpotLocation(this.name, this.latitude, this.longitude);
}

class LocationService {
  LocationService._();

  /// Position actuelle + ville la plus proche dans la base des villes du monde.
  /// Renvoie null si la localisation est refusée ou indisponible.
  static Future<SpotLocation?> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 12)),
    );

    await AppData.loadWorldCities();
    Map<String, dynamic>? nearest;
    var best = double.infinity;
    for (final city in AppData.worldCities) {
      final lat = (city['latitude'] as num?)?.toDouble();
      final lon = (city['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      final d = _distanceKm(pos.latitude, pos.longitude, lat, lon);
      if (d < best) {
        best = d;
        nearest = city;
      }
    }

    final name = nearest != null && best < 40 ? nearest['nom'] as String : 'Position actuelle';
    return SpotLocation(name, pos.latitude, pos.longitude);
  }

  static double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * r * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double d) => d * pi / 180;
}
