import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/AppConfig.dart';
import '/Helper/API.dart';

class TenantProfileTab extends StatefulWidget {
  final User? user;
  final Map<String, dynamic>? tenantData;

  const TenantProfileTab({Key? key, this.user, this.tenantData})
      : super(key: key);

  @override
  State<TenantProfileTab> createState() => _TenantProfileTabState();
}

class _TenantProfileTabState extends State<TenantProfileTab> {
  // Sign out method
  Future<void> _signOut() async {
    try {
      await Api.signOut();
      // Navigate to login screen after sign out
      Navigator.pushReplacementNamed(context, 'LoginScreen');
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String firstName = '';
    String lastName = '';
    String email = '';
    String mobile = '';
    String gender = '';

    if (widget.tenantData != null) {
      firstName = widget.tenantData!['firstName'] ?? '';
      lastName = widget.tenantData!['lastName'] ?? '';
      email = widget.tenantData!['email'] ?? widget.user?.email ?? '';
      mobile = widget.tenantData!['mobileNumber'] ?? '';
      gender = widget.tenantData!['gender'] ?? '';
    } else if (widget.user != null) {
      email = widget.user!.email ?? '';
      if (widget.user!.displayName != null) {
        List<String> nameParts = widget.user!.displayName!.split(' ');
        if (nameParts.isNotEmpty) {
          firstName = nameParts.first;
          if (nameParts.length > 1) {
            lastName = nameParts.last;
          }
        }
      }
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),

              // Profile avatar and name
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppConfig.primaryColor,
                      child: Text(
                        '${firstName.isNotEmpty ? firstName[0].toUpperCase() : ''}${lastName.isNotEmpty ? lastName[0].toUpperCase() : ''}',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '$firstName $lastName',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // Profile details section
              _buildProfileSection(
                title: 'Personal Information',
                children: [
                  _buildProfileDetail(
                    icon: Icons.phone,
                    title: 'Phone',
                    value: mobile.isNotEmpty ? mobile : 'Not added',
                  ),
                  _buildProfileDetail(
                    icon: Icons.person_outline,
                    title: 'Gender',
                    value: gender.isNotEmpty ? gender : 'Not specified',
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Account settings section
              _buildProfileSection(
                title: 'Account Settings',
                children: [
                  _buildProfileAction(
                    icon: Icons.edit,
                    title: 'Edit Profile',
                    onTap: () {
                      // Navigate to edit profile page
                    },
                  ),
                  _buildProfileAction(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    onTap: () {
                      // Navigate to notifications settings
                    },
                  ),
                  _buildProfileAction(
                    icon: Icons.security,
                    title: 'Privacy & Security',
                    onTap: () {
                      // Navigate to privacy settings
                    },
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Help section
              _buildProfileSection(
                title: 'Help & Support',
                children: [
                  _buildProfileAction(
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    onTap: () {
                      // Navigate to help center
                    },
                  ),
                  _buildProfileAction(
                    icon: Icons.info_outline,
                    title: 'About',
                    onTap: () {
                      // Show about dialog
                    },
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Sign out button
              Center(
                child: TextButton.icon(
                  onPressed: _signOut,
                  icon: Icon(Icons.logout, color: Colors.red),
                  label: Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileDetail({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: AppConfig.primaryColor),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: AppConfig.primaryColor),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            Spacer(),
            Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
