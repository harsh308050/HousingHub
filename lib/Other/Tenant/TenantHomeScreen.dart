import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'TenantPropertyDetail.dart';
import 'TenantSearchScreen.dart';
import 'TenantBookmarkScreen.dart';
import 'TenantMessageScreen.dart';
import 'TenantProfileScreen.dart';

class TenantHomeScreen extends StatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  State<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends State<TenantHomeScreen> {
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
    _currentUser = FirebaseAuth.instance.currentUser;

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
      ),
      TenantSearchTab(),
      TenantBookmarksTab(),
      TenantMessagesTab(),
      TenantProfileTab(user: _currentUser, tenantData: _tenantData),
    ];
  }

  // Update city across the app when selected from HomeTab
  void _updateCity(String city, String? state) {
    setState(() {
      _currentCity = city;
      _selectedState = state;
      // Update screens with new city data
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
        setState(() {
          _currentCity = 'Select City';
          _isLocationDetected = true;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);

      // Get address from lat/lng
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        String? detectedState = place.administrativeArea;
        String? detectedCity = place.locality ?? place.subAdministrativeArea;

        setState(() {
          _currentCity = detectedCity ?? 'Unknown City';
          _selectedState = detectedState;
          _isLocationDetected = true;
          _updateScreensWithNewData();
        });
      } else {
        setState(() {
          _currentCity = 'Unknown City';
          _isLocationDetected = true;
          _updateScreensWithNewData();
        });
      }
    } catch (e) {
      setState(() {
        _currentCity = 'Select City';
        _isLocationDetected = true;
        _updateScreensWithNewData();
      });
      print('Error getting location: $e');
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
      showUnselectedLabels: true,
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
}

class TenantHomeTab extends StatefulWidget {
  final User? user;
  final Map<String, dynamic>? tenantData;
  final String currentCity;
  final String? selectedState;
  final Function(String, String?) onCityChanged;

  const TenantHomeTab({
    Key? key,
    this.user,
    this.tenantData,
    this.currentCity = 'Loading...',
    this.selectedState,
    required this.onCityChanged,
  }) : super(key: key);

  @override
  State<TenantHomeTab> createState() => _TenantHomeTabState();
}

class _TenantHomeTabState extends State<TenantHomeTab> {
  String _currentCity = 'Loading...';
  bool _isLoading = false;
  bool _showCityPicker = false;
  List<String> _states = [];
  List<String> _cities = [];
  Map<String, String> _stateCodeMap = {};
  String? _selectedState;
  List<String> _filteredStates = [];
  List<String> _filteredCities = [];

  @override
  void initState() {
    super.initState();
    // Use city data from parent widget
    _currentCity = widget.currentCity;
    _selectedState = widget.selectedState;
    
    // Only fetch states for the city picker, not location
    _fetchStates();
  }
  
  @override
  void didUpdateWidget(TenantHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update state when parent sends new city data
    if (oldWidget.currentCity != widget.currentCity) {
      setState(() {
        _currentCity = widget.currentCity;
      });
    }
    
    if (oldWidget.selectedState != widget.selectedState) {
      setState(() {
        _selectedState = widget.selectedState;
      });
    }
  }  String stateCityAPI =
      "YTBrQWhHWEVWUk9SSEVSYllzbVNVTUJWRm1oaFBpN2FWeTRKbFpqbQ==";

  Future<void> _fetchStates() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.countrystatecity.in/v1/countries/IN/states'),
        headers: {'X-CSCAPI-KEY': '$stateCityAPI'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _states = [];
            _stateCodeMap = {};

            for (var state in data) {
              String stateName = state['name'].toString();
              String stateCode = state['iso2'].toString();
              _states.add(stateName);
              _stateCodeMap[stateName] = stateCode;
            }

            // Sort states alphabetically
            _states.sort();

            // Initialize filtered states
            _filteredStates = List.from(_states);
          });
        }
      } else {
        throw Exception('Failed to load states');
      }
    } catch (e) {
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

      final response = await http.get(
        Uri.parse(
            'https://api.countrystatecity.in/v1/countries/IN/states/$stateCode/cities'),
        headers: {'X-CSCAPI-KEY': '$stateCityAPI'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _cities = data.map((city) => city['name'].toString()).toList();
            _cities.sort();
            _filteredCities = List.from(_cities);
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load cities');
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
                        });
                      },
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: AppConfig.primaryColor),
                          SizedBox(width: 4),
                          Text(
                            _isLoading ? 'Loading...' : _currentCity,
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
                    // Notification icon
                    IconButton(
                      icon: Icon(Icons.notifications_none_outlined, size: 28),
                      onPressed: () {},
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
                                    _selectedState = null;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _selectedState == null
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
                                        color: _selectedState == null
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
                                    setState(() {});
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _selectedState != null
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
                                        color: _selectedState != null
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
                            hintText: _selectedState == null
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
                              if (_selectedState == null) {
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
                            ? Center(child: CircularProgressIndicator())
                            : _selectedState == null
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
                  decoration: InputDecoration(
                    hintText: 'Search rooms, areas, or landmarks',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              // Promotional Banner
              Container(
                margin: EdgeInsets.symmetric(vertical: height * 0.01),
                height: height * 0.18,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: AssetImage('assets/images/Logo.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(12)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Get 50% Off',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              'On your first month\'s rent',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Popular Near You Section
              SizedBox(height: height * 0.02),
              Text(
                'Popular Near You',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: height * 0.01),

              // Popular Properties Row
              Container(
                height: height * 0.28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildPropertyCard(
                      price: '\$1,200/mo',
                      location: 'Upper East Side',
                      rating: '4.8',
                      imagePath: 'assets/images/Logo.png',
                      width: width * 0.6,
                      height: height * 0.26,
                    ),
                    SizedBox(width: 12),
                    _buildPropertyCard(
                      price: '\$1,500/mo',
                      location: 'Brooklyn',
                      rating: null,
                      imagePath: 'assets/images/Logo.png',
                      width: width * 0.6,
                      height: height * 0.26,
                    ),
                  ],
                ),
              ),

              // Recently Viewed Section
              SizedBox(height: height * 0.02),
              Text(
                'Recently Viewed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: height * 0.01),

              // Recently Viewed Properties Row
              Container(
                height: height * 0.28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildPropertyCard(
                      price: '\$1,400/mo',
                      location: 'SoHo',
                      rating: null,
                      imagePath: 'assets/images/Logo.png',
                      width: width * 0.6,
                      height: height * 0.26,
                    ),
                    SizedBox(width: 12),
                    _buildPropertyCard(
                      price: '\$1,750/mo',
                      location: 'Greenwich Village',
                      rating: null,
                      imagePath: 'assets/images/Logo.png',
                      width: width * 0.6,
                      height: height * 0.26,
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

  Widget _buildPropertyCard({
    required String price,
    required String location,
    String? rating,
    required String imagePath,
    required double width,
    required double height,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TenantPropertyDetail(
              price: price,
              location: location,
              imagePath: imagePath,
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
            // Property Image
            Container(
              height: height * 0.65,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Property Info
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        price,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (rating != null)
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            SizedBox(width: 4),
                            Text(rating),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    location,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
