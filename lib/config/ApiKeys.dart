/// Centralized API keys and third-party configuration.
/// NOTE: Do NOT commit real secrets to source control. Use env/secret management for production.
class ApiKeys {
  // Country-State-City API (CSC)
  // Used in: LoginScreen, EditOwnerProfile, Api.getIndianStates/getCitiesForState
  static const String cscApiKey =
      'YTBrQWhHWEVWUk9SSEVSYllzbVNVTUJWRm1oaFBpN2FWeTRKbFpqbQ==';

  // Cloudinary public configuration
  // Used in: Api.uploadImageToCloudinary, Api.uploadVideoToCloudinary, Api.uploadChatAttachment
  static const String cloudinaryCloudName = 'debf09qz0';
  static const String cloudinaryUploadPreset = 'HousingHub';

  // Razorpay public key (client key, NOT the secret)
  // Used in: Tenant/BookingScreen.dart
  // Replace with your live key for production and store secrets securely on backend.
  static const String razorpayKey = 'rzp_test_1DP5mmOlF5G5ag';

  // Google Maps Android API key is currently defined in AndroidManifest.xml.
  // Consider moving it to Gradle manifestPlaceholders for per-env control.
  // For iOS, set GMS API key in AppDelegate or Info.plist.
}
