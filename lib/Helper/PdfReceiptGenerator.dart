import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/config/ApiKeys.dart';

class PdfReceiptGenerator {
  static Future<String> generateAndUploadReceipt({
    required String bookingId,
    required Map<String, dynamic> tenantData,
    required Map<String, dynamic> propertyData,
    required Map<String, dynamic> ownerData,
    required Map<String, dynamic> paymentData,
    required DateTime checkInDate,
    DateTime? checkoutDate,
    int? bookingPeriodMonths,
    required DateTime paymentDate,
    required double rentAmount,
    required double depositAmount,
    String? notes,
  }) async {
    try {
      // Create a human-friendly receipt number
      final datePart = DateFormat('yyyyMMdd').format(paymentDate);
      final shortId = bookingId.isNotEmpty && bookingId.length >= 8
          ? bookingId.substring(0, 8).toUpperCase()
          : bookingId.toUpperCase();
      final receiptNo = 'HH-$shortId-$datePart';
      // Generate PDF
      final pdf = await _generatePdfReceipt(
        bookingId: bookingId,
        receiptNo: receiptNo,
        tenantData: tenantData,
        propertyData: propertyData,
        ownerData: ownerData,
        paymentData: paymentData,
        checkInDate: checkInDate,
        checkoutDate: checkoutDate,
        bookingPeriodMonths: bookingPeriodMonths,
        paymentDate: paymentDate,
        rentAmount: rentAmount,
        depositAmount: depositAmount,
        notes: notes,
      );

      // Save PDF to temporary file
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'receipt_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Upload to Cloudinary as RAW (best for PDFs for direct download)
      final cloudinary = CloudinaryPublic(
        ApiKeys.cloudinaryCloudName,
        ApiKeys.cloudinaryUploadPreset,
      );
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Raw,
          folder: 'receipts',
        ),
      );

      // Clean up temporary file
      await file.delete();

