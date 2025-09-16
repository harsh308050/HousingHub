import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Helper/ShimmerHelper.dart';
import 'package:housinghub/config/AppConfig.dart';
import '../Chat/ChatScreen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final String? _currentUserEmail = FirebaseAuth.instance.currentUser?.email;
  bool _useFallbackStream = false;

  @override
  void initState() {
    super.initState();
    // Mark all notifications as read when opening the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentUserEmail != null) {
        Api.markAllNotificationsAsRead(_currentUserEmail);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserEmail == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Notifications'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: Center(
          child: Text('Please sign in to view notifications'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: Icon(Icons.done_all),
            onPressed: () {
              Api.markAllNotificationsAsRead(_currentUserEmail);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('All notifications marked as read'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: StreamBuilder<dynamic>(
        stream: _useFallbackStream
            ? Api.getNotificationsStreamFallback(_currentUserEmail)
            : Api.getNotificationsStream(_currentUserEmail),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ShimmerHelper.notificationShimmer();
          }

          if (snapshot.hasError) {
            print('Notification stream error: ${snapshot.error}');
            // Check if it's an index error and switch to fallback
            if (!_useFallbackStream &&
                (snapshot.error.toString().contains('FAILED_PRECONDITION') ||
                    snapshot.error.toString().contains('index'))) {
              // Automatically switch to fallback stream
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _useFallbackStream = true;
                });
              });

              return _buildIndexErrorState();
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Error loading notifications',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Trigger rebuild to retry
                    },
                    child: Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          // Handle both QuerySnapshot and List<QueryDocumentSnapshot>
          List<QueryDocumentSnapshot<Map<String, dynamic>>> notifications = [];

          if (snapshot.data is QuerySnapshot<Map<String, dynamic>>) {
            // Handle fallback stream (QuerySnapshot)
            notifications =
                (snapshot.data as QuerySnapshot<Map<String, dynamic>>).docs;
          } else if (snapshot.data is List) {
            // Handle combined stream (List<QueryDocumentSnapshot>)
            notifications = snapshot.data
                as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
          }

          // Sort notifications on client side by timestamp (newest first)
          notifications.sort((a, b) {
            final aData = a.data();
            final bData = b.data();

            // Handle both timestamp and createdAt fields
            final aTimestamp =
                aData['timestamp'] ?? aData['createdAt'] as Timestamp?;
            final bTimestamp =
                bData['timestamp'] ?? bData['createdAt'] as Timestamp?;

            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1;
            if (bTimestamp == null) return -1;

            return bTimestamp
                .compareTo(aTimestamp); // Descending order (newest first)
          });

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index].data();
              return _buildNotificationItem(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'When someone messages you, notifications will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storage,
            size: 64,
            color: Colors.orange[400],
          ),
          SizedBox(height: 16),
          Text(
            'Setting up notifications...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.orange[700],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Loading notifications with fallback method. This may take a moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(height: 16),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[400]!),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] ?? false;
    final timestamp =
        notification['timestamp'] ?? notification['createdAt'] as Timestamp?;

    // Handle both chat and booking notifications
    final type = notification['type'] ?? 'chat_message';

    // For chat notifications
    final title = notification['title'] ?? 'New message';
    final body = notification['body'] ?? notification['message'] ?? '';
    final senderName = notification['senderName'] ?? 'Someone';
    final senderEmail = notification['senderEmail'] ?? '';
    final isBookingNotification = type.toString().contains('booking');

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead ? Colors.grey.shade200 : Colors.blue.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isBookingNotification) {
            // Mark as read
            if (!isRead && notification['notificationId'] != null) {
              Api.markNotificationAsRead(notification['notificationId']);
            }
            // For booking notifications, we don't navigate anywhere yet
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Booking notification viewed'),
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            // For chat notifications
            _navigateToChat(senderEmail, senderName);
          }
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar or icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppConfig.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBookingNotification
                      ? Icons.home_work
                      : Icons.chat_bubble_outline,
                  color: AppConfig.primaryColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              // Notification content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  isRead ? FontWeight.w500 : FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 6),
                    Text(
                      _formatNotificationTime(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow indicator
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToChat(String otherEmail, String otherName) {
    if (_currentUserEmail == null || otherEmail.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          currentEmail: _currentUserEmail,
          otherEmail: otherEmail,
          otherName: otherName,
        ),
      ),
    );
  }

  String _formatNotificationTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';

    final now = DateTime.now();
    final notificationTime = timestamp.toDate();
    final difference = now.difference(notificationTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${notificationTime.day}/${notificationTime.month}/${notificationTime.year}';
    }
  }
}
