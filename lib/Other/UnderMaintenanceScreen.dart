import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:housinghub/config/AppConfig.dart';

class UnderMaintenanceScreen extends StatefulWidget {
  const UnderMaintenanceScreen({super.key});

  @override
  State<UnderMaintenanceScreen> createState() => _UnderMaintenanceScreenState();
}

class _UnderMaintenanceScreenState extends State<UnderMaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Lock to portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    _animationController.dispose();
    // Reset orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;

    return Scaffold(
      body: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppConfig.primaryColor,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: width * 0.08, vertical: height * 0.025),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // App Logo
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          AppConfig.logoPath,
                          width: width * 0.3,
                          height: width * 0.3,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    SizedBox(height: height * 0.01),

                    // Main Title
                    Text(
                      'Under Maintenance',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: width * 0.08,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: height * 0.02),

                    // Subtitle
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.05,
                        vertical: height * 0.015,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        'We\'re Working On Something Amazing',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: width * 0.04,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.95),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    SizedBox(height: height * 0.02),

                    // Description Card
                    Container(
                      padding: EdgeInsets.all(width * 0.06),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.build_rounded,
                                color: AppConfig.primaryVariant,
                                size: width * 0.08,
                              ),
                              SizedBox(width: width * 0.03),
                              Text(
                                'Scheduled Maintenance',
                                style: TextStyle(
                                  fontSize: width * 0.05,
                                  fontWeight: FontWeight.w600,
                                  color: AppConfig.primaryVariant,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: height * 0.015),
                          Text(
                            'We\'re currently upgrading our systems to serve you better. Our team is working hard to bring enhanced features and improved performance.',
                            // textAlign: TextAlign.center,
                            textAlign: TextAlign.justify,
                            style: TextStyle(
                              fontSize: width * 0.038,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: height * 0.015),
                          Divider(
                            color: Colors.grey[300],
                            thickness: 1,
                          ),
                          SizedBox(height: height * 0.02),
                          _buildInfoRow(
                            Icons.access_time_rounded,
                            'Expected Duration',
                            'A few hours',
                            width,
                          ),
                          SizedBox(height: height * 0.015),
                          _buildInfoRow(
                            Icons.replay_rounded,
                            'What to do?',
                            'Please check back soon',
                            width,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: height * 0.04),

                    // Support Info
                    Container(
                      padding: EdgeInsets.all(width * 0.05),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.headset_mic_rounded,
                            color: Colors.white,
                            size: width * 0.06,
                          ),
                          SizedBox(width: width * 0.03),
                          Flexible(
                            child: Text(
                              'Need urgent help? Contact support',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: width * 0.037,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: height * 0.02),

                    // Footer
                    Text(
                      'Thank you for your patience! 🙏',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: width * 0.035,
                        color: Colors.white.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String title, String value, double width) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppConfig.primaryVariant.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: width * 0.05,
            color: AppConfig.primaryVariant,
          ),
        ),
        SizedBox(width: width * 0.03),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: width * 0.035,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: width * 0.04,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
