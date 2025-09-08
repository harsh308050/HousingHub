import 'package:flutter/material.dart';
import 'package:housinghub/Login/SplashScreen.dart';
import 'package:housinghub/Login/LoginScreen.dart';
import 'package:housinghub/Other/Owner/OwnerHomeScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'Other/Tenant/TenantPropertyDetail.dart';
import 'package:housinghub/Helper/API.dart';

import 'Other/Tenant/TenantHomeScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Maps
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
  StreamSubscription<Uri>? _linkSub;
  final AppLinks _appLinks = AppLinks();
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initDeepLink();
  }

  Future<void> _initDeepLink() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) unawaited(_handleUri(initial));
    } catch (_) {}

    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      unawaited(_handleUri(uri));
    }, onError: (err) {});
  }

  Future<void> _handleUri(Uri uri) async {
    if (uri.scheme == 'housinghub' && uri.host == 'property') {
      final owner = uri.queryParameters['owner'];
      final id = uri.queryParameters['id'];
      if (owner != null && id != null) {
        // Attempt to fetch full property data
        Map<String, dynamic>? propertyData;
        try {
          propertyData = await Api.getPropertyById(owner, id, checkUnavailable: true);
          if (propertyData != null) {
            propertyData['ownerEmail'] = owner; // ensure present
          }
        } catch (_) {}

        final dataForScreen = propertyData ?? {'id': id, 'ownerEmail': owner};
        if (_navKey.currentState != null) {
          _navKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => TenantPropertyDetail(
                propertyId: id,
                propertyData: dataForScreen,
              ),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

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
