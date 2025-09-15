import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_filex/open_filex.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/Helper/BookingModels.dart';
import 'package:housinghub/Helper/PdfReceiptGenerator.dart';

class BookingDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final String viewer; // 'tenant' | 'owner'

  const BookingDetailsScreen(
      {super.key, required this.bookingData, required this.viewer});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  late final Map<String, dynamic> booking;
  late final Map<String, dynamic> property;
  late final Map<String, dynamic> tenant;

  final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    booking = widget.bookingData;
    property = booking['propertyData'] ?? {};
    tenant = booking['tenantData'] ?? {};
  }

  @override
  Widget build(BuildContext context) {
    final status = _parseStatus(booking['status']);
    final createdAt = _asDateTime(booking['createdAt']);
    final checkInDate = _asDateTime(booking['checkInDate']);
    final amount = _computeTotalAmount(booking);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Booking Details',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerCard(status, createdAt, amount),
            const SizedBox(height: 16),
            _propertyCard(),
            const SizedBox(height: 16),
            _bookingInfoCard(checkInDate, amount),
            const SizedBox(height: 16),
            _peopleCard(),
            const SizedBox(height: 16),
            _documentsCard(),
            const SizedBox(height: 16),
            _paymentCard(),
            const SizedBox(height: 24),
            _actionsRow(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _headerCard(BookingStatus status, DateTime? createdAt, double amount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusChip(status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property['title'] ?? 'Property',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  booking['bookingId'] != null
                      ? 'Booking ID: ${booking['bookingId']}'
                      : '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                      'Booked on ${DateFormat('MMM dd, yyyy - hh:mm a').format(createdAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ],
            ),
          ),
          Text(_inr.format(amount),
              style: TextStyle(
                  color: AppConfig.primaryColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statusChip(BookingStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case BookingStatus.accepted:
        bg = Colors.green[50]!;
        fg = Colors.green[700]!;
        break;
      case BookingStatus.rejected:
        bg = Colors.red[50]!;
        fg = Colors.red[700]!;
        break;
      case BookingStatus.completed:
        bg = Colors.blue[50]!;
        fg = Colors.blue[700]!;
        break;
      case BookingStatus.pending:
        bg = Colors.orange[50]!;
        fg = Colors.orange[700]!;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status.displayName,
          style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
    );
  }

  Widget _propertyCard() {
    final images = (property['images'] is List)
        ? List<String>.from(property['images'])
        : const <String>[];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  images.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(property['title'] ?? 'Property',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(property['address'] ?? 'Address',
                          style: TextStyle(color: Colors.grey[700]))),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  _pill(
                      'Type',
                      '${property['roomType'] ?? 'N/A'} ${property['propertyType'] ?? ''}'
                          .trim()),
                  _pill(
                      'Monthly Rent',
                      _amountText(_parsePrice(property['rent'] ??
                          property['price'] ??
                          property['monthlyRent']))),
                  _pill(
                      'Security Deposit',
                      _amountText(_parsePrice(
                          property['deposit'] ?? property['securityDeposit']))),
                  if ((property['minimumBookingPeriod'] ?? '')
                      .toString()
                      .isNotEmpty)
                    _pill('Min Period', property['minimumBookingPeriod']),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _amountText(double v) => v > 0 ? _inr.format(v) : 'N/A';

  Widget _bookingInfoCard(DateTime? checkInDate, double amount) {
    return _sectionCard('Booking Information', [
      _row(
          'Check-in Date',
          checkInDate != null
              ? DateFormat('MMM dd, yyyy').format(checkInDate)
              : 'N/A'),
      _row('Total Amount', _inr.format(amount)),
      if ((booking['notes'] ?? '').toString().trim().isNotEmpty)
        _row('Notes', booking['notes']),
    ]);
  }

  Widget _peopleCard() {
    final ownerName =
        (booking['ownerName'] ?? property['ownerName'] ?? '').toString();
    final ownerPhone =
        (booking['ownerMobileNumber'] ?? property['ownerPhone'] ?? '')
            .toString();
    final ownerEmail = (booking['ownerEmail'] ?? '').toString();

    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 600; // stack on phones

      final tenantCard = _sectionCard('Tenant', [
        _row('Name',
            '${tenant['firstName'] ?? ''} ${tenant['lastName'] ?? ''}'.trim()),
        _row('Email', tenant['tenantEmail'] ?? ''),
        _row('Phone', tenant['mobileNumber'] ?? ''),
        _row('Gender', tenant['gender'] ?? ''),
      ]);

      final ownerCard = _sectionCard('Owner', [
        _row('Name', ownerName.isNotEmpty ? ownerName : 'Not provided'),
        if (ownerEmail.isNotEmpty) _row('Email', ownerEmail),
        if (ownerPhone.isNotEmpty) _row('Phone', ownerPhone),
      ]);

      if (isNarrow) {
        // No Expanded inside Column with unbounded height
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tenantCard,
            const SizedBox(height: 12),
            ownerCard,
          ],
        );
      }

      // Wide screens: use Row with Expanded to split space evenly
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: tenantCard),
          const SizedBox(width: 12),
          Expanded(child: ownerCard),
        ],
      );
    });
  }

  Widget _documentsCard() {
    final idProof = booking['idProof'];
    if (idProof == null) return const SizedBox.shrink();

    final entries = <MapEntry<String, dynamic>>[];
    if (idProof is Map) {
      idProof.forEach((k, v) => entries.add(MapEntry(k.toString(), v)));
    } else if (idProof is List) {
      for (final item in idProof) {
        if (item is Map<String, dynamic>) {
          entries.add(
              MapEntry(item['documentType']?.toString() ?? 'Document', item));
        }
      }
    }

    if (entries.isEmpty) return const SizedBox.shrink();

    return _sectionCard('Tenant Documents', [
      ...entries.map((e) => _docRow(e.key, e.value)),
    ]);
  }

  Widget _paymentCard() {
    final payment = booking['paymentInfo'];
    final status =
        payment != null ? (payment['status']?.toString() ?? 'N/A') : 'N/A';
    final amount = payment != null && payment['amount'] != null
        ? _inr.format(_parsePrice(payment['amount']))
        : null;
    final date = payment != null && payment['paymentCompletedAt'] != null
        ? DateFormat('MMM dd, yyyy HH:mm').format(
            DateTime.tryParse(payment['paymentCompletedAt'].toString()) ??
                DateTime.now())
        : null;
    final receiptUrl = booking['receiptUrl']?.toString();

    return _sectionCard('Payment', [
      _row('Status', status),
      if (payment != null && payment['paymentId'] != null)
        _row('Payment ID', payment['paymentId'].toString()),
      if (payment != null && payment['paymentMethod'] != null)
        _row('Method', payment['paymentMethod'].toString()),
      if (payment != null && payment['currency'] != null)
        _row('Currency', payment['currency'].toString()),
      if (amount != null) _row('Amount', amount),
      if (date != null) _row('Payment Date', date),
      if (receiptUrl != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(Icons.receipt, color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Receipt available',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600))),
              TextButton.icon(
                onPressed: () => _downloadReceipt(receiptUrl),
                icon: const Icon(Icons.download),
                label: const Text('Download'),
                style: TextButton.styleFrom(
                    foregroundColor: AppConfig.primaryColor),
              )
            ],
          ),
        ),
    ]);
  }

  Widget _actionsRow() {
    final receiptUrl = booking['receiptUrl']?.toString();
    return Row(
      children: [
        if (receiptUrl != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _downloadReceipt(receiptUrl),
              icon: const Icon(Icons.download, color: Colors.white),
              label: const Text('Download Receipt',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        if (receiptUrl != null) const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _contactOwner,
            icon: const Icon(Icons.phone),
            label: const Text('Contact Owner'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: AppConfig.primaryColor)),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: Colors.grey[600]))),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              softWrap: false,
              overflow: TextOverflow.fade,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppConfig.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppConfig.primaryColor.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ',
            style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        Text(value,
            style: TextStyle(
                color: AppConfig.primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
      ]),
    );
  }

  Widget _docRow(String docType, dynamic doc) {
    final name = (doc['name'] ?? doc['documentName'] ?? docType).toString();
    final url = (doc['documentUrl'] ?? doc['url'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        const Icon(Icons.description, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text('$docType — $name')),
        if (url.isNotEmpty)
          TextButton(
            onPressed: () => _openUrl(url),
            child: const Text('Open'),
          )
      ]),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open document')));
      }
    }
  }

  Future<void> _downloadReceipt(String url) async {
    try {
      // Try Cloudinary-safe URL variants first
      final variants = <String>{
        url,
        _forceRawAttachmentUrl(url),
        _forceRawUrl(url),
      }.toList();

      http.Response? ok;
      for (final u in variants) {
        final resp = await http.get(Uri.parse(u));
        if (resp.statusCode == 200 &&
            resp.bodyBytes.isNotEmpty &&
            _looksLikePdf(resp.bodyBytes, resp.headers)) {
          ok = resp;
          break;
        }
      }

      // If still unauthorized, regenerate locally as a fallback
      if (ok == null) {
        final bytes = await _generateReceiptLocally();
        final baseName =
            'HousingHub_Receipt_${booking['bookingId'] ?? DateTime.now().millisecondsSinceEpoch}';
        final savedPath = await _savePdfToDownloads(bytes, baseName) ?? '';
        if (mounted) {
          final hasPath = savedPath.toString().isNotEmpty;
          final snackBar = SnackBar(
            content: Text(hasPath
                ? 'Receipt saved: $savedPath'
                : 'Receipt saved to Downloads (regenerated locally)'),
            action: hasPath
                ? SnackBarAction(
                    label: 'Open',
                    onPressed: () {
                      OpenFilex.open(savedPath.toString());
                    },
                  )
                : null,
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
        return;
      }

      final baseName =
          'HousingHub_Receipt_${booking['bookingId'] ?? DateTime.now().millisecondsSinceEpoch}';
      final savedPath = await _savePdfToDownloads(ok.bodyBytes, baseName) ?? '';

      if (mounted) {
        final hasPath = savedPath.toString().isNotEmpty;
        final snackBar = SnackBar(
          content: Text(hasPath
              ? 'Receipt saved: $savedPath'
              : 'Receipt saved to Downloads'),
          action: hasPath
              ? SnackBarAction(
                  label: 'Open',
                  onPressed: () {
                    OpenFilex.open(savedPath.toString());
                  },
                )
              : null,
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error downloading receipt: $e')));
      }
    }
  }

  // Best-effort save to public Downloads/HousingHub on Android; otherwise fall back to plugin's location
  Future<String?> _savePdfToDownloads(
      Uint8List bytes, String fileBaseName) async {
    String? finalPath;
    try {
      finalPath = await FileSaver.instance.saveFile(
          name: fileBaseName, bytes: bytes, ext: 'pdf', mimeType: MimeType.pdf);
    } catch (_) {}

    if (Platform.isAndroid) {
      try {
        final downloadsDir =
            Directory('/storage/emulated/0/Download/HousingHub');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        final out = File('${downloadsDir.path}/$fileBaseName.pdf');
        await out.writeAsBytes(bytes, flush: true);
        finalPath = out.path;
      } catch (e) {
        // Ignore if scoped storage blocks direct write; the plugin-saved path remains
        debugPrint('Warning: Could not copy to public Downloads: $e');
      }
    }
    return finalPath;
  }

  bool _looksLikePdf(Uint8List bytes, Map<String, String> headers) {
    final ct = headers['content-type']?.toLowerCase() ?? '';
    // Check for proper content-type or PDF magic header
    final hasPdfHeader = bytes.length > 5 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46 && // F
        bytes[4] == 0x2D; // -
    if (ct.contains('application/pdf')) return hasPdfHeader;
    // Some CDNs return octet-stream; rely on magic header
    if (ct.contains('application/octet-stream')) return hasPdfHeader;
    // If content-type looks like HTML or text, reject
    if (ct.contains('text/html') || ct.contains('text/plain')) return false;
    // Fallback to header check
    return hasPdfHeader;
  }

  Future<Uint8List> _generateReceiptLocally() async {
    final tenantData = Map<String, dynamic>.from(tenant);
    final propertyData = Map<String, dynamic>.from(property);
    final ownerData = <String, dynamic>{
      'name': (booking['ownerName'] ?? property['ownerName'] ?? '').toString(),
      'email':
          (booking['ownerEmail'] ?? property['ownerEmail'] ?? '').toString(),
      'mobileNumber':
          (booking['ownerMobileNumber'] ?? property['ownerPhone'] ?? '')
              .toString(),
    };
    final paymentInfo = Map<String, dynamic>.from(booking['paymentInfo'] ?? {});
    final checkInDate = _asDateTime(booking['checkInDate']) ?? DateTime.now();
    final paymentDate = _asDateTime(
            paymentInfo['paymentCompletedAt'] ?? booking['createdAt']) ??
        DateTime.now();
    final rentAmount = _parsePrice(
        property['rent'] ?? property['price'] ?? property['monthlyRent']);
    final depositAmount =
        _parsePrice(property['deposit'] ?? property['securityDeposit']);
    double r = rentAmount, d = depositAmount;
    if (r <= 0 && d <= 0) {
      r = _computeTotalAmount(booking);
      d = 0;
    }
    final bytes = await PdfReceiptGenerator.generateReceiptBytes(
      bookingId: (booking['bookingId'] ?? '').toString(),
      tenantData: tenantData,
      propertyData: propertyData,
      ownerData: ownerData,
      paymentData: paymentInfo,
      checkInDate: checkInDate,
      paymentDate: paymentDate,
      rentAmount: r,
      depositAmount: d,
      notes: (booking['notes'] ?? '').toString().trim().isEmpty
          ? null
          : booking['notes'].toString(),
    );
    return bytes;
  }

  String _forceRawAttachmentUrl(String url) {
    // Cloudinary PDF direct download normalization
    var u = url;
    // If delivered on image pipeline, switch to raw
    if (u.contains('/image/upload/')) {
      u = u.replaceFirst('/image/upload/', '/raw/upload/');
    }
    // Ensure attachment flag for better saving behavior
    if (u.contains('/upload/') && !u.contains('/upload/fl_attachment/')) {
      u = u.replaceFirst('/upload/', '/upload/fl_attachment/');
    }
    return u;
  }

  String _forceRawUrl(String url) {
    // Minimal raw variant without attachment flag
    if (url.contains('/image/upload/')) {
      return url.replaceFirst('/image/upload/', '/raw/upload/');
    }
    return url;
  }

  void _contactOwner() async {
    // Prefer booking ownerMobileNumber; fallback to property ownerPhone
    final raw = (booking['ownerMobileNumber'] ?? property['ownerPhone'] ?? '')
        .toString()
        .trim();
    final phone = _sanitizePhone(raw);
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Owner phone number not available')));
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open dialer')));
      }
    }
  }

  String _sanitizePhone(String input) {
    // Keep leading + and digits
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < trimmed.length; i++) {
      final c = trimmed[i];
      if (i == 0 && c == '+') {
        buffer.write(c);
      } else if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) {
        buffer.write(c);
      }
    }
    return buffer.toString();
  }

  static BookingStatus _parseStatus(dynamic value) {
    try {
      return BookingStatus.values.firstWhere((s) => s.toFirestore() == value);
    } catch (_) {
      return BookingStatus.pending;
    }
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static double _parsePrice(dynamic price) {
    if (price == null) return 0;
    if (price is num) return price.toDouble();
    final s = price.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }

  static double _computeTotalAmount(Map<String, dynamic> bookingData) {
    final amount = bookingData['amount'];
    if (amount != null) {
      final a = _parsePrice(amount);
      if (a > 0) return a;
    }
    final propertyData = bookingData['propertyData'] ?? {};
    final rent = _parsePrice(propertyData['rent'] ??
        propertyData['price'] ??
        propertyData['monthlyRent']);
    final deposit =
        _parsePrice(propertyData['deposit'] ?? propertyData['securityDeposit']);
    final computed = rent + deposit;
    if (computed > 0) return computed;
    final paymentInfo = bookingData['paymentInfo'];
    if (paymentInfo != null) {
      final paid = _parsePrice(paymentInfo['amount']);
      if (paid > 0) return paid;
    }
    return 0;
  }
}
