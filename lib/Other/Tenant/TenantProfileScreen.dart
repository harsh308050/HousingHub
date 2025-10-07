import 'dart:io';
import 'package:flutter/material.dart';
import 'package:housinghub/Helper/Models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/AppConfig.dart';
import '/Helper/API.dart';
import 'TenantBookingsScreen.dart';
import 'TenantSupportScreen.dart';
import '../../Login/LoginScreen.dart';

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

  // Booking counts
  int activeBookingsCount = 0;
  int pendingBookingsCount = 0;
  int totalBookingsCount = 0;
  bool _loadingBookingCounts = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _hydrateFromInputs();
    _loadLatestTenantData();
    _loadBookingCounts();
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

  Future<void> _loadBookingCounts() async {
    if (email.isEmpty) return;

    try {
      setState(() {
        _loadingBookingCounts = true;
      });

      // Fetch all tenant bookings
      final bookings = await Api.getTenantBookings(email);

      // Count bookings by status
      int active = 0;
      int pending = 0;
      int total = bookings.length;

      for (var booking in bookings) {
        final status = booking['status']?.toString().toLowerCase() ?? '';
        final paymentInfo = booking['paymentInfo'] as Map<String, dynamic>?;
        final paymentStatus =
            paymentInfo?['status']?.toString().toLowerCase() ?? 'pending';

        // Only count bookings with completed payments
        if (paymentStatus == 'completed') {
          if (status == 'accepted' || status == 'completed') {
            active++;
          } else if (status == 'pending') {
            pending++;
          }
        }
        // If payment is not completed, it's still counted in total but not in active/pending
      }

      setState(() {
        activeBookingsCount = active;
        pendingBookingsCount = pending;
        totalBookingsCount = total;
        _loadingBookingCounts = false;
      });
    } catch (e) {
      print('Error loading booking counts: $e');
      setState(() {
        _loadingBookingCounts = false;
      });
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
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _BookingsTab(
                    activeCount: activeBookingsCount,
                    pendingCount: pendingBookingsCount,
                    totalCount: totalBookingsCount,
                    isLoading: _loadingBookingCounts,
                  ),
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
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Container(
      width: width - 20,
      height: height * 0.3,
      alignment: Alignment.center,
      margin: EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: AppConfig.primaryColor.withOpacity(0.12),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? Text(
                    (firstName.isNotEmpty ? firstName[0] : '?').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            '${firstName.isNotEmpty ? firstName : ''} ${lastName.isNotEmpty ? lastName : ''}'
                .trim(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (email.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.email_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Flexible(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(mobile, style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        splashFactory: NoSplash.splashFactory,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppConfig.primaryColor,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppConfig.primaryColor,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        tabs: const [
          SizedBox(
              width: 120,
              child: Tab(
                  icon: Icon(Icons.book_outlined, size: 20), text: 'Bookings')),
          SizedBox(
              width: 120,
              child: Tab(
                  icon: Icon(Icons.description_outlined, size: 20),
                  text: 'Documents')),
          SizedBox(
            width: 120,
            child: Tab(
                icon: Icon(Icons.settings_outlined, size: 20),
                text: 'Preferences'),
          ),
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
      Models.showSuccessSnackBar(context, 'Profile photo updated');
    } catch (e) {
      if (!mounted) return;
      Models.showErrorSnackBar(context, 'Failed to update photo: $e');
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
      Models.showSuccessSnackBar(context, 'Profile saved');
    } catch (e) {
      if (!mounted) return;
      Models.showErrorSnackBar(context, 'Failed to save: $e');
    }
  }
}

// ============ Documents Tab ============
class _DocumentsTab extends StatelessWidget {
  final String email;
  const _DocumentsTab({required this.email});

  static const List<_DocType> _docTypes = [
    _DocType(
      label: 'Proof of Identity',
      options: [
        'Aadhaar Card',
        'Passport',
        'Voter ID',
        "Driver's License",
      ],
      docKey: 'Proof of Identity',
    ),
    _DocType(
      label: 'Proof of Address',
      options: [
        'Aadhaar Card',
        'Utility Bill',
        'Bank Statement',
      ],
      docKey: 'Proof of Address',
    ),
    _DocType(
      label: 'PAN Card',
      options: ['PAN Card'],
      docKey: 'PAN Card',
    ),
    _DocType(
      label: 'Passport-Sized Photograph',
      options: ['Photograph 1'],
      docKey: 'Passport Photo',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Section(title: 'Documents for Rent Agreement'),
          const SizedBox(height: 8),
          ..._docTypes.map((t) => _DocumentTile(
                email: email,
                docType: t.docKey,
                label: t.label,
                options: t.options,
              )),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatefulWidget {
  final String email;
  final String docType;
  final String label;
  final List<String> options;
  const _DocumentTile({
    required this.email,
    required this.docType,
    required this.label,
    required this.options,
  });

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  bool _uploading = false;
  String? _selectedOption;

  Future<void> _pickAndUpload() async {
    if (widget.options.length > 1 &&
        (_selectedOption == null || _selectedOption!.isEmpty)) {
      Models.showWarningSnackBar(context, 'Please select a document type');
      return;
    }
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
        'name': widget.label,
        'option': _selectedOption ?? widget.options.first,
        'url': url,
        'status': 'Uploaded',
        'uploadedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      Models.showSuccessSnackBar(context, '${widget.label} uploaded');
    } catch (e) {
      if (!mounted) return;
      Models.showErrorSnackBar(context, 'Upload failed: $e');
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
        final option = data?['option'] as String?;
        final isUploaded = status.toLowerCase() == 'uploaded';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.insert_drive_file_outlined,
                      color: Colors.black87),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _StatusChip(
                    label: isUploaded ? 'Uploaded' : 'Not uploaded',
                    color: isUploaded ? const Color(0xFF1976D2) : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (widget.options.length > 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedOption ?? option,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    hint: const Text('Select type'),
                    items: widget.options
                        .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedOption = v),
                  ),
                ),
              if (widget.options.length > 1) const SizedBox(height: 10),
              Row(
                children: [
                  if (option != null && option.isNotEmpty)
                    Expanded(
                      child: Text(
                        option,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (_uploading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Row(
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
                ],
              ),
            ],
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

class _DocType {
  final String label;
  final List<String> options;
  final String docKey;
  const _DocType(
      {required this.label, required this.options, required this.docKey});
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
    final width = MediaQuery.of(context).size.width;
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
                  icon: const Icon(Icons.camera_alt_outlined,
                      color: AppConfig.primaryColor),
                  label: const Text('Change photo',
                      style: TextStyle(color: AppConfig.primaryColor)),
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
                    width: width - 20,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: Text('Save changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppConfig.primaryColor, // Button background
                        foregroundColor: Colors.white, // Text and icon color
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8), // Reduced radius
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    )),
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
  const _Section({required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
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

class _BookingsTab extends StatefulWidget {
  final int activeCount;
  final int pendingCount;
  final int totalCount;
  final bool isLoading;

  const _BookingsTab({
    required this.activeCount,
    required this.pendingCount,
    required this.totalCount,
    required this.isLoading,
  });

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  bool _checkingAccountStatus = false;

  Future<void> _signOut() async {
    try {
      await Api.signOut();
      Navigator.pushReplacementNamed(context, 'LoginScreen');
    } catch (e) {
      Models.showErrorSnackBar(context, 'Error signing out: $e');
    }
  }

  Future<void> _switchToOwnerAccount() async {
    setState(() => _checkingAccountStatus = true);

    try {
      final currentUser = Api.getCurrentUser();
      if (currentUser?.email == null) {
        Models.showErrorSnackBar(context, 'No user logged in');
        return;
      }

      final switchingInfo =
          await Api.getAccountSwitchingInfo(currentUser!.email!);

      if (switchingInfo['canSwitchToOwner'] == true) {
        // User has approved owner account, navigate to owner home
        Navigator.pushNamedAndRemoveUntil(
            context, 'OwnerHomeScreen', (route) => false);
      } else if (switchingInfo['hasOwnerAccount'] == true) {
        // User has owner account but not approved
        final status = switchingInfo['ownerApprovalStatus'] ?? 'unknown';
        if (status == 'pending') {
          Models.showInfoSnackBar(context,
              'Your owner account is pending approval. Please wait for verification.');
          Navigator.pushNamedAndRemoveUntil(
              context, 'OwnerApprovalScreen', (route) => false);
        } else if (status == 'rejected') {
          Models.showWarningSnackBar(context,
              'Your owner account was rejected. Please resubmit your documents.');
          Navigator.pushNamedAndRemoveUntil(
              context, 'OwnerApprovalScreen', (route) => false);
        } else {
          Models.showInfoSnackBar(
              context, 'Please complete your owner verification first.');
          Navigator.pushNamedAndRemoveUntil(
              context, 'OwnerApprovalScreen', (route) => false);
        }
      } else {
        // User doesn't have owner account, navigate to signup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
            settings: RouteSettings(arguments: {
              'preOpenTab': 'ownerSignup',
              'switchingFromTenant': true,
            }),
          ),
        );
      }
    } catch (e) {
      Models.showErrorSnackBar(context, 'Error checking account status: $e');
    } finally {
      if (mounted) setState(() => _checkingAccountStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.book_outlined, size: 24),
              const SizedBox(width: 12),
              const Text(
                'My Bookings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Quick stats cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Active',
                  widget.isLoading ? '...' : '${widget.activeCount}',
                  Icons.home_outlined,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  widget.isLoading ? '...' : '${widget.pendingCount}',
                  Icons.schedule_outlined,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total',
                  widget.isLoading ? '...' : '${widget.totalCount}',
                  Icons.book_outlined,
                  AppConfig.primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // View All Bookings Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TenantBookingsScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'View All Bookings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Account switching section
          ElevatedButton(
            onPressed: _checkingAccountStatus ? null : _switchToOwnerAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppConfig.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: AppConfig.primaryColor, width: 1.5),
              ),
              shadowColor: Colors.black.withOpacity(0),
            ),
            child: _checkingAccountStatus
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppConfig.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Checking...'),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Switch to Owner Mode',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 16),
          _Section(title: 'Help & Support'),
          _ListTileCard(
            leading:
                const Icon(Icons.support_agent_outlined, color: Colors.black87),
            title: 'Contact Support',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TenantSupportScreen(),
                ),
              );
            },
          ),
          SizedBox(height: 8),
          // Quick actions
          GestureDetector(
            onTap: _signOut,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.logout, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Log Out',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
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
