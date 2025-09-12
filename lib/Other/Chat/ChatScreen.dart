import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/Other/Chat/TypingIndicator.dart';

class ChatScreen extends StatefulWidget {
  final String currentEmail;
  final String otherEmail;
  final String? otherName;

  const ChatScreen({
    Key? key,
    required this.currentEmail,
    required this.otherEmail,
    this.otherName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _sending = false;

  // Profile information
  String _otherUserDisplayName = '';
  String _otherUserProfilePicture = '';
  bool _profileLoaded = false;

  // Typing indicator variables
  Timer? _typingTimer;
  bool _isCurrentUserTyping = false;
  late Stream<bool> _otherUserTypingStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOtherUserProfile();
    _updateCurrentUserPresence();

    // Initialize typing status stream
    _otherUserTypingStream =
        Api.getTypingStatusStream(widget.otherEmail, widget.currentEmail);

    // Set up text controller listener for typing detection
    _msgCtrl.addListener(_onTextChanged);

    // Mark as read on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Api.markChatAsRead(
          currentEmail: widget.currentEmail, otherEmail: widget.otherEmail);
    });
  }

  // Load the other user's profile information
  Future<void> _loadOtherUserProfile() async {
    try {
      final profile = await Api.getUserProfileInfo(widget.otherEmail);
      setState(() {
        _otherUserDisplayName =
            profile['displayName'] ?? _formatDisplayName(widget.otherEmail);
        _otherUserProfilePicture = profile['profilePicture'] ?? '';
        _profileLoaded = true;
      });
    } catch (e) {
      setState(() {
        _otherUserDisplayName = _formatDisplayName(widget.otherEmail);
        _otherUserProfilePicture = '';
        _profileLoaded = true;
      });
    }
  }

  // Update current user's presence
  Future<void> _updateCurrentUserPresence() async {
    await Api.updateUserPresence(widget.currentEmail);
  }

  // Handle text input changes for typing indicator
  void _onTextChanged() {
    final text = _msgCtrl.text;

    if (text.isNotEmpty && !_isCurrentUserTyping) {
      // User started typing - send immediately
      print('[TYPING] User started typing: ${text.length} characters');
      _isCurrentUserTyping = true;
      Api.updateTypingStatus(widget.currentEmail, widget.otherEmail, true);
    } else if (text.isEmpty && _isCurrentUserTyping) {
      // User cleared the text field - stop immediately
      print('[TYPING] User cleared text - stopping typing indicator immediately');
      _isCurrentUserTyping = false;
      Api.updateTypingStatus(widget.currentEmail, widget.otherEmail, false);
    } else if (text.isNotEmpty && _isCurrentUserTyping) {
      // User is continuing to type - refresh the typing status immediately for real-time updates
      Api.updateTypingStatus(widget.currentEmail, widget.otherEmail, true);
    }

    // Reset or set timer for stopping typing status
    _typingTimer?.cancel();
    if (text.isNotEmpty) {
      _typingTimer = Timer(const Duration(milliseconds: 500), () {
        // User stopped typing after 0.5 seconds of inactivity (ultra-fast for real-time response)
        if (_isCurrentUserTyping) {
          print('[TYPING] Typing timeout - clearing status after 0.5s inactivity');
          _isCurrentUserTyping = false;
          Api.updateTypingStatus(widget.currentEmail, widget.otherEmail, false);
        }
      });
    }
  }

  // Clear typing status when user sends message or leaves chat
  Future<void> _clearTypingStatus() async {
    _typingTimer?.cancel();
    if (_isCurrentUserTyping) {
      _isCurrentUserTyping = false;
      await Api.updateTypingStatus(
          widget.currentEmail, widget.otherEmail, false);
    }
  }

  // Make phone call to the other user
  Future<void> _makePhoneCall() async {
    try {
      final mobileNumber = await Api.getUserMobileNumber(widget.otherEmail);

      if (mobileNumber == null || mobileNumber.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Phone number not available for this user'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Format phone number for calling (remove any spaces, dashes, etc.)
      final cleanNumber = mobileNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Use tel: scheme which opens the dialer with the number pre-filled
      final phoneUri = Uri(scheme: 'tel', path: cleanNumber);

      print('Attempting to launch: $phoneUri'); // Debug log

      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(
          phoneUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback: try with different approach
        final dialUri = Uri.parse('tel:$cleanNumber');
        if (await canLaunchUrl(dialUri)) {
          await launchUrl(dialUri);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'No phone app available to make calls\nNumber: $cleanNumber'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Phone call error: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _updateCurrentUserPresence();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        Api.setUserOffline(widget.currentEmail);
        _clearTypingStatus(); // Clear typing when app goes to background
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Api.setUserOffline(widget.currentEmail);
    // Clean up typing status and timer
    _typingTimer?.cancel();
    _clearTypingStatus();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndSendAttachment() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80, // Optimize like Lets_Chat
    );
    if (picked == null) return;

    setState(() => _sending = true);
    try {
      final url = await Api.uploadChatAttachment(File(picked.path));
      await Api.sendChatMessage(
        senderEmail: widget.currentEmail,
        receiverEmail: widget.otherEmail,
        attachmentUrl: url,
      );

      // Smooth auto-scroll to bottom
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0, // Since we're using reverse: true, 0 is the bottom
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send attachment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    // Clear the text field immediately for better UX
    _msgCtrl.clear();
    setState(() => _sending = true);

    // Clear typing status immediately when sending message
    await _clearTypingStatus();

    try {
      await Api.sendChatMessage(
        senderEmail: widget.currentEmail,
        receiverEmail: widget.otherEmail,
        text: text,
      );

      // Smooth auto-scroll to bottom like Lets_Chat
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0, // Since we're using reverse: true, 0 is the bottom
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use loaded profile info if available, otherwise fallback to provided name or email-derived name
    final displayName = _profileLoaded && _otherUserDisplayName.isNotEmpty
        ? _otherUserDisplayName
        : (widget.otherName ?? _formatDisplayName(widget.otherEmail));

    final profilePicture = _profileLoaded ? _otherUserProfilePicture : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Profile picture or avatar with online status indicator
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: profilePicture.isEmpty
                          ? _getAvatarColor(widget.otherEmail)
                          : null,
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
                              Api.getUserInitials(
                                  displayName, widget.otherEmail),
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                          )
                        : null,
                  ),
                  // Online status indicator - green dot (smaller for app bar)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: Api.getUserPresenceStream(widget.otherEmail),
                      builder: (context, snapshot) {
                        bool isOnline = false;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          isOnline = data['isOnline'] ?? false;
                        }

                        return AnimatedOpacity(
                          opacity: isOnline ? 1.0 : 0.0,
                          duration: Duration(milliseconds: 300),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    StreamBuilder<DocumentSnapshot>(
                      stream: Api.getUserPresenceStream(widget.otherEmail),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return Text(
                            'Last seen: Unknown',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          );
                        }

                        final data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        final isOnline = data['isOnline'] ?? false;
                        final lastSeen = data['lastSeen'] as Timestamp?;

                        if (isOnline) {
                          return Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Online',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Check if user has been offline for more than 24 hours
                          if (lastSeen != null) {
                            return Text(
                              Api.formatLastSeen(lastSeen),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            );
                          } else {
                            return Text(
                              'Last seen: Unknown',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _makePhoneCall,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.shade200,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.phone,
                      size: 20,
                      color: Colors.green.shade600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: Api.streamChatMessages(
                  widget.currentEmail, widget.otherEmail),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.chat_bubble_outline,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Say hello 👋',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.black54)),
                        ],
                      ),
                    ),
                  );
                }

                // Convert to list and reverse for better performance
                final messages = docs.map((doc) => doc.data()).toList();

                return StreamBuilder<bool>(
                  stream: _otherUserTypingStream,
                  builder: (context, typingSnapshot) {
                    final isOtherUserTyping = typingSnapshot.data ?? false;
                    print(
                        '[TYPING] StreamBuilder - isOtherUserTyping: $isOtherUserTyping, connectionState: ${typingSnapshot.connectionState}, hasError: ${typingSnapshot.hasError}');
                    if (typingSnapshot.hasError) {
                      print('[TYPING] Stream error: ${typingSnapshot.error}');
                    }

                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: messages.length + (isOtherUserTyping ? 1 : 0),
                      reverse:
                          true, // Messages appear from bottom like Lets_Chat
                      physics:
                          const BouncingScrollPhysics(), // Smooth iOS-like scrolling
                      itemBuilder: (c, i) {
                        // If it's the typing indicator (first item due to reverse: true)
                        if (isOtherUserTyping && i == 0) {
                          print('[TYPING] Displaying typing indicator for ${widget.otherEmail}');
                          return const TypingIndicator();
                        }

                        // Adjust index for messages
                        final messageIndex = isOtherUserTyping ? i - 1 : i;
                        final reversedIndex =
                            messages.length - 1 - messageIndex;
                        final m = messages[reversedIndex];
                        final isMe = (m['senderId'] as String?) ==
                            widget.currentEmail.trim().toLowerCase();
                        final text = (m['text'] ?? '') as String;
                        final att = m['attachment'] as String?;
                        final timestamp = m['timestamp'] as Timestamp?;
                        final timeStr = timestamp != null
                            ? _formatTime(timestamp.toDate())
                            : '';

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * .75),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  // Handle attachment separately without bubble
                                  if (att != null && att.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: isMe
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.network(
                                            att,
                                            fit: BoxFit.cover,
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.6,
                                            height: 200,
                                          ),
                                        ),
                                        if (timeStr.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              timeStr,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  // Handle text message with bubble (only if there's text and no attachment)
                                  if (text.isNotEmpty &&
                                      (att == null || att.isEmpty))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? AppConfig.primaryColor
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(18),
                                          topRight: Radius.circular(18),
                                          bottomLeft: isMe
                                              ? Radius.circular(18)
                                              : Radius.circular(4),
                                          bottomRight: isMe
                                              ? Radius.circular(4)
                                              : Radius.circular(18),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            text,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: isMe
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                          if (timeStr.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 4.0),
                                              child: Text(
                                                timeStr,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isMe
                                                      ? Colors.white
                                                          .withOpacity(0.7)
                                                      : Colors.grey[500],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
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
          _buildMessageInput(),
        ],
      ),
    );
  }

  // Message input area matching your design
  Widget _buildMessageInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _sending ? null : _pickAndSendAttachment,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Icon(
                    Icons.attach_file,
                    size: 20,
                    color: _sending ? Colors.grey : Colors.black54,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _msgCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            SizedBox(width: 12),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppConfig.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.send,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper functions for UI formatting
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

  Color _getAvatarColor(String email) {
    final colors = [
      Color(0xFF6366F1), // Indigo
      Color(0xFF8B5CF6), // Violet
      Color(0xFF06B6D4), // Cyan
      Color(0xFF10B981), // Emerald
      Color(0xFFF59E0B), // Amber
      Color(0xFFEF4444), // Red
    ];

    final hash = email.codeUnits.fold(0, (prev, element) => prev + element);
    return colors[hash % colors.length];
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDay == today) {
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final amPm = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $amPm';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
