import 'package:flutter/material.dart';
import 'package:housinghub/Login/SplashScreen.dart';
import 'package:housinghub/Login/LoginScreen.dart';
import 'package:housinghub/Other/Owner/OwnerHomeScreen.dart';
import 'package:firebase_core/firebase_core.dart';

import 'Other/Tenant/TenantHomeScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
