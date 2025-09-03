import 'package:flutter/material.dart';
import 'package:housinghub/config/AppConfig.dart';

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

class _TenantPropertyDetailState extends State<TenantPropertyDetail> {
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom app bar with property image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: widget.imagePath != null &&
                      widget.imagePath!.startsWith('http')
                  ? Image.network(
                      widget.imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/Logo.png',
                          fit: BoxFit.cover,
                        );
                      },
                    )
                  : Image.asset(
                      'assets/images/Logo.png',
                      fit: BoxFit.cover,
                    ),
            ),
            leading: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.8),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  child: IconButton(
                    icon: Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: _isSaved ? AppConfig.primaryColor : Colors.black,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSaved = !_isSaved;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isSaved
                                ? 'Property saved to bookmarks'
                                : 'Property removed from bookmarks',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          // Property details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price and location
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.price ?? '\$1,200/mo',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        spacing: 5,
                        children: [
                          Icon(
                            Icons.star_border_purple500_outlined,
                            color: Colors.amber,
                            size: 18,
                          ),
                          Text(
                            // widget.rating?.toStringAsFixed(1) ?? '0.0'
                            '0.0',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.location ?? 'Location not specified',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ),

                  // Divider
                  Divider(height: 32),

                  // Property features
                  Text(
                    'Features',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildFeatureItem(Icons.king_bed, '2 Beds'),
                      _buildFeatureItem(Icons.bathtub_outlined, '1 Bath'),
                      _buildFeatureItem(Icons.square_foot, '750 sqft'),
                      _buildFeatureItem(Icons.chair_outlined, 'Furnished'),
                    ],
                  ),

                  // Divider
                  Divider(height: 32),

                  // Property description
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This beautiful apartment is located in the heart of ${widget.location ?? "the city"} with easy access to public transportation, restaurants, and shopping. The unit features hardwood floors, stainless steel appliances, and plenty of natural light.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),

                  // Divider
                  Divider(height: 32),

                  // Amenities
                  Text(
                    'Amenities',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildAmenityChip('WiFi'),
                      _buildAmenityChip('Parking'),
                      _buildAmenityChip('Gym'),
                      _buildAmenityChip('Swimming Pool'),
                      _buildAmenityChip('Security'),
                      _buildAmenityChip('Laundry'),
                    ],
                  ),

                  // Divider
                  Divider(height: 32),

                  // Location
                  Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Map will be displayed here',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 100), // Extra space for bottom buttons
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom action buttons
      bottomSheet: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Contact button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Open chat with owner
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Chat functionality coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icon(Icons.chat_bubble_outline),
                label: Text('Contact'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: AppConfig.primaryColor),
                ),
              ),
            ),
            SizedBox(width: 16),
            // Book tour button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Book a viewing
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Booking functionality coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icon(Icons.calendar_today),
                label: Text('Book Tour'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppConfig.primaryColor,
          size: 28,
        ),
        SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildAmenityChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.grey[200],
      labelStyle: TextStyle(color: Colors.black87),
    );
  }
}
