import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Other/Chat/ChatScreen.dart';

class TenantMessagesTab extends StatefulWidget {
  const TenantMessagesTab({super.key});

  @override
  State<TenantMessagesTab> createState() => _TenantMessagesTabState();
}

class _TenantMessagesTabState extends State<TenantMessagesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  // Cache for user profile information
  final Map<String, Map<String, String>> _userProfileCache = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Get or cache user profile information
  Future<Map<String, String>> _getUserProfile(String email) async {
    if (_userProfileCache.containsKey(email)) {
      return _userProfileCache[email]!;
    }

    final profile = await Api.getUserProfileInfo(email);
    _userProfileCache[email] = profile;
    return profile;
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
          children: [
            Center(child: _buildHeader()),
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
                    final participants =
                        ((data['participants'] ?? []) as List).cast<String>();
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

                  return ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (c, i) {
                      final d = filtered[i].data();
                      final participants =
                          ((d['participants'] ?? []) as List).cast<String>();
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

                      // Use FutureBuilder to load profile information
                      return FutureBuilder<Map<String, String>>(
                        future: _getUserProfile(other),
                        builder: (context, profileSnapshot) {
                          String displayName = 'Loading...';
                          String profilePicture = '';
                          String avatarText = '?';

                          if (profileSnapshot.connectionState ==
                                  ConnectionState.done &&
                              profileSnapshot.hasData) {
                            final profile = profileSnapshot.data!;
                            displayName = profile['displayName'] ??
                                _formatDisplayName(other);
                            profilePicture = profile['profilePicture'] ?? '';
                            avatarText =
                                Api.getUserInitials(displayName, other);
                          } else if (profileSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            // Show loading state with email-based fallback
                            displayName = _formatDisplayName(other);
                            avatarText = _getInitials(other);
                          } else {
                            // Error state - fallback to email-based display
                            displayName = _formatDisplayName(other);
                            avatarText = _getInitials(other);
                          }

                          return _buildConversationItem(
                            name: displayName,
                            lastMessage: last.isEmpty ? 'Attachment' : last,
                            timeAgo: timeAgo,
                            unread: unread > 0,
                            avatarText: avatarText,
                            profilePicture: profilePicture,
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Custom back button

  // Header with back button and "Messages" title
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Text(
            textAlign: TextAlign.center,
            'Messages',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
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
            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
          style: TextStyle(fontSize: 16),
          onChanged: (v) => setState(() => _filter = v),
        ),
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

  // Individual conversation list item - matches your design exactly
  Widget _buildConversationItem({
    required String name,
    required String lastMessage,
    required String timeAgo,
    required bool unread,
    required String avatarText,
    String profilePicture = '',
    VoidCallback? onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with profile picture or initials
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: profilePicture.isEmpty ? _getAvatarColor(name) : null,
                  image: profilePicture.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(profilePicture),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: profilePicture.isEmpty
                    ? Center(
                        child: Text(
                          avatarText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 16),

              // Message content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and time row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    // Last message
                    Text(
                      lastMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper function to get initials from email
  String _getInitials(String email) {
    if (email.isEmpty) return '?';
    final parts = email.split('@')[0].split('.');
    if (parts.length >= 2) {
      return '${parts[0][0].toUpperCase()}${parts[1][0].toUpperCase()}';
    }
    return email[0].toUpperCase();
  }

  // Helper function to format display name from email
  String _formatDisplayName(String email) {
    if (email.isEmpty) return 'Unknown';
    final username = email.split('@')[0];
    final parts = username.split('.');
    if (parts.length >= 2) {
      return '${_capitalize(parts[0])} ${_capitalize(parts[1])}';
    }
    return _capitalize(username);
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
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
