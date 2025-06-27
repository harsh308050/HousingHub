import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:housinghub/Helper/API.dart'; // Used for authentication check

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  @override
  void initState() {
    super.initState();
    // We'll let the animations play, then check authentication status after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      checkAuthAndNavigate();
    });
  }

  // Check if user is logged in and navigate accordingly
  void checkAuthAndNavigate() {
    // Get current user from Firebase
    final currentUser = Api.getCurrentUser();

    if (currentUser != null) {
      // User is logged in, navigate to HomeScreen
      Navigator.pushReplacementNamed(context, 'HomeScreen');
    } else {
      // User is not logged in, navigate to LoginScreen
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
              Color(0xFF2563EB),
              Color.fromARGB(255, 217, 236, 255),
              Color(0xFF2563EB),
            ],
            stops: [0.0, 0.62, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  width: 250,
                  height: 250,
                  child: Image.asset(
                    'assets/images/Logo.png',
                    fit: BoxFit.cover,
                  )),
              AnimatedTextKit(animatedTexts: [
                ColorizeAnimatedText(
                  'Housing Hub',
                  speed: Duration(milliseconds: 800),
                  colors: [
                    Color.fromARGB(186, 37, 100, 235),
                    Color.fromARGB(255, 217, 236, 255),
                    Color.fromARGB(186, 37, 100, 235),
                  ],
                  textStyle: TextStyle(
                    fontSize: 40.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]),
              SizedBox(height: 20),
              AnimatedTextKit(animatedTexts: [
                FadeAnimatedText(
                  'Find Your Perfect Stay',
                  duration: Duration(seconds: 3),
                  textStyle: TextStyle(
                    fontSize: 25.0,
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
