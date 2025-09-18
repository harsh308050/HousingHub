import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:housinghub/Helper/API.dart';

/// Simple coordinate holder
class Coord {
  final double lat;
  final double lng;
  const Coord(this.lat, this.lng);
}

/// Location resolver that maps GPS to valid CSC cities
class LocationResolver {
  static const double _citySelectionRadiusMeters = 50000; // 50 km
  static const String _cacheCollection = 'cityCoordinatesCache';
  static const Duration _geocodeTimeout = Duration(seconds: 3);
  static const int _maxConcurrentGeocodes = 5;

  // In-memory cache: state -> city -> Coord
  static final Map<String, Map<String, Coord>> _coordCache = {};
  // Cache for CSC data to avoid repeated API calls
  static List<Map<String, String>>? _cachedStates;
  static final Map<String, List<String>> _cachedCities = {};
  static bool _cacheLoaded = false;

  /// Normalize city/state names for consistent caching
  static String _normalize(String name) => name.trim().toLowerCase();

  /// Geocode a city to get its coordinates with timeout
  static Future<Coord?> _geocodeCity(String city, String state) async {
    try {
      final query = '$city, $state, India';
      final locations =
          await locationFromAddress(query).timeout(_geocodeTimeout);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        return Coord(loc.latitude, loc.longitude);
      }
    } catch (e) {
      // Ignore geocoding failures for small towns
    }
    return null;
  }

  /// Load cached coordinates from Firestore (incremental loading)
  static Future<void> _loadCacheFromFirestore() async {
    if (_cacheLoaded) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_cacheCollection)
          .orderBy('timestamp', descending: true)
          .limit(200) // Limit to prevent loading too much data
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final state = data['state'] as String;
        final city = data['city'] as String;
        final lat = data['lat'] as double;
        final lng = data['lng'] as double;
        final stateKey = _normalize(state);
        _coordCache.putIfAbsent(stateKey, () => {});
        _coordCache[stateKey]![_normalize(city)] = Coord(lat, lng);
      }
      _cacheLoaded = true;
    } catch (e) {
      // Ignore cache load failures
    }
  }

  /// Save coordinate to Firestore cache
  static Future<void> _saveToCache(
      String state, String city, Coord coord) async {
    try {
      await FirebaseFirestore.instance
          .collection(_cacheCollection)
          .doc('$state-$city')
          .set({
        'state': state,
        'city': city,
        'lat': coord.lat,
        'lng': coord.lng,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ignore save failures
    }
  }

  /// Get CSC states (with caching)
  static Future<List<Map<String, String>>> _getCachedStates() async {
    if (_cachedStates == null) {
      _cachedStates = await Api.getIndianStates();
    }
    return _cachedStates!;
  }

  /// Get CSC cities for state (with caching)
  static Future<List<String>> _getCachedCities(String stateCode) async {
    if (!_cachedCities.containsKey(stateCode)) {
      _cachedCities[stateCode] = await Api.getCitiesForState(stateCode);
    }
    return _cachedCities[stateCode]!;
  }

  /// Geocode only the cities we actually need (lazy geocoding)
  static Future<Map<String, Coord>> _geocodeCitiesBatch(
      List<String> cities, String state) async {
    final results = <String, Coord>{};
    final toGeocode = <String>[];

    // Check cache first
    final stateKey = _normalize(state);
    _coordCache.putIfAbsent(stateKey, () => {});

    for (final city in cities) {
      final ck = _normalize(city);
      final cached = _coordCache[stateKey]![ck];
      if (cached != null) {
        results[city] = cached;
      } else {
        toGeocode.add(city);
      }
    }

    if (toGeocode.isEmpty) return results;

    // Geocode missing cities in parallel (limited concurrency)
    final futures = <Future>[];
    for (int i = 0; i < toGeocode.length; i += _maxConcurrentGeocodes) {
      final batch = toGeocode.skip(i).take(_maxConcurrentGeocodes).toList();
      final batchFutures = batch.map((city) async {
        final coord = await _geocodeCity(city, state);
        if (coord != null) {
          final ck = _normalize(city);
          _coordCache[stateKey]![ck] = coord;
          results[city] = coord;
          // Save to cache asynchronously (don't wait)
          _saveToCache(state, city, coord);
        }
      });
      futures.addAll(batchFutures);
    }

    await Future.wait(futures);
    return results;
  }

  /// Find nearest city from a list of cities (with fallback for failed geocoding)
  static Future<String?> _findNearestCity(
      Position position, List<String> cities, String state) async {
    if (cities.isEmpty) return null;

    // Geocode cities we need
    final coords = await _geocodeCitiesBatch(cities, state);

    String? nearestCity;
    double nearestDist = double.infinity;
    final failedGeocodes = <String>[];

    // First pass: use successfully geocoded cities
    for (final city in cities) {
      final coord = coords[city];
      if (coord == null) {
        failedGeocodes.add(city);
        continue;
      }

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        coord.lat,
        coord.lng,
      );

      if (distance < nearestDist) {
        nearestDist = distance;
        nearestCity = city;
      }
    }

    // If we found a city within radius, return it
    if (nearestCity != null && nearestDist <= _citySelectionRadiusMeters) {
      return nearestCity;
    }

    // Second pass: retry failed geocodes one more time (sequentially to avoid overwhelming)
    for (final city in failedGeocodes) {
      try {
        final coord = await _geocodeCity(city, state).timeout(_geocodeTimeout);
        if (coord != null) {
          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            coord.lat,
            coord.lng,
          );

          // Cache the successful geocode
          final stateKey = _normalize(state);
          final ck = _normalize(city);
          _coordCache[stateKey]![ck] = coord;
          coords[city] = coord;
          _saveToCache(state, city, coord);

          if (distance < nearestDist) {
            nearestDist = distance;
            nearestCity = city;
          }
        }
      } catch (e) {
        // Still failed, skip this city
        continue;
      }
    }

    return nearestCity;
  }

  /// Resolve city from GPS position (optimized version)
  static Future<String?> resolveCity(Position position,
      {String? detectedDistrict}) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Load cache in background (don't wait for it)
      _loadCacheFromFirestore();

      // Parallel: Reverse geocode + get CSC data
      final reverseGeocodeFuture =
          placemarkFromCoordinates(position.latitude, position.longitude)
              .timeout(_geocodeTimeout);

      final statesFuture = _getCachedStates();

      final results = await Future.wait([reverseGeocodeFuture, statesFuture]);
      final placemarks = results[0] as List<Placemark>;
      final states = results[1] as List<Map<String, String>>;

      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final detectedCity = place.locality?.trim();
      final detectedState = place.administrativeArea?.trim();

      if (detectedState == null || detectedCity == null) return null;

      print(
          'LocationResolver: Reverse geocode took ${stopwatch.elapsedMilliseconds}ms');

      // Find matching state
      final stateEntry = states.firstWhere(
        (e) => _normalize(e['name'] ?? '') == _normalize(detectedState),
        orElse: () => const {'name': '', 'code': ''},
      );
      final stateCode = (stateEntry['code'] ?? '').toString();
      if (stateCode.isEmpty) return null;

      // Get cities for state
      final cscCities = await _getCachedCities(stateCode);
      if (cscCities.isEmpty) return null;

      print(
          'LocationResolver: CSC data loaded in ${stopwatch.elapsedMilliseconds}ms');

      // 1. Exact match for detected city (fastest path)
      final exact = cscCities.firstWhere(
        (c) => _normalize(c) == _normalize(detectedCity),
        orElse: () => '',
      );
      if (exact.isNotEmpty) {
        print(
            'LocationResolver: Exact match found in ${stopwatch.elapsedMilliseconds}ms');
        return exact;
      }

      // 2. Check district hint first (if provided)
      if (detectedDistrict != null) {
        final hintCity = _getMainCityForDistrict(detectedDistrict);
        if (hintCity != null && cscCities.contains(hintCity)) {
          // Quick check if hint city coordinates are cached
          final stateKey = _normalize(detectedState);
          final hk = _normalize(hintCity);
          final cachedCoord = _coordCache[stateKey]?[hk];

          if (cachedCoord != null) {
            final hintDist = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              cachedCoord.lat,
              cachedCoord.lng,
            );
            if (hintDist <= _citySelectionRadiusMeters) {
              print(
                  'LocationResolver: District hint ($hintCity) used in ${stopwatch.elapsedMilliseconds}ms, distance: ${hintDist.toStringAsFixed(1)}km');
              return hintCity;
            } else {
              print(
                  'LocationResolver: District hint ($hintCity) too far: ${hintDist.toStringAsFixed(1)}km');
            }
          } else {
            // Try to geocode hint city specifically
            try {
              final hintCoord = await _geocodeCity(hintCity, detectedState)
                  .timeout(_geocodeTimeout);
              if (hintCoord != null) {
                final hintDist = Geolocator.distanceBetween(
                  position.latitude,
                  position.longitude,
                  hintCoord.lat,
                  hintCoord.lng,
                );
                if (hintDist <= _citySelectionRadiusMeters) {
                  // Cache the successful geocode
                  _coordCache[stateKey]![hk] = hintCoord;
                  _saveToCache(detectedState, hintCity, hintCoord);
                  print(
                      'LocationResolver: District hint ($hintCity) geocoded and used in ${stopwatch.elapsedMilliseconds}ms, distance: ${hintDist.toStringAsFixed(1)}km');
                  return hintCity;
                } else {
                  print(
                      'LocationResolver: District hint ($hintCity) geocoded but too far: ${hintDist.toStringAsFixed(1)}km');
                }
              }
            } catch (e) {
              print(
                  'LocationResolver: Failed to geocode district hint ($hintCity): $e');
            }
          }
        }
      }

      // 3. Find nearest city (only geocode what's needed)
      final nearestCity =
          await _findNearestCity(position, cscCities, detectedState);

      if (nearestCity != null) {
        // Verify distance for the nearest city
        final stateKey = _normalize(detectedState);
        final nk = _normalize(nearestCity);
        final coord = _coordCache[stateKey]?[nk];

        if (coord != null) {
          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            coord.lat,
            coord.lng,
          );

          if (distance <= _citySelectionRadiusMeters) {
            print(
                'LocationResolver: Nearest city ($nearestCity) found in ${stopwatch.elapsedMilliseconds}ms, distance: ${distance.toStringAsFixed(1)}km');
            return nearestCity;
          } else {
            print(
                'LocationResolver: Nearest city ($nearestCity) too far: ${distance.toStringAsFixed(1)}km > ${_citySelectionRadiusMeters / 1000}km');
          }
        }
      }

      // 4. Fallback to detected city
      print(
          'LocationResolver: Fallback to detected city in ${stopwatch.elapsedMilliseconds}ms');
      return detectedCity;
    } catch (e) {
      print(
          'LocationResolver: Error after ${stopwatch.elapsedMilliseconds}ms: $e');
      return null;
    } finally {
      stopwatch.stop();
    }
  }

  /// Simple district to city mapping (can be expanded)
  static String? _getMainCityForDistrict(String district) {
    final normalized = _normalize(district);
    if (normalized.contains('anand')) return 'Anand';
    if (normalized.contains('vadodara') || normalized.contains('baroda'))
      return 'Vadodara';
    if (normalized.contains('ahmedabad')) return 'Ahmedabad';
    if (normalized.contains('surat')) return 'Surat';
    if (normalized.contains('rajkot')) return 'Rajkot';
    if (normalized.contains('bharuch')) return 'Bharuch';
    if (normalized.contains('nadiad')) return 'Nadiad';
    if (normalized.contains('navsari')) return 'Navsari';
    if (normalized.contains('valsad')) return 'Valsad';
    // Add more mappings as needed
    return null;
  }
}
