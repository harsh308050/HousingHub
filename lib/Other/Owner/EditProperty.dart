import 'package:flutter/material.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class EditProperty extends StatefulWidget {
  final Map<String, dynamic> property;

  const EditProperty({Key? key, required this.property}) : super(key: key);

  @override
  State<EditProperty> createState() => _EditPropertyState();
}

class _EditPropertyState extends State<EditProperty> {
  final _formKey = GlobalKey<FormState>();
  bool _isAvailable = true;
  bool _isMaleAllowed = true;
  bool _isFemaleAllowed = true;

  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _squareFootageController =
      TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  // Property details
  String _propertyType = 'Apartment';
  int _bedrooms = 1;
  int _bathrooms = 1;
  String _roomType = '1BHK';

  // Amenities map
  Map<String, bool> _amenities = {
    'WiFi': false,
    'Parking': false,
    'Laundry': false,
    'AC': false,
    'Mess Facility': false,
    'House Keeping': false,
    'Furnished': false,
    'Unfurnished': false,
  };

  // Property type options
  final List<String> _propertyTypes = [
    'Apartment',
    'House',
    'Villa',
    'PG/Hostel',
    'Others'
  ];

  // Room type options
  final List<String> _roomTypes = [
    '1RK',
    '1BHK',
    '2BHK',
    '3BHK',
    '4BHK',
    'Studio'
  ];

