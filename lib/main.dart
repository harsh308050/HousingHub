import 'package:flutter/material.dart';
import 'package:housinghub/Login/SplashScreen.dart';
import 'package:housinghub/Login/LoginScreen.dart';
import 'package:housinghub/Other/Owner/OwnerHomeScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:housinghub/firebase_options.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/config/ApiKeys.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'Other/Tenant/TenantHomeScreen.dart';
import 'Other/Notification/NotificationScreen.dart';
import 'Other/Owner/OwnerApprovalScreen.dart';
import 'Other/UnderMaintenanceScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final mapsImplementation = GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
  }

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize API keys from Firestore
  await ApiKeys.initialize();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: ThemeData(
        primaryColor: AppConfig.primaryColor,
        colorScheme: ColorScheme.fromSeed(seedColor: AppConfig.primaryColor),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppConfig.primaryColor,
          selectionColor: AppConfig.primaryColor.withOpacity(0.3),
          selectionHandleColor: AppConfig.primaryColor,
        ),
      ),
      navigatorKey: _navKey,
      home: const Splashscreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        'SplashScreen': (context) => const Splashscreen(),
        'LoginScreen': (context) => LoginScreen(),
        'OwnerHomeScreen': (context) => OwnerHomeScreen(),
        'OwnerApprovalScreen': (context) => const OwnerApprovalScreen(),
        'TenantHomeScreen': (context) => TenantHomeScreen(),
        'NotificationScreen': (context) => NotificationScreen(),
        'UnderMaintenanceScreen': (context) => const UnderMaintenanceScreen(),
      },
    );
  }
}
