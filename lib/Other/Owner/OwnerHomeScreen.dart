import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:housinghub/Helper/API.dart'; // Add API import
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/Other/Owner/OwnerProfileTab.dart';
import 'package:housinghub/Other/Owner/AddProperty.dart';
import 'OwnerChatTab.dart';
import 'OwnerPropertyTab.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late List<Widget Function(BuildContext)>
      _screens; // Use 'late' for deferred initialization
  User? _currentUser;
  Map<String, dynamic>? _ownerData;

  // Function to change the selected index
  void _onProfileTapped() {
    setState(() {
      _selectedIndex = 3; // Index for Profile tab
    });
  }

  void _onPropertyTapped() {
    setState(() {
      _selectedIndex = 1; // Index for Property tab
    });
  }

  void _onChatTapped() {
    setState(() {
      _selectedIndex = 2; // Index for Property tab
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUser = FirebaseAuth.instance.currentUser;

    // Update user presence when app starts
    if (_currentUser?.email != null) {
      Api.updateUserPresence(_currentUser!.email!);
    }

    // Fetch user data from Firestore
    _fetchOwnerData();

    // Initialize _screens in initState
    _screens = [
      (context) => HomeTab(
          onProfileTapped: _onProfileTapped,
          onPropertyTapped: _onPropertyTapped,
          onChatTapped: _onChatTapped,
          user: _currentUser,
          ownerData: _ownerData),
      (context) => OwnerPropertyTab(),
      (context) => OwnerChatTab(),
      (context) => OwnerProfileTab(user: _currentUser, ownerData: _ownerData),
    ];
  }

  // Fetch owner data from Firestore
  Future<void> _fetchOwnerData() async {
    if (_currentUser != null && _currentUser!.email != null) {
      try {
        Map<String, dynamic>? userData =
            await Api.getOwnerDetailsByEmail(_currentUser!.email!);
        if (userData != null) {
          setState(() {
            _ownerData = userData;
            // Update the screens with the new data
            _screens = [
              (context) => HomeTab(
                  onProfileTapped: _onProfileTapped,
                  onPropertyTapped: _onPropertyTapped,
                  onChatTapped: _onChatTapped,
                  user: _currentUser,
                  ownerData: _ownerData),
              (context) => OwnerPropertyTab(),
              (context) => OwnerChatTab(),
              (context) =>
                  OwnerProfileTab(user: _currentUser, ownerData: _ownerData),
            ];
          });
        }
      } catch (e) {
        print("Error fetching owner data: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Container(
              decoration: BoxDecoration(color: Colors.white),
              child: _screens[_selectedIndex](context))),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // Handle app lifecycle changes for presence tracking
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_currentUser?.email != null) {
      switch (state) {
        case AppLifecycleState.resumed:
          Api.updateUserPresence(_currentUser!.email!);
          break;
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
        case AppLifecycleState.detached:
          Api.setUserOffline(_currentUser!.email!);
          break;
        case AppLifecycleState.hidden:
          break;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_currentUser?.email != null) {
      Api.setUserOffline(_currentUser!.email!);
    }
    super.dispose();
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      selectedItemColor: AppConfig.primaryColor,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.business_outlined),
          activeIcon: Icon(Icons.business_rounded),
          label: 'Properties',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_outlined),
          activeIcon: Icon(Icons.chat_rounded),
          label: 'Messages',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}

class HomeTab extends StatefulWidget {
  final VoidCallback onProfileTapped;
  final VoidCallback onPropertyTapped;
  final VoidCallback onChatTapped;
  final User? user;
  final Map<String, dynamic>? ownerData;

  const HomeTab(
      {super.key,
      required this.onProfileTapped,
      required this.onPropertyTapped,
      required this.onChatTapped,
      this.user,
      this.ownerData});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _totalProperties = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPropertyCount();
  }

  Future<void> _fetchPropertyCount() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        final properties = await Api.getAllOwnerProperties(user.email!);

        setState(() {
          _totalProperties = properties.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching property count: $e");
      setState(() {
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    // Get user name from Firestore data if available, otherwise fallback to Auth
    String displayName = '';
    if (widget.ownerData != null && widget.ownerData!['fullName'] != null) {
      displayName = widget.ownerData!['fullName'];
    } else {
      displayName = widget.user?.displayName ?? 'User';
    }

    String initials = _getInitials(displayName);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: width * 0.05,
            horizontal: width * 0.05,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with user profile and notification icon
              Padding(
                padding: EdgeInsets.symmetric(vertical: height * 0.02),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: widget.onProfileTapped,
                          child: Container(
                            alignment: Alignment.center,
                            width: width * 0.12,
                            height: width * 0.12,
                            decoration: BoxDecoration(
                              color: (widget.ownerData?['profilePicture'] !=
                                          null &&
                                      widget.ownerData!['profilePicture']
                                          .toString()
                                          .isNotEmpty)
                                  ? null
                                  : AppConfig.primaryVariant,
                              borderRadius: BorderRadius.circular(width),
                              image: (widget.ownerData?['profilePicture'] !=
                                          null &&
                                      widget.ownerData!['profilePicture']
                                          .toString()
                                          .isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(
                                          widget.ownerData!['profilePicture']),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child:
                                (widget.ownerData?['profilePicture'] == null ||
                                        widget.ownerData!['profilePicture']
                                            .toString()
                                            .isEmpty)
                                    ? Text(
                                        initials,
                                        style: TextStyle(
                                          fontSize: 22.0,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                          ),
                        ),
                        SizedBox(width: width * 0.02),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Welcome, ",
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppConfig.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Notification icon with unread count
                    StreamBuilder<int>(
                      stream: Api.getUnreadNotificationCountStream(
                          widget.user?.email ?? ''),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data ?? 0;
                        return Stack(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.notifications_none_outlined,
                                size: 30,
                                color: Color(0xFF007AFF),
                              ),
                              onPressed: () {
                                Navigator.pushNamed(
                                    context, 'NotificationScreen');
                              },
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Property Stats Row
              Row(
                children: [
                  // Total Properties Card
                  Expanded(
                    child: _buildStatsCard(
                      icon: Icons.business,
                      iconColor: Colors.blue,
                      value: _isLoading ? '...' : _totalProperties.toString(),
                      label: 'Total Properties',
                    ),
                  ),
                  SizedBox(width: 12),
                  // Pending Requests Card (Dummy data)
                  Expanded(
                    child: _buildStatsCard(
                      icon: Icons.assignment_outlined,
                      iconColor: Colors.blue,
                      value: '3',
                      label: 'Pending Requests',
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Views Stats Card (Dummy data)
              _buildViewsCard(),

              SizedBox(height: 24),

              // Quick Actions Section
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              SizedBox(height: 12),

              // Add Property Button
              _buildActionButton(
                icon: Icons.add,
                label: 'Add Property',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddProperty()),
                  ).then((_) {
                    _fetchPropertyCount(); // Refresh count when returning
                  });
                },
              ),

              SizedBox(height: 12),

              // Manage Properties Button
              _buildActionButton(
                icon: Icons.business_outlined,
                label: 'Manage Properties',
                onTap: widget.onPropertyTapped,
              ),

              SizedBox(height: 12),

              // Chats Button
              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                label: 'Chats',
                onTap: widget.onChatTapped,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 30),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewsCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, color: Colors.blue, size: 30),
          SizedBox(width: 16),
          Text(
            '245',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Views',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue, size: 24),
            SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
