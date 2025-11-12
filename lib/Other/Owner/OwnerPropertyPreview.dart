import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:housinghub/Helper/Models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OwnerPropertyPreview extends StatefulWidget {
  final Map<String, dynamic> propertyData;

  const OwnerPropertyPreview({
    Key? key,
    required this.propertyData,
  }) : super(key: key);

  @override
  State<OwnerPropertyPreview> createState() => _OwnerPropertyPreviewState();
}

class _OwnerPropertyPreviewState extends State<OwnerPropertyPreview>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentMediaIndex = 0; // unified index for images + optional video
  bool _isVideoSelected = false;
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoFuture;

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

    // Load property data
    _loadPropertyData();

    // Listen for tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  void _loadPropertyData() {
    // Load images if available
    if (widget.propertyData['images'] != null &&
        widget.propertyData['images'] is List &&
        (widget.propertyData['images'] as List).isNotEmpty) {
      roomImages = List<String>.from(widget.propertyData['images']);
    }

    // Parse amenities from property data
    if (widget.propertyData['amenities'] != null) {
      final amenities = widget.propertyData['amenities'];

      // Extract amenities from the property data
      if (amenities is List) {
        amenitiesList = _parseAmenities(amenities);
      }
    }

    // Setup map marker if coordinates available
    final lat = widget.propertyData['latitude'];
    final lng = widget.propertyData['longitude'];
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

    // Get current user as owner
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        ownerName = user.displayName ?? user.email?.split('@')[0] ?? 'Owner';
        ownerProfilePicture = user.photoURL ?? '';
      });
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
    final videoUrl =
        widget.propertyData['video'] ?? widget.propertyData['videoUrl'];

    // Build combined media list: images + (video placeholder at end if exists)
    final int imageCount = roomImages.length;
    final bool hasVideo = videoUrl != null && videoUrl.toString().isNotEmpty;
    final int totalMediaItems = hasVideo ? imageCount + 1 : imageCount;

    // Extract property data
    final propertyType = widget.propertyData['propertyType'] ?? 'House';
    final roomType = widget.propertyData['roomType'] ?? 'N/A';
    final femaleAllowed = widget.propertyData['femaleAllowed'] ?? false;
    final maleAllowed = widget.propertyData['maleAllowed'] ?? false;
    final propertyTitle = widget.propertyData['title'] ?? 'Property Details';
    final formattedPrice = _buildPriceText(widget.propertyData);
    final address = widget.propertyData['address'] ?? 'Address not specified';
    final city = widget.propertyData['city'] ?? 'City not specified';
    final state = widget.propertyData['state'] ?? 'State not specified';
    final pincode = widget.propertyData['pincode'] ?? '';
    final fullAddress =
        '$address, $city, $state ${pincode.isNotEmpty ? '- $pincode' : ''}';
    final squareFootage =
        widget.propertyData['squareFootage']?.toString() ?? 'Not specified';
    final bedrooms = widget.propertyData['bedrooms']?.toString() ?? '1';
    final bathrooms = widget.propertyData['bathrooms']?.toString() ?? '1';
    final description =
        widget.propertyData['description'] ?? 'No description available';
    final availabilityStatus = widget.propertyData['isAvailable'] == true
        ? 'Available'
        : 'Not Available';
    final createdAt = widget.propertyData['createdAt'] != null
        ? _formatCreatedAt(widget.propertyData['createdAt'])
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
          SizedBox(width: 16),
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
                        Image.network(
                          roomImages.isNotEmpty &&
                                  _currentMediaIndex < roomImages.length
                              ? roomImages[_currentMediaIndex]
                              : (roomImages.isNotEmpty ? roomImages.first : ''),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: Center(
                                child: Icon(Icons.broken_image,
                                    size: 50, color: Colors.grey[500]),
                              ),
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
                                  Container(color: Colors.black26),
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

            // Price and availability section
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price with availability badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formattedPrice,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if ((widget.propertyData['listingType'] ?? 'rent') ==
                              'rent')
                            Text(
                              '/month',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      // Availability status badge
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.propertyData['isAvailable'] == true
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.propertyData['isAvailable'] == true
                                ? Colors.green.shade300
                                : Colors.red.shade300,
                          ),
                        ),
                        child: Text(
                          availabilityStatus,
                          style: TextStyle(
                            color: widget.propertyData['isAvailable'] == true
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
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
                    squareFootage, bedrooms, bathrooms),
                // Amenities tab
                _buildAmenitiesTab(),
                // Location tab
                _buildLocationTab(fullAddress, city, state),
              ][_tabController.index],
            ),

            // Owner info section (instead of bottom sheet)
            Container(
              margin: EdgeInsets.all(16),
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ownerName.isNotEmpty ? ownerName : 'Property Owner',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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

            // Add bottom padding
            SizedBox(height: 24),
          ],
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
      String bathrooms) {
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
        if ((widget.propertyData['listingType'] ?? 'rent') == 'sale') ...[
          _buildDetailRow('Furnishing Status',
              widget.propertyData['furnishingStatus'] ?? 'Not specified'),
          _buildDetailRow(
              'Property Age',
              widget.propertyData['propertyAge']?.toString() ??
                  'Not specified'),
          _buildDetailRow('Ownership Type',
              widget.propertyData['ownershipType'] ?? 'Not specified'),
        ] else ...[
          _buildDetailRow(
              'Security Deposit',
              widget.propertyData['securityDeposit'] != null
                  ? '₹${widget.propertyData['securityDeposit']}'
                  : 'Not specified'),
          _buildDetailRow('Minimum Booking Period',
              widget.propertyData['minimumBookingPeriod'] ?? 'Not specified'),
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
    final latVal = widget.propertyData['latitude'];
    final lngVal = widget.propertyData['longitude'];
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

  // Build price text based on listing type
  String _buildPriceText(Map<String, dynamic> propertyData) {
    final listingType = propertyData['listingType'] ?? 'rent';

    if (listingType == 'sale') {
      final salePrice =
          propertyData['salePrice'] ?? propertyData['price'] ?? 'N/A';
      if (salePrice == 'N/A') return '₹N/A';
      String priceValue =
          salePrice.toString().replaceAll('₹', '').replaceAll(',', '').trim();
      return '₹${Models.formatIndianCurrency(priceValue)}';
    } else {
      final rentPrice = propertyData['price'] ?? 'N/A';
      if (rentPrice == 'N/A') return '₹N/A';
      String priceValue =
          rentPrice.toString().replaceAll('₹', '').replaceAll(',', '').trim();
      return '₹${Models.formatIndianCurrency(priceValue)}';
    }
  }

  // Share property with Google Maps link
  Future<void> _shareProperty() async {
    try {
      final title = widget.propertyData['title'] ?? 'Property';
      final formattedPrice = _buildPriceText(widget.propertyData);
      final address = widget.propertyData['address'] ?? '';
      final lat = widget.propertyData['latitude'];
      final lng = widget.propertyData['longitude'];
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
              'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
        }
      }
      final listingType = widget.propertyData['listingType'] ?? 'rent';
      final priceText =
          listingType == 'sale' ? formattedPrice : '$formattedPrice/month';
      final shareText = [
        '$title • $priceText',
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
}
