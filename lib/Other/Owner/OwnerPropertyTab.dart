import 'package:flutter/material.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/Other/Owner/AddProperty.dart';
import 'package:housinghub/Other/Owner/EditProperty.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Helper/ShimmerHelper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OwnerPropertyTab extends StatefulWidget {
  const OwnerPropertyTab({super.key});

  @override
  State<OwnerPropertyTab> createState() => _OwnerPropertyTabState();
}

class _OwnerPropertyTabState extends State<OwnerPropertyTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showFloatingButton = true;

  List<Map<String, dynamic>> _properties = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _fetchProperties();
  }

  Future<void> _fetchProperties() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        setState(() {
          _error = 'You must be logged in to view properties.';
          _isLoading = false;
        });
        return;
      }
      // First, auto-revert any expired bookings so lists reflect reality
      await Api.autoRevertExpiredBookingsForOwner(user.email!);
      final properties = await Api.getAllOwnerProperties(user.email!);
      setState(() {
        _properties = properties;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load properties.';
        _isLoading = false;
      });
    }
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
              child: _isLoading
                  ? ShimmerHelper.ownerPropertyCardShimmer()
                  : _error != null
                      ? Center(child: Text(_error!))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPropertyList(_properties), // All properties
                            _buildPropertyList(_properties
                                .where((p) => p['isAvailable'] == true)
                                .toList()), // Available
                            _buildPropertyList(_properties
                                .where((p) => p['isAvailable'] == false)
                                .toList()), // Unavailable
                          ],
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _showFloatingButton
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddProperty(),
                  ),
                );
                _fetchProperties(); // Refresh after adding
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
      margin: EdgeInsets.only(left: 16, right: 16, bottom: 16),
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
    return RefreshIndicator(
      onRefresh: _fetchProperties,
      child: properties.isEmpty
          ? Center(
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  SizedBox(height: 40),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home_work,
                            size: 60, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'No properties found',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ), // Space for FAB
                      ],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: properties.length +
                  1, // +1 for the Add Property button at bottom
              itemBuilder: (context, index) {
                if (index == properties.length) {
                  return SizedBox(height: 60); // Space for FAB
                }
                return _buildPropertyCard(properties[index]);
              },
            ),
    );
  }

  // Show confirmation dialog before deleting a property
  void _showDeleteConfirmation(Map<String, dynamic> property) {
    // Store the current context for later use
    final BuildContext currentContext = context;

    showDialog<bool>(
      context: currentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Delete Property'),
          content: Text(
              'Are you sure you want to delete "${property['title']?.toString() ?? 'this property'}"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: Text('Delete',
                  style: TextStyle(color: AppConfig.dangerColor)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    ).then((bool? confirmed) async {
      if (confirmed != true) return;

      // Store context for loading dialog
      BuildContext? loadingDialogContext;

      // Show loading indicator
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
        await Api.deleteProperty(property['id']);

        // Close loading dialog safely
        if (loadingDialogContext != null &&
            Navigator.canPop(loadingDialogContext!)) {
          Navigator.pop(loadingDialogContext!);
        }

        // Check if widget is still mounted before showing snackbar
        if (mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(content: Text('Property deleted successfully')),
          );
          // Refresh property list
          _fetchProperties();
        }
      } catch (e) {
        // Close loading dialog safely
        if (loadingDialogContext != null &&
            Navigator.canPop(loadingDialogContext!)) {
          Navigator.pop(loadingDialogContext!);
        }

        // Check if widget is still mounted before showing snackbar
        if (mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(
                content: Text('Failed to delete property: ${e.toString()}')),
          );
        }
      }
    });
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
              // Use first image from the images array or a placeholder
              (property['images'] != null &&
                      property['images'] is List &&
                      (property['images'] as List).isNotEmpty)
                  ? property['images'][0].toString()
                  : 'https://images.pexels.com/photos/106399/pexels-photo-106399.jpeg',
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
                            property['title']?.toString() ??
                                'Untitled Property',
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
                                  property['address']?.toString() ??
                                      'No address provided',
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
                          '₹${property['price']?.toString() ?? '0'}',
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
                          color: property['isAvailable'] == true
                              ? AppConfig.successColor
                              : AppConfig.dangerColor,
                        ),
                        SizedBox(width: 8),
                        Text(
                          property['isAvailable'] == true
                              ? 'Available'
                              : 'Unavailable',
                          style: TextStyle(
                            color: property['isAvailable'] == true
                                ? AppConfig.successColor
                                : AppConfig.dangerColor,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditProperty(property: property),
                              ),
                            );

                            // Refresh property list if changes were made
                            if (result == true) {
                              _fetchProperties();
                            }
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
                            _showDeleteConfirmation(property);
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
