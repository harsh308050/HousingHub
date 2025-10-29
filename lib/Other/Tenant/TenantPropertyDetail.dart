import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Helper/Models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Chat/ChatScreen.dart';
import 'BookingScreen.dart';

class TenantPropertyDetail extends StatefulWidget {
  final String? propertyId;
  final String? price;
  final String? location;
  final String? imagePath;
  final Map<String, dynamic>? propertyData;

  const TenantPropertyDetail({
    Key? key,
    this.propertyId,
    this.price,
    this.location,
    this.imagePath,
    this.propertyData,
  }) : super(key: key);

  @override
  State<TenantPropertyDetail> createState() => _TenantPropertyDetailState();
}

class _TenantPropertyDetailState extends State<TenantPropertyDetail>
    with TickerProviderStateMixin {
  bool _isSaved = false;
  late TabController _tabController;
  int _currentMediaIndex = 0; // unified index for images + optional video
  bool _isVideoSelected = false;
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoFuture;
  // Availability state
  bool _isUnavailable = false;
  bool _isDeleted = false; // NEW: Track if property is deleted
  bool _isCheckingProperty = true; // NEW: Track if checking property existence
  // Note: we don't currently render a loading state for availability check

  // Sample images for the thumbnail gallery
  List<String> roomImages = [
    'https://images.pexels.com/photos/106399/pexels-photo-106399.jpeg',
    'https://images.pexels.com/photos/1457847/pexels-photo-1457847.jpeg',
    'https://images.pexels.com/photos/1571460/pexels-photo-1571460.jpeg',
    'https://images.pexels.com/photos/1643383/pexels-photo-1643383.jpeg',
  ];

  // List to store property amenities
  List<Map<String, dynamic>> amenitiesList = [];

  // Fetched owner display name and profile picture (from Owners collection)
  String ownerName = '';
  String ownerProfilePicture = '';

  // Map controller and markers
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Check if property exists first
    _checkPropertyExists();

    // Load property data
    _loadPropertyData();
    _checkAvailability();
    _checkIfSaved();
    _trackPropertyView();

    // Listen for tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  Future<void> _checkPropertyExists() async {
    try {
      final propertyId = widget.propertyData?['id'] ?? widget.propertyId;
      final ownerEmail = widget.propertyData?['ownerEmail']?.toString();

      if (propertyId == null || ownerEmail == null || ownerEmail.isEmpty) {
        setState(() {
          _isCheckingProperty = false;
        });
        return;
      }

      // Check if property still exists in Firestore
      final propertyData = await Api.getPropertyById(ownerEmail, propertyId);

      if (mounted) {
        setState(() {
          _isDeleted = (propertyData == null);
          _isCheckingProperty = false;
        });
      }
    } catch (e) {
      print('Error checking if property exists: $e');
      if (mounted) {
        setState(() {
          _isCheckingProperty = false;
        });
      }
    }
  }

  Future<void> _checkIfSaved() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final propertyId = widget.propertyData?['id'] ?? widget.propertyId;
      if (user?.email != null && propertyId != null) {
        final saved = await Api.isPropertySaved(
            tenantEmail: user!.email!, propertyId: propertyId);
        if (mounted) {
          setState(() => _isSaved = saved);
        }
      }
    } catch (e) {
      // silent fail
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

  Future<void> _trackPropertyView() async {
    try {
      final user = FirebaseAuth.instance.currentUser?.email;
      final propertyId = widget.propertyData?['id'] ?? widget.propertyId;
      if (user != null && propertyId != null) {
        // Create a map with all the property data needed for display
        final propertyData = Map<String, dynamic>.from(
            widget.propertyData ?? <String, dynamic>{});

        // Ensure we have the minimum required data
        if (!propertyData.containsKey('id')) {
          propertyData['id'] = propertyId;
        }

        // Add other essential display fields if available from widget parameters
        if (widget.price != null && !propertyData.containsKey('price')) {
          propertyData['price'] = widget.price;
        }

        if (widget.location != null && !propertyData.containsKey('location')) {
          propertyData['location'] = widget.location;
        }

        if (widget.imagePath != null && !propertyData.containsKey('images')) {
          propertyData['images'] = [widget.imagePath];
        }

        // Ensure ownerEmail is present for aggregation
        final ownerEmail = widget.propertyData?['ownerEmail']?.toString();
        if (ownerEmail != null && ownerEmail.isNotEmpty) {
          propertyData['ownerEmail'] = ownerEmail;
        }

        // Record this view in Firestore
        await Api.addRecentlyViewedProperty(
          tenantEmail: user,
          propertyId: propertyId,
          propertyData: propertyData,
        );

        // Track unique view for owner aggregation
        if (ownerEmail != null && ownerEmail.isNotEmpty) {
          await Api.trackUniqueOwnerView(
            ownerEmail: ownerEmail,
            tenantEmail: user,
            propertyId: propertyId,
          );
        }
      }
    } catch (e) {
      // silent fail for tracking
      print('Error tracking property view: $e');
    }
  }

  void _loadPropertyData() {
    print('=== Loading Property Data ===');
    print('Property Data: ${widget.propertyData}');
    print('Image Path: ${widget.imagePath}');
    
    // Load images if available
    if (widget.propertyData != null &&
        widget.propertyData!['images'] != null &&
        widget.propertyData!['images'] is List &&
        (widget.propertyData!['images'] as List).isNotEmpty) {
      List<String> imagesList = List<String>.from(widget.propertyData!['images']);
      print('Original images list: $imagesList');
      
      // Filter out empty or invalid URLs
      imagesList = imagesList.where((url) => url.isNotEmpty && Uri.tryParse(url) != null).toList();
      print('Filtered images list: $imagesList');
      
      if (imagesList.isNotEmpty) {
        roomImages = imagesList;
        print('Using property images: $roomImages');
      }
    } else if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      roomImages = [widget.imagePath!];
      print('Using widget imagePath: $roomImages');
    }
    
    // Ensure we always have at least default images as fallback
    if (roomImages.isEmpty) {
      roomImages = [
        'https://images.pexels.com/photos/106399/pexels-photo-106399.jpeg',
        'https://images.pexels.com/photos/1457847/pexels-photo-1457847.jpeg',
        'https://images.pexels.com/photos/1571460/pexels-photo-1571460.jpeg',
        'https://images.pexels.com/photos/1643383/pexels-photo-1643383.jpeg',
      ];
      print('Using fallback images: $roomImages');
    }
    
    print('Final roomImages: $roomImages');
    print('============================');

    // Parse amenities from property data
    if (widget.propertyData != null &&
        widget.propertyData!['amenities'] != null) {
      final amenities = widget.propertyData!['amenities'];

      // Extract amenities from the property data
      if (amenities is List) {
        amenitiesList = _parseAmenities(amenities);
      }
    }

    // Setup map marker if coordinates available
    final lat = widget.propertyData?['latitude'];
    final lng = widget.propertyData?['longitude'];
    if (lat != null && lng != null) {
      try {
        final double latitude =
            lat is num ? lat.toDouble() : double.parse(lat.toString());
        final double longitude =
            lng is num ? lng.toDouble() : double.parse(lng.toString());
        _markers = {
          Marker(
            markerId: MarkerId('property_marker'),
            position: LatLng(latitude, longitude),
          )
        };
      } catch (e) {
        print('Error parsing coordinates: $e');
      }
    }

    // Fetch owner display name and profile picture from Owners collection using ownerEmail
    final ownerEmail = widget.propertyData?['ownerEmail'] as String?;
    if (ownerEmail != null && ownerEmail.isNotEmpty) {
      Api.getOwnerDetailsByEmail(ownerEmail).then((ownerData) {
        if (ownerData != null) {
          setState(() {
            ownerName = ownerData['fullName'] ??
                ownerData['firstName'] ??
                ownerEmail.split('@')[0];
            ownerProfilePicture = ownerData['profilePicture'] ?? '';
          });
        }
      }).catchError((e) {
        print('Error fetching owner details: $e');
      });
    }

    // If ownerName still not found, try fallback using ownerId (some properties store owner uid)
    final ownerId = widget.propertyData?['ownerId'] as String?;
    if ((ownerEmail == null || ownerEmail.isEmpty) &&
        ownerId != null &&
        ownerId.isNotEmpty) {
      Api.getUserDetailsByUID(ownerId).then((userData) {
        if (userData != null) {
          setState(() {
            ownerName =
                userData['fullName'] ?? userData['firstName'] ?? ownerId;
            ownerProfilePicture = userData['profilePicture'] ?? '';
          });
        }
      }).catchError((e) {
        print('Error fetching owner by UID fallback: $e');
      });
    }
  }

  Future<void> _checkAvailability() async {
    try {
      final propertyId = widget.propertyData?['id'] ?? widget.propertyId;
      final ownerEmail = widget.propertyData?['ownerEmail']?.toString();
      if (propertyId == null || ownerEmail == null || ownerEmail.isEmpty) {
        return;
      }

      // If property data explicitly says unavailable, respect it
      if ((widget.propertyData?['isAvailable'] == false) ||
          (widget.propertyData?['available'] == false)) {
        setState(() {
          _isUnavailable = true;
        });
        return;
      }

      // no-op loading flag
      final data = await Api.getPropertyById(ownerEmail, propertyId,
          checkUnavailable: true);
      if (!mounted) return;
      setState(() {
        // If found and isAvailable is not true, mark as unavailable
        _isUnavailable = (data != null && data['isAvailable'] != true);
      });
    } catch (e) {
      // Fail open (allow booking) but log error
      debugPrint('Error checking availability: $e');
      if (!mounted) return;
    }
  }

  List<Map<String, dynamic>> _parseAmenities(List amenities) {
    final iconMap = {
      'WiFi': Icons.wifi,
      'Laundry': Icons.local_laundry_service,
      'AC': Icons.ac_unit,
      'House Keeping': Icons.cleaning_services,
      'Furnished': Icons.chair,
      'Parking': Icons.local_parking,
      'Unfurnished': Icons.other_houses_outlined,
      'Mess Facility': Icons.restaurant,
    };

    return amenities.map((amenity) {
      if (amenity is String) {
        final IconData icon = iconMap[amenity] ?? Icons.check_circle;
        return {'icon': icon, 'name': amenity};
      }
      return {'icon': Icons.check_circle, 'name': amenity.toString()};
    }).toList();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking if property exists
    if (_isCheckingProperty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Property Details'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppConfig.primaryColor),
              ),
              SizedBox(height: 16),
              Text(
                'Loading property details...',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Show "Property Deleted" screen if property no longer exists
    if (_isDeleted) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Property Not Available'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.home_work_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 24),
                Text(
                  'Property No Longer Available',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'This property has been removed by the owner and is no longer available for viewing or booking.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back),
                  label: Text('Back to Home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Debug logging to understand the issue
    print('=== TenantPropertyDetail Debug ===');
    print('Property ID: ${widget.propertyId}');
    print('Property Data Keys: ${widget.propertyData?.keys.toList()}');
    print('Property Data: ${widget.propertyData}');
    print('Room Images: $roomImages');
    print('===================================');

    // Early return with error screen if critical data is missing
    if (widget.propertyData == null && widget.propertyId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Property Details'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Property information not found',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Create working data with fallback values
    final Map<String, dynamic> workingPropertyData = Map<String, dynamic>.from(widget.propertyData ?? {});
    
    // If property data is empty or missing critical fields, populate fallback data
    if (workingPropertyData.isEmpty || !workingPropertyData.containsKey('title')) {
      print('WARNING: Property data is empty or incomplete, using fallback');
      workingPropertyData.addAll({
        'title': workingPropertyData['title'] ?? 'Property Details',
        'price': workingPropertyData['price'] ?? widget.price ?? 'N/A',
        'address': workingPropertyData['address'] ?? widget.location ?? 'Address not available',
        'city': workingPropertyData['city'] ?? 'City not specified',
        'state': workingPropertyData['state'] ?? 'State not specified',
        'description': workingPropertyData['description'] ?? 'Property information is being loaded...',
        'images': workingPropertyData['images'] ?? (roomImages.isNotEmpty ? roomImages : [
          'https://images.pexels.com/photos/106399/pexels-photo-106399.jpeg'
        ]),
        'propertyType': workingPropertyData['propertyType'] ?? 'House',
        'roomType': workingPropertyData['roomType'] ?? 'N/A',
        'femaleAllowed': workingPropertyData['femaleAllowed'] ?? false,
        'maleAllowed': workingPropertyData['maleAllowed'] ?? false,
        'squareFootage': workingPropertyData['squareFootage'] ?? 'Not specified',
        'bedrooms': workingPropertyData['bedrooms'] ?? 1,
        'bathrooms': workingPropertyData['bathrooms'] ?? 1,
        'listingType': workingPropertyData['listingType'] ?? 'rent',
      });
    }

    final height = MediaQuery.of(context).size.height;
    final videoUrl = workingPropertyData['video'] ?? workingPropertyData['videoUrl'];

    // Build combined media list: images + (video placeholder at end if exists)
    final int imageCount = roomImages.length;
    final bool hasVideo = videoUrl != null && videoUrl.toString().isNotEmpty;
    final int totalMediaItems = hasVideo ? imageCount + 1 : imageCount;
    
    // Extract property data from working data
    final propertyType = workingPropertyData['propertyType'] ?? 'House';
    final roomType = workingPropertyData['roomType'] ?? 'N/A';
    final femaleAllowed = workingPropertyData['femaleAllowed'] ?? false;
    final maleAllowed = workingPropertyData['maleAllowed'] ?? false;
    final propertyTitle = workingPropertyData['title'] ?? 'Property Details';
    final formattedPrice = _buildPriceText(workingPropertyData);
    final address = workingPropertyData['address'] ??
        widget.location ??
        'Address not specified';
    final city = workingPropertyData['city'] ?? 'City not specified';
    final state = workingPropertyData['state'] ?? 'State not specified';
    final pincode = workingPropertyData['pincode'] ?? '';
    final fullAddress =
        '$address, $city, $state ${pincode.isNotEmpty ? '- $pincode' : ''}';
    final squareFootage =
        workingPropertyData['squareFootage']?.toString() ?? 'Not specified';
    final bedrooms = workingPropertyData['bedrooms']?.toString() ?? '1';
    final bathrooms = workingPropertyData['bathrooms']?.toString() ?? '1';
    final description =
        workingPropertyData['description'] ?? 'No description available';

    // Sale-specific fields  
    final furnishingStatus = workingPropertyData['furnishingStatus'] ?? 'Not specified';
    final propertyAge = workingPropertyData['propertyAge'] != null 
        ? '${workingPropertyData['propertyAge']} years' 
        : 'Not specified';
    final ownershipType = workingPropertyData['ownershipType'] ?? 'Not specified';

    final ownerEmail = workingPropertyData['ownerEmail'] ?? '';
    final createdAt = workingPropertyData['createdAt'] != null
        ? _formatCreatedAt(workingPropertyData['createdAt'])
        : 'Unknown date';
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
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
          propertyTitle,
          style: TextStyle(
              color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          GestureDetector(
            onTap: () => _shareProperty(),
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
                  Icons.share_outlined,
                  size: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 7,
          ),
          GestureDetector(
            onTap: () => _toggleSave(),
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
                  _isSaved ? Icons.favorite : Icons.favorite_border,
                  color: _isSaved ? Colors.red : Colors.black,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 16,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main media display (image or video)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _isVideoSelected && hasVideo
                  ? Stack(
                      children: [
                        FutureBuilder(
                          future: _initializeVideoFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
                              return GestureDetector(
                                onTap: () {
                                  if (_videoController == null) return;
                                  setState(() {
                                    if (_videoController!.value.isPlaying) {
                                      _videoController!.pause();
                                    } else {
                                      _videoController!.play();
                                    }
                                  });
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    VideoPlayer(_videoController!),
                                    if (!_videoController!.value.isPlaying)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.35),
                                          shape: BoxShape.circle,
                                        ),
                                        padding: EdgeInsets.all(16),
                                        child: Icon(Icons.play_arrow,
                                            size: 48, color: Colors.white),
                                      ),
                                  ],
                                ),
                              );
                            } else {
                              return Center(child: CircularProgressIndicator());
                            }
                          },
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: _buildMediaCounter(totalMediaItems),
                        )
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Builder(
                          builder: (context) {
                            // Ensure we always have a valid image URL
                            String imageUrl = '';
                            if (roomImages.isNotEmpty && _currentMediaIndex < roomImages.length) {
                              imageUrl = roomImages[_currentMediaIndex];
                            } else if (roomImages.isNotEmpty) {
                              imageUrl = roomImages.first;
                            }
                            
                            // If still empty, use a placeholder
                            if (imageUrl.isEmpty) {
                              imageUrl = 'https://images.pexels.com/photos/106399/pexels-photo-106399.jpeg';
                            }
                            
                            print('Displaying image: $imageUrl');
                            
                            return Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print('Image load error: $error');
                                return Container(
                                  color: Colors.grey[300],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image,
                                          size: 50, color: Colors.grey[500]),
                                      SizedBox(height: 8),
                                      Text(
                                        'Image not available',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: _buildMediaCounter(totalMediaItems),
                        )
                      ],
                    ),
            ),

            // Media thumbnails (images + optional video)
            Container(
              height: 80,
              padding: EdgeInsets.symmetric(vertical: 10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: totalMediaItems,
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final bool isVideoThumb =
                      hasVideo && index == totalMediaItems - 1;
                  final bool isSelected = _currentMediaIndex == index &&
                      _isVideoSelected == isVideoThumb;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isVideoThumb) {
                          _isVideoSelected = true;
                          _currentMediaIndex = index;
                          if (_videoController == null ||
                              _videoController!.dataSource != videoUrl) {
                            _videoController?.dispose();
                            _videoController = VideoPlayerController.networkUrl(
                                Uri.parse(videoUrl));
                            _initializeVideoFuture =
                                _videoController!.initialize().then((_) {
                              setState(() {});
                            });
                          }
                        } else {
                          _isVideoSelected = false;
                          _currentMediaIndex = index;
                          // pause video if switching away
                          _videoController?.pause();
                        }
                      });
                    },
                    child: Container(
                      width: 80,
                      margin: EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? AppConfig.primaryColor
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[300],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: isVideoThumb
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Use first image as placeholder background if available
                                  if (roomImages.isNotEmpty)
                                    Image.network(
                                      roomImages.first,
                                      fit: BoxFit.cover,
                                    )
                                  else
                                    Container(color: Colors.black12),
                                  Container(
                                    color: Colors.black26,
                                  ),
                                  Center(
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ],
                              )
                            : Image.network(
                                roomImages[index],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                      child: Icon(Icons.image_not_supported));
                                },
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Price section
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price with badges
                  Row(
                    children: [
                      Text(
                        formattedPrice,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // Property type badges
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          propertyType,
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          femaleAllowed && !maleAllowed
                              ? 'Female Only'
                              : (maleAllowed && !femaleAllowed
                                  ? 'Male Only'
                                  : 'Open to All'),
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Location with icon
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 18, color: Colors.grey[700]),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Bar for different sections
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppConfig.primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppConfig.primaryColor,
                tabs: [
                  Tab(text: 'About'),
                  Tab(text: 'Amenities'),
                  Tab(text: 'Location'),
                ],
              ),
            ),

            // Tab content
            Container(
              padding: EdgeInsets.all(16),
              constraints: BoxConstraints(minHeight: 300),
              child: [
                // About tab
                _buildAboutTab(description, roomType, propertyType,
                    squareFootage, bedrooms, bathrooms, furnishingStatus, propertyAge, ownershipType, workingPropertyData),

                // Amenities tab
                _buildAmenitiesTab(),

                // Location tab
                _buildLocationTab(fullAddress, city, state),
              ][_tabController.index],
            ),

            // Add padding at the bottom to ensure content isn't hidden behind the bottomSheet
            SizedBox(height: 160),
          ],
        ),
      ),

      // Bottom action buttons
      bottomSheet: Container(
        height: height * 0.18,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            spacing: height * 0.01,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: ownerProfilePicture.isNotEmpty 
                        ? Colors.grey[300] 
                        : AppConfig.primaryColor.withOpacity(0.1),
                    backgroundImage: ownerProfilePicture.isNotEmpty
                        ? NetworkImage(ownerProfilePicture)
                        : null,
                    child: ownerProfilePicture.isEmpty
                        ? Text(
                            _getInitials(ownerName),
                            style: TextStyle(
                              color: AppConfig.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                ownerName.isNotEmpty
                                    ? ownerName
                                    : (ownerEmail.isNotEmpty
                                        ? ownerEmail
                                        : 'Property Owner'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Listed on $createdAt',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Ratings removed per request
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  // Chat Now button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final me = FirebaseAuth.instance.currentUser?.email;
                        final ownerEmail =
                            widget.propertyData?['ownerEmail']?.toString();
                        if (me == null ||
                            ownerEmail == null ||
                            ownerEmail.isEmpty) {
                          Models.showWarningSnackBar(
                              context, 'Sign in to chat or owner info missing');
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              currentEmail: me,
                              otherEmail: ownerEmail,
                              otherName:
                                  widget.propertyData?['ownerName']?.toString(),
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppConfig.primaryColor,
                        side: BorderSide(color: AppConfig.primaryColor),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Chat Now',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  SizedBox(width: 12),

                  // Book Now button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_isUnavailable) {
                          Models.showWarningSnackBar(context,
                              'This property is not available.');
                          return;
                        }
                        
                        final listingType = workingPropertyData['listingType'] ?? 'rent';
                        if (listingType == 'sale') {
                          _contactOwner();
                        } else {
                          _navigateToBooking();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isUnavailable
                            ? Colors.grey
                            : AppConfig.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _isUnavailable 
                          ? 'Not Available' 
                          : (workingPropertyData['listingType'] ?? 'rent') == 'sale'
                            ? 'Contact Owner'
                            : 'Book Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutTab(
      String description,
      String roomType,
      String propertyType,
      String squareFootage,
      String bedrooms,
      String bathrooms,
      String furnishingStatus,
      String propertyAge,
      String ownershipType,
      Map<String, dynamic> propertyData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        // Room features
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildFeatureBox(Icons.king_bed_outlined, '$bedrooms Beds'),
            _buildFeatureBox(Icons.bathroom_outlined, '$bathrooms Baths'),
            _buildFeatureBox(Icons.square_foot, '$squareFootage sq.ft'),
            _buildFeatureBox(Icons.house, roomType),
          ],
        ),
        SizedBox(height: 20),
        // More details
        Text(
          'Room Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        _buildDetailRow('Room Type', roomType),
        _buildDetailRow('Property Type', propertyType),
        _buildDetailRow('Bedrooms', bedrooms),
        _buildDetailRow('Bathrooms', bathrooms),
        _buildDetailRow('Square Footage', '$squareFootage sq.ft'),
        
        // Conditional fields based on listing type
        if ((propertyData['listingType'] ?? 'rent') == 'sale') ...[
          _buildDetailRow('Furnishing Status', furnishingStatus),
          _buildDetailRow('Property Age', propertyAge),
          _buildDetailRow('Ownership Type', ownershipType),
        ] else ...[
          _buildDetailRow(
              'Security Deposit',
              propertyData['securityDeposit'] != null
                  ? '₹${Models.formatIndianCurrency(propertyData['securityDeposit'].toString())}'
                  : 'Not specified'),
          _buildDetailRow('Minimum Booking Period',
              propertyData['minimumBookingPeriod']?.toString() ?? 'Not specified'),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesTab() {
    // If we have amenities from property data, use those
    if (amenitiesList.isNotEmpty) {
      return GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3,
        ),
        itemCount: amenitiesList.length,
        itemBuilder: (context, index) {
          return Row(
            children: [
              Icon(
                amenitiesList[index]['icon'] as IconData,
                color: AppConfig.primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  amenitiesList[index]['name'] as String,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      );
    } else {
      // Default amenities if none are provided
      final defaultAmenities = [
        {'icon': Icons.wifi, 'name': 'WiFi'},
        {'icon': Icons.local_laundry_service, 'name': 'Laundry'},
        {'icon': Icons.ac_unit, 'name': 'AC'},
        {'icon': Icons.tv, 'name': 'TV'},
        {'icon': Icons.cleaning_services, 'name': 'House Keeping'},
        {'icon': Icons.chair, 'name': 'Furnished'},
      ];

      return GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3,
        ),
        itemCount: defaultAmenities.length,
        itemBuilder: (context, index) {
          return Row(
            children: [
              Icon(
                defaultAmenities[index]['icon'] as IconData,
                color: AppConfig.primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(defaultAmenities[index]['name'] as String),
            ],
          );
        },
      );
    }
  }

  Widget _buildLocationTab(String fullAddress, String city, String state) {
    // Parse coordinates robustly (could be num or String)
    double? latitude;
    double? longitude;
    final latVal = widget.propertyData?['latitude'];
    final lngVal = widget.propertyData?['longitude'];
    try {
      if (latVal != null) {
        latitude = latVal is num
            ? latVal.toDouble()
            : double.tryParse(latVal.toString());
      }
      if (lngVal != null) {
        longitude = lngVal is num
            ? lngVal.toDouble()
            : double.tryParse(lngVal.toString());
      }
    } catch (e) {
      latitude = null;
      longitude = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Map container
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // Use GoogleMap widget when coordinates available
              if (latitude != null && longitude != null)
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(latitude, longitude),
                    zoom: 15,
                  ),
                  markers: _markers,
                  mapType: MapType.normal,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  onMapCreated: (GoogleMapController controller) async {
                    if (!_mapController.isCompleted)
                      _mapController.complete(controller);
                    // Animate camera to marker if available
                    if (_markers.isNotEmpty) {
                      try {
                        final markerPos = _markers.first.position;
                        await controller.animateCamera(
                          CameraUpdate.newLatLngZoom(markerPos, 15),
                        );
                      } catch (e) {
                        // ignore animation errors
                      }
                    }
                  },
                )
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map,
                        size: 40,
                        color: Colors.grey[600],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Location map not available',
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Navigation button
        if (latitude != null && longitude != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                // Open Google Maps with the property location
                final url =
                    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
                launchMapsUrl(url);
              },
              icon: Icon(Icons.directions, size: 20, color: Colors.white),
              label: Text('Navigate to this location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        SizedBox(height: 16),
        Text(
          'Address',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          fullAddress,
          style: TextStyle(
            color: Colors.grey[800],
            height: 1.5,
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.location_on_outlined, color: Colors.grey[700]),
            SizedBox(width: 8),
            Text(
              city + ', ' + state,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureBox(IconData icon, String text) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppConfig.primaryColor,
            size: 22,
          ),
        ),
        SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaCounter(int total) {
    if (total <= 1) return SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${_currentMediaIndex + 1}/$total',
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  // Launch URL in external browser or maps app
  Future<void> launchMapsUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        Models.showErrorSnackBar(context, 'Could not open maps application');
      }
    } catch (e) {
      Models.showErrorSnackBar(context, 'Error launching maps: $e');
    }
  }

  // Format createdAt date from various formats (Timestamp, String, DateTime)
  String _formatCreatedAt(dynamic createdAt) {
    try {
      if (createdAt is Timestamp) {
        return createdAt.toDate().toString().substring(0, 10);
      } else if (createdAt is DateTime) {
        return createdAt.toString().substring(0, 10);
      } else if (createdAt is String) {
        // If it's already a string, try to parse it or use as is
        if (createdAt.length >= 10) {
          return createdAt.substring(0, 10);
        }
        return createdAt;
      }
      return 'Unknown date';
    } catch (e) {
      return 'Unknown date';
    }
  }

  // Build price text based on listing type (rent or sale)
  String _buildPriceText(Map<String, dynamic> propertyData) {
    final listingType = propertyData['listingType'] ?? 'rent';
    
    if (listingType == 'sale') {
      final salePrice = propertyData['salePrice'] ?? propertyData['price'] ?? 'N/A';
      if (salePrice == 'N/A') return '₹N/A';
      String priceValue = salePrice.toString().replaceAll('₹', '').replaceAll(',', '').trim();
      return '₹${Models.formatIndianCurrency(priceValue)}';
    } else {
      final rentPrice = propertyData['price'] ?? widget.price ?? 'N/A';
      if (rentPrice == 'N/A') return '₹N/A/month';
      String priceValue = rentPrice.toString().replaceAll('₹', '').replaceAll('/month', '').replaceAll(',', '').trim();
      return '₹${Models.formatIndianCurrency(priceValue)}/month';
    }
  }

  // Share property with Google Maps link
  Future<void> _shareProperty() async {
    try {
      final title = widget.propertyData?['title'] ?? 'Property';
      final price = widget.propertyData?['price'] ?? widget.price ?? '';
      final address = widget.propertyData?['address'] ?? widget.location ?? '';
      final lat = widget.propertyData?['latitude'];
      final lng = widget.propertyData?['longitude'];
      String? mapsUrl;
      if (lat != null && lng != null) {
        double? latitude;
        double? longitude;
        try {
          latitude =
              lat is num ? lat.toDouble() : double.tryParse(lat.toString());
          longitude =
              lng is num ? lng.toDouble() : double.tryParse(lng.toString());
        } catch (_) {}
        if (latitude != null && longitude != null) {
          mapsUrl =
              'https://www.google.com/maps/search/?api=1&query=\$latitude,\$longitude';
        }
      }
      final shareText = [
        '$title • $price/month',
        address,
        if (mapsUrl != null) ...['', 'View on Google Maps:', mapsUrl],
      ].join('\n');
      await Share.share(
        shareText,
        subject: 'Check out this property on HousingHub',
      );
    } catch (e) {
      Models.showErrorSnackBar(context, 'Error sharing property: $e');
    }
  }

  Future<void> _toggleSave() async {
    final user = FirebaseAuth.instance.currentUser;
    final propertyId = widget.propertyData?['id'] ?? widget.propertyId;
    if (user?.email == null || propertyId == null) {
      Models.showWarningSnackBar(
          context, 'Please sign in to save properties');
      return;
    }

    final tenantEmail = user!.email!;
    final wasSaved = _isSaved;
    setState(() => _isSaved = !wasSaved); // optimistic

    try {
      if (!wasSaved) {
        // Save
        final data = widget.propertyData ??
            {
              'id': propertyId,
              'title': widget.propertyData?['title'] ?? 'Property',
            };
        await Api.savePropertyForTenant(
            tenantEmail: tenantEmail,
            propertyId: propertyId,
            propertyData: data);
        if (mounted) {
          Models.showSuccessSnackBar(context, 'Property saved');
        }
      } else {
        // Remove
        await Api.removeSavedProperty(
            tenantEmail: tenantEmail, propertyId: propertyId);
        if (mounted) {
          Models.showInfoSnackBar(context, 'Removed from saved');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaved = wasSaved); // revert
        Models.showErrorSnackBar(
            context, 'Error updating saved property: $e');
      }
    }
  }

  Future<void> _navigateToBooking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) {
      Models.showWarningSnackBar(
          context, 'Please sign in to book this property');
      return;
    }

    if (_isUnavailable) {
      Models.showWarningSnackBar(
          context, 'This property is not available for booking.');
      return;
    }

    // Validate required property data
    if (widget.propertyData == null) {
      Models.showErrorSnackBar(
          context, 'Property information is incomplete');
      return;
    }

    try {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => BookingScreen(
            propertyData: widget.propertyData!,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Models.showErrorSnackBar(context, 'Error opening booking: $e');
      }
    }
  }

  Future<void> _contactOwner() async {
    // Validate required property data
    if (widget.propertyData == null) {
      Models.showErrorSnackBar(
          context, 'Property information is incomplete');
      return;
    }

    final ownerEmail = widget.propertyData!['ownerEmail']?.toString();
    if (ownerEmail == null || ownerEmail.isEmpty) {
      Models.showWarningSnackBar(context, 'Owner email not available');
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Fetch owner details from Owners collection
      final ownerData = await Api.getOwnerDetailsByEmail(ownerEmail);
      
      // Hide loading indicator
      if (mounted) Navigator.pop(context);

      if (ownerData == null) {
        if (mounted) {
          Models.showWarningSnackBar(context, 'Owner details not found');
        }
        return;
      }

      final mobileNumber = ownerData['mobileNumber']?.toString();
      if (mobileNumber == null || mobileNumber.isEmpty) {
        if (mounted) {
          Models.showWarningSnackBar(context, 'Owner phone number not available');
        }
        return;
      }

      final Uri phoneUri = Uri(scheme: 'tel', path: mobileNumber);
      
      // Use url_launcher to open the dialer
      await launchUrl(phoneUri);
    } catch (e) {
      // Hide loading indicator if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        Models.showErrorSnackBar(context, 'Error contacting owner: $e');
      }
    }
  }
}
