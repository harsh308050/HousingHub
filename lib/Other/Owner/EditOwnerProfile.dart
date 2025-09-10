import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Helper/Models.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditOwnerProfile extends StatefulWidget {
  final Map<String, dynamic>? ownerData;

  const EditOwnerProfile({Key? key, this.ownerData}) : super(key: key);

  @override
  State<EditOwnerProfile> createState() => _EditOwnerProfileState();
}

class _EditOwnerProfileState extends State<EditOwnerProfile> {
  // Form controllers
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // State and city dropdown controllers
  final TextEditingController _stateSearchController = TextEditingController();
  final TextEditingController _citySearchController = TextEditingController();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Loading state
  bool _isLoading = false;
  bool _uploadingPhoto = false;

  // Profile picture
  String? _currentProfilePicture;
  final ImagePicker _picker = ImagePicker();

  // For dropdown functionality
  List<String> _states = [];
  List<String> _cities = [];
  Map<String, String> _stateCodeMap =
      {}; // Map to store state names and their codes
  bool _showStateDropdown = false;
  bool _showCityDropdown = false;
  List<String> _filteredStates = [];
  List<String> _filteredCities = [];
  String? selectedState;
  String? selectedCity;

  // API key for state/city data
  String stateCityAPI =
      "YTBrQWhHWEVWUk9SSEVSYllzbVNVTUJWRm1oaFBpN2FWeTRKbFpqbQ==";

  @override
  void initState() {
    super.initState();

    // Populate form fields with existing data
    if (widget.ownerData != null) {
      _mobileController.text = widget.ownerData!['mobileNumber'] ?? '';
      _fullNameController.text = widget.ownerData!['fullName'] ?? '';
      _emailController.text = widget.ownerData!['email'] ?? '';
      _currentProfilePicture = widget.ownerData!['profilePicture'];

      // Set initial state and city values
      selectedState = widget.ownerData!['state'];
      selectedCity = widget.ownerData!['city'];

      if (selectedState != null && selectedState!.isNotEmpty) {
        _stateSearchController.text = selectedState!;
      }

      if (selectedCity != null && selectedCity!.isNotEmpty) {
        _citySearchController.text = selectedCity!;
      }
    }

    // Initialize search controllers and fetch states
    _stateSearchController.addListener(_filterStates);
    _citySearchController.addListener(_filterCities);
    _fetchStates();
  }

  // Filter states based on search
  void _filterStates() {
    String query = _stateSearchController.text.toLowerCase();
    setState(() {
      _filteredStates = _states
          .where((state) => state.toLowerCase().contains(query))
          .toList();
    });
  }

  // Filter cities based on search
  void _filterCities() {
    String query = _citySearchController.text.toLowerCase();
    setState(() {
      _filteredCities =
          _cities.where((city) => city.toLowerCase().contains(query)).toList();
    });
  }

