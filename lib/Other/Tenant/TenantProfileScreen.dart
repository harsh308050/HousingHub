import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/AppConfig.dart';
import '/Helper/API.dart';

class TenantProfileTab extends StatefulWidget {
  final User? user;
  final Map<String, dynamic>? tenantData;

  const TenantProfileTab({Key? key, this.user, this.tenantData})
      : super(key: key);

  @override
  State<TenantProfileTab> createState() => _TenantProfileTabState();
}

class _TenantProfileTabState extends State<TenantProfileTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Editable profile fields
  String firstName = '';
  String lastName = '';
  String email = '';
  String mobile = '';
  String gender = '';
  String? photoUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _hydrateFromInputs();
    _loadLatestTenantData();
  }

  void _hydrateFromInputs() {
    if (widget.tenantData != null) {
      firstName = widget.tenantData!['firstName'] ?? '';
      lastName = widget.tenantData!['lastName'] ?? '';
      email = widget.tenantData!['email'] ?? widget.user?.email ?? '';
      mobile = widget.tenantData!['mobileNumber'] ?? '';
      gender = widget.tenantData!['gender'] ?? '';
      photoUrl = widget.tenantData!['photoUrl'] as String?;
    } else if (widget.user != null) {
      email = widget.user!.email ?? '';
      if (widget.user!.displayName != null) {
        final parts = widget.user!.displayName!.trim().split(' ');
        if (parts.isNotEmpty) {
          firstName = parts.first;
          lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }
      }
      photoUrl = widget.user!.photoURL;
    }
  }

  Future<void> _loadLatestTenantData() async {
    if (email.isEmpty) return;
    final data = await Api.getUserDetailsByEmail(email);
    if (data != null) {
      setState(() {
        firstName = data['firstName'] ?? firstName;
        lastName = data['lastName'] ?? lastName;
        mobile = data['mobileNumber'] ?? mobile;
        gender = data['gender'] ?? gender;
        photoUrl = data['photoUrl'] ?? photoUrl;
      });
    }
  }

  // Sign out
  Future<void> _signOut() async {
    try {
      await Api.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, 'LoginScreen');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _BookingsTab(),
                  _DocumentsTab(email: email),
                  _PreferencesTab(
                    formKey: _formKey,
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    mobile: mobile,
                    gender: gender,
                    photoUrl: photoUrl,
                    onPickPhoto: _pickAndUploadProfilePhoto,
                    onSave: _saveProfile,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppConfig.primaryColor.withOpacity(0.1),
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl!) : null,
                child: photoUrl == null
                    ? Text(
                        (firstName.isNotEmpty ? firstName[0] : '?')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${firstName.isNotEmpty ? firstName : ''} ${lastName.isNotEmpty ? lastName : ''}'
                      .trim(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (email.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          email,
                          style: TextStyle(color: Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (mobile.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(mobile, style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppConfig.primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: AppConfig.primaryColor, width: 2.5),
          insets: const EdgeInsets.symmetric(horizontal: 24),
        ),
        tabs: const [
          Tab(icon: Icon(Icons.event_available), text: 'Bookings'),
          Tab(icon: Icon(Icons.description_outlined), text: 'Documents'),
          Tab(icon: Icon(Icons.settings_outlined), text: 'Preferences'),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final file = File(picked.path);
      final url = await Api.uploadImageToCloudinary(file, 'tenant_profiles');
      await FirebaseFirestore.instance
          .collection('Tenants')
          .doc(email)
          .set({'photoUrl': url}, SetOptions(merge: true));
      setState(() => photoUrl = url);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update photo: $e')),
      );
    }
  }

  Future<void> _saveProfile({
    required String first,
    required String last,
    required String phone,
    required String g,
  }) async {
    try {
      if (email.isEmpty) throw 'No email associated to this account';
      await FirebaseFirestore.instance.collection('Tenants').doc(email).set(
        {
          'firstName': first,
          'lastName': last,
          'mobileNumber': phone,
          'gender': g,
          'email': email,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      setState(() {
        firstName = first;
        lastName = last;
        mobile = phone;
        gender = g;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }
}

// ============ Bookings Tab (UI placeholder like the shared mock) ============
class _BookingsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Section(
              title: 'My Bookings',
              trailing:
                  TextButton(onPressed: () {}, child: const Text('View All'))),
          _BookingCard(),
          const SizedBox(height: 16),
          _Section(title: 'Help & Support'),
          _ListTileCard(
            leading:
                const Icon(Icons.support_agent_outlined, color: Colors.black87),
            title: 'Contact Support',
            onTap: () {},
          ),
          _ListTileCard(
            leading:
                const Icon(Icons.bug_report_outlined, color: Colors.black87),
            title: 'Report an Issue',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=80&q=80',
            width: 56,
            height: 56,
            fit: BoxFit.cover,
          ),
        ),
        title: const Text('Luxury Beach Resort'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SizedBox(height: 4),
            Text('Mar 15 - Mar 20, 2024'),
            SizedBox(height: 6),
            _StatusChip(label: 'Upcoming', color: Color(0xFF1976D2)),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}

// ============ Documents Tab ============
class _DocumentsTab extends StatelessWidget {
  final String email;
  const _DocumentsTab({required this.email});

  static const List<String> _docTypes = [
    'Passport',
    "Driver's License",
    'ID Card',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Section(title: 'My Documents'),
          const SizedBox(height: 8),
          ..._docTypes.map((t) => _DocumentTile(email: email, docType: t)),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatefulWidget {
  final String email;
  final String docType;
  const _DocumentTile({required this.email, required this.docType});

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    try {
      setState(() => _uploading = true);
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        setState(() => _uploading = false);
        return;
      }
      final url = await Api.uploadImageToCloudinary(
        File(picked.path),
        'tenant_documents/${widget.email.replaceAll('@', '_')}',
      );
      await FirebaseFirestore.instance
          .collection('Tenants')
          .doc(widget.email)
          .collection('Documents')
          .doc(widget.docType)
          .set({
        'name': widget.docType,
        'url': url,
        'status': 'Pending',
        'uploadedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${widget.docType} uploaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection('Tenants')
        .doc(widget.email)
        .collection('Documents')
        .doc(widget.docType);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final url = data?['url'] as String?;
        final status = (data?['status'] as String?) ?? 'Not uploaded';
        final isVerified = status.toLowerCase() == 'verified';
        final isPending = status.toLowerCase() == 'pending';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: _cardDecoration(),
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined,
                color: Colors.black87),
            title: Text(widget.docType),
            subtitle: Row(
              children: [
                _StatusChip(
                  label: status,
                  color: isVerified
                      ? const Color(0xFF2E7D32)
                      : isPending
                          ? const Color(0xFFF9A825)
                          : Colors.grey,
                ),
              ],
            ),
            trailing: _uploading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (url != null)
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () => _showImage(context, url),
                          tooltip: 'View',
                        ),
                      IconButton(
                        icon: const Icon(Icons.upload_outlined),
                        onPressed: _pickAndUpload,
                        tooltip: url == null ? 'Upload' : 'Replace',
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  void _showImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ============ Preferences Tab (editable profile) ============
class _PreferencesTab extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final String firstName;
  final String lastName;
  final String email;
  final String mobile;
  final String gender;
  final String? photoUrl;
  final Future<void> Function() onPickPhoto;
  final Future<void> Function({
    required String first,
    required String last,
    required String phone,
    required String g,
  }) onSave;

  const _PreferencesTab({
    required this.formKey,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.mobile,
    required this.gender,
    required this.photoUrl,
    required this.onPickPhoto,
    required this.onSave,
  });

  @override
  State<_PreferencesTab> createState() => _PreferencesTabState();
}

class _PreferencesTabState extends State<_PreferencesTab> {
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _phoneCtrl;
  String _gender = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firstCtrl = TextEditingController(text: widget.firstName);
    _lastCtrl = TextEditingController(text: widget.lastName);
    _phoneCtrl = TextEditingController(text: widget.mobile);
    _gender = widget.gender;
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Section(title: 'Edit Profile'),
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundImage: widget.photoUrl != null
                      ? NetworkImage(widget.photoUrl!)
                      : null,
                  child: widget.photoUrl == null
                      ? const Icon(Icons.person, size: 44)
                      : null,
                ),
                TextButton.icon(
                  onPressed: widget.onPickPhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Change photo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Form(
            key: widget.formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _input('First name', _firstCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _input('Last name', _lastCtrl)),
                  ],
                ),
                const SizedBox(height: 12),
                _input('Phone', _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    validator: (v) => v != null && v.length >= 8
                        ? null
                        : 'Enter valid phone'),
                const SizedBox(height: 12),
                _genderPicker(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save changes'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!widget.formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSave(
      first: _firstCtrl.text.trim(),
      last: _lastCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      g: _gender,
    );
    if (mounted) setState(() => _saving = false);
  }

  Widget _genderPicker() {
    return Container(
      decoration: _roundedBox(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.wc_outlined),
          const SizedBox(width: 12),
          const Text('Gender'),
          const Spacer(),
          DropdownButton<String>(
            value: _gender.isEmpty ? null : _gender,
            hint: const Text('Select'),
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _gender = v ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _input(String label, TextEditingController c,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return Container(
      decoration: _roundedBox(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
        keyboardType: keyboardType,
        validator:
            validator ?? (v) => v == null || v.isEmpty ? 'Required' : null,
      ),
    );
  }
}

// ============ Shared small widgets ============
class _Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _Section({required this.title, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _ListTileCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final VoidCallback? onTap;
  const _ListTileCard({required this.leading, required this.title, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: _cardDecoration(),
      child: ListTile(leading: leading, title: Text(title), onTap: onTap),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );

BoxDecoration _roundedBox() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
