import 'package:flutter/material.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Helper/Models.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ChatScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileDetailScreen extends StatefulWidget {
  final String email;
  final String? currentEmail; // optional: who is viewing

  const UserProfileDetailScreen(
      {Key? key, required this.email, this.currentEmail})
      : super(key: key);

  @override
  State<UserProfileDetailScreen> createState() =>
      _UserProfileDetailScreenState();
}

class _UserProfileDetailScreenState extends State<UserProfileDetailScreen> {
  String _displayName = '';
  String _profilePicture = '';
  String _userType = 'Unknown';
  String? _mobile;
  bool _isOnline = false;
  String _lastSeen = '';
  bool _loading = true;

  // Full profile data
  Map<String, dynamic>? _fullProfileData;

  // Counts
  int _recentlyViewedCount = 0;
  int _availablePropertiesCount = 0;
  int _unavailablePropertiesCount = 0;
  int _totalPropertiesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await Api.getUserProfileInfo(widget.email);
      final presence = await Api.getUserPresence(widget.email);
      final mobile = await Api.getUserMobileNumber(widget.email);

      // Fetch full profile data based on user type
      Map<String, dynamic>? fullData;
      if (profile['userType'] == 'tenant') {
        fullData = await Api.getUserDetailsByEmail(widget.email);
        // Get recently viewed count for tenants
        try {
          final recentlyViewed =
              await Api.getRecentlyViewedProperties(widget.email, limit: 1000);
          _recentlyViewedCount = recentlyViewed.length;
        } catch (e) {
          print('Error fetching recently viewed: $e');
        }
      } else if (profile['userType'] == 'owner') {
        fullData = await Api.getOwnerDetailsByEmail(widget.email);
        // Get property counts for owners
        try {
          final availableProps = await Api.getOwnerProperties(widget.email);
          final unavailableProps =
              await Api.getOwnerUnavailableProperties(widget.email);
          _availablePropertiesCount = availableProps.length;
          _unavailablePropertiesCount = unavailableProps.length;
          _totalPropertiesCount =
              _availablePropertiesCount + _unavailablePropertiesCount;
        } catch (e) {
          print('Error fetching property counts: $e');
        }
      }