  // Upload profile picture
  Future<void> _pickAndUploadProfilePhoto() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _uploadingPhoto = true);

      final file = File(picked.path);
      final url = await Api.uploadImageToCloudinary(file, 'owner_profiles');

      setState(() {
        _currentProfilePicture = url;
        _uploadingPhoto = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile photo updated! Save to confirm changes.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update photo: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _stateSearchController.dispose();
    _citySearchController.dispose();
    super.dispose();
  }

  // Fetch states from API
  Future<void> _fetchStates() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse('https://api.countrystatecity.in/v1/countries/IN/states'),
        headers: {'X-CSCAPI-KEY': stateCityAPI},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
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

          // If we have a selected state, fetch its cities
          if (selectedState != null && selectedState!.isNotEmpty) {
            // Find the matching state in our list
            String? matchingState = _states.firstWhere(
              (s) => s.toLowerCase() == selectedState!.toLowerCase(),
              orElse: () => '',
            );

            if (matchingState.isNotEmpty) {
              _fetchCities(matchingState);
            }
          }

          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load states');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Models.showErrorSnackBar(
          context,
          'Failed to load states: $e',
        );
      }
    }
  }

  // Fetch cities for a selected state
  Future<void> _fetchCities(String stateName) async {
    setState(() {
      _isLoading = true;
    });
    try {
      if (!_stateCodeMap.containsKey(stateName)) {
        throw Exception('State code not found for $stateName');
      }

      String stateCode = _stateCodeMap[stateName]!;

      // Now fetch cities for this state
      final response = await http.get(
        Uri.parse(
            'https://api.countrystatecity.in/v1/countries/IN/states/$stateCode/cities'),
        headers: {'X-CSCAPI-KEY': stateCityAPI},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _cities = data.map((city) => city['name'].toString()).toList();
          // Sort cities alphabetically
          _cities.sort();

          // Initialize filtered cities
          _filteredCities = List.from(_cities);

          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load cities');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Models.showErrorSnackBar(
          context,
          'Failed to load cities: $e',
        );
      }
    }
  }

  // Helper method to build a custom text form field
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    String? Function(String?)? validator,
    bool isEnabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        enabled: isEnabled,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: AppConfig.primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: AppConfig.primaryColor,
              width: 1.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: AppConfig.primaryColor,
              width: 2.0,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // Helper method to build state dropdown
  Widget _buildStateDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                // State input with search functionality
                TextFormField(
                  controller: _stateSearchController,
                  decoration: InputDecoration(
                    labelText: 'State',
                    labelStyle: TextStyle(
                      color: AppConfig.primaryColor,
                    ),
                    prefixIcon: Icon(Icons.map, color: AppConfig.primaryColor),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_stateSearchController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _stateSearchController.clear();
                                selectedState = null;
                                _showStateDropdown = false;
                              });
                            },
                          ),
                        IconButton(
                          icon: Icon(
                            _showStateDropdown
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            color: AppConfig.primaryColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _showStateDropdown = !_showStateDropdown;
                              if (_showStateDropdown) {
                                _showCityDropdown = false;
                                _filteredStates = _states;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _showStateDropdown = true;
                      _showCityDropdown = false;
                      _filteredStates = _states;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a state';
                    }
                    return null;
                  },
                ),

                // State dropdown list
                if (_showStateDropdown)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    constraints: BoxConstraints(
                      maxHeight: 200,
                    ),
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(),
                          )
                        : _filteredStates.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Center(
                                  child: Text(
                                    "No states found",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _filteredStates.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    dense: true,
                                    title: Text(_filteredStates[index]),
                                    onTap: () {
                                      setState(() {
                                        selectedState = _filteredStates[index];
                                        _stateSearchController.text =
                                            selectedState!;
                                        _showStateDropdown = false;
                                        selectedCity = null;
                                        _citySearchController.clear();
                                        _cities = [];
                                      });
                                      _fetchCities(selectedState!);
                                    },
                                  );
                                },
                              ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build city dropdown
  Widget _buildCityDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                // City input with search functionality
                TextFormField(
                  controller: _citySearchController,
                  decoration: InputDecoration(
                    labelText: 'City',
                    labelStyle: TextStyle(
                      color: AppConfig.primaryColor,
                    ),
                    prefixIcon: Icon(Icons.location_city,
                        color: AppConfig.primaryColor),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_citySearchController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _citySearchController.clear();
                                selectedCity = null;
                                _showCityDropdown = false;
                              });
                            },
                          ),
                        IconButton(
                          icon: Icon(
                            _showCityDropdown
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            color: AppConfig.primaryColor,
                          ),
                          onPressed: () {
                            if (_cities.isEmpty) {
                              if (mounted) {
                                Models.showWarningSnackBar(
                                    context, 'Please select a state first');
                              }
                              return;
                            }
                            setState(() {
                              _showCityDropdown = !_showCityDropdown;
                              if (_showCityDropdown) {
                                _showStateDropdown = false;
                                _filteredCities = _cities;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  enabled: _cities.isNotEmpty,
                  onTap: () {
                    if (_cities.isEmpty) {
                      if (mounted) {
                        Models.showWarningSnackBar(
                            context, 'Please select a state first');
                      }
                      return;
                    }
                    setState(() {
                      _showCityDropdown = true;
                      _showStateDropdown = false;
                      _filteredCities = _cities;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a city';
                    }
                    return null;
                  },
                ),

                // City dropdown list
                if (_showCityDropdown)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    constraints: BoxConstraints(
                      maxHeight: 200,
                    ),
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(),
                          )
                        : _filteredCities.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Center(
                                  child: Text(
                                    "No cities found",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _filteredCities.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    dense: true,
                                    title: Text(_filteredCities[index]),
                                    onTap: () {
                                      setState(() {
                                        selectedCity = _filteredCities[index];
                                        _citySearchController.text =
                                            selectedCity!;
                                        _showCityDropdown = false;
                                      });
                                    },
                                  );
                                },
                              ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build a primary button
  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConfig.primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // Method to update owner profile
  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Prepare updated data
        Map<String, dynamic> updatedData = {
          'mobileNumber': _mobileController.text,
          'fullName': _fullNameController.text,
          'city': selectedCity,
          'state': selectedState,
        };

        // Add profile picture if it exists
        if (_currentProfilePicture != null &&
            _currentProfilePicture!.isNotEmpty) {
          updatedData['profilePicture'] = _currentProfilePicture;
        }

        // Update profile in Firestore
        await Api.updateOwnerProfile(_emailController.text, updatedData);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Return to profile page
          Navigator.pop(
              context, true); // Return true to indicate profile was updated
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update profile: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('Edit Profile',
            style:
                TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header section

                  // Profile Picture section
                  Container(
                    margin: EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: _uploadingPhoto
                                ? null
                                : _pickAndUploadProfilePhoto,
                            child: Stack(
                              children: [
                                Container(
                                  height: 120,
                                  width: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentProfilePicture == null ||
                                            _currentProfilePicture!.isEmpty
                                        ? AppConfig.primaryColor
                                        : null,
                                    image: _currentProfilePicture != null &&
                                            _currentProfilePicture!.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(
                                                _currentProfilePicture!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _currentProfilePicture == null ||
                                          _currentProfilePicture!.isEmpty
                                      ? Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                // Upload indicator
                                if (_uploadingPhoto)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
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
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppConfig.primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap to change profile picture',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Full Name field
                  _buildTextField(
                    controller: _fullNameController,
                    hintText: 'Full Name',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),

                  // Email field (disabled)
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'Email',
                    icon: Icons.email,
                    isEnabled: false, // Email cannot be changed
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      return null;
                    },
                  ),

                  // Mobile Number field
                  _buildTextField(
                    controller: _mobileController,
                    hintText: 'Mobile Number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your mobile number';
                      }
                      if (value.trim().length != 10) {
                        return 'Mobile number should be 10 digits';
                      }
                      return null;
                    },
                  ),

                  // State Dropdown
                  _buildStateDropdown(),

                  // City Dropdown
                  _buildCityDropdown(),

                  SizedBox(height: 24),

                  // Update Button
                  _buildPrimaryButton(
                    text: 'Update Profile',
                    onPressed: _updateProfile,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