      // Normalize to raw + fl_attachment for consistent public delivery
      return _normalizeRawAttachmentUrl(response.secureUrl);
    } catch (e) {
      throw Exception('Failed to generate and upload receipt: $e');
    }
  }

  static String _normalizeRawAttachmentUrl(String url) {
    var u = url;
    if (u.contains('/image/upload/')) {
      u = u.replaceFirst('/image/upload/', '/raw/upload/');
    }
    if (u.contains('/upload/') && !u.contains('/upload/fl_attachment/')) {
      u = u.replaceFirst('/upload/', '/upload/fl_attachment/');
    }
    return u;
  }

  // Generate the receipt PDF bytes without uploading (for local save/fallback)
  static Future<Uint8List> generateReceiptBytes({
    required String bookingId,
    required Map<String, dynamic> tenantData,
    required Map<String, dynamic> propertyData,
    required Map<String, dynamic> ownerData,
    required Map<String, dynamic> paymentData,
    required DateTime checkInDate,
    DateTime? checkoutDate,
    int? bookingPeriodMonths,
    required DateTime paymentDate,
    required double rentAmount,
    required double depositAmount,
    String? notes,
  }) async {
    // Create a human-friendly receipt number
    final datePart = DateFormat('yyyyMMdd').format(paymentDate);
    final shortId = bookingId.isNotEmpty && bookingId.length >= 8
        ? bookingId.substring(0, 8).toUpperCase()
        : bookingId.toUpperCase();
    final receiptNo = 'HH-$shortId-$datePart';

    final doc = await _generatePdfReceipt(
      bookingId: bookingId,
      receiptNo: receiptNo,
      tenantData: tenantData,
      propertyData: propertyData,
      ownerData: ownerData,
      paymentData: paymentData,
      checkInDate: checkInDate,
      checkoutDate: checkoutDate,
      bookingPeriodMonths: bookingPeriodMonths,
      paymentDate: paymentDate,
      rentAmount: rentAmount,
      depositAmount: depositAmount,
      notes: notes,
    );
    return await doc.save();
  }

  static Future<pw.Document> _generatePdfReceipt({
    required String bookingId,
    required String receiptNo,
    required Map<String, dynamic> tenantData,
    required Map<String, dynamic> propertyData,
    required Map<String, dynamic> ownerData,
    required Map<String, dynamic> paymentData,
    required DateTime checkInDate,
    DateTime? checkoutDate,
    int? bookingPeriodMonths,
    required DateTime paymentDate,
    required double rentAmount,
    required double depositAmount,
    String? notes,
  }) async {
    final pdf = pw.Document();

    // Load fonts
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final totalAmount = rentAmount + depositAmount;

    // Prepare logo image if available
    pw.ImageProvider? logoImage;
    if (AppConfig.showLogoOnReceipt) {
      try {
        logoImage = await imageFromAssetBundle(AppConfig.logoPath);
      } catch (_) {
        logoImage = null; // ignore if not found
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        footer: (context) => _buildFooter(
          font,
          receiptNo: receiptNo,
          bookingId: bookingId,
          paymentId: paymentData['paymentId']?.toString(),
        ),
        build: (pw.Context context) => [
          // Header Section
          _buildHeader(font, fontBold, logoImage),
          pw.SizedBox(height: 30),

          // Receipt Title
          pw.Center(
            child: pw.Text(
              'PAYMENT RECEIPT',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 20,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          _buildMetaRow(
            font,
            fontBold,
            receiptNo,
            bookingId,
            paymentDate,
            paymentData['status']?.toString() ?? 'Captured',
            paymentData['paymentMethod']?.toString() ?? 'Razorpay',
            paymentData['paymentId']?.toString(),
            paymentData['orderId']?.toString(),
            paymentData['currency']?.toString() ?? 'INR',
          ),
          pw.SizedBox(height: 18),

          // Tenant and Property Info
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildTenantInfo(tenantData, font, fontBold),
              ),
              pw.SizedBox(width: 40),
              pw.Expanded(
                child:
                    _buildPropertyInfo(propertyData, ownerData, font, fontBold),
              ),
            ],
          ),
          pw.SizedBox(height: 30),

          // Booking Details
          _buildBookingDetails(checkInDate, checkoutDate, bookingPeriodMonths,
              paymentDate, font, fontBold),
          pw.SizedBox(height: 30),

          // Payment Table
          _buildPaymentTable(
              NumberFormat.currency(locale: 'en_IN', symbol: '₹'),
              rentAmount,
              depositAmount,
              totalAmount,
              font,
              fontBold,
              checkInDate),
          pw.SizedBox(height: 30),

          // Payment Information
          _buildPaymentInfo(
            paymentData['paymentId']?.toString(),
            paymentData['status']?.toString() ?? 'Captured',
            paymentData['paymentMethod']?.toString() ?? 'Razorpay',
            paymentData['currency']?.toString() ?? 'INR',
            font,
            fontBold,
          ),
          pw.SizedBox(height: 20),

          // Notes Section
          if (notes != null && notes.isNotEmpty) ...[
            _buildNotesSection(notes, font, fontBold),
            pw.SizedBox(height: 20),
          ],

          // Terms and Conditions
          _buildTermsSection(font, fontBold),
        ],
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader(
      pw.Font font, pw.Font fontBold, pw.ImageProvider? logoImage) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logoImage != null) pw.Image(logoImage, width: 56, height: 56),
          if (logoImage != null) pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(AppConfig.companyName,
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 18, color: PdfColors.black)),
                if (AppConfig.companyTagline.isNotEmpty)
                  pw.Text(AppConfig.companyTagline,
                      style: pw.TextStyle(
                          font: font, fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${AppConfig.companyAddressLine1}${AppConfig.companyAddressLine2.isNotEmpty ? ' • ' + AppConfig.companyAddressLine2 : ''}',
                  style: pw.TextStyle(
                      font: font, fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(AppConfig.supportEmail,
                  style: pw.TextStyle(
                      font: font, fontSize: 9, color: PdfColors.grey700)),
              pw.Text(AppConfig.supportPhone,
                  style: pw.TextStyle(
                      font: font, fontSize: 9, color: PdfColors.grey700)),
              if (AppConfig.companyWebsite.isNotEmpty)
                pw.UrlLink(
                  destination: AppConfig.companyWebsite,
                  child: pw.Text(AppConfig.companyWebsite,
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 9,
                          color: PdfColors.blue800,
                          decoration: pw.TextDecoration.underline)),
                ),
            ],
          )
        ],
      ),
    );
  }

  static pw.Widget _buildTenantInfo(
    Map<String, dynamic> tenantData,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TENANT DETAILS',
            style: pw.TextStyle(
                font: fontBold, fontSize: 14, color: PdfColors.blue800),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            '${tenantData['firstName'] ?? ''} ${tenantData['lastName'] ?? ''}',
            style: pw.TextStyle(font: fontBold, fontSize: 12),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Email: ${tenantData['tenantEmail'] ?? ''}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
          pw.Text(
            'Phone: ${tenantData['mobileNumber'] ?? ''}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
          pw.Text(
            'Gender: ${tenantData['gender'] ?? ''}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPropertyInfo(
    Map<String, dynamic> propertyData,
    Map<String, dynamic> ownerData,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final String ownerName = (ownerData['fullName'].toString());
    final String ownerEmail = (ownerData['email']?.toString() ??
            propertyData['ownerEmail']?.toString() ??
            '')
        .trim();
    final String ownerPhone =
        (ownerData['mobileNumber']?.toString() ?? '').trim().isNotEmpty
            ? ownerData['mobileNumber'].toString()
            : (propertyData['ownerPhone']?.toString() ?? 'Not provided');

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PROPERTY DETAILS',
            style: pw.TextStyle(
                font: fontBold, fontSize: 14, color: PdfColors.blue800),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            propertyData['title'] ?? 'N/A',
            style: pw.TextStyle(font: fontBold, fontSize: 12),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Address: ${propertyData['address'] ?? 'N/A'}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
          pw.Text(
            'Room Type: ${propertyData['roomType'] ?? 'N/A'}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'OWNER DETAILS',
            style: pw.TextStyle(
                font: fontBold, fontSize: 12, color: PdfColors.blue800),
          ),
          pw.SizedBox(height: 5),
          pw.Text('Name: $ownerName',
              style: pw.TextStyle(font: font, fontSize: 10)),
          pw.Text(
            'Email: ${ownerEmail.isNotEmpty ? ownerEmail : 'Not provided'}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
          pw.Text(
            'Contact: ${ownerPhone.isNotEmpty ? ownerPhone : 'Not provided'}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBookingDetails(
    DateTime checkInDate,
    DateTime? checkoutDate,
    int? bookingPeriodMonths,
    DateTime paymentDate,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BOOKING DETAILS',
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 14, color: PdfColors.blue800),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Move-in Date: ${DateFormat('MMM dd, yyyy').format(checkInDate)}',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
                if (checkoutDate != null)
                  pw.Text(
                    'Checkout Date: ${DateFormat('MMM dd, yyyy').format(checkoutDate)}',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                if (bookingPeriodMonths != null)
                  pw.Text(
                    'Agreement Period: ${bookingPeriodMonths} month(s)',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PAYMENT DETAILS',
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 14, color: PdfColors.blue800),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Payment Date: ${DateFormat('MMM dd, yyyy HH:mm').format(paymentDate)}',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPaymentTable(
    NumberFormat inr,
    double rentAmount,
    double depositAmount,
    double totalAmount,
    pw.Font font,
    pw.Font fontBold,
    DateTime checkInDate,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          // Header
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.blue800),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Text(
                  'DESCRIPTION',
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 12, color: PdfColors.white),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Text(
                  'AMOUNT',
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 12, color: PdfColors.white),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
          // Rent row (month-specific)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Text(
                  'Monthly Rent — ${DateFormat('MMM yyyy').format(checkInDate)}',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Text(
                  inr.format(rentAmount),
                  style: pw.TextStyle(font: font, fontSize: 12),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
          // Deposit row
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Text(
                  'Security Deposit',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Text(
                  inr.format(depositAmount),
                  style: pw.TextStyle(font: font, fontSize: 12),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
          // Total row
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Text(
                  'TOTAL PAID',
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 14, color: PdfColors.black),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Text(
                  inr.format(totalAmount),
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 14, color: PdfColors.black),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPaymentInfo(
    String? paymentId,
    String status,
    String method,
    String currency,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PAYMENT INFORMATION',
            style: pw.TextStyle(
                font: fontBold, fontSize: 14, color: PdfColors.black),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Payment ID: ${paymentId ?? 'N/A'}',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.Text(
                      'Payment Status: $status',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Payment Method: $method',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.Text(
                      'Currency: $currency (Processed by Razorpay)',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildNotesSection(
      String notes, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.yellow50,
        border: pw.Border.all(color: PdfColors.yellow200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTES',
            style: pw.TextStyle(
                font: fontBold, fontSize: 12, color: PdfColors.orange800),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            notes,
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTermsSection(pw.Font font, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TERMS & CONDITIONS',
            style: pw.TextStyle(
                font: fontBold, fontSize: 12, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '• This receipt is valid for the booking and payment transaction mentioned above.',
            style: pw.TextStyle(font: font, fontSize: 9),
          ),
          pw.Text(
            '• Refunds and cancellations are governed by our Terms of Service.',
            style: pw.TextStyle(font: font, fontSize: 9),
          ),
          pw.Text(
            '• Security deposit will be refunded as per company policy after property inspection.',
            style: pw.TextStyle(font: font, fontSize: 9),
          ),
          pw.Text(
            '• For any queries regarding this transaction, please contact our support team.',
            style: pw.TextStyle(font: font, fontSize: 9),
          ),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Text('Read: ', style: pw.TextStyle(font: font, fontSize: 9)),
            pw.UrlLink(
              destination: AppConfig.termsUrl,
              child: pw.Text('Terms',
                  style: pw.TextStyle(
                      font: font,
                      fontSize: 9,
                      color: PdfColors.blue800,
                      decoration: pw.TextDecoration.underline)),
            ),
            pw.Text('  |  ', style: pw.TextStyle(font: font, fontSize: 9)),
            pw.UrlLink(
              destination: AppConfig.privacyUrl,
              child: pw.Text('Privacy',
                  style: pw.TextStyle(
                      font: font,
                      fontSize: 9,
                      color: PdfColors.blue800,
                      decoration: pw.TextDecoration.underline)),
            ),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(
    pw.Font font, {
    required String receiptNo,
    required String bookingId,
    String? paymentId,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 18),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Contact + Verify text
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  AppConfig.companyName,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Support: ${AppConfig.supportEmail} • Helpline: ${AppConfig.supportPhone}',
                  style: pw.TextStyle(
                      font: font, fontSize: 9, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 2),
                if (AppConfig.companyWebsite.isNotEmpty)
                  pw.UrlLink(
                    destination: AppConfig.companyWebsite,
                    child: pw.Text(
                      AppConfig.companyWebsite,
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 9,
                          color: PdfColors.blue800,
                          decoration: pw.TextDecoration.underline),
                    ),
                  ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Digitally issued by ${AppConfig.companyName}. No physical signature required.',
                  style: pw.TextStyle(
                      font: font, fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          // Signature placeholder
          pw.Container(
            width: 140,
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              children: [
                pw.Text('Authorized Signatory',
                    style: pw.TextStyle(
                        font: font, fontSize: 8, color: PdfColors.grey700)),
                pw.SizedBox(height: 16),
                pw.Text('${AppConfig.companyName} (Automated)',
                    style: pw.TextStyle(font: font, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // New helper: Meta row block with receipt/payment identifiers
  static pw.Widget _buildMetaRow(
    pw.Font font,
    pw.Font fontBold,
    String receiptNo,
    String bookingId,
    DateTime paymentDate,
    String paymentStatus,
    String paymentMethod,
    String? paymentId,
    String? orderId,
    String currency,
  ) {
    final tzText =
        DateFormat('dd MMM yyyy, HH:mm').format(paymentDate) + ' IST';
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _metaLine('Receipt No.', receiptNo, font, fontBold),
                _metaLine('Receipt Date', tzText, font, fontBold),
                _metaLine('Booking ID', bookingId, font, fontBold),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _metaLine('Payment Status', paymentStatus, font, fontBold),
                _metaLine('Payment Method', paymentMethod, font, fontBold),
                _metaLine('Payment ID', paymentId ?? 'N/A', font, fontBold),
                if (orderId != null && orderId.isNotEmpty)
                  _metaLine('Order ID', orderId, font, fontBold),
                _metaLine('Currency', currency, font, fontBold),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaLine(
      String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 90,
            child: pw.Text(label,
                style: pw.TextStyle(
                    font: fontBold, fontSize: 10, color: PdfColors.grey800)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    font: font, fontSize: 10, color: PdfColors.black)),
          ),
        ],
      ),
    );
  }
}
