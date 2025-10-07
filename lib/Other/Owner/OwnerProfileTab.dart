import 'package:flutter/material.dart';
import 'package:housinghub/Helper/Models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/Other/Owner/EditOwnerProfile.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../Login/LoginScreen.dart';

class OwnerProfileTab extends StatefulWidget {
  final User? user;
  final Map<String, dynamic>? ownerData;

  const OwnerProfileTab({super.key, this.user, this.ownerData});

  @override
  State<OwnerProfileTab> createState() => _OwnerProfileTabState();
}

class _OwnerProfileTabState extends State<OwnerProfileTab> {
  Map<String, dynamic>? _ownerData;
  bool _isLoading = false;
  bool _uploadingPhoto = false;
  bool _checkingAccountStatus = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _ownerData = widget.ownerData;

    // If no owner data provided, fetch it
    if (_ownerData == null &&
        widget.user != null &&
        widget.user!.email != null) {
      _fetchOwnerData();
    }
  }

  // Fetch owner data from Firestore
  Future<void> _fetchOwnerData() async {
    if (widget.user != null && widget.user!.email != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        Map<String, dynamic>? userData =
            await Api.getOwnerDetailsByEmail(widget.user!.email!);
        setState(() {
          _ownerData = userData;
          _isLoading = false;
        });
      } catch (e) {
        print("Error fetching owner data: $e");
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Upload profile picture
  Future<void> _pickAndUploadProfilePhoto() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _uploadingPhoto = true);

      final file = File(picked.path);
      final url = await Api.uploadImageToCloudinary(file, 'owner_profiles');

      // Update owner profile with new picture
      if (widget.user?.email != null) {
        await Api.updateOwnerProfilePicture(widget.user!.email!, url);

        // Refresh owner data to show new picture
        await _fetchOwnerData();

        if (mounted) {
          Models.showSuccessSnackBar(
              context, 'Profile photo updated successfully!');
        }
      }
    } catch (e) {
      if (mounted) {
        Models.showErrorSnackBar(context, 'Failed to update photo: $e');
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '??';
    final nameParts = name.trim().split(' ');
    String initials = '';
    for (var part in nameParts) {
      if (part.isNotEmpty && initials.length < 2) {
        initials += part[0].toUpperCase();
      }
    }
    return initials.isEmpty ? '??' : initials;
  }

  // Account switching method - switch to tenant account
  Future<void> _switchToTenantAccount() async {
    if (widget.user?.email == null) return;

    setState(() => _checkingAccountStatus = true);

    try {
      final switchingInfo =
          await Api.getAccountSwitchingInfo(widget.user!.email!);

      if (mounted) {
        setState(() => _checkingAccountStatus = false);

        if (switchingInfo['hasTenantAccount']) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            'TenantHomeScreen',
            (route) => false,
          );
        } else {
          // Navigate to login screen with tenant signup tab
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
              settings: RouteSettings(
                arguments: {'preOpenTab': 'tenantSignup'},
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingAccountStatus = false);
        Models.showErrorSnackBar(
          context,
          'Failed to check tenant account: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    String initials = _getInitials(_ownerData?['fullName']);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size(width, height * 0.05),
        child: AppBar(
          title: Container(
            padding: EdgeInsets.all(height * 0.01),
            alignment: Alignment.center,
            width: width,
            decoration: BoxDecoration(
              color: Colors.white,
            ),
            child: Text(
              'Profile',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      body: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                      color: AppConfig.primaryVariant))
              : Container(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                  height: height,
                  width: width,
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: height * 0.03,
                    children: [
                      Column(
                        spacing: 5,
                        children: [
                          GestureDetector(
                            onTap: _uploadingPhoto
                                ? null
                                : _pickAndUploadProfilePhoto,
                            child: Stack(
                              children: [
                                Container(
                                  height: width * 0.3,
                                  width: width * 0.3,
                                  margin: EdgeInsets.only(top: height * 0.03),
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:
                                        _ownerData!['profilePicture'] != null &&
                                                _ownerData!['profilePicture']
                                                    .toString()
                                                    .isNotEmpty
                                            ? null
                                            : AppConfig.primaryColor,
                                    borderRadius: BorderRadius.circular(width),
                                    image: _ownerData!['profilePicture'] !=
                                                null &&
                                            _ownerData!['profilePicture']
                                                .toString()
                                                .isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(
                                                _ownerData!['profilePicture']),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child:
                                      _ownerData!['profilePicture'] == null ||
                                              _ownerData!['profilePicture']
                                                  .toString()
                                                  .isEmpty
                                          ? Text(
                                              initials,
                                              style: TextStyle(
                                                fontSize: height * 0.05,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            )
                                          : null,
                                ),
                                // Upload indicator
                                if (_uploadingPhoto)
                                  Positioned.fill(
                                    child: Container(
                                      margin:
                                          EdgeInsets.only(top: height * 0.03),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius:
                                            BorderRadius.circular(width),
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Camera icon overlay
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppConfig.primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 3),
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            spacing: 5,
                            children: [
                              Text(
                                _ownerData!['fullName'] ?? 'user last',
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _ownerData!['email'] ?? 'user@example.com',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: AppConfig.textSecondary),
                              ),
                              Text(
                                _ownerData!['mobileNumber'] ?? '+91 XXXXXXXXXX',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: AppConfig.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        spacing: height * 0.02,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              // Navigate to edit profile screen
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditOwnerProfile(
                                    ownerData: _ownerData,
                                  ),
                                ),
                              );

                              // Refresh profile data if updated
                              if (result == true &&
                                  widget.user != null &&
                                  widget.user!.email != null) {
                                _fetchOwnerData();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              fixedSize: Size(width, height * 0.07),
                              backgroundColor: AppConfig.primaryColor,
                              padding: EdgeInsets.symmetric(
                                  vertical: height * 0.015),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Edit Profile',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _checkingAccountStatus
                                ? null
                                : _switchToTenantAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              fixedSize: Size(width, height * 0.07),
                              padding: EdgeInsets.symmetric(
                                  vertical: height * 0.015),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: AppConfig.primaryColor,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              shadowColor: Colors.black.withOpacity(0),
                            ),
                            child: _checkingAccountStatus
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppConfig.primaryColor,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Checking...',
                                        style: TextStyle(
                                            fontSize: 18,
                                            color: AppConfig.primaryColor),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Switch to Tenant Mode',
                                        style: TextStyle(
                                            fontSize: 18,
                                            color: AppConfig.primaryColor),
                                      ),
                                    ],
                                  ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              try {
                                await Api.signOut();
                                if (context.mounted) {
                                  Navigator.pushNamedAndRemoveUntil(
                                      context, 'LoginScreen', (route) => false);
                                }
                              } catch (e) {
                                print("Error signing out: $e");
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              fixedSize: Size(width, height * 0.07),
                              padding: EdgeInsets.symmetric(
                                  vertical: height * 0.015),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: AppConfig.dangerColor,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Logout',
                              style: TextStyle(
                                  fontSize: 18, color: AppConfig.dangerColor),
                            ),
                          )
                        ],
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: height * 0.01,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                      context, 'NotificationScreen');
                                },
                                style: ElevatedButton.styleFrom(
                                  overlayColor: Colors.transparent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  fixedSize: Size(width, height * 0.07),
                                  side: BorderSide(
                                    color: Colors.white,
                                    width: 1.0,
                                  ),
                                  backgroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      vertical: height * 0.02,
                                      horizontal: width * 0.05),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      spacing: 11,
                                      children: [
                                        Icon(
                                          Icons.notifications_active,
                                          color: Colors.black54,
                                          size: 24,
                                        ),
                                        Text(
                                          'Notifications',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Privacy(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  overlayColor: Colors.transparent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  fixedSize: Size(width, height * 0.07),
                                  side: BorderSide(
                                    color: Colors.white,
                                    width: 1.0,
                                  ),
                                  backgroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      vertical: height * 0.02,
                                      horizontal: width * 0.05),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      spacing: 11,
                                      children: [
                                        Icon(
                                          Icons.privacy_tip,
                                          color: Colors.black54,
                                          size: 24,
                                        ),
                                        Text(
                                          'Privacy',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Help(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  overlayColor: Colors.transparent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  fixedSize: Size(width, height * 0.07),
                                  side: BorderSide(
                                    color: Colors.white,
                                    width: 1.0,
                                  ),
                                  backgroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      vertical: height * 0.02,
                                      horizontal: width * 0.05),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      spacing: 11,
                                      children: [
                                        Icon(
                                          Icons.help,
                                          color: Colors.black54,
                                          size: 24,
                                        ),
                                        Text(
                                          'Help & Support',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => About(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  overlayColor: Colors.transparent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  fixedSize: Size(width, height * 0.07),
                                  side: BorderSide(
                                    color: Colors.white,
                                    width: 1.0,
                                  ),
                                  backgroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      vertical: height * 0.02,
                                      horizontal: width * 0.05),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      spacing: 11,
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          color: Colors.black54,
                                          size: 24,
                                        ),
                                        Text(
                                          'About',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
    );
  }
}

class Privacy extends StatelessWidget {
  const Privacy({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
        title: Text('Privacy Policy', style: TextStyle(color: Colors.black87)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Container(
          color: Colors.white,
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(0xFFE6F0FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF0066FF),
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Effective date
                  Container(
                    margin: EdgeInsets.only(top: 20, bottom: 16),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Color(0xFFE6F0FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Effective Date: ${AppConfig.privacyEffectiveDate}',
                      style: TextStyle(
                        color: AppConfig.primaryVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Introduction
                  Container(
                    margin: EdgeInsets.only(bottom: 24),
                    child: Text(
                      'At HousingHub, your privacy is our top priority. We are committed to protecting your personal information and ensuring a safe, secure user experience.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),

                  // Section 1: Information We Collect
                  _buildSectionTitle('1. Information We Collect'),
                  _buildParagraph(
                      'We collect the following data when you register or use the app:'),
                  _buildBulletPoint('Name, email, phone number'),
                  _buildBulletPoint('Location (for property recommendations)'),
                  _buildBulletPoint(
                      'Property listing information (for owners)'),
                  _buildBulletPoint('User preferences (for tenants)'),
                  _buildBulletPoint('Chat messages (stored securely)'),
                  SizedBox(height: 24),

                  // Section 2: How We Use Your Information
                  _buildSectionTitle('2. How We Use Your Information'),
                  _buildBulletPoint(
                      'To connect tenants with suitable accommodations'),
                  _buildBulletPoint(
                      'To allow owners to manage and display their listings'),
                  _buildBulletPoint(
                      'To improve the user experience and provide relevant suggestions'),
                  _buildBulletPoint(
                      'For communication between tenants and owners'),
                  SizedBox(height: 24),

                  // Section 3: Data Sharing
                  _buildSectionTitle('3. Data Sharing'),
                  _buildParagraph(
                      'We do not sell or share your data with third-party advertisers. Data may be shared only:'),
                  _buildBulletPoint(
                      'With property owners or tenants during interactions'),
                  _buildBulletPoint(
                      'With service providers for app functionality (e.g., Firebase)'),
                  _buildBulletPoint('When required by law'),
                  SizedBox(height: 24),

                  // Section 4: Data Security
                  _buildSectionTitle('4. Data Security'),
                  _buildParagraph(
                      'We use encrypted connections and secure databases (Firebase) to store and manage your information safely.'),
                  SizedBox(height: 24),

                  // Section 5: Your Rights
                  _buildSectionTitle('5. Your Rights'),
                  _buildParagraph('You can:'),
                  _buildBulletPoint('Update your profile data'),
                  _buildBulletPoint(
                      'Request data deletion by contacting support'),
                  _buildBulletPoint('Withdraw consent anytime'),
                  SizedBox(height: 24),

                  // Section 6: Contact Us
                  _buildSectionTitle('6. Contact Us'),
                  _buildParagraph(
                      'For any privacy-related concerns, email us at:'),

                  // Email container with style
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 16),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email_outlined, color: Color(0xFF0066FF)),
                        SizedBox(width: 12),
                        Text(
                          AppConfig.supportEmail,
                          style: TextStyle(
                            color: AppConfig.primaryVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Agreement text
                  Container(
                    margin: EdgeInsets.only(top: 8, bottom: 40),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFFE6F0FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'By continuing to use ${AppConfig.appName}, you agree to this privacy policy.',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method for section titles
  Widget _buildSectionTitle(String title) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // Helper method for paragraph text
  Widget _buildParagraph(String text) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          color: Colors.black87,
          height: 1.5,
        ),
      ),
    );
  }

  // Helper method for bullet points
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 8),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Color(0xFF0066FF),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class About extends StatelessWidget {
  const About({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
        title: Text('About', style: TextStyle(color: Colors.black87)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Container(
          color: Colors.white,
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        // padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(0xFFE6F0FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.asset(
                          'assets/images/Logo.png',
                          width: 40,
                          height: 40,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'About HousingHub',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // App description
                  Container(
                    margin: EdgeInsets.only(top: 24, bottom: 24),
                    child: Text(
                      'HousingHub is a smart, location-based mobile platform designed to simplify the search for student and professional accommodations.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),

                  // Mission section
                  _buildSectionWithIcon(
                    title: '🏠 Our Mission:',
                    content:
                        'To bridge the gap between tenants and verified property owners by providing a secure, transparent, and easy-to-use platform.',
                    iconData: Icons.emoji_objects_outlined,
                  ),

                  // What we offer section
                  _buildSectionWithIcon(
                    title: '🔍 What We Offer:',
                    content: '',
                    iconData: Icons.check_circle_outline,
                    hasBulletPoints: true,
                    bulletPoints: [
                      'Location-based PG & rental search',
                      'Verified property listings',
                      'Direct communication with property owners',
                      'Remote inspection request feature',
                      'Budget and preference-based filters',
                    ],
                  ),

                  // Who we help section
                  _buildSectionWithIcon(
                    title: '👥 Who We Help:',
                    content: '',
                    iconData: Icons.people_outline,
                    hasBulletPoints: true,
                    bulletPoints: [
                      'Students and professionals looking for trusted places to stay',
                      'Owners who want to easily list and manage rental properties',
                    ],
                  ),

                  // Our values section
                  _buildSectionWithIcon(
                    title: '🛡 Our Values:',
                    content: '',
                    iconData: Icons.verified_user_outlined,
                    hasBulletPoints: true,
                    bulletPoints: [
                      'Trust & Transparency',
                      'Simplicity & Accessibility',
                      'Verified Data & Real-time Access',
                    ],
                  ),

                  // Closing statement
                  Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.all(16),
                    margin: EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Color(0xFFE6F0FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Made with ❤️ by Harsh Parmar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),

                  // Contact section
                  Container(
                    margin: EdgeInsets.only(top: 8, bottom: 16),
                    child: Text(
                      'Have questions or suggestions?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  // Email contact
                  Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email_outlined,
                            color: AppConfig.primaryVariant),
                        SizedBox(width: 12),
                        Text(
                          AppConfig.developerEmail,
                          style: TextStyle(
                            color: AppConfig.primaryVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build sections with icons
  Widget _buildSectionWithIcon({
    required String title,
    required String content,
    required IconData iconData,
    bool hasBulletPoints = false,
    List<String> bulletPoints = const [],
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),

          // Section content
          if (content.isNotEmpty)
            Text(
              content,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.5,
              ),
            ),

          // Bullet points if any
          if (hasBulletPoints)
            ...bulletPoints.map((point) => _buildBulletPoint(point)).toList(),
        ],
      ),
    );
  }

  // Helper method for bullet points
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 8),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Color(0xFF0066FF),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Help extends StatefulWidget {
  const Help({super.key});

  @override
  State<Help> createState() => _HelpState();
}

class _HelpState extends State<Help> {
  // For expandable FAQ items
  List<bool> _isExpanded = List.generate(5, (_) => false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          title:
              Text('Help & Support', style: TextStyle(color: Colors.black87)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with icon
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color(0xFFE6F0FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.support_agent,
                            color: Color(0xFF0066FF),
                            size: 28,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Help & Support',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Introduction
                    Container(
                      margin: EdgeInsets.only(top: 24, bottom: 24),
                      child: Text(
                        "We're here to assist you with any issues, questions, or feedback regarding your HousingHub experience.",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ),

                    // Common Questions Header
                    Container(
                      margin: EdgeInsets.only(bottom: 16),
                      child: Text(
                        "📌 Common Questions:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    // FAQ Section with expandable panels
                    _buildFaqItem(
                        index: 0,
                        question:
                            "How do I search for PGs or rental properties?",
                        answer:
                            "Use the Home screen or Search Filters to explore properties based on location, budget, room type, and amenities."),

                    _buildFaqItem(
                        index: 1,
                        question: "I'm an owner. How do I list a property?",
                        answer:
                            "Go to the \"Add Property\" section from your dashboard. Fill in the details, upload images, and submit the listing for approval."),

                    _buildFaqItem(
                        index: 2,
                        question:
                            "How do I contact a property owner or tenant?",
                        answer:
                            "You can use the in-app Chat feature to directly message the other party regarding listings or rental inquiries."),

                    _buildFaqItem(
                        index: 3,
                        question:
                            "What if I find incorrect or suspicious property details?",
                        answer:
                            "Please report the property using the \"Report\" option on the listing, or email us at the address below."),

                    _buildFaqItem(
                        index: 4,
                        question: "Can I request a video tour before visiting?",
                        answer:
                            "Yes! Many owners provide a remote inspection option. Click on \"Request Inspection\" inside the property details screen."),

                    // Still Need Help Section
                    Container(
                      margin: EdgeInsets.only(top: 24, bottom: 16),
                      child: Text(
                        "📬 Still need help?",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    Container(
                      margin: EdgeInsets.only(bottom: 20),
                      child: Text(
                        "If your question isn't listed above, don't worry! Reach out to us:",
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ),

                    // Email support button with Gmail navigation
                    Container(
                      margin: EdgeInsets.only(bottom: 16),
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _launchEmail();
                        },
                        child: Text(
                          "✉️ Email Us",
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0066FF),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    // Thanks message
                    Container(
                      alignment: Alignment.center,
                      margin: EdgeInsets.only(bottom: 40),
                      child: Text(
                        "Thanks for using HousingHub!",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0066FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  // Helper method to build FAQ expandable items
  Widget _buildFaqItem(
      {required int index, required String question, required String answer}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        border: Border.all(color: Color(0xFFE0E0E0)),
      ),
      child: ExpansionPanelList(
        elevation: 0,
        expandedHeaderPadding: EdgeInsets.zero,
        expansionCallback: (panelIndex, isExpanded) {
          setState(() {
            _isExpanded[index] = !isExpanded;
          });
        },
        children: [
          ExpansionPanel(
            headerBuilder: (context, isExpanded) {
              return ListTile(
                title: Text(
                  question,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              );
            },
            body: Container(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              alignment: Alignment.topLeft,
              child: Text(
                answer,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
            isExpanded: _isExpanded[index],
            backgroundColor: Colors.white,
            canTapOnHeader: true,
          ),
        ],
      ),
    );
  }

  // Method to launch email
  void _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'harshparmar308050@gmail.com',
      query: encodeQueryParameters(<String, String>{
        'subject': 'HousingHub Support Request',
      }),
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        Models.showErrorSnackBar(context, 'Could not open email client.');
      }
    } catch (e) {
      Models.showErrorSnackBar(context, 'Could not open email client.');
    }
  }

  // Helper method to encode query parameters
  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
