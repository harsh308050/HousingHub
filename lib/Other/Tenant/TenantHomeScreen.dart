import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Helper/Models.dart';
import 'package:housinghub/Helper/ShimmerHelper.dart';
import 'package:housinghub/Helper/LocationResolver.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:url_launcher/url_launcher.dart';
import 'TenantPropertyDetail.dart';
import 'TenantSearchScreen.dart';
import 'TenantBookmarkScreen.dart';
import 'TenantMessageScreen.dart';
import 'TenantProfileScreen.dart';

// Using Property class from API.dart

class TenantHomeScreen extends StatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  State<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends State<TenantHomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late List<Widget> _screens;
  User? _currentUser;
  Map<String, dynamic>? _tenantData;

  // Location data to persist across tab switches
  String _currentCity = 'Loading...';
  String? _selectedState;
  bool _isLocationDetected = false;

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
    _fetchTenantData();

    // Detect location once when app starts
    _detectLocationOnce();

    // Initialize _screens in initState
    _screens = [
      TenantHomeTab(
        user: _currentUser,
        tenantData: _tenantData,
        currentCity: _currentCity,
        selectedState: _selectedState,
        onCityChanged: _updateCity,
        onSearchTapped: () => setState(() => _selectedIndex = 1),
      ),
      TenantSearchTab(),
      TenantBookmarksTab(),
      TenantMessagesTab(),
      TenantProfileTab(user: _currentUser, tenantData: _tenantData),
    ];
  }

  void _updateCity(String city, String? state) {
    setState(() {
      _currentCity = city;
      _selectedState = state;
      _updateScreensWithNewData();
    });
  }

  // Detect location only once when app starts
  Future<void> _detectLocationOnce() async {
    if (_isLocationDetected) return;

    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied) {
          setState(() {
            _currentCity = 'Select City';
            _isLocationDetected = true;
          });
          return;
        }
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // If permission is granted but location is off, prompt user
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          // ignore: use_build_context_synchronously
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text('Enable Location'),
              content: Text(
                  'Location services are turned off. Would you like to open settings to enable location?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _checkAndRetryLocation();
                  },
                  child: Text('Not Now',
                      style: TextStyle(color: AppConfig.primaryColor)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await Geolocator.openLocationSettings();
                    // Add a small delay to allow user time to change settings
                    await Future.delayed(Duration(seconds: 3));
                    _checkAndRetryLocation();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                  ),
                  child: Text('Open Settings',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
        setState(() {
          _currentCity = 'Select City';
          _isLocationDetected = true;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);

      // Use API to get city and state from coordinates
      Map<String, String?> locationData =
          await Api.getCityFromLocation(position.latitude, position.longitude);

      final detectedCity = locationData['city'] ?? 'Unknown City';
      final detectedState = locationData['state'];
      final detectedDistrict = locationData['district'];

      print('Location detection results:');
      print('  City: $detectedCity');
      print('  State: $detectedState');
      print('  District: $detectedDistrict');

      // Use LocationResolver to get valid CSC city
      final resolvedCity = await LocationResolver.resolveCity(position);

      setState(() {
        _currentCity = resolvedCity ?? detectedCity;
        _selectedState = detectedState;
        _isLocationDetected = true;
        _updateScreensWithNewData();
      });
    } catch (e) {
      setState(() {
        _currentCity = 'Select City';
        _isLocationDetected = true;
        _updateScreensWithNewData();
      });
      print('Error getting location: $e');
    }
  }

  // Check if location is enabled and retry location detection
  Future<void> _checkAndRetryLocation() async {
    // Reset location detection flag to allow retry
    _isLocationDetected = false;

    // Check if location is now enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      // If location is now enabled, retry detection
      _detectLocationOnce();
    } else {
      // If still not enabled, leave the default city
      setState(() {
        _currentCity = 'Select City';
        _isLocationDetected = true;
        _updateScreensWithNewData();
      });
    }
  }

  // Update screens with new data
  void _updateScreensWithNewData() {
    _screens = [
      TenantHomeTab(
        user: _currentUser,
        tenantData: _tenantData,
        currentCity: _currentCity,
        selectedState: _selectedState,
        onCityChanged: _updateCity,
        onSearchTapped: () => setState(() => _selectedIndex = 1),
      ),
      TenantSearchTab(),
      TenantBookmarksTab(),
      TenantMessagesTab(),
      TenantProfileTab(user: _currentUser, tenantData: _tenantData),
    ];
  }

  // Fetch tenant data from Firestore
  Future<void> _fetchTenantData() async {
    if (_currentUser != null && _currentUser!.email != null) {
      try {
        Map<String, dynamic>? userData =
            await Api.getUserDetailsByEmail(_currentUser!.email!);
        if (userData != null) {
          setState(() {
            _tenantData = userData;
            // Update the screens with the new data
            _updateScreensWithNewData();
          });
        }
      } catch (e) {
        print("Error fetching tenant data: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _screens[_selectedIndex],
      ),
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
    if (_currentUser?.email == null) {
      // Fallback if no user is logged in
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
            icon: Icon(Icons.search),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            activeIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat),
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

    return StreamBuilder<int>(
      stream: Api.getUnreadMessageCountStream(_currentUser!.email!),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

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
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search),
              activeIcon: Icon(Icons.search),
              label: 'Search',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_border),
              activeIcon: Icon(Icons.bookmark),
              label: 'Saved',
            ),
            BottomNavigationBarItem(
              icon: _buildMessageTabIcon(unreadCount, false),
              activeIcon: _buildMessageTabIcon(unreadCount, true),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageTabIcon(int unreadCount, bool isActive) {
    final icon = Icon(
      isActive ? Icons.chat : Icons.chat_outlined,
      color: isActive ? AppConfig.primaryColor : Colors.grey,
    );

    if (unreadCount > 0) {
      return Stack(
        children: [
          icon,
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return icon;
  }
}

class TenantHomeTab extends StatefulWidget {
  final User? user;
  final Map<String, dynamic>? tenantData;
  final String currentCity;
  final String? selectedState;
  final Function(String, String?) onCityChanged;
  final VoidCallback onSearchTapped;

  const TenantHomeTab({
    Key? key,
    this.user,
    this.tenantData,
    this.currentCity = 'Loading...',
    this.selectedState,
    required this.onCityChanged,
    required this.onSearchTapped,
  }) : super(key: key);

  @override
  State<TenantHomeTab> createState() => _TenantHomeTabState();
}

class _TenantHomeTabState extends State<TenantHomeTab> {
  String _currentCity = 'Loading...';
  bool _isLoading = false;
  bool _showCityPicker = false;
  // Track which tab is selected in the city picker: true = State, false = City
  bool _isStateTabSelected = true;
  List<String> _states = [];
  List<String> _cities = [];
  Map<String, String> _stateCodeMap = {};
  String? _selectedState;
  List<String> _filteredStates = [];
  List<String> _filteredCities = [];

  // Properties data
  List<Property> _nearbyProperties = [];
  bool _loadingProperties = true;
  String? _propertyError;

  // Listing type filter
  String _listingTypeFilter =
      'all'; // 'rent', 'sale', or 'all' - default to show all properties

  // Banner state - no need to store it since StreamBuilder handles it

  @override
  void initState() {
    super.initState();
    // Use city data from parent widget
    _currentCity = widget.currentCity;
    _selectedState = widget.selectedState;

    print('TenantHomeTab initialized with city: $_currentCity');

    // Only fetch states for the city picker, not location
    _fetchStates();

    // Fetch properties based on current city
    _fetchPropertiesNearby();
  }

  @override
  void didUpdateWidget(TenantHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update state when parent sends new city data
    if (oldWidget.currentCity != widget.currentCity) {
      setState(() {
        _currentCity = widget.currentCity;
      });

      // Refresh properties when city changes
      _fetchPropertiesNearby();
    }

    if (oldWidget.selectedState != widget.selectedState) {
      setState(() {
        _selectedState = widget.selectedState;
      });
    }
  }

  // Fetch properties near the current city
  Future<void> _fetchPropertiesNearby() async {
    if (_currentCity == 'Loading...' ||
        _currentCity == 'Select City' ||
        _currentCity == 'Unknown City') {
      setState(() {
        _nearbyProperties = [];
        _loadingProperties = false;
      });
      return;
    }

    setState(() {
      _loadingProperties = true;
      _propertyError = null;
    });

    try {
      print('Searching for properties in city: $_currentCity');

      // Fetch properties using API with listing type filter
      List<Property> properties = await Api.getPropertiesByCity(
        _currentCity,
        listingType: _listingTypeFilter,
      );
      print(
          'Total properties loaded: ${properties.length} (filter: $_listingTypeFilter)');

      if (mounted) {
        setState(() {
          _nearbyProperties = properties;
          _loadingProperties = false;
        });
      }
    } catch (e) {
      print('Error fetching properties: $e');
      if (mounted) {
        setState(() {
          _propertyError = 'Failed to load properties: $e';
          _loadingProperties = false;
        });
      }
    }
  }

  Future<void> _fetchStates() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get states list from API service
      List<Map<String, String>> statesData = await Api.getIndianStates();

      if (mounted) {
        setState(() {
          _states = [];
          _stateCodeMap = {};

          for (var stateData in statesData) {
            String stateName = stateData['name'] ?? '';
            String stateCode = stateData['code'] ?? '';
            _states.add(stateName);
            _stateCodeMap[stateName] = stateCode;
          }

          // Initialize filtered states
          _filteredStates = List.from(_states);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('Error fetching states: $e');
    }
  }

  Future<void> _fetchCities(String stateName) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (!_stateCodeMap.containsKey(stateName)) {
        throw Exception('State code not found for $stateName');
      }

      String stateCode = _stateCodeMap[stateName]!;

      // Get cities for state from API service
      List<String> citiesData = await Api.getCitiesForState(stateCode);

      if (mounted) {
        setState(() {
          _cities = citiesData;
          _filteredCities = List.from(_cities);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching cities: $e');
    }
  }

  // Location detection is now handled in the parent widget

  void _selectCity(String city) {
    setState(() {
      _currentCity = city;
      _showCityPicker = false;
    });

    // Notify parent widget of city change
    widget.onCityChanged(city, _selectedState);
  }

  Widget _buildStatesList() {
    return ListView.builder(
      itemCount: _filteredStates.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(_filteredStates[index]),
          onTap: () {
            setState(() {
              _selectedState = _filteredStates[index];
              _filteredCities = [];
              _cities = [];
              _isStateTabSelected = false; // Automatically switch to City tab
              _fetchCities(_selectedState!);
            });
          },
        );
      },
    );
  }

  Widget _buildCitiesList() {
    return ListView.builder(
      itemCount: _filteredCities.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(_filteredCities[index]),
          onTap: () {
            _selectCity(_filteredCities[index]);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: width * 0.04,
          vertical: height * 0.01,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location and Profile Row
              Padding(
                padding: EdgeInsets.symmetric(vertical: height * 0.01),
                child: Row(
                  children: [
                    // Location dropdown
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showCityPicker = !_showCityPicker;
                          if (_showCityPicker) {
                            // Always show State tab first when opening picker
                            _isStateTabSelected = true;
                            _selectedState = null;
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 20, color: AppConfig.primaryColor),
                          SizedBox(width: 4),
                          _isLoading || _currentCity == 'Loading...'
                              ? ShimmerHelper.locationTextShimmer(width: 100)
                              : Text(
                                  _currentCity,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          Icon(_showCityPicker
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down)
                        ],
                      ),
                    ),
                    Spacer(),
                    // Notification icon with unread count
                    StreamBuilder<int>(
                      stream: Api.getUnreadNotificationCountStream(
                          widget.user?.email ?? ''),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data ?? 0;
                        return Stack(
                          children: [
                            IconButton(
                              icon: Icon(Icons.notifications_none_outlined,
                                  size: 28, color: AppConfig.primaryColor),
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

              // City Picker Dropdown
              if (_showCityPicker)
                Container(
                  height: height * 0.4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Tabs for State and City selection
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isStateTabSelected = true;
                                    _selectedState = null;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _isStateTabSelected
                                            ? AppConfig.primaryColor
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'State',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _isStateTabSelected
                                            ? AppConfig.primaryColor
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_selectedState != null) {
                                    setState(() {
                                      _isStateTabSelected = false;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: !_isStateTabSelected &&
                                                _selectedState != null
                                            ? AppConfig.primaryColor
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'City',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: !_isStateTabSelected &&
                                                _selectedState != null
                                            ? AppConfig.primaryColor
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Search Bar
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: _isStateTabSelected
                                ? 'Search state'
                                : 'Search city',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 0),
                          ),
                          onChanged: (value) {
                            setState(() {
                              if (_isStateTabSelected) {
                                _filteredStates = _states
                                    .where((state) => state
                                        .toLowerCase()
                                        .contains(value.toLowerCase()))
                                    .toList();
                              } else {
                                _filteredCities = _cities
                                    .where((city) => city
                                        .toLowerCase()
                                        .contains(value.toLowerCase()))
                                    .toList();
                              }
                            });
                          },
                        ),
                      ),

                      // List of States or Cities
                      Expanded(
                        child: _isLoading
                            ? ShimmerHelper.propertyCardShimmer()
                            : _isStateTabSelected
                                ? _buildStatesList()
                                : _buildCitiesList(),
                      ),
                    ],
                  ),
                ),

              // Search Bar
              Container(
                margin: EdgeInsets.symmetric(vertical: height * 0.01),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  onTap: () {
                    widget.onSearchTapped();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search rooms, areas, or landmarks',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              // Dynamic Promotional Banner from Firestore - Single Active Banner
              Container(
                margin: EdgeInsets.symmetric(vertical: height * 0.01),
                height: height * 0.18,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: StreamBuilder<Map<String, dynamic>?>(
                    stream: Api.getActiveBannerStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ShimmerHelper.bannerShimmer(
                            height: height * 0.18);
                      }

                      if (snapshot.hasError) {
                        print('Error loading banner: ${snapshot.error}');
                        return _buildPlaceholderBanner(width);
                      }

                      if (!snapshot.hasData || snapshot.data == null) {
                        print('No active banner found');
                        return _buildPlaceholderBanner(width);
                      }

                      final banner = snapshot.data!;
                      final imageUrl = banner['imageUrl'] ?? '';
                      final title = banner['title'] ?? 'Welcome';
                      final subtitle = banner['subtitle'] ?? '';

                      return GestureDetector(
                        onTap: () =>
                            _handleBannerTap(banner['link'] as String?),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Banner Image
                            Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey[300],
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading banner image: $error');
                                return _buildPlaceholderBanner(width);
                              },
                            ),
                            // Gradient overlay at bottom
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: height * 0.2,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.vertical(
                                    bottom: Radius.circular(12),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.9),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Text overlay
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty) SizedBox(height: 4),
                                  if (subtitle.isNotEmpty)
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Properties Near You Section
              SizedBox(height: height * 0.02),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Properties Near You',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      if (!_loadingProperties)
                        IconButton(
                          icon: Icon(
                            Icons.refresh,
                            size: 20,
                            color: AppConfig.primaryColor,
                          ),
                          onPressed: () {
                            _fetchPropertiesNearby();
                          },
                          tooltip: 'Refresh properties',
                        ),
                      if (_loadingProperties)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppConfig.primaryColor),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Listing type filter toggle
              SizedBox(height: height * 0.015),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _listingTypeFilter = 'all';
                          });
                          _fetchPropertiesNearby();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _listingTypeFilter == 'all'
                                ? AppConfig.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            'All',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _listingTypeFilter == 'all'
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _listingTypeFilter = 'rent';
                          });
                          _fetchPropertiesNearby();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _listingTypeFilter == 'rent'
                                ? AppConfig.primaryColor
                                : Colors.transparent,
                          ),
                          child: Text(
                            'For Rent',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _listingTypeFilter == 'rent'
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _listingTypeFilter = 'sale';
                          });
                          _fetchPropertiesNearby();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _listingTypeFilter == 'sale'
                                ? AppConfig.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            'For Sale',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _listingTypeFilter == 'sale'
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: height * 0.01),

              // Properties Near You Row
              Container(
                height: height * 0.28,
                child: _loadingProperties
                    ? Center(
                        child: ShimmerHelper.propertyCardShimmer(),
                      )
                    : _propertyError != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red[300], size: 32),
                                SizedBox(height: 8),
                                Text(
                                  'Error loading properties',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                Text(
                                  _propertyError!.length > 50
                                      ? '${_propertyError!.substring(0, 50)}...'
                                      : _propertyError!,
                                  style: TextStyle(
                                      color: Colors.red[300], fontSize: 12),
                                ),
                                SizedBox(height: 10),
                                ElevatedButton.icon(
                                  onPressed: () => _fetchPropertiesNearby(),
                                  icon: Icon(Icons.refresh),
                                  label: Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConfig.primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _nearbyProperties.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.home_outlined,
                                        color: Colors.grey[400], size: 32),
                                    SizedBox(height: 8),
                                    Text(
                                      'No properties available',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Tip: Use the Search tab to find properties by area or landmark.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _nearbyProperties.length,
                                itemBuilder: (context, index) {
                                  final property = _nearbyProperties[index];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right:
                                          index < _nearbyProperties.length - 1
                                              ? 12
                                              : 0,
                                    ),
                                    child: _buildPropertyCardFromProperty(
                                      property: property,
                                      width: width * 0.6,
                                      height: height * 0.26,
                                    ),
                                  );
                                },
                              ),
              ),

              // Recently Viewed Section
              SizedBox(height: height * 0.02),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recently Viewed',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: height * 0.01),

              // Recently Viewed Properties Row
              Container(
                height: height * 0.28,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: Api.streamRecentlyViewedProperties(
                    FirebaseAuth.instance.currentUser?.email ?? '',
                    limit: 10, // Fetch more to account for deleted ones
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: ShimmerHelper.propertyCardShimmer(),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red[300], size: 32),
                            SizedBox(height: 8),
                            Text(
                              'Error loading recently viewed properties',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history,
                                color: Colors.grey[400], size: 32),
                            SizedBox(height: 8),
                            Text(
                              'No recently viewed properties',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    // Use FutureBuilder to validate properties exist
                    return FutureBuilder<List<Property>>(
                      future: _validateRecentlyViewedProperties(docs),
                      builder: (context, validationSnapshot) {
                        if (validationSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: ShimmerHelper.propertyCardShimmer(),
                          );
                        }

                        final validProperties = validationSnapshot.data ?? [];

                        if (validProperties.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history,
                                    color: Colors.grey[400], size: 32),
                                SizedBox(height: 8),
                                Text(
                                  'No recently viewed properties',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: validProperties.length > 5
                              ? 5
                              : validProperties.length, // Show max 5
                          itemBuilder: (context, index) {
                            final property = validProperties[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                right:
                                    index < validProperties.length - 1 ? 12 : 0,
                              ),
                              child: _buildPropertyCardFromProperty(
                                property: property,
                                width: width * 0.6,
                                height: height * 0.26,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyCardFromProperty({
    required Property property,
    required double width,
    required double height,
  }) {
    print(
        'Building property card for: ${property.title} in ${property.city}, image: ${property.imageUrl}');

    return GestureDetector(
      onTap: () {
        print('Navigating to property detail: ${property.id}');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TenantPropertyDetail(
              propertyId: property.id,
              price: property.price,
              location: property.location,
              imagePath: property.imageUrl,
              propertyData: property.toMap(),
            ),
          ),
        );
      },
      child: Container(
        width: width,
        height: height,
        margin: EdgeInsets.only(bottom: 8),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Image with gradient overlay
            Stack(
              children: [
                Container(
                  height: height * 0.7,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(12)),
                    child: property.images.isNotEmpty
                        ? Image.network(
                            property.images.first,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[200],
                                child: ShimmerHelper.propertyCardShimmer(),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print(
                                  'Error loading image: $error for URL ${property.images.first}');
                              return Container(
                                color: Colors.grey[300],
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image,
                                          color: Colors.grey[500]),
                                      SizedBox(height: 4),
                                      Text(
                                        'Image unavailable',
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: Center(
                              child: Icon(Icons.home,
                                  color: Colors.grey[500], size: 40),
                            ),
                          ),
                  ),
                ),

                // Gradient overlay only at the bottom of the image
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: height * 0.5, // controls gradient coverage
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(12)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // Property type badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConfig.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      property.propertyType,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),

                // Property title text (over gradient)
                Positioned(
                  bottom: 8,
                  left: 10,
                  right: 10,
                  child: Text(
                    property.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Property Info section (below image)
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _buildPriceText(property),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        property.roomType,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 14, color: Colors.grey[600]),
                      SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          property.location,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build price text based on listing type
  String _buildPriceText(Property property) {
    final listingType = property.listingType;

    if (listingType == 'sale') {
      // For sale properties, show sale price
      String salePrice = property.salePrice ?? property.price;
      // Remove ₹ symbol if present to format the number properly
      String priceValue =
          salePrice.replaceAll('₹', '').replaceAll(',', '').trim();
      String formattedPrice = Models.formatIndianCurrency(priceValue);
      return '₹$formattedPrice';
    } else {
      // For rent properties, show monthly rent
      String price = property.price;
      // Remove ₹ symbol and /month if present to format the number properly
      String priceValue = price
          .replaceAll('₹', '')
          .replaceAll('/month', '')
          .replaceAll(',', '')
          .trim();
      String formattedPrice = Models.formatIndianCurrency(priceValue);
      return '₹$formattedPrice/month';
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Validate recently viewed properties to filter out deleted ones
  Future<List<Property>> _validateRecentlyViewedProperties(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    List<Property> validProperties = [];

    for (var doc in docs) {
      try {
        final data = doc.data();
        final propertyId = data['id'] ?? doc.id;
        final ownerEmail = data['ownerEmail'] as String?;
        final ownerId = data['ownerId'] as String? ?? '';

        // Skip if no owner email
        if (ownerEmail == null || ownerEmail.isEmpty) {
          print('Skipping property $propertyId - no owner email');
          continue;
        }

        // Check if property still exists in Firestore
        final propertyExists =
            await Api.getPropertyById(ownerEmail, propertyId);

        if (propertyExists != null) {
          // Property still exists, add to valid list
          final property = Property.fromFirestore(doc, ownerId);
          validProperties.add(property);
        } else {
          print(
              'Property $propertyId by $ownerEmail has been deleted - removing from recently viewed');
          // Optionally: Remove from recently viewed collection
          _removeDeletedPropertyFromRecentViews(doc.reference);
        }
      } catch (e) {
        print('Error validating property: $e');
        // On error, skip this property
        continue;
      }
    }

    return validProperties;
  }

  // Remove deleted property from tenant's recent views
  Future<void> _removeDeletedPropertyFromRecentViews(
      DocumentReference docRef) async {
    try {
      await docRef.delete();
      print('Removed deleted property from recent views');
    } catch (e) {
      print('Error removing deleted property from recent views: $e');
    }
  }

  // Build placeholder banner when no active banner is available
  Widget _buildPlaceholderBanner(double width) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'Find Your Dream Home',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  // Handle banner tap to open link
  Future<void> _handleBannerTap(String? link) async {
    if (link == null || link.trim().isEmpty) return;

    try {
      final Uri url = Uri.parse(link);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error launching banner URL: $e');
    }
  }
}
