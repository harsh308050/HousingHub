import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Other/Chat/ChatScreen.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'dart:math' as math;

class TenantMessagesTab extends StatefulWidget {
  const TenantMessagesTab({super.key});

  @override
  State<TenantMessagesTab> createState() => _TenantMessagesTabState();
}

class _TenantMessagesTabState extends State<TenantMessagesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.email;
    if (me == null) {
      return Scaffold(
        body: const Center(child: Text('Sign in to view messages')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: Api.streamUserRooms(me),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading messages'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = [...(snapshot.data?.docs ?? [])];
                  // Sort by lastTimestamp desc client-side
                  docs.sort((a, b) {
                    final am = a.data();
                    final bm = b.data();
                    final at = am['lastTimestamp'];
                    final bt = bm['lastTimestamp'];
                    final aMs = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                    final bMs = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
                    return bMs.compareTo(aMs);
                  });
                  
                  // Filter conversations if search text is entered
                  final meNorm = me.trim().toLowerCase();
                  final filtered = docs.where((doc) {
                    final data = doc.data();
                    final participants = ((data['participants'] ?? []) as List).cast<String>();
                    final other = participants.firstWhere(
                      (p) => p != meNorm,
                      orElse: () => 'unknown',
                    );
                    final last = (data['lastMessage'] ?? '') as String;
                    if (_filter.isEmpty) return true;
                    return other.contains(_filter.toLowerCase()) ||
                        last.toLowerCase().contains(_filter.toLowerCase());
                  }).toList();
                  
                  if (filtered.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.only(top: 8),
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 72,
                      endIndent: 16,
                      color: Colors.grey[200],
                    ),
                    itemBuilder: (c, i) {
                      final d = filtered[i].data();
                      final participants = ((d['participants'] ?? []) as List).cast<String>();
                      final other = participants.firstWhere(
                        (p) => p != meNorm,
                        orElse: () => 'unknown',
                      );
                      final last = (d['lastMessage'] ?? '') as String;
                      final unread = (d['unreadCounts'] is Map)
                          ? (d['unreadCounts'][meNorm] ?? 0) as int
                          : 0;
                      final timestamp = d['lastTimestamp'] as Timestamp?;
                      final timeAgo = timestamp != null
                          ? _getTimeAgo(timestamp.toDate())
                          : '';
                      
                      return _buildConversationItem(
                        name: other,
                        lastMessage: last.isEmpty ? 'Attachment' : last,
                        timeAgo: timeAgo,
                        unread: unread > 0,
                        avatarColor: _getAvatarColor(other),
                        hasAttachment: last.isEmpty,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                currentEmail: me,
                                otherEmail: other,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Custom back button SVG
  Widget _buildBackButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: Colors.black,
        ),
      ),
    );
  }

  // Header with "Messages" title
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: 16),
          const Text(
            'Messages',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // Search bar for conversations
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search conversations',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                style: TextStyle(fontSize: 16),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Icon(
                Icons.tune,
                size: 20,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Empty state when no conversations are available
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your conversations will appear here',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Individual conversation list item
  Widget _buildConversationItem({
    required String name,
    required String lastMessage,
    required String timeAgo,
    required bool unread,
    required Color avatarColor,
    required bool hasAttachment,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar with first letter or status indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: avatarColor,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (unread)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 16),

            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: unread ? FontWeight.bold : FontWeight.w500,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: unread ? AppConfig.primaryColor : Colors.grey[500],
                          fontWeight: unread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // Last message with attachment icon if needed
                  Row(
                    children: [
                      if (hasAttachment)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.attach_file, size: 14, color: Colors.grey[600]),
                        ),
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: unread ? Colors.black87 : Colors.grey[600],
                            fontWeight: unread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper function to get time ago string
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
  
  // Helper function to generate consistent avatar colors
  Color _getAvatarColor(String name) {
    final colors = [
      Color(0xFF1ABC9C), // Turquoise
      Color(0xFF3498DB), // Blue
      Color(0xFF9B59B6), // Purple
      Color(0xFFE74C3C), // Red
      Color(0xFFE67E22), // Orange
      Color(0xFF2ECC71), // Green
    ];
    
    // Use a hash of the name to pick a consistent color
    final hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    return colors[hash % colors.length];
  }
}
