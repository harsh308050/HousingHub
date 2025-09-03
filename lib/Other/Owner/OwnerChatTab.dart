import 'package:flutter/material.dart';
import 'package:housinghub/config/AppConfig.dart';

class OwnerChatTab extends StatefulWidget {
  const OwnerChatTab({super.key});

  @override
  State<OwnerChatTab> createState() => _OwnerChatTabState();
}

class _OwnerChatTabState extends State<OwnerChatTab> {
  // Controller for search field
  final TextEditingController _searchController = TextEditingController();

  // Sample data for conversations
  final List<Map<String, dynamic>> _conversations = [
    {
      'name': 'Sarah Wilson',
      'lastMessage':
          'The apartment looks great! When can I schedule a viewing?',
      'time': '2m ago',
      'avatar': 'https://randomuser.me/api/portraits/women/12.jpg',
      'unread': true,
      'lastSeen': '',
      'property': 'Skyline Apartments',
    },
    {
      'name': 'Michael Brown',
      'lastMessage': 'I\'ve attached my ID for verification. Please check.',
      'time': '1h ago',
      'avatar': 'https://randomuser.me/api/portraits/men/32.jpg',
      'unread': false,
      'lastSeen': 'Last seen today at 2:30 PM',
      'property': 'Garden View House',
    },
    {
      'name': 'James Wilson',
      'lastMessage': 'Perfect! I\'ll send you the details by tomorrow morning.',
      'time': 'Yesterday',
      'avatar': 'https://randomuser.me/api/portraits/men/45.jpg',
      'unread': false,
      'lastSeen': 'Last seen 2 days ago',
      'property': 'Downtown Loft',
    },
    {
      'name': 'Lisa Anderson',
      'lastMessage': 'Thank you for your quick response regarding the rental.',
      'time': '2 days ago',
      'avatar': 'https://randomuser.me/api/portraits/women/65.jpg',
      'unread': false,
      'lastSeen': 'Last seen 3 days ago',
      'property': 'Riverside Villa',
    },
    {
      'name': 'David Thompson',
      'lastMessage':
          'Would you be open to a 2-year lease with a small discount?',
      'time': '3 days ago',
      'avatar': 'https://randomuser.me/api/portraits/men/67.jpg',
      'unread': false,
      'lastSeen': 'Last seen 4 days ago',
      'property': 'Mountain View Condo',
    },
    {
      'name': 'Emily Johnson',
      'lastMessage': 'Is the parking space included in the monthly rent?',
      'time': '5 days ago',
      'avatar': 'https://randomuser.me/api/portraits/women/33.jpg',
      'unread': false,
      'lastSeen': 'Last seen 6 days ago',
      'property': 'Hillside Residences',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildHeader(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            Expanded(
              child: _buildConversationsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Action to start a new conversation
          // Will be implemented later
        },
        backgroundColor: AppConfig.primaryColor,
        child: Icon(Icons.chat_outlined, color: Colors.white),
      ),
    );
  }

  // Header with "Messages" title
  PreferredSizeWidget _buildHeader() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
        onPressed: () {
          // Navigation will be added later
          Navigator.pop(context);
        },
      ),
      title: Text(
        'Messages',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  // Search bar for conversations
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(25),
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
        ),
      ),
    );
  }

  // List of conversations
  Widget _buildConversationsList() {
    if (_conversations.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      itemCount: _conversations.length,
      padding: EdgeInsets.only(top: 8),
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: 72, // Align with the end of avatar
        endIndent: 16,
        color: Colors.grey[200],
      ),
      itemBuilder: (context, index) {
        return _buildConversationItem(_conversations[index]);
      },
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
            'Your conversations with tenants will appear here',
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
  Widget _buildConversationItem(Map<String, dynamic> conversation) {
    return InkWell(
      onTap: () {
        // Navigate to conversation detail screen
        // Will implement later when functionality is added
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar with status indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(conversation['avatar']),
                ),
                if (conversation['unread'])
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
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
                        conversation['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        conversation['time'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),

                  // Property name
                  Text(
                    'About: ${conversation['property']}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppConfig.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  SizedBox(height: 2),

                  // Last message
                  Text(
                    conversation['lastMessage'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: conversation['unread']
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Last seen (if available)
                  if (conversation['lastSeen'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        conversation['lastSeen'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
