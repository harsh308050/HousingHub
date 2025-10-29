import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized API keys and third-party configuration.
/// Keys are fetched from Firestore (AppControl/ApiKeys) with local fallback values.
/// IMPORTANT: These are public API keys safe for client-side use.
/// Never commit secret keys or private keys to source control.
class ApiKeys {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cached values from Firestore
  static Map<String, dynamic>? _cachedKeys;
  static bool _isInitialized = false;

  // Fallback values (used if Firestore fetch fails or during initialization)
  static const String _fallbackCscApiKey =
      'YTBrQWhHWEVWUk9SSEVSYllzbVNVTUJWRm1oaFBpN2FWeTRKbFpqbQ==';
  static const String _fallbackCloudinaryCloudName = 'debf09qz0';
  static const String _fallbackCloudinaryUploadPreset = 'HousingHub';
  static const String _fallbackRazorpayKey = 'rzp_test_1DP5mmOlF5G5ag';
  static const String _fallbackGoogleMapsApiKey =
      'AIzaSyBOJn7KGIWw4rUtoTaTQDg56hgXFlBI5ME';

  /// Initialize and fetch API keys from Firestore
  /// Should be called once during app startup
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔄 Fetching API keys from Firestore...');

      final docSnapshot = await _firestore
          .collection('AppControl')
          .doc('ApiKeys')
          .get()
          .timeout(
            Duration(seconds: 10),
            onTimeout: () => throw Exception('Firestore fetch timeout'),
          );

      if (docSnapshot.exists) {
        _cachedKeys = docSnapshot.data();
        _isInitialized = true;
        print('✅ API keys loaded from Firestore');
        print('   - CSC API: ${cscApiKey.isNotEmpty ? "✓" : "✗"}');
        print('   - Cloudinary: ${cloudinaryCloudName.isNotEmpty ? "✓" : "✗"}');
        print('   - Razorpay: ${razorpayKey.isNotEmpty ? "✓" : "✗"}');
        print('   - Google Maps: ${googleMapsApiKey.isNotEmpty ? "✓" : "✗"}');
      } else {
        print(
            '⚠️  ApiKeys document not found in Firestore, using fallback values');
        _isInitialized = true;
      }
    } catch (e) {
      print('⚠️  Error fetching API keys from Firestore: $e');
      print('   Using fallback values');
      _isInitialized = true;
    }
  }

  /// Stream to listen for real-time API key updates from Firestore
  static Stream<Map<String, dynamic>?> apiKeysStream() {
    return _firestore
        .collection('AppControl')
        .doc('ApiKeys')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        _cachedKeys = snapshot.data();
        return _cachedKeys;
      }
      return null;
    });
  }

  // Country-State-City API (CSC)
  // Used in: LoginScreen, EditOwnerProfile, Api.getIndianStates/getCitiesForState
  static String get cscApiKey {
    return _cachedKeys?['countryStateCityAPI'] as String? ?? _fallbackCscApiKey;
  }

  // Cloudinary public configuration
  // Used in: Api.uploadImageToCloudinary, Api.uploadVideoToCloudinary, Api.uploadChatAttachment
  static String get cloudinaryCloudName {
    return _cachedKeys?['cloudinaryCloudName'] as String? ??
        _fallbackCloudinaryCloudName;
  }

  static String get cloudinaryUploadPreset {
    return _cachedKeys?['cloudinaryUploadPreset'] as String? ??
        _fallbackCloudinaryUploadPreset;
  }

  // Razorpay public key (client key, NOT the secret)
  // Used in: Tenant/BookingScreen.dart
  static String get razorpayKey {
    return _cachedKeys?['razorpayKey'] as String? ?? _fallbackRazorpayKey;
  }

  // Google Maps API key
  // Used in: AndroidManifest.xml, AppDelegate.swift
  static String get googleMapsApiKey {
    return _cachedKeys?['googleMapsApiKey'] as String? ??
        _fallbackGoogleMapsApiKey;
  }

  /// Validates that all required API keys are set
  static bool validateKeys() {
    final missingKeys = <String>[];

    if (cscApiKey.isEmpty) missingKeys.add('CSC_API_KEY');
    if (cloudinaryCloudName.isEmpty) missingKeys.add('CLOUDINARY_CLOUD_NAME');
    if (cloudinaryUploadPreset.isEmpty) {
      missingKeys.add('CLOUDINARY_UPLOAD_PRESET');
    }
    if (razorpayKey.isEmpty) missingKeys.add('RAZORPAY_KEY');
    if (googleMapsApiKey.isEmpty) missingKeys.add('GOOGLE_MAPS_API_KEY');

    if (missingKeys.isNotEmpty) {
      print('⚠️  Missing API keys: ${missingKeys.join(', ')}');
      print('Please check Firestore AppControl/ApiKeys document.');
      return false;
    }

    print('✅ All API keys validated successfully');
    return true;
  }

  /// Force refresh API keys from Firestore
  static Future<void> refresh() async {
    _isInitialized = false;
    _cachedKeys = null;
    await initialize();
  }
}
