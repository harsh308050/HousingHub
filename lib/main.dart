import 'package:flutter/material.dart';
import 'package:housinghub/Login/SplashScreen.dart';
import 'package:housinghub/Login/LoginScreen.dart';
import 'package:housinghub/Other/Owner/OwnerHomeScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'Other/Tenant/TenantHomeScreen.dart';
import 'Other/Notification/NotificationScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final mapsImplementation = GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
  }

  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: ThemeData(
        primaryColor: AppConfig.primaryColor,
        colorScheme: ColorScheme.fromSeed(seedColor: AppConfig.primaryColor),
      ),
      home: const Splashscreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        'SplashScreen': (context) => const Splashscreen(),
        'LoginScreen': (context) => LoginScreen(),
        'OwnerHomeScreen': (context) => OwnerHomeScreen(),
        'TenantHomeScreen': (context) => TenantHomeScreen(),
        'NotificationScreen': (context) => NotificationScreen()
      },
    );
  }
}
