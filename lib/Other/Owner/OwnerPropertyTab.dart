import 'package:flutter/material.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/Other/Owner/AddProperty.dart';

class OwnerPropertyTab extends StatefulWidget {
  const OwnerPropertyTab({super.key});

  @override
  State<OwnerPropertyTab> createState() => _OwnerPropertyTabState();
}

class _OwnerPropertyTabState extends State<OwnerPropertyTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showFloatingButton = true;

  // Sample data for properties
  final List<Map<String, dynamic>> _properties = [
    {
      'name': 'Modern Downtown Apartment',
      'address': '123 Main St, Downtown',
      'price': 2500,
      'image':
          'https://images.pexels.com/photos/106399/pexels-photo-106399.jpeg',
      'isAvailable': true,
    },
    {
      'name': 'Luxury Beach House',
      'address': '456 Ocean Drive, Beachside',
      'price': 4500,
      'image':
          'https://images.pexels.com/photos/106399/pexels-photo-106399.jpeg',
      'isAvailable': false,
    },
    // Add more sample properties as needed
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPropertyList(_properties), // All properties
                  _buildPropertyList(_properties
                      .where((p) => p['isAvailable'])
                      .toList()), // Available
                  _buildPropertyList(_properties
                      .where((p) => !p['isAvailable'])
                      .toList()), // Unavailable
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _showFloatingButton
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddProperty(),
                  ),
                );
              },
              backgroundColor: AppConfig.primaryColor,
              child: Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'My Properties',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _tabController,
        labelColor: AppConfig.primaryColor,
        indicatorColor: AppConfig.primaryColor,
        tabs: [
          Tab(text: 'All (${_properties.length})'),
          Tab(text: 'Available'),
          Tab(text: 'Unavailable'),
        ],
      ),
    );
  }

  Widget _buildPropertyList(List<Map<String, dynamic>> properties) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount:
          properties.length + 1, // +1 for the Add Property button at bottom
      itemBuilder: (context, index) {
        if (index == properties.length) {
          return SizedBox(height: 60); // Space for FAB
        }
        return _buildPropertyCard(properties[index]);
      },
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
          // Property Image
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              property['image'],
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: Icon(Icons.error, color: Colors.grey[500]),
                );
              },
            ),
          ),
          // Property Details
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property['name'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  size: 16, color: Colors.grey),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  property['address'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${property['price']}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppConfig.primaryColor,
                          ),
                        ),
                        Text(
                          '/month',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: property['isAvailable']
                              ? AppConfig.successColor
                              : AppConfig.dangerColor,
                        ),
                        SizedBox(width: 8),
                        Text(
                          property['isAvailable'] ? 'Available' : 'Unavailable',
                          style: TextStyle(
                            color: property['isAvailable']
                                ? AppConfig.successColor
                                : AppConfig.dangerColor,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            // TODO: Implement edit functionality
                          },
                          icon: Icon(Icons.edit,
                              size: 20, color: AppConfig.primaryColor),
                          label: Text('Edit'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppConfig.primaryColor,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            // TODO: Implement delete functionality
                          },
                          icon: Icon(Icons.delete,
                              size: 20, color: AppConfig.dangerColor),
                          label: Text('Delete'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppConfig.dangerColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