  // Images
  List<dynamic> _existingImages = [];
  List<XFile> _newImages = [];
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPropertyData();
  }

  void _loadPropertyData() {
    // Load existing property data into form
    final property = widget.property;

    _titleController.text = property['title']?.toString() ?? '';
    _priceController.text = property['price']?.toString() ?? '';
    _addressController.text = property['address']?.toString() ?? '';
    _descriptionController.text = property['description']?.toString() ?? '';
    _squareFootageController.text = property['squareFootage']?.toString() ?? '';
    _cityController.text = property['city']?.toString() ?? '';
    _stateController.text = property['state']?.toString() ?? '';
    _pincodeController.text = property['pincode']?.toString() ?? '';

    setState(() {
      _isAvailable = property['isAvailable'] == true;
      _isMaleAllowed = property['maleAllowed'] == true;
      _isFemaleAllowed = property['femaleAllowed'] == true;
      _propertyType = property['propertyType']?.toString() ?? 'Apartment';
      _bedrooms = property['bedrooms'] ?? 1;
      _bathrooms = property['bathrooms'] ?? 1;
      _roomType = property['roomType']?.toString() ?? '1BHK';

      // Load amenities if available
      if (property['amenities'] != null && property['amenities'] is List) {
        List<dynamic> amenitiesList = property['amenities'];
        // Reset all amenities to false first
        _amenities.updateAll((key, value) => false);
        // Then set the ones that are in the list to true
        for (var amenity in amenitiesList) {
          if (_amenities.containsKey(amenity)) {
            _amenities[amenity] = true;
          }
        }
      }

      // Load existing images
      if (property['images'] != null && property['images'] is List) {
        _existingImages = List<String>.from(property['images']);
      }
    });
  }

  Future<void> _pickImages() async {
    final List<XFile> pickedImages = await _imagePicker.pickMultiImage();

    if (pickedImages.isNotEmpty) {
      // Check image sizes
      for (var image in pickedImages) {
        final fileSize = await File(image.path).length();
        final fileSizeInMB = fileSize / (1024 * 1024);

        // Cloudinary free plan has a 10MB limit
        if (fileSizeInMB > 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image ${image.name} exceeds 10MB limit')),
          );
        } else {
          setState(() {
            _newImages.add(image);
          });
        }
      }
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<void> _updateProperty() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text("Updating property..."),
                ],
              ),
            );
          },
        );

        // Prepare property data regardless of availability change
        Map<String, dynamic> propertyData = {
          'title': _titleController.text,
          'price': int.tryParse(_priceController.text) ?? 0,
          'address': _addressController.text,
          'city': _cityController.text,
          'state': _stateController.text,
          'pincode': _pincodeController.text,
          'description': _descriptionController.text,
          'squareFootage': int.tryParse(_squareFootageController.text) ?? 0,
          'propertyType': _propertyType,
          'bedrooms': _bedrooms,
          'bathrooms': _bathrooms,
          'roomType': _roomType,
          'isAvailable': _isAvailable,
          'maleAllowed': _isMaleAllowed,
          'femaleAllowed': _isFemaleAllowed,
          'amenities': _amenities.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList(),
          'images': _existingImages, // Keep existing images
          'keepExistingImages':
              true, // Flag to indicate we want to keep existing images
        };

        // Convert new images to File objects
        List<File>? newImageFiles;
        if (_newImages.isNotEmpty) {
          newImageFiles = _newImages.map((xFile) => File(xFile.path)).toList();
        }

        // Check if property status changed
        bool wasAvailable = widget.property['isAvailable'] == true;

        // If property availability status has changed
        if (wasAvailable != _isAvailable) {
          // If property was available before and is now being marked as unavailable
          if (wasAvailable && !_isAvailable) {
            // Call the enhanced API method that handles both status change and updates
            await Api.markPropertyAsUnavailable(widget.property['id'],
                propertyData, newImageFiles, null // No new video for now
                );

            // Close loading dialog and show success message
            Navigator.of(context).pop();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Property updated and marked as unavailable')),
            );

            // Go back to property list
            Navigator.of(context)
                .pop(true); // Return true to indicate update was successful
          }
          // If property was unavailable before and is now being marked as available
          else if (!wasAvailable && _isAvailable) {
            // Call the enhanced API method that handles both status change and updates
            await Api.markPropertyAsAvailable(widget.property['id'],
                propertyData, newImageFiles, null // No new video for now
                );

            // Close loading dialog and show success message
            Navigator.of(context).pop();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Property updated and marked as available')),
            );

            // Go back to property list
            Navigator.of(context)
                .pop(true); // Return true to indicate update was successful
          }
        } else {
          // If property status didn't change, proceed with normal update
          // Update property in Firestore
          await Api.updateProperty(
            widget.property['id'],
            propertyData,
            newImageFiles,
            null, // No new video for now
          );

          // Close loading dialog and show success message
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Property updated successfully')),
          );

          // Go back to property list
          Navigator.of(context)
              .pop(true); // Return true to indicate update was successful
        }
      } catch (e) {
        // Close loading dialog if open
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating property: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteProperty() async {
    // Store context reference before any async operations
    final BuildContext currentContext = context;

    // Show confirmation dialog
    bool? confirmDelete = await showDialog<bool>(
      context: currentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Delete Property'),
          content: Text(
              'Are you sure you want to delete this property? This action cannot be undone.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false); // Return false for cancel
              },
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // Return true for delete
              },
            ),
          ],
        );
      },
    );

    // If user canceled or dialog was dismissed
    if (confirmDelete != true) return;

    // Create a separate loading dialog controller
    BuildContext? loadingDialogContext;

    // Show loading dialog and save its context
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        loadingDialogContext = dialogContext;
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Deleting property..."),
            ],
          ),
        );
      },
    );

    try {
      // Delete the property
      await Api.deleteProperty(widget.property['id']);

      // Close loading dialog safely
      if (loadingDialogContext != null &&
          Navigator.canPop(loadingDialogContext!)) {
        Navigator.pop(loadingDialogContext!);
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Property deleted successfully')),
        );

        // Return to property list safely
        Navigator.of(currentContext)
            .pop(true); // Return true to indicate refresh needed
      }
    } catch (e) {
      // Close loading dialog safely
      if (loadingDialogContext != null &&
          Navigator.canPop(loadingDialogContext!)) {
        Navigator.pop(loadingDialogContext!);
      }

      // Show error message if the widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Error deleting property: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Edit Property'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Property Images Section
              _buildImagesSection(),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Property Title
                    _buildSectionHeader('Property Title'),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
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
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),

                    // Price
                    _buildSectionHeader('Price'),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 55,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(12)),
                            color: Colors.grey[50],
                          ),
                          child: Text('₹', style: TextStyle(fontSize: 18)),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.horizontal(
                                    right: Radius.circular(12)),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.horizontal(
                                    right: Radius.circular(12)),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.horizontal(
                                    right: Radius.circular(12)),
                                borderSide:
                                    BorderSide(color: AppConfig.primaryColor),
                              ),
                              hintText: 'Enter price',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a price';
                              }
                              return null;
                            },
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          height: 60,
                          alignment: Alignment.center,
                          child: Text('/month'),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Location
                    _buildSectionHeader('Address'),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        prefixIcon:
                            Icon(Icons.location_on, color: Colors.grey[600]),
                        hintText: 'Address cannot be changed',
                        helperText:
                            'Address cannot be modified once property is created',
                        filled: true,
                        fillColor: Colors.grey[200],
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
                      enabled:
                          false, // Disabled as the address cannot be changed
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an address';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),

                    // Available Switch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Available',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                        Switch(
                          value: _isAvailable,
                          onChanged: (value) {
                            setState(() {
                              _isAvailable = value;
                            });
                          },
                          activeColor: AppConfig.primaryColor,
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Bedrooms and Bathrooms
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bedrooms',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: AppConfig.primaryVariant)),
                              SizedBox(height: 8),
                              Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[50],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove,
                                          color: AppConfig.primaryColor),
                                      onPressed: _bedrooms > 1
                                          ? () {
                                              setState(() {
                                                _bedrooms--;
                                              });
                                            }
                                          : null,
                                    ),
                                    Text('$_bedrooms',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500)),
                                    IconButton(
                                      icon: Icon(Icons.add,
                                          color: AppConfig.primaryColor),
                                      onPressed: () {
                                        setState(() {
                                          _bedrooms++;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bathrooms',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: AppConfig.primaryVariant)),
                              SizedBox(height: 8),
                              Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[50],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove,
                                          color: AppConfig.primaryColor),
                                      onPressed: _bathrooms > 1
                                          ? () {
                                              setState(() {
                                                _bathrooms--;
                                              });
                                            }
                                          : null,
                                    ),
                                    Text('$_bathrooms',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500)),
                                    IconButton(
                                      icon: Icon(Icons.add,
                                          color: AppConfig.primaryColor),
                                      onPressed: () {
                                        setState(() {
                                          _bathrooms++;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Square Footage
                    _buildSectionHeader('Square Footage'),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _squareFootageController,
                            decoration: InputDecoration(
                              hintText: 'Enter square footage',
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: AppConfig.primaryColor),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter square footage';
                              }
                              return null;
                            },
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          height: 60,
                          alignment: Alignment.center,
                          child: Text('sq ft'),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Property Type
                    _buildSectionHeader('Property Type'),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[50],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _propertyType,
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down,
                              color: AppConfig.primaryColor),
                          items: _propertyTypes.map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _propertyType = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Room Type
                    _buildSectionHeader('Room Type'),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[50],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _roomType,
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down,
                              color: AppConfig.primaryColor),
                          items: _roomTypes.map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _roomType = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Description
                    _buildSectionHeader('Description'),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        hintText: 'Describe your property...',
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
                      maxLines: 5,
                    ),
                    SizedBox(height: 24),

                    // Gender Allowed
                    _buildSectionHeader('Gender Allowed'),
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
                                border: Border.all(
                                  color: _isMaleAllowed
                                      ? AppConfig.primaryColor
                                      : Colors.grey[300]!,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.male,
                                    color: _isMaleAllowed
                                        ? AppConfig.primaryColor
                                        : Colors.grey[600],
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Male',
                                    style: TextStyle(
                                      color: _isMaleAllowed
                                          ? AppConfig.primaryColor
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
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
                                border: Border.all(
                                  color: _isFemaleAllowed
                                      ? AppConfig.primaryColor
                                      : Colors.grey[300]!,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.female,
                                    color: _isFemaleAllowed
                                        ? AppConfig.primaryColor
                                        : Colors.grey[600],
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Female',
                                    style: TextStyle(
                                      color: _isFemaleAllowed
                                          ? AppConfig.primaryColor
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Amenities
                    _buildSectionHeader('Amenities'),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _amenities.entries.map((entry) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _amenities[entry.key] = !entry.value;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
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
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _updateProperty,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Save Changes',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Delete Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton(
                        onPressed: _deleteProperty,
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.red),
                          ),
                        ),
                        child: Text(
                          'Delete Property',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                              fontWeight: FontWeight.bold),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppConfig.primaryVariant),
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

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main image preview or placeholder
        Container(
          height: 250,
          width: double.infinity,
          child: _existingImages.isNotEmpty || _newImages.isNotEmpty
              ? Stack(
                  children: [
                    // Show first image (either existing or new)
                    Container(
                      width: double.infinity,
                      child: _existingImages.isNotEmpty
                          ? Image.network(
                              _existingImages[0].toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(
                                      child:
                                          Icon(Icons.broken_image, size: 50)),
                            )
                          : _newImages.isNotEmpty
                              ? Image.file(
                                  File(_newImages[0].path),
                                  fit: BoxFit.cover,
                                )
                              : Container(),
                    ),

                    // Camera button overlay
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton(
                        onPressed: _pickImages,
                        backgroundColor: Colors.white.withOpacity(0.8),
                        child: Icon(Icons.camera_alt, color: Colors.black),
                      ),
                    ),
                  ],
                )
              : GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 50, color: Colors.grey[400]),
                          SizedBox(height: 10),
                          Text("Add Photos",
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ),
                ),
        ),

        // Thumbnail images
        Container(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.all(8),
            children: [
              // Existing images
              ..._existingImages.asMap().entries.map((entry) {
                final index = entry.key;
                final imageUrl = entry.value.toString();

                return Container(
                  width: 80,
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Center(child: Icon(Icons.broken_image)),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _removeExistingImage(index),
                          child: Container(
                            color: Colors.black.withOpacity(0.5),
                            child: Icon(Icons.close,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // New images
              ..._newImages.asMap().entries.map((entry) {
                final index = entry.key;
                final image = entry.value;

                return Container(
                  width: 80,
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(image.path),
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _removeNewImage(index),
                          child: Container(
                            color: Colors.black.withOpacity(0.5),
                            child: Icon(Icons.close,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            "New",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Add more images button
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Icon(Icons.add_photo_alternate, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "Maximum 8 photos",
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _squareFootageController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }
}
