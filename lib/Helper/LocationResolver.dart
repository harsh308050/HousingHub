import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Simple coordinate holder
class Coord {
  final double lat;
  final double lng;
  const Coord(this.lat, this.lng);
}

/// Location resolver that maps GPS to valid CSC cities
class LocationResolver {
  // static const double _citySelectionRadiusMeters = 50000; // 50 km
  // static const String _cacheCollection = 'cityCoordinatesCache';
  static const Duration _geocodeTimeout = Duration(seconds: 3);
  // static const int _maxConcurrentGeocodes = 5;

  // // In-memory cache: state -> city -> Coord
  // static final Map<String, Map<String, Coord>> _coordCache = {};
  // // Note: CSC caches removed as we no longer select nearest CSC city

  // /// Normalize city/state names for consistent caching
  // static String _normalize(String name) => name.trim().toLowerCase();

  // /// Geocode a city to get its coordinates with timeout
  // static Future<Coord?> _geocodeCity(String city, String state) async {
  //   try {
  //     final query = '$city, $state, India';
  //     final locations =
  //         await locationFromAddress(query).timeout(_geocodeTimeout);
  //     if (locations.isNotEmpty) {
  //       final loc = locations.first;
  //       return Coord(loc.latitude, loc.longitude);
  //     }
  //   } catch (e) {
  //     // Ignore geocoding failures for small towns
  //   }
  //   return null;
  // }

  // // Firestore cache helpers removed (not needed for current-city-only logic)

  // /// Save coordinate to Firestore cache
  // static Future<void> _saveToCache(
  //     String state, String city, Coord coord) async {
  //   try {
  //     await FirebaseFirestore.instance
  //         .collection(_cacheCollection)
  //         .doc('$state-$city')
  //         .set({
  //       'state': state,
  //       'city': city,
  //       'lat': coord.lat,
  //       'lng': coord.lng,
  //       'timestamp': FieldValue.serverTimestamp(),
  //     });
  //   } catch (e) {
  //     // Ignore save failures
  //   }
  // }

  // CSC state/city caches removed

  // Batch city geocoding removed

  // Nearest city logic removed

  /// Resolve city from GPS position (optimized version)
  static Future<String?> resolveCity(Position position,
      {String? detectedDistrict}) async {
    // Simplified: return the reverse-geocoded current location city only.
    try {
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude)
              .timeout(_geocodeTimeout);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final detectedCity = place.locality?.trim();
      final district = place.subAdministrativeArea?.trim();

      // Prefer locality; fallback to district if locality is unavailable
      if (detectedCity != null && detectedCity.isNotEmpty) return detectedCity;
      if (district != null && district.isNotEmpty) return district;
      return null;
    } catch (e) {
      return null;
    }
  }

  // District-to-city mapping removed
}
