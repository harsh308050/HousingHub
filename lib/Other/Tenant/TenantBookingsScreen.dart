import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:housinghub/Other/BookingDetailsScreen.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Helper/BookingModels.dart';
// shimmer removed along with old loading UI

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
  final NumberFormat _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

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
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Bookings')),
        body: const Center(child: Text('Please sign in to view your bookings')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('My Bookings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _bookingsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = (snapshot.data ?? [])
            ..sort((a, b) {
              final ta = (a['createdAt'] as Timestamp?)?.toDate();
              final tb = (b['createdAt'] as Timestamp?)?.toDate();
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return tb.compareTo(ta);
            });

          final pendingKey = BookingStatus.pending.toFirestore();
          final acceptedKey = BookingStatus.accepted.toFirestore();
          final completedKey = BookingStatus.completed.toFirestore();
          final rejectedKey = BookingStatus.rejected.toFirestore();

          final pending =
              items.where((e) => e['status'] == pendingKey).toList();
          final active =
              items.where((e) => e['status'] == acceptedKey).toList();
          final history = items
              .where((e) =>
                  e['status'] == completedKey || e['status'] == rejectedKey)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildBookingsList(pending),
              _buildBookingsList(active),
              _buildBookingsList(history),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) {
      return const Center(child: Text('No bookings found'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _buildBookingCard(booking);
      },
    );
  }

  // Helpers to compute amounts consistently
  static double _parsePrice(dynamic price) {
    if (price == null) return 0;
    if (price is num) return price.toDouble();
    final s = price.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }

  double _extractTotalAmount(Map<String, dynamic> bookingData) {
    // Prefer explicit booking amount if set, else compute from property data, else payment amount
    final amount = bookingData['amount'];
    if (amount != null) {
      final a = _parsePrice(amount);
      if (a > 0) return a;
    }
    final propertyData = bookingData['propertyData'] ?? {};
    final rent = _parsePrice(propertyData['rent'] ??
        propertyData['price'] ??
        propertyData['monthlyRent']);
    final deposit =
        _parsePrice(propertyData['deposit'] ?? propertyData['securityDeposit']);
    final computed = rent + deposit;
    if (computed > 0) return computed;
    final paymentInfo = bookingData['paymentInfo'];
    if (paymentInfo != null) {
      final paid = _parsePrice(paymentInfo['amount']);
      if (paid > 0) return paid;
    }
    return 0;
  }

  Widget _buildBookingCard(Map<String, dynamic> bookingData) {
    final propertyData = bookingData['propertyData'] ?? {};
    final status = BookingStatus.values.firstWhere(
      (s) => s.toFirestore() == bookingData['status'],
      orElse: () => BookingStatus.pending,
    );

    final checkInDate = bookingData['checkInDate'] as Timestamp?;
    final createdAt = bookingData['createdAt'] as Timestamp?;
    final amount = _extractTotalAmount(bookingData);

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
                        _inr.format(amount),
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
        // For accepted bookings, allow contacting owner only
        buttons.add(const SizedBox(width: 8));
        buttons.add(
          Expanded(
            child: ElevatedButton(
              onPressed: () => _contactOwner(bookingData),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Contact Owner'),
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

  // Receipt URL adjustments now handled in BookingDetailsScreen

  // Receipt download now handled inside BookingDetailsScreen

  void _showBookingDetails(Map<String, dynamic> bookingData) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingDetailsScreen(
          bookingData: bookingData,
          viewer: 'tenant',
        ),
      ),
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

// Legacy modal removed; details handled by BookingDetailsScreen
