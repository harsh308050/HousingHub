import 'package:flutter/material.dart';
import 'package:housinghub/Login/SplashScreen.dart';
import 'package:housinghub/Login/LoginScreen.dart';
import 'package:housinghub/Other/Owner/OwnerHomeScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'Other/Tenant/TenantHomeScreen.dart';

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
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
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
      },
    );
  }
}
