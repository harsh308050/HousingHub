import 'package:flutter/material.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:housinghub/Helper/Models.dart';
import '../../Helper/API.dart';
import '../../Helper/ShimmerHelper.dart';

class AddProperty extends StatefulWidget {
  const AddProperty({super.key});

  @override
  State<AddProperty> createState() => _AddPropertyState();
}

class _AddPropertyState extends State<AddProperty> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _squareFootageController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _otherPropertyTypeController =
      TextEditingController();

  // Property Type Selection
  String? _propertyType;
  final List<String> _propertyTypes = [
    'Apartment',
    'House',
    'Villa',
    'PG/Hostel',
    'Others'
  ];

  // Room counts
  int _bedrooms = 1;
  int _bathrooms = 1;

  // Location related variables
  double? _latitude;
  double? _longitude;
  bool _isMapLoading = true;
  Timer? _searchDebouncer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _squareFootageController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _otherPropertyTypeController.dispose();
    _priceController.dispose();
    _securityDepositController.dispose();
    _salePriceController.dispose();
    _propertyAgeController.dispose();
    _searchDebouncer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      await _updateAddressFromCoordinates(
        LatLng(_latitude!, _longitude!),
      );
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  Future<void> _updateAddressFromCoordinates(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _addressController.text =
              '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.postalCode ?? ''}';
          _cityController.text = place.locality ?? '';
          _stateController.text = place.administrativeArea ?? '';
          _pincodeController.text = place.postalCode ?? '';
        });
      }
    } catch (e) {
      print('Error getting address: $e');
    }
  }

  Future<void> _updateCoordinatesFromAddress(String address) async {
    if (address.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        setState(() {
          _latitude = locations[0].latitude;
          _longitude = locations[0].longitude;
        });
      }
    } catch (e) {
      print('Error getting coordinates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
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
        title: Text(
          textAlign: TextAlign.center,
          'Add Property',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: List.generate(4, (index) {
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                right: index < 3 ? 8 : 0,
                              ),
                              height: 4,
                              decoration: BoxDecoration(
                                color: index <= _currentStep
                                    ? AppConfig.primaryColor
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              // Step Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: _currentStep == 0
                        ? _buildBasicInfoStep()
                        : _currentStep == 1
                            ? _buildLocationStep()
                            : _currentStep == 2
                                ? _buildPropertyDetailsStep()
                                : _buildMediaStep(),
                  ),
                ),
              ),
              // Navigation Buttons
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (_currentStep != 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            if (_currentStep > 0) {
                              setState(() => _currentStep--);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: AppConfig.primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Previous',
                            style: TextStyle(
                              color: AppConfig.primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    if (_currentStep != 0) SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                if (_currentStep < 3) {
                                  if (_formKey.currentState!.validate()) {
                                    setState(() => _currentStep++);
                                  }
                                } else {
                                  if (_formKey.currentState!.validate()) {
                                    if (propertyImages.isEmpty) {
                                      Models.showWarningSnackBar(context,
                                          'Please add at least one property image');
                                    } else {
                                      _savePropertyToFirestore();
                                    }
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting && _currentStep == 3
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Submitting...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                _currentStep == 3 ? 'Submit' : 'Next',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
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

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Info',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppConfig.primaryColor,
              ),
            ),
            SizedBox(height: 24),
            // Property Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Property Title',
                floatingLabelStyle: TextStyle(color: AppConfig.primaryColor),
                hintText: 'Enter property title',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppConfig.primaryColor),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter property title';
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            // Property Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Description',
                floatingLabelStyle: TextStyle(color: AppConfig.primaryColor),
                hintText: 'Describe your property',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppConfig.primaryColor),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter property description';
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            // Property Type
            DropdownButtonFormField<String>(
              value: _propertyType,
              decoration: InputDecoration(
                labelText: 'Property Type',
                floatingLabelStyle: TextStyle(color: AppConfig.primaryColor),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppConfig.primaryColor),
                ),
              ),
              items: _propertyTypes.map((String type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _propertyType = newValue;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select property type';
                }
                return null;
              },
            ),
            if (_propertyType == 'Others') ...[
              SizedBox(height: 20),
              TextFormField(
                controller: _otherPropertyTypeController,
                decoration: InputDecoration(
                  labelText: 'Specify Property Type',
                  floatingLabelStyle: TextStyle(color: AppConfig.primaryColor),
                  hintText: 'Enter your property type',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                validator: (value) {
                  if (_propertyType == 'Others' &&
                      (value == null || value.isEmpty)) {
                    return 'Please specify your property type';
                  }
                  return null;
                },
              ),
            ],
            SizedBox(height: 20),
            // Rooms Count
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bedrooms',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove),
                              onPressed: () {
                                if (_bedrooms > 1) {
                                  setState(() => _bedrooms--);
                                }
                              },
                              color: AppConfig.primaryColor,
                            ),
                            Expanded(
                              child: Text(
                                '$_bedrooms',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add),
                              onPressed: () {
                                setState(() => _bedrooms++);
                              },
                              color: AppConfig.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bathrooms',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove),
                              onPressed: () {
                                if (_bathrooms > 1) {
                                  setState(() => _bathrooms--);
                                }
                              },
                              color: AppConfig.primaryColor,
                            ),
                            Expanded(
                              child: Text(
                                '$_bathrooms',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add),
                              onPressed: () {
                                setState(() => _bathrooms++);
                              },
                              color: AppConfig.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            // Square Footage
            TextFormField(
              controller: _squareFootageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Square Footage',
                floatingLabelStyle: TextStyle(color: AppConfig.primaryColor),
                hintText: 'Enter square footage',
                prefixIcon: Icon(
                  Icons.center_focus_strong_rounded,
                  color: Colors.grey[500],
                ),
                suffixText: 'sq ft',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppConfig.primaryColor),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter square footage';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // Property details variables
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _securityDepositController =
      TextEditingController();
  bool _isMaleAllowed = false;
  bool _isFemaleAllowed = false;
  String? _selectedRoomType;
  final List<String> _roomTypes = [
    '1RK',
    '1BHK',
    '2BHK',
    '3BHK',
    '4BHK',
    'Studio'
  ];

  String? _selectedMinimumBookingPeriod;
  final List<String> _bookingPeriods = [
    '1 Month',
    '3 Months',
    '6 Months',
    '12 Months'
  ];

  // New sale property fields
  String _listingType = 'rent'; // 'rent' or 'sale'
  final TextEditingController _salePriceController = TextEditingController();
  String? _selectedFurnishingStatus;
  final List<String> _furnishingOptions = [
    'Furnished',
    'Semi-Furnished',
    'Unfurnished'
  ];
  final TextEditingController _propertyAgeController = TextEditingController();
  String? _selectedOwnershipType;
  final List<String> _ownershipTypes = [
    'Freehold',
    'Leasehold',
    'Co-operative'
  ];

  final Map<String, bool> _amenities = {
    'WiFi': false,
    'Parking': false,
    'Laundry': false,
    'AC': false,
    'Mess Facility': false,
    'House Keeping': false,
    'Furnished': false,
    'Unfurnished': false,
  };

  Widget _buildPropertyDetailsStep() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Other Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppConfig.primaryColor,
              ),
            ),
            SizedBox(height: 24),

            // Listing Type Selection
            Text(
              'Listing Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _listingType = 'rent';
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _listingType == 'rent'
                              ? AppConfig.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          'For Rent',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _listingType == 'rent'
                                ? Colors.white
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _listingType = 'sale';
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _listingType == 'sale'
                              ? AppConfig.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          'For Sale',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _listingType == 'sale'
                                ? Colors.white
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Price (conditional based on listing type)
            Text(
              _listingType == 'rent' ? 'Monthly Rent' : 'Sale Price',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _listingType == 'rent'
                  ? _priceController
                  : _salePriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: _listingType == 'rent'
                    ? 'Enter monthly rent'
                    : 'Enter sale price',
                suffixText: _listingType == 'rent' ? '₹/month' : '₹',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppConfig.primaryColor),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _listingType == 'rent'
                      ? 'Please enter monthly rent'
                      : 'Please enter sale price';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            SizedBox(height: 24),

            // Conditional fields based on listing type
            if (_listingType == 'rent') ...[
              // Security Deposit (only for rent)
              Text(
                'Security Deposit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _securityDepositController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter security deposit',
                  suffixText: '₹',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter security deposit';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),

              // Minimum Booking Period (only for rent)
              Text(
                'Minimum Booking Period',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedMinimumBookingPeriod,
                decoration: InputDecoration(
                  hintText: 'Select minimum booking period',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                items: _bookingPeriods.map((String period) {
                  return DropdownMenuItem(
                    value: period,
                    child: Text(period),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedMinimumBookingPeriod = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select minimum booking period';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
            ],

            // Sale-specific fields
            if (_listingType == 'sale') ...[
              // Furnishing Status
              Text(
                'Furnishing Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedFurnishingStatus,
                decoration: InputDecoration(
                  hintText: 'Select furnishing status',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                items: _furnishingOptions.map((String option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedFurnishingStatus = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select furnishing status';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),

              // Property Age
              Text(
                'Property Age',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _propertyAgeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter property age',
                  suffixText: 'years',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter property age';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),

              // Ownership Type
              Text(
                'Ownership Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedOwnershipType,
                decoration: InputDecoration(
                  hintText: 'Select ownership type',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                items: _ownershipTypes.map((String type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedOwnershipType = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select ownership type';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
            ],

            // Gender Allowed - only show for rental properties
            if (_listingType == 'rent') ...[
              Text(
                'Gender Allowed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isMaleAllowed = !_isMaleAllowed;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isMaleAllowed
                              ? AppConfig.primaryColor.withOpacity(0.1)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isMaleAllowed
                                ? AppConfig.primaryColor
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          'Male',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isMaleAllowed
                                ? AppConfig.primaryColor
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isFemaleAllowed = !_isFemaleAllowed;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isFemaleAllowed
                              ? AppConfig.primaryColor.withOpacity(0.1)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isFemaleAllowed
                                ? AppConfig.primaryColor
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          'Female',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isFemaleAllowed
                                ? AppConfig.primaryColor
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
            ],

            // Room Type
            Text(
              'Room Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _roomTypes.map((type) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRoomType = type;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedRoomType == type
                          ? AppConfig.primaryColor.withOpacity(0.1)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedRoomType == type
                            ? AppConfig.primaryColor
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: _selectedRoomType == type
                            ? AppConfig.primaryColor
                            : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 24),

            // Amenities
            Text(
              'Amenities',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _amenities.entries.where((entry) {
                // Filter out Furnished and Unfurnished for sale properties
                if (_listingType == 'sale' && 
                    (entry.key == 'Furnished' || entry.key == 'Unfurnished')) {
                  return false;
                }
                return true;
              }).map((entry) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _amenities[entry.key] = !entry.value;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: entry.value
                          ? AppConfig.primaryColor.withOpacity(0.1)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: entry.value
                            ? AppConfig.primaryColor
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getAmenityIcon(entry.key),
                          size: 18,
                          color: entry.value
                              ? AppConfig.primaryColor
                              : Colors.grey[600],
                        ),
                        SizedBox(width: 8),
                        Text(
                          entry.key,
                          style: TextStyle(
                            color: entry.value
                                ? AppConfig.primaryColor
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAmenityIcon(String amenity) {
    switch (amenity) {
      case 'WiFi':
        return Icons.wifi;
      case 'Parking':
        return Icons.local_parking;
      case 'Laundry':
        return Icons.local_laundry_service;
      case 'AC':
        return Icons.ac_unit;
      case 'Mess Facility':
        return Icons.restaurant;
      case 'House Keeping':
        return Icons.cleaning_services;
      case 'Furnished':
        return Icons.chair;
      case 'Unfurnished':
        return Icons.other_houses_outlined;
      default:
        return Icons.check_circle;
    }
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Location Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppConfig.primaryColor,
              ),
            ),
          ),
          Container(
            height: 200,
            margin: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target:
                          LatLng(_latitude ?? 20.5937, _longitude ?? 78.9629),
                      zoom: 15,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    onMapCreated: (controller) {
                      setState(() => _isMapLoading = false);
                    },
                    onTap: (latLng) async {
                      setState(() {
                        _latitude = latLng.latitude;
                        _longitude = latLng.longitude;
                      });
                      await _updateAddressFromCoordinates(latLng);
                    },
                    markers: _latitude != null && _longitude != null
                        ? {
                            Marker(
                              markerId: MarkerId('selected_location'),
                              position: LatLng(_latitude!, _longitude!),
                              infoWindow:
                                  InfoWindow(title: 'Selected Location'),
                            ),
                          }
                        : {},
                  ),
                  if (_isMapLoading)
                    Container(
                      color: Colors.white.withOpacity(0.8),
                      child: ShimmerHelper.mapShimmer(),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    floatingLabelStyle:
                        TextStyle(color: AppConfig.primaryColor),
                    hintText: 'Enter complete address',
                    prefixIcon:
                        Icon(Icons.location_on, color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppConfig.primaryColor),
                    ),
                  ),
                  maxLines: 2,
                  onChanged: (value) {
                    _searchDebouncer?.cancel();
                    _searchDebouncer = Timer(Duration(milliseconds: 500), () {
                      if (value.isNotEmpty) {
                        _updateCoordinatesFromAddress(value);
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter address';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: InputDecoration(
                          labelText: 'State',
                          floatingLabelStyle:
                              TextStyle(color: AppConfig.primaryColor),
                          hintText: 'Enter state',
                          prefixIcon: Icon(Icons.location_city,
                              color: Colors.grey[500]),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppConfig.primaryColor),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter state';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: InputDecoration(
                          labelText: 'City',
                          floatingLabelStyle:
                              TextStyle(color: AppConfig.primaryColor),
                          hintText: 'Enter city',
                          prefixIcon: Icon(Icons.location_city_outlined,
                              color: Colors.grey[500]),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppConfig.primaryColor),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter city';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _pincodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Pincode',
                    floatingLabelStyle:
                        TextStyle(color: AppConfig.primaryColor),
                    hintText: 'Enter pincode',
                    prefixIcon: Icon(Icons.pin_drop, color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppConfig.primaryColor),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter pincode';
                    }
                    if (value.length != 6) {
                      return 'Pincode must be 6 digits';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter valid pincode';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<File> propertyImages = [];
  File? propertyVideo;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Optimize by specifying image quality
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality:
            70, // Reduce image quality to make uploads faster and smaller
      );
      if (pickedFile != null) {
        setState(() {
          propertyImages.add(File(pickedFile.path));
        });
        print('Image added: ${pickedFile.path}');
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(
            minutes: 2), // Reduced to 2 minutes for better upload performance
        // quality: VideoQuality.medium, // Uncomment if you want to set video quality
      );
      if (pickedFile != null) {
        // Check file size before setting - Cloudinary free plan has a 10MB limit
        final File file = File(pickedFile.path);
        final int fileSizeInBytes = await file.length();
        final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

        if (fileSizeInMB > 50) {
          print(
              'Video file is too large: ${fileSizeInMB.toStringAsFixed(2)}MB');
          Models.showWarningSnackBar(context,
              'Video size exceeds 50MB. Please select a smaller video.');
          return;
        }

        setState(() {
          propertyVideo = file;
        });
        print('Video added: ${pickedFile.path}');
      }
    } catch (e) {
      print('Error picking video: $e');
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Save property data to Firestore using API
  Future<void> _savePropertyToFirestore() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isSubmitting = true;
        });

        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(color: AppConfig.primaryColor),
                  SizedBox(width: 20),
                  Text("Adding property..."),
                ],
              ),
            );
          },
        );

        // Get current user
        final User? user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          Navigator.of(context).pop(); // Close loading dialog
          Models.showWarningSnackBar(
              context, 'You must be logged in to add a property');
          return;
        }

        print('Current user: ${user.email}');

        // Create property data map
        print('Creating property data map');
        Map<String, dynamic> propertyData = {
          'title': _titleController.text,
          'description': _descriptionController.text,
          'propertyType': _propertyType == 'Others'
              ? _otherPropertyTypeController.text
              : _propertyType,
          'bedrooms': _bedrooms,
          'bathrooms': _bathrooms,
          'squareFootage': int.parse(_squareFootageController.text),
          'address': _addressController.text,
          'city': _cityController.text,
          'state': _stateController.text,
          'pincode': _pincodeController.text,
          'latitude': _latitude,
          'longitude': _longitude,
          'maleAllowed': _isMaleAllowed,
          'femaleAllowed': _isFemaleAllowed,
          'roomType': _selectedRoomType,
          'amenities': _amenities.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList(),
          // New sale/rent distinction fields
          'listingType': _listingType,
        };

        // Add listing-type specific fields
        if (_listingType == 'rent') {
          propertyData.addAll({
            'price': int.parse(_priceController.text),
            'securityDeposit': _securityDepositController.text.isNotEmpty
                ? int.parse(_securityDepositController.text)
                : 0,
            'minimumBookingPeriod': _selectedMinimumBookingPeriod,
          });
        } else {
          // Sale properties
          propertyData.addAll({
            'salePrice': int.parse(_salePriceController.text),
            'furnishingStatus': _selectedFurnishingStatus,
            'propertyAge': _propertyAgeController.text.isNotEmpty
                ? int.parse(_propertyAgeController.text)
                : 0,
            'ownershipType': _selectedOwnershipType,
          });
        }

        print('Property data map created');

        try {
          String propertyId = await Api.addProperty(
              propertyData, propertyImages, propertyVideo);

          print('Successfully saved property with ID: $propertyId');

          // Close loading dialog
          Navigator.of(context).pop();

          // Show success message
          Models.showSuccessSnackBar(context, 'Property added successfully!');

          // Navigate back after a short delay
          Future.delayed(Duration(seconds: 1), () {
            Navigator.of(context).pop();
          });
        } catch (e) {
          print('Error saving property: $e');
          throw Exception('Failed to save property to database: $e');
        }
      } catch (e) {
        // Close loading dialog
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }

        print('Error in _savePropertyToFirestore: $e');

        // Show detailed error message
        String errorMessage = 'Error adding property: $e';
        if (e.toString().contains('DioException')) {
          errorMessage =
              'Error uploading media: There was a problem with the Cloudinary upload. Please check your internet connection and try again.';
        } else if (e.toString().contains('permission-denied')) {
          errorMessage =
              'Permission denied: You do not have permission to add a property.';
        }

        Models.showErrorSnackBar(context, errorMessage);
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildMediaStep() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Media Upload',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppConfig.primaryColor,
              ),
            ),
            SizedBox(height: 24),

            // Property Images Section
            Text(
              'Property Images',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),

            Container(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Container(
                    width: 120,
                    margin: EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        _showImagePickerOptions();
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 32,
                            color: Colors.grey[600],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add Image',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Selected Images
                  ...propertyImages
                      .map((image) => Container(
                            width: 120,
                            margin: EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(image),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      setState(() {
                                        propertyImages.remove(image);
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      margin: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ],
              ),
            ),

            SizedBox(height: 32),

            // Video Upload Container
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[300]!,
                  style: BorderStyle.solid,
                ),
              ),
              child: propertyVideo == null
                  ? InkWell(
                      onTap: () {
                        _pickVideo();
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            size: 32,
                            color: Colors.grey[600],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add Video',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Maximum size: 50MB',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_circle_outline,
                                  size: 48,
                                  color: AppConfig.primaryColor,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Video uploaded',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                propertyVideo = null;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.all(4),
                              margin: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
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
