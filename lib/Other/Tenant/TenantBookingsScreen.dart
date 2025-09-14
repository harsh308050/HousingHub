import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Helper/BookingModels.dart';
import 'package:shimmer/shimmer.dart';

class TenantBookingsScreen extends StatefulWidget {
  const TenantBookingsScreen({Key? key}) : super(key: key);

  @override
  State<TenantBookingsScreen> createState() => _TenantBookingsScreenState();
}

class _TenantBookingsScreenState extends State<TenantBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Stream<List<Map<String, dynamic>>>? _bookingsStream;
  String? _tenantEmail;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeBookings();
  }

  void _initializeBookings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      _tenantEmail = user!.email!;
      _bookingsStream = Api.streamTenantBookings(_tenantEmail!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterBookingsByStatus(
    List<Map<String, dynamic>> bookings,
    List<BookingStatus> statuses,
  ) {
    return bookings.where((booking) {
      final statusStr = booking['status'] as String?;
      if (statusStr == null) return false;

      // Find matching enum by comparing with toFirestore() values
      final status = BookingStatus.values.firstWhere(
        (s) => s.toFirestore() == statusStr,
        orElse: () => BookingStatus.pending,
      );
      return statuses.contains(status);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'My Bookings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppConfig.primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppConfig.primaryColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Pending'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _tenantEmail == null
          ? _buildSignInPrompt()
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _bookingsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerLoading();
                }

                if (snapshot.hasError) {
                  return _buildErrorWidget(snapshot.error.toString());
                }

                final bookings = snapshot.data ?? [];

                if (bookings.isEmpty) {
                  return _buildEmptyState();
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    // Active bookings (accepted)
                    _buildBookingsList(
                        _filterBookingsByStatus(
                          bookings,
                          [BookingStatus.accepted],
                        ),
                        'active'),

                    // Pending bookings
                    _buildBookingsList(
                        _filterBookingsByStatus(
                          bookings,
                          [BookingStatus.pending],
                        ),
                        'pending'),

                    // History (completed, rejected)
                    _buildBookingsList(
                        _filterBookingsByStatus(
                          bookings,
                          [BookingStatus.completed, BookingStatus.rejected],
                        ),
                        'history'),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.login,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Please sign in to view your bookings',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading bookings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _initializeBookings();
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No bookings yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your property bookings will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings, String type) {
    if (bookings.isEmpty) {
      String message;
      IconData icon;

      switch (type) {
        case 'active':
          message = 'No active bookings';
          icon = Icons.home_outlined;
          break;
        case 'pending':
          message = 'No pending bookings';
          icon = Icons.schedule_outlined;
          break;
        case 'history':
          message = 'No booking history';
          icon = Icons.history_outlined;
          break;
        default:
          message = 'No bookings found';
          icon = Icons.bookmark_border;
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _initializeBookings();
        });
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return _buildBookingCard(booking);
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> bookingData) {
    final propertyData = bookingData['propertyData'] ?? {};
    final status = BookingStatus.values.firstWhere(
      (s) => s.toFirestore() == bookingData['status'],
      orElse: () => BookingStatus.pending,
    );

    final checkInDate = bookingData['checkInDate'] as Timestamp?;
    final createdAt = bookingData['createdAt'] as Timestamp?;
    final amount = bookingData['amount'] as double? ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property image and basic info
          if (propertyData['images'] != null &&
              propertyData['images'].isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  propertyData['images'][0],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Property title and status badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        propertyData['title'] ?? 'Property',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),

                const SizedBox(height: 8),

                // Location
                if (propertyData['address'] != null)
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          propertyData['address'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                // Booking details row
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        'Check-in Date',
                        checkInDate != null
                            ? DateFormat('MMM dd, yyyy')
                                .format(checkInDate.toDate())
                            : 'Not specified',
                        Icons.calendar_today,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        'Amount',
                        '₹${amount.toStringAsFixed(0)}',
                        Icons.payments,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Booking date
                if (createdAt != null)
                  Text(
                    'Booked on ${DateFormat('MMM dd, yyyy').format(createdAt.toDate())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),

                const SizedBox(height: 16),

                // Action buttons
                _buildActionButtons(bookingData, status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BookingStatus status) {
    Color backgroundColor;
    Color textColor;
    String text;

    switch (status) {
      case BookingStatus.pending:
        backgroundColor = Colors.orange[50]!;
        textColor = Colors.orange[700]!;
        text = 'Pending';
        break;
      case BookingStatus.accepted:
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        text = 'Accepted';
        break;
      case BookingStatus.rejected:
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        text = 'Rejected';
        break;
      case BookingStatus.completed:
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        text = 'Completed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
      Map<String, dynamic> bookingData, BookingStatus status) {
    List<Widget> buttons = [];

    // View Details button - always shown
    buttons.add(
      Expanded(
        child: OutlinedButton(
          onPressed: () => _showBookingDetails(bookingData),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppConfig.primaryColor,
            side: BorderSide(color: AppConfig.primaryColor),
          ),
          child: const Text('View Details'),
        ),
      ),
    );

    // Status-specific actions
    switch (status) {
      case BookingStatus.pending:
        buttons.add(const SizedBox(width: 8));
        buttons.add(
          Expanded(
            child: ElevatedButton(
              onPressed: () => _cancelBooking(bookingData),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel'),
            ),
          ),
        );
        break;

      case BookingStatus.accepted:
        // For accepted bookings, only contact and view options are available
        buttons.add(const SizedBox(width: 8));
        buttons.add(
          Expanded(
            child: ElevatedButton(
              onPressed: () => _contactOwner(bookingData),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ),
        );
        break;

      default:
        // For completed, cancelled, rejected - only view details
        break;
    }

    return Row(children: buttons);
  }

  void _showBookingDetails(Map<String, dynamic> bookingData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingDetailsModal(bookingData: bookingData),
    );
  }

  Future<void> _cancelBooking(Map<String, dynamic> bookingData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content:
            const Text('Are you sure you want to cancel this booking request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Api.updateBookingStatus(
          bookingId: bookingData['bookingId'],
          tenantEmail: bookingData['tenantEmail'],
          ownerEmail: bookingData['ownerEmail'],
          newStatus: BookingStatus.rejected.toFirestore(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking cancelled successfully'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cancelling booking: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _contactOwner(Map<String, dynamic> bookingData) {
    final ownerEmail = bookingData['ownerEmail'];
    if (ownerEmail != null) {
      // Navigate to chat screen (assuming it exists)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening chat with owner: $ownerEmail'),
        ),
      );
    }
  }
}

class _BookingDetailsModal extends StatelessWidget {
  final Map<String, dynamic> bookingData;

  const _BookingDetailsModal({required this.bookingData});

  @override
  Widget build(BuildContext context) {
    final propertyData = bookingData['propertyData'] ?? {};
    final status = BookingStatus.values.firstWhere(
      (s) => s.toFirestore() == bookingData['status'],
      orElse: () => BookingStatus.pending,
    );

    final checkInDate = bookingData['checkInDate'] as Timestamp?;
    final createdAt = bookingData['createdAt'] as Timestamp?;
    final amount = bookingData['amount'] as double? ?? 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Booking Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Status
                    _buildDetailSection('Status', [
                      _buildDetailRow('Current Status', status.displayName),
                      if (createdAt != null)
                        _buildDetailRow(
                            'Booked on',
                            DateFormat('MMM dd, yyyy - hh:mm a')
                                .format(createdAt.toDate())),
                    ]),

                    const SizedBox(height: 16),

                    // Property Details
                    _buildDetailSection('Property Details', [
                      _buildDetailRow('Title', propertyData['title'] ?? 'N/A'),
                      _buildDetailRow(
                          'Address', propertyData['address'] ?? 'N/A'),
                      _buildDetailRow('Type',
                          '${propertyData['roomType'] ?? ''} ${propertyData['propertyType'] ?? ''}'),
                      _buildDetailRow('Monthly Rent',
                          '₹${propertyData['monthlyRent']?.toStringAsFixed(0) ?? 'N/A'}'),
                      _buildDetailRow('Security Deposit',
                          '₹${propertyData['securityDeposit']?.toStringAsFixed(0) ?? 'N/A'}'),
                    ]),

                    const SizedBox(height: 16),

                    // Booking Details
                    _buildDetailSection('Booking Information', [
                      if (checkInDate != null)
                        _buildDetailRow(
                            'Check-in Date',
                            DateFormat('MMM dd, yyyy')
                                .format(checkInDate.toDate())),
                      _buildDetailRow(
                          'Total Amount', '₹${amount.toStringAsFixed(0)}'),
                      if (bookingData['notes'] != null &&
                          bookingData['notes'].isNotEmpty)
                        _buildDetailRow('Notes', bookingData['notes']),
                    ]),

                    const SizedBox(height: 16),

                    // Owner Information
                    if (bookingData['ownerEmail'] != null)
                      _buildDetailSection('Owner Information', [
                        _buildDetailRow('Email', bookingData['ownerEmail']),
                      ]),

                    const SizedBox(height: 16),

                    // Payment Information
                    if (bookingData['paymentInfo'] != null)
                      _buildDetailSection('Payment Information', [
                        _buildDetailRow('Payment ID',
                            bookingData['paymentInfo']['paymentId'] ?? 'N/A'),
                        _buildDetailRow('Method',
                            bookingData['paymentInfo']['method'] ?? 'N/A'),
                        _buildDetailRow('Status',
                            bookingData['paymentInfo']['status'] ?? 'N/A'),
                      ]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
