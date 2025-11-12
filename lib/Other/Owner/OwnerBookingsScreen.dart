import 'package:flutter/material.dart';
import 'package:housinghub/Other/BookingDetailsScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Helper/BookingModels.dart';
import 'package:shimmer/shimmer.dart';
import 'package:housinghub/Other/Chat/ChatScreen.dart';
import 'package:housinghub/Helper/Models.dart';

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
        appBar: AppBar(
            title: const Text(
          'Bookings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        )),
        body: _buildSignInPrompt(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Bookings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppConfig.primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppConfig.primaryColor,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
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
    // Prefer paid amount from paymentInfo; fallback to computed property total
    double amount = 0.0;
    final paymentInfo = bookingData['paymentInfo'] as Map<String, dynamic>?;
    if (paymentInfo != null && paymentInfo['amount'] != null) {
      final v = paymentInfo['amount'];
      amount = v is num
          ? v.toDouble()
          : double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ??
              0.0;
    } else {
      final rentRaw = propertyData['rent'] ?? propertyData['price'];
      final depRaw = propertyData['deposit'] ?? propertyData['securityDeposit'];
      double rent = 0.0;
      double dep = 0.0;
      if (rentRaw != null) {
        rent = rentRaw is num
            ? rentRaw.toDouble()
            : double.tryParse(
                    rentRaw.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ??
                0.0;
      }
      if (depRaw != null) {
        dep = depRaw is num
            ? depRaw.toDouble()
            : double.tryParse(
                    depRaw.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ??
                0.0;
      }
      amount = rent + dep;
    }

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
                            onPressed: () => _openChat(bookingData),
                            icon: const Icon(Icons.chat_bubble_outline),
                            color: AppConfig.primaryColor,
                            tooltip: 'Open Chat',
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
    // Common styles
    final ButtonStyle primaryOutlined = OutlinedButton.styleFrom(
      foregroundColor: AppConfig.primaryColor,
      side: BorderSide(color: AppConfig.primaryColor, width: 1.2),
      minimumSize: const Size.fromHeight(44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
    final ButtonStyle solidGreen = ElevatedButton.styleFrom(
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
    final ButtonStyle solidRed = ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
    final ButtonStyle solidPrimary = ElevatedButton.styleFrom(
      backgroundColor: AppConfig.primaryColor,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );

    // Label helpers to prevent wrapping on small screens
    Text _label(String text) => Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final isNarrow = maxW < 360; // very small phones
        final isMedium = maxW >= 360 && maxW < 480; // typical phones

        // Builders for buttons
        Widget viewDetailsBtn = OutlinedButton.icon(
          onPressed: () => _showBookingDetails(bookingData),
          style: primaryOutlined,
          icon: const Icon(
            Icons.info_outline,
            color: AppConfig.primaryColor,
          ),
          label: _label('View Details'),
        );
        Widget rejectBtn = ElevatedButton(
          onPressed: () => _rejectBooking(bookingData),
          style: solidRed,
          child: _label(
            'Reject',
          ),
        );
        Widget approveBtn = ElevatedButton(
          onPressed: () => _approveBooking(bookingData),
          style: solidGreen,
          child: _label("Approve"),
          // icon: const Icon(Icons.check_circle_outline, color: Colors.white),
          // label: _label('Approve'),
        );
        Widget markCompleteBtn = ElevatedButton(
          onPressed: () => _markCompleted(bookingData),
          style: solidPrimary,
          // icon: const Icon(Icons.task_alt, color: Colors.white),
          child: _label('Mark Complete'),
        );
        Widget contactBtn = OutlinedButton.icon(
          onPressed: () => _openChat(bookingData),
          style: primaryOutlined,
          icon: const Icon(Icons.chat_bubble_outline,
              color: AppConfig.primaryColor),
          label: _label('Contact'),
        );

        // Helper to build two buttons side-by-side with equal width
        Widget twoCol(Widget a, Widget b) {
          return Row(
            children: [
              Expanded(child: a),
              const SizedBox(width: 8),
              Expanded(child: b),
            ],
          );
        }

        // Pending: 3 actions (details, reject, approve)
        if (status == BookingStatus.pending) {
          if (isNarrow) {
            // Stack into 2 rows for very small screens
            return Column(
              children: [
                viewDetailsBtn,
                const SizedBox(height: 8),
                twoCol(rejectBtn, approveBtn),
              ],
            );
          } else if (isMedium) {
            // Two rows: details + approve on first, reject on second full width
            return Column(
              children: [
                twoCol(viewDetailsBtn, approveBtn),
                const SizedBox(height: 8),
                rejectBtn,
              ],
            );
          } else {
            // Wide: single row 3 buttons
            return Row(
              children: [
                Expanded(child: viewDetailsBtn),
                const SizedBox(width: 8),
                Expanded(child: rejectBtn),
                const SizedBox(width: 8),
                Expanded(child: approveBtn),
              ],
            );
          }
        }

        // Accepted: View details + Mark complete
        if (status == BookingStatus.accepted) {
          if (isNarrow) {
            return Column(
              children: [
                viewDetailsBtn,
                const SizedBox(height: 8),
                markCompleteBtn,
              ],
            );
          } else {
            return twoCol(viewDetailsBtn, markCompleteBtn);
          }
        }

        // Completed/Rejected: View details (+ Contact for completed)
        if (status == BookingStatus.completed) {
          if (isNarrow) {
            return Column(
              children: [
                viewDetailsBtn,
                const SizedBox(height: 8),
                contactBtn,
              ],
            );
          } else {
            return twoCol(viewDetailsBtn, contactBtn);
          }
        }

        // Rejected: only View details
        return viewDetailsBtn;
      },
    );
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
        title: const Text('Approve Booking',
            style: TextStyle(color: AppConfig.primaryColor)),
        content: Text(
            'Approve booking request from ${bookingData['tenantData']['firstName']} ${bookingData['tenantData']['lastName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppConfig.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
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
          Models.showSuccessSnackBar(context, 'Booking approved successfully!');
        }
      } catch (e) {
        if (mounted) {
          Models.showErrorSnackBar(context, 'Error approving booking: $e');
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
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
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
          Models.showInfoSnackBar(context, 'Booking rejected');
        }
      } catch (e) {
        if (mounted) {
          Models.showErrorSnackBar(context, 'Error rejecting booking: $e');
        }
      }
    }
  }

  Future<void> _markCompleted(Map<String, dynamic> bookingData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Mark Booking Complete',
          style: TextStyle(color: AppConfig.primaryColor),
        ),
        content: const Text(
            'Mark this booking as completed? \nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppConfig.primaryColor),
            ),
          ),
          SizedBox(
            width: 10,
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.primaryColor,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark Complete',
                style: TextStyle(color: Colors.white)),
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
          Models.showSuccessSnackBar(context, 'Booking marked as completed!');
        }
      } catch (e) {
        if (mounted) {
          Models.showErrorSnackBar(context, 'Error updating booking: $e');
        }
      }
    }
  }

  void _openChat(Map<String, dynamic> bookingData) {
    final tenantEmail = bookingData['tenantEmail'] as String?;
    final tenantFirst =
        (bookingData['tenantData']?['firstName'] ?? '').toString();
    final tenantLast =
        (bookingData['tenantData']?['lastName'] ?? '').toString();
    final tenantName = ('$tenantFirst $tenantLast').trim();

    final ownerEmail = FirebaseAuth.instance.currentUser?.email;
    if (tenantEmail == null || tenantEmail.isEmpty || ownerEmail == null) {
      Models.showErrorSnackBar(
          context, 'Unable to open chat. Missing user information.');
      return;
    }

    // Prevent users from messaging themselves
    if (ownerEmail.toLowerCase().trim() == tenantEmail.toLowerCase().trim()) {
      Models.showWarningSnackBar(context, 'Cannot open chat with yourself');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentEmail: ownerEmail,
          otherEmail: tenantEmail,
          otherName: tenantName.isEmpty ? null : tenantName,
        ),
      ),
    );
  }
}

// Legacy modal removed; details handled by BookingDetailsScreen
