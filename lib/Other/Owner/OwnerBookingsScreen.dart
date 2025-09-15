import 'package:flutter/material.dart';
import 'package:housinghub/Other/BookingDetailsScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Helper/BookingModels.dart';
import 'package:shimmer/shimmer.dart';

class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({Key? key}) : super(key: key);

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Legacy refresh hook; stream updates live, but keep this to satisfy callers
  void _initializeBookings() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Owner Bookings')),
        body: _buildSignInPrompt(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Bookings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('Bookings')
            .where('ownerEmail', isEqualTo: user.email)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerLoading();
          }
          if (snapshot.hasError) {
            return _buildErrorWidget(snapshot.error.toString());
          }
          final docs = snapshot.data?.docs ?? const [];
          final items = docs.map((d) {
            final data = Map<String, dynamic>.from(d.data());
            data['bookingId'] = data['bookingId'] ?? d.id;
            return data;
          }).toList()
            ..sort((a, b) {
              final ta = (a['createdAt'] as Timestamp?)?.toDate();
              final tb = (b['createdAt'] as Timestamp?)?.toDate();
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return tb.compareTo(ta);
            });

          String pendingKey = BookingStatus.pending.toFirestore();
          String acceptedKey = BookingStatus.accepted.toFirestore();
          String completedKey = BookingStatus.completed.toFirestore();
          String rejectedKey = BookingStatus.rejected.toFirestore();

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
              _buildBookingsList(pending, 'pending'),
              _buildBookingsList(active, 'active'),
              _buildBookingsList(history, 'history'),
            ],
          );
        },
      ),
    );
  }

  // Owner modal removed; navigation now opens BookingDetailsScreen
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
              height: 200,
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

  // Removed unused empty state widget

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings, String type) {
    if (bookings.isEmpty) {
      String message;
      IconData icon;

      switch (type) {
        case 'pending':
          message = 'No pending booking requests';
          icon = Icons.schedule_outlined;
          break;
        case 'active':
          message = 'No active bookings';
          icon = Icons.home_outlined;
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
    final tenantData = bookingData['tenantData'] ?? {};
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with property name and status
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            propertyData['title'] ?? 'Property',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (propertyData['address'] != null)
                            Text(
                              propertyData['address'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),

                const SizedBox(height: 16),

                // Tenant information card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                AppConfig.primaryColor.withOpacity(0.1),
                            child: Text(
                              '${tenantData['firstName']?.substring(0, 1).toUpperCase() ?? 'T'}${tenantData['lastName']?.substring(0, 1).toUpperCase() ?? 'T'}',
                              style: TextStyle(
                                color: AppConfig.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${tenantData['firstName'] ?? ''} ${tenantData['lastName'] ?? ''}'
                                      .trim(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (tenantData['mobileNumber'] != null)
                                  Text(
                                    tenantData['mobileNumber'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _contactTenant(bookingData),
                            icon: const Icon(Icons.chat_bubble_outline),
                            color: AppConfig.primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Booking details
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

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        'Applied On',
                        createdAt != null
                            ? DateFormat('MMM dd, yyyy')
                                .format(createdAt.toDate())
                            : 'Unknown',
                        Icons.access_time,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        'Gender',
                        tenantData['gender'] ?? 'Not specified',
                        Icons.person_outline,
                      ),
                    ),
                  ],
                ),

                // Notes if any
                if (bookingData['notes'] != null &&
                    bookingData['notes'].isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tenant Notes:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bookingData['notes'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

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
        text = 'Pending Review';
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
              onPressed: () => _rejectBooking(bookingData),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ),
        );
        buttons.add(const SizedBox(width: 8));
        buttons.add(
          Expanded(
            child: ElevatedButton(
              onPressed: () => _approveBooking(bookingData),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve'),
            ),
          ),
        );
        break;

      case BookingStatus.accepted:
        buttons.add(const SizedBox(width: 8));
        buttons.add(
          Expanded(
            child: ElevatedButton(
              onPressed: () => _contactTenant(bookingData),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Contact Tenant'),
            ),
          ),
        );
        // Allow marking as completed for accepted bookings
        buttons.add(const SizedBox(width: 8));
        buttons.add(
          Expanded(
            child: ElevatedButton(
              onPressed: () => _markCompleted(bookingData),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Mark Complete'),
            ),
          ),
        );
        break;

      default:
        // For completed and rejected - only view details and contact
        if (status != BookingStatus.rejected) {
          buttons.add(const SizedBox(width: 8));
          buttons.add(
            Expanded(
              child: OutlinedButton(
                onPressed: () => _contactTenant(bookingData),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                ),
                child: const Text('Contact'),
              ),
            ),
          );
        }
        break;
    }

    return Row(children: buttons);
  }

  // Receipt handling now lives in BookingDetailsScreen

  void _showBookingDetails(Map<String, dynamic> bookingData) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingDetailsScreen(
          bookingData: bookingData,
          viewer: 'owner',
        ),
      ),
    );
  }

  Future<void> _approveBooking(Map<String, dynamic> bookingData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Booking'),
        content: Text(
            'Approve booking request from ${bookingData['tenantData']['firstName']} ${bookingData['tenantData']['lastName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
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
          newStatus: BookingStatus.accepted.toFirestore(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking approved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error approving booking: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectBooking(Map<String, dynamic> bookingData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Booking'),
        content: Text(
            'Reject booking request from ${bookingData['tenantData']['firstName']} ${bookingData['tenantData']['lastName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
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
              content: Text('Booking rejected'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error rejecting booking: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _markCompleted(Map<String, dynamic> bookingData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Booking Complete'),
        content: const Text(
            'Mark this booking as completed? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark Complete'),
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
          newStatus: BookingStatus.completed.toFirestore(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking marked as completed!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating booking: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _contactTenant(Map<String, dynamic> bookingData) {
    final tenantEmail = bookingData['tenantEmail'];
    final tenantName =
        '${bookingData['tenantData']['firstName']} ${bookingData['tenantData']['lastName']}';

    if (tenantEmail != null) {
      // Navigate to chat screen (assuming it exists)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening chat with $tenantName'),
        ),
      );
    }
  }
}

// Legacy modal removed; details handled by BookingDetailsScreen
