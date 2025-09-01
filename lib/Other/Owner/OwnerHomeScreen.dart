import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:housinghub/Helper/API.dart'; // Add API import
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/Other/Owner/OwnerProfileTab.dart';
import 'OwnerChatTab.dart';
import 'OwnerPropertyTab.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
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
    _currentUser = FirebaseAuth.instance.currentUser;

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
        child: _screens[_selectedIndex](context),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
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
                              color: AppConfig.primaryVariant,
                              borderRadius: BorderRadius.circular(width),
                            ),
                            child: Text(
                              initials,
                              style: TextStyle(
                                fontSize: 22.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
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
                    Icon(
                      Icons.notifications_none_outlined,
                      size: 30,
                      color: Color(0xFF007AFF),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