      setState(() {
        _displayName =
            profile['displayName'] ?? _formatDisplayNameFromEmail(widget.email);
        _profilePicture = profile['profilePicture'] ?? '';
        _userType = profile['userType'] ?? 'unknown';
        _isOnline = presence['isOnline'] ?? false;
        _lastSeen = Api.formatLastSeen((presence['lastSeen'] is Timestamp)
            ? presence['lastSeen'] as Timestamp
            : null);
        _mobile = mobile;
        _fullProfileData = fullData;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _displayName = _formatDisplayNameFromEmail(widget.email);
        _profilePicture = '';
        _userType = 'unknown';
        _mobile = null;
        _isOnline = false;
        _lastSeen = '';
        _fullProfileData = null;
        _loading = false;
      });
    }
  }

  String _formatDisplayNameFromEmail(String email) {
    if (email.isEmpty) return 'Unknown User';
    final username = email.split('@')[0];
    final parts = username.split('.');
    if (parts.length >= 2) {
      return '${_capitalize(parts[0])} ${_capitalize(parts[1])}';
    }
    return _capitalize(username);
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _startCall() async {
    if (_mobile == null || _mobile!.trim().isEmpty) {
      Models.showWarningSnackBar(
          context, 'Phone number not available for this user');
      return;
    }

    final clean = _mobile!.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Models.showErrorSnackBar(context, 'Unable to launch phone dialer');
    }
  }

  void _openChat() {
    final me = widget.currentEmail;
    if (me == null) {
      Models.showWarningSnackBar(context, 'Sign in to start chat');
      return;
    }
    if (me.toLowerCase().trim() == widget.email.toLowerCase().trim()) {
      Models.showWarningSnackBar(context, 'Cannot chat with yourself');
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
          currentEmail: me, otherEmail: widget.email, otherName: _displayName),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppConfig.textPrimary),
        title: Text(
          'Profile',
          style: TextStyle(color: AppConfig.textPrimary),
        ),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppConfig.primaryColor)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x11000000),
                              blurRadius: 8,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor:
                                AppConfig.primaryColor.withOpacity(0.12),
                            backgroundImage: _profilePicture.isNotEmpty
                                ? NetworkImage(_profilePicture)
                                : null,
                            child: _profilePicture.isEmpty
                                ? Text(
                                    Api.getUserInitials(
                                        _displayName, widget.email),
                                    style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(_displayName,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppConfig.lightPrimaryBackground,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _userType.toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppConfig.primaryColor),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _isOnline
                                    ? Icons.circle
                                    : Icons.circle_outlined,
                                size: 12,
                                color: _isOnline
                                    ? AppConfig.successColor
                                    : AppConfig.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                  _isOnline
                                      ? 'Online'
                                      : (_lastSeen.isNotEmpty
                                          ? _lastSeen
                                          : 'Offline'),
                                  style: TextStyle(
                                      color: AppConfig.textSecondary,
                                      fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(widget.email,
                              style: TextStyle(color: AppConfig.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Contact card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x11000000),
                              blurRadius: 6,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Contact',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                    _mobile ?? 'Phone number not available',
                                    style: TextStyle(
                                        color: AppConfig.textSecondary)),
                              ),
                              ElevatedButton.icon(
                                onPressed: _mobile == null ? null : _startCall,
                                icon: const Icon(Icons.call,
                                    size: 18, color: Colors.white),
                                label: const Text('Call',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConfig.primaryColor),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: (widget.currentEmail == null ||
                                        widget.currentEmail!
                                                .toLowerCase()
                                                .trim() ==
                                            widget.email.toLowerCase().trim())
                                    ? null
                                    : _openChat,
                                icon: const Icon(Icons.message,
                                    size: 18, color: Colors.white),
                                label: const Text('Message',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConfig.primaryColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Statistics card (for tenant or owner)
                    if (_userType == 'tenant')
                      _buildStatisticsCard(
                        'Recently Viewed',
                        '$_recentlyViewedCount Properties',
                        Icons.visibility_outlined,
                        AppConfig.primaryColor,
                      )
                    else if (_userType == 'owner')
                      _buildOwnerStatisticsCard(),

                    const SizedBox(height: 16),

                    // Profile Details Section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Profile Details',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppConfig.textPrimary)),
                    ),
                    const SizedBox(height: 8),

                    // Display all profile fields
                    if (_fullProfileData != null) ...[
                      if (_userType == 'tenant')
                        _buildTenantProfileDetails()
                      else if (_userType == 'owner')
                        _buildOwnerProfileDetails()
                    ] else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x11000000),
                                blurRadius: 6,
                                offset: Offset(0, 2))
                          ],
                        ),
                        child: Text(
                          'No additional profile information available.',
                          style: TextStyle(color: AppConfig.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatisticsCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x11000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: AppConfig.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerStatisticsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x11000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Properties',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPropertyStatItem(
                    'Total', _totalPropertiesCount, AppConfig.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPropertyStatItem('Available',
                    _availablePropertiesCount, const Color(0xFF34C759)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPropertyStatItem('Unavailable',
                    _unavailablePropertiesCount, const Color(0xFFFF3B30)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyStatItem(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppConfig.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTenantProfileDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x11000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
              'First Name', _fullProfileData?['firstName'] ?? 'N/A'),
          _buildDetailRow('Last Name', _fullProfileData?['lastName'] ?? 'N/A'),
          _buildDetailRow('Gender', _fullProfileData?['gender'] ?? 'N/A'),
          _buildDetailRow(
              'Mobile Number', _fullProfileData?['mobileNumber'] ?? 'N/A'),
          _buildDetailRow('Email', _fullProfileData?['email'] ?? widget.email),
          _buildDetailRow(
              'User Type',
              (_fullProfileData?['userType'] ?? 'tenant')
                  .toString()
                  .toUpperCase()),
          _buildDetailRow('UID', _fullProfileData?['uid'] ?? 'N/A'),
          if (_fullProfileData?['createdAt'] != null)
            _buildDetailRow(
                'Joined', _formatTimestamp(_fullProfileData!['createdAt'])),
          if (_fullProfileData?['updatedAt'] != null)
            _buildDetailRow('Last Updated',
                _formatTimestamp(_fullProfileData!['updatedAt'])),
        ],
      ),
    );
  }

  Widget _buildOwnerProfileDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x11000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Full Name', _fullProfileData?['fullName'] ?? 'N/A'),
          _buildDetailRow(
              'Mobile Number', _fullProfileData?['mobileNumber'] ?? 'N/A'),
          _buildDetailRow('Email', _fullProfileData?['email'] ?? widget.email),
          _buildDetailRow('City', _fullProfileData?['city'] ?? 'N/A'),
          _buildDetailRow('State', _fullProfileData?['state'] ?? 'N/A'),
          _buildDetailRow(
              'User Type',
              (_fullProfileData?['userType'] ?? 'owner')
                  .toString()
                  .toUpperCase()),
          _buildDetailRow('UID', _fullProfileData?['uid'] ?? 'N/A'),

          // Approval Status
          if (_fullProfileData?['approvalStatus'] != null) ...[
            const Divider(height: 24),
            Text('Verification Status',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppConfig.textSecondary)),
            const SizedBox(height: 8),
            _buildApprovalStatusChip(_fullProfileData!['approvalStatus']),
            const SizedBox(height: 8),
          ],

          // ID Proof Info
          if (_fullProfileData?['idProof'] != null) ...[
            _buildDetailRow(
                'ID Proof Type', _fullProfileData!['idProof']['type'] ?? 'N/A'),
            if (_fullProfileData!['idProof']['uploadedAt'] != null)
              _buildDetailRow('ID Uploaded',
                  _formatTimestamp(_fullProfileData!['idProof']['uploadedAt'])),
          ],

          const Divider(height: 24),

          if (_fullProfileData?['createdAt'] != null)
            _buildDetailRow(
                'Joined', _formatTimestamp(_fullProfileData!['createdAt'])),
          if (_fullProfileData?['approvalRequestedAt'] != null)
            _buildDetailRow('Approval Requested',
                _formatTimestamp(_fullProfileData!['approvalRequestedAt'])),
          if (_fullProfileData?['approvalUpdatedAt'] != null)
            _buildDetailRow('Approval Updated',
                _formatTimestamp(_fullProfileData!['approvalUpdatedAt'])),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: AppConfig.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalStatusChip(String status) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'approved':
        color = const Color(0xFF34C759);
        icon = Icons.check_circle;
        break;
      case 'pending':
        color = const Color(0xFFFFCC00);
        icon = Icons.access_time;
        break;
      case 'rejected':
        color = const Color(0xFFFF3B30);
        icon = Icons.cancel;
        break;
      default:
        color = AppConfig.textSecondary;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'N/A';
    }

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $year at $hour:$minute $amPm';
  }
}
