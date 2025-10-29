import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:housinghub/Helper/API.dart'; // Used for authentication check
import 'package:housinghub/config/AppConfig.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  @override
  void initState() {
    super.initState();
    // We'll let the animations play, then check maintenance and authentication status after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      checkMaintenanceAndNavigate();
    });
  }

  // Check maintenance status first, then authentication
  void checkMaintenanceAndNavigate() async {
    try {
      // First, check if app is under maintenance
      bool isUnderMaintenance = await Api.isAppUnderMaintenance();

      if (isUnderMaintenance) {
        // Navigate to maintenance screen
        Navigator.pushReplacementNamed(context, 'UnderMaintenanceScreen');
        return;
      }

      // If not under maintenance, proceed with normal authentication check
      checkAuthAndNavigate();
    } catch (e) {
      print("Error checking maintenance status: $e");
      // On error, proceed with normal flow
      checkAuthAndNavigate();
    }
  }

  // Check if user is logged in and navigate accordingly
  void checkAuthAndNavigate() async {
    try {
      // Get current user from Firebase
      final currentUser = Api.getCurrentUser();

      if (currentUser != null) {
        // Reload user to ensure we have the latest auth state
        await Api.reloadUser();

        // Check if email is verified
        if (Api.isEmailVerified()) {
          // User is logged in and email is verified, check user type
          String email = currentUser.email ?? '';

          if (email.isNotEmpty) {
            // Set user presence as online for auto-login
            Api.updateUserPresence(email);

            // Prefer tenant experience if both profiles exist
            final tenantDoc = await Api.getUserDetailsByEmail(email);
            final ownerDoc = await Api.getOwnerDetailsByEmail(email);

            if (tenantDoc != null) {
              // Always send tenants to TenantHome first; no owner gating here
              Navigator.pushReplacementNamed(context, 'TenantHomeScreen');
              return;
            }

            if (ownerDoc != null) {
              // Owner flow: gate by approval
              final status = await Api.getOwnerApprovalStatus(email);
              if (status == 'approved') {
                Navigator.pushReplacementNamed(context, 'OwnerHomeScreen');
              } else {
                Navigator.pushReplacementNamed(context, 'OwnerApprovalScreen');
              }
              return;
            }
          }
        }
      }

      // Default case: not logged in, email not verified, or user type unknown
      Navigator.pushReplacementNamed(context, 'LoginScreen');
    } catch (e) {
      print("Error during authentication check: $e");
      // In case of any error, navigate to login screen
      Navigator.pushReplacementNamed(context, 'LoginScreen');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppConfig.primaryVariant,
              AppConfig.lightPrimaryBackground,
              AppConfig.primaryVariant,
            ],
            stops: [0.0, 0.62, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  padding: EdgeInsets.all(10),
                  width: 180,
                  height: 180,
                  child: Image.asset(
                    AppConfig.logoPath,
                    fit: BoxFit.cover,
                  )),
              SizedBox(height: 10),
              AnimatedTextKit(animatedTexts: [
                ColorizeAnimatedText(
                  AppConfig.appName,
                  speed: Duration(milliseconds: 800),
                  colors: [
                    AppConfig.primaryVariant.withAlpha(186),
                    AppConfig.lightPrimaryBackground,
                    AppConfig.primaryVariant.withAlpha(186),
                  ],
                  textStyle: TextStyle(
                    fontSize: 30.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
