import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:housinghub/Helper/Models.dart';

class OwnerApprovalScreen extends StatefulWidget {
  const OwnerApprovalScreen({super.key});

  @override
  State<OwnerApprovalScreen> createState() => _OwnerApprovalScreenState();
}

class _OwnerApprovalScreenState extends State<OwnerApprovalScreen> {
  final _picker = ImagePicker();
  File? _selectedImage;
  String _proofType = 'Aadhaar';
  bool _isSubmitting = false;
  String? _status; // pending | approved | rejected | not-submitted | null
  String? _rejectionReason;
  String? _email;

  @override
  void initState() {
    super.initState();
    _email = FirebaseAuth.instance.currentUser?.email;
  }

  Future<void> _pickImage() async {
    final x =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x != null) {
      setState(() => _selectedImage = File(x.path));
    }
  }

  Future<void> _submit() async {
    if (_email == null || _email!.isEmpty) return;
    if (_selectedImage == null) {
      Models.showWarningSnackBar(context, 'Please select an ID proof image.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await Api.uploadOwnerIdProofAndRequestApproval(
        email: _email!,
        proofImageFile: _selectedImage!,
        proofType: _proofType,
      );
      Models.showSuccessSnackBar(context, 'Submitted for approval.');
      setState(() {
        _status = 'pending';
      });
    } catch (e) {
      Models.showErrorSnackBar(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _email ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Owner Verification',
            style: TextStyle(color: Colors.black87)),
      ),
      body: email.isEmpty
          ? const Center(child: Text('Please sign in again.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('Owners')
                  .doc(email)
                  .snapshots(),
              builder: (context, snapshot) {
                final raw = snapshot.data?.data() ?? {};
                // Normalize dynamic map to Map<String, dynamic>
                final Map<String, dynamic> data = {
                  for (final e in raw.entries) e.key.toString(): e.value
                };
                final status =
                    (data['approvalStatus'] ?? _status ?? 'not-submitted')
                        .toString();
                final dynamic dynProof = data['idProof'] ?? {};
                final Map<String, dynamic> idProof = dynProof is Map
                    ? {
                        for (final e in dynProof.entries)
                          e.key.toString(): e.value
                      }
                    : <String, dynamic>{};
                _rejectionReason = data['rejectionReason']?.toString();

                if (status == 'approved') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    Navigator.pushReplacementNamed(context, 'OwnerHomeScreen');
                  });
                }

                return SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildContent(status),
                        const SizedBox(height: 12),
                        _OwnerDetailsCard(owner: data),
                        const SizedBox(height: 12),
                        _DocumentCard(
                          idProof: idProof,
                          onReplace:
                              status == 'rejected' || status == 'not-submitted'
                                  ? () {
                                      _showReplaceBottomSheet();
                                    }
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        if (status == 'rejected' &&
                            (_rejectionReason?.isNotEmpty ?? false))
                          _RejectionReason(reason: _rejectionReason!),
                        const SizedBox(height: 12),
                        _HelpRow(onEmail: _launchEmail, onCall: _launchCall),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildContent(String status) {
    switch (status) {
      case 'pending':
        return _StatusCard(
          title: 'Verification in progress',
          message:
              'We\'ll notify you once the admin reviews your document. This usually takes up to 24 hours.',
          color: Colors.amber[700]!,
          icon: Icons.hourglass_top,
        );
      case 'rejected':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusCard(
              title: 'Verification Rejected',
              message: _rejectionReason ??
                  'Your document was rejected. Please re-upload a clear, valid ID and resubmit.',
              color: Colors.red[700]!,
              icon: Icons.error_outline,
            ),
            const SizedBox(height: 12),
            _uploadForm(reupload: true),
          ],
        );
      case 'not-submitted':
      default:
        return _uploadForm();
    }
  }

  Widget _uploadForm({bool reupload = false}) {
    final width = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          reupload ? 'Re-upload Proof of Identity' : 'Proof of Identity',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonFormField<String>(
            value: _proofType,
            decoration: const InputDecoration(
              labelText: 'Document Type',
              border: InputBorder.none,
            ),
            items: const [
              DropdownMenuItem(value: 'Aadhaar', child: Text('Aadhaar Card')),
              DropdownMenuItem(value: 'PAN', child: Text('PAN Card')),
              DropdownMenuItem(
                  value: 'Driving License', child: Text('Driving License')),
              DropdownMenuItem(value: 'Passport', child: Text('Passport')),
            ],
            onChanged: (v) => setState(() => _proofType = v ?? 'Aadhaar'),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: width * 0.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.grey.shade100,
              image: _selectedImage != null
                  ? DecorationImage(
                      image: FileImage(_selectedImage!), fit: BoxFit.cover)
                  : null,
            ),
            child: _selectedImage == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.upload_file, size: 36, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Tap to upload ID proof'),
                      ],
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor),
            child: _isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    reupload ? 'Resubmit for Approval' : 'Submit for Approval',
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }
}

class _OwnerDetailsCard extends StatelessWidget {
  final Map<String, dynamic> owner;
  const _OwnerDetailsCard({required this.owner});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Profile',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _infoRow('Name', owner['fullName'] ?? owner['displayName'] ?? '-'),
          _infoRow('Email', owner['email'] ?? '-'),
          _infoRow('Phone', owner['mobileNumber'] ?? owner['phone'] ?? '-'),
          _infoRow('City', owner['city'] ?? '-'),
          _infoRow('State', owner['state'] ?? '-'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          )
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final Map<String, dynamic> idProof;
  final VoidCallback? onReplace;
  const _DocumentCard({required this.idProof, this.onReplace});

  @override
  Widget build(BuildContext context) {
    final String type = (idProof['type'] ?? '').toString();
    final String url = (idProof['url'] ?? '').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Uploaded Document',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (onReplace != null)
                TextButton.icon(
                  onPressed: onReplace,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Replace'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (url.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        )),
              ),
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              alignment: Alignment.center,
              child: const Text('No document submitted yet'),
            ),
          if (type.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Type: $type', style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _RejectionReason extends StatelessWidget {
  final String reason;
  const _RejectionReason({required this.reason});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5C2BD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFB3261E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Why it was rejected',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.black87)),
                const SizedBox(height: 6),
                Text(reason, style: const TextStyle(color: Colors.black87)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final VoidCallback onEmail;
  final VoidCallback onCall;
  const _HelpRow({required this.onEmail, required this.onCall});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(
              Icons.email_outlined,
              color: Colors.white,
            ),
            label: const Text('Email support'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCall,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppConfig.primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(Icons.call_outlined, color: AppConfig.primaryColor),
            label: Text('Call helpline',
                style: TextStyle(color: AppConfig.primaryColor)),
          ),
        ),
      ],
    );
  }
}

// ======== helpers ========

void _showReplaceBottomSheet() {}

Future<void> _launchEmail() async {
  final Uri email = Uri(
    scheme: 'mailto',
    path: AppConfig.supportEmail,
    queryParameters: {
      'subject': "Owner verification help",
    },
  );
  try {
    final ok = await canLaunchUrl(email) && await launchUrl(email);
    if (!ok) throw Exception();
  } catch (_) {}
}

Future<void> _launchCall() async {
  final Uri tel = Uri(scheme: 'tel', path: AppConfig.supportPhone);
  try {
    final ok = await canLaunchUrl(tel) && await launchUrl(tel);
    if (!ok) throw Exception();
  } catch (_) {}
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  const _StatusCard(
      {required this.title,
      required this.message,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 6),
                Text(message, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
