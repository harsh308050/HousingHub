import 'package:flutter/material.dart';

/// Central configuration for app-wide constants (colors, strings, assets)
class AppConfig {
  // App identity
  static const String appName = 'HousingHub';
  static const String logoPath = 'assets/images/Logo.png';

  // Feature toggles
  static const bool useProfessionalReceipt =
      true; // Switch between simple/pro receipts
  static const bool showLogoOnReceipt = true;

  // Company / brand details
  static const String companyName = 'HousingHub';
  static const String companyTagline = 'Your Trusted Property Booking Partner';
  static const String companyAddressLine1 = 'Ahmedabad, Gujarat, India';
  static const String companyAddressLine2 = '';
  static const String companyWebsite = 'https://housinghub.app';
  static const String termsUrl = 'https://housinghub.app/terms';
  static const String privacyUrl = 'https://housinghub.app/privacy';
  static const String receiptVerificationBaseUrl =
      'https://housinghub.app/verify/receipt';

  // Contact
  static const String supportEmail = 'harshparmar.dev@gmail.com';
  static const String developerEmail = 'harshparmar308050@gmail.com';
  static const String supportPhone = '+91-1234567890';
  static const String privacyEffectiveDate = 'June 30, 2025';

  // Colors
  static const Color primaryColor = Color(0xFF007AFF);
  static const Color primaryVariant = Color(0xFF0066FF);
  static const Color lightPrimaryBackground = Color(0xFFE6F0FF);
  static const Color dangerColor = Color(0xFFFF3B30);
  static const Color successColor = Color.fromARGB(255, 57, 159, 53);
  static const Color infoColor = Color(0xFF404893);
  static const Color warningColor = Color.fromARGB(255, 221, 125, 52);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color borderGrey = Color(0xFFE0E0E0);
  static const Color textSecondary = Colors.black54;
  static const Color textPrimary = Colors.black87;
}
